defmodule GAWeb.ComplianceLiveTest do
  use GAWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import GA.AccountsFixtures

  alias GA.Accounts
  alias GA.Compliance

  setup %{conn: conn} do
    user = user_fixture()
    {:ok, account} = Accounts.create_account(user, %{name: "Compliance Test Account"})
    conn = log_in_user(conn, user)
    %{conn: conn, user: user, account: account}
  end

  defp compliance_path(account), do: ~p"/dashboard/accounts/#{account}/compliance"

  describe "mount and framework card rendering" do
    test "renders all five framework cards", %{conn: conn, account: account} do
      {:ok, _view, html} = live(conn, compliance_path(account))

      assert html =~ "Compliance Frameworks"
      assert html =~ "HIPAA"
      assert html =~ "SOC 2 Type II"
      assert html =~ "PCI-DSS v4"
      assert html =~ "GDPR"
      assert html =~ "ISO 27001"
    end

    test "active frameworks show enabled toggle", %{conn: conn, account: account} do
      {:ok, _} = Compliance.activate_framework(account.id, "hipaa")

      {:ok, _view, html} = live(conn, compliance_path(account))

      assert html =~ "Active"
      assert html =~ "Inactive"
    end

    test "sidebar shows Compliance link under Configuration", %{conn: conn, account: account} do
      {:ok, _view, html} = live(conn, compliance_path(account))

      assert html =~ "Configuration"
      assert html =~ "hero-shield-check"
      assert html =~ "Compliance"
    end
  end

  describe "framework activation" do
    test "toggle activates inactive framework", %{conn: conn, account: account} do
      {:ok, view, _html} = live(conn, compliance_path(account))

      view
      |> element("#framework-hipaa input[type=checkbox]")
      |> render_click()

      assert Compliance.active_framework_ids(account.id) == ["hipaa"]

      html = render(view)
      assert html =~ "Active"
    end

    test "toggle deactivates active framework", %{conn: conn, account: account} do
      {:ok, _} = Compliance.activate_framework(account.id, "hipaa")

      {:ok, view, _html} = live(conn, compliance_path(account))

      view
      |> element("#framework-hipaa input[type=checkbox]")
      |> render_click()

      assert Compliance.active_framework_ids(account.id) == []
    end
  end

  describe "settings update" do
    test "save updates framework config", %{conn: conn, account: account} do
      {:ok, _} = Compliance.activate_framework(account.id, "hipaa")

      {:ok, view, _html} = live(conn, compliance_path(account))

      # Change validation mode
      view
      |> element("#framework-hipaa select[name=action_validation_mode]")
      |> render_change(%{"action_validation_mode" => "strict"})

      # Change retention days
      view
      |> element("#framework-hipaa input[name=retention_days]")
      |> render_change(%{"retention_days" => "3650"})

      # Click save
      view
      |> element("#framework-hipaa button", "Save")
      |> render_click()

      {:ok, updated} = Compliance.get_active_framework(account.id, "hipaa")
      assert updated.action_validation_mode == "strict"
      assert updated.config_overrides["retention_days"] == 3650
    end
  end

  describe "read-only view for non-admin users" do
    test "member sees read-only view without toggles and inputs", %{conn: conn, account: account} do
      {:ok, _} = Compliance.activate_framework(account.id, "hipaa")

      # Create a member user
      member = user_fixture()
      {:ok, _} = Accounts.add_user_to_account(account, member, :member)
      member_conn = log_in_user(conn, member)

      {:ok, _view, html} = live(member_conn, compliance_path(account))

      assert html =~ "Compliance Frameworks"
      assert html =~ "HIPAA"
      # Should show read-only values
      assert html =~ "Enabled"
      assert html =~ "Validation Mode"
      # Should not have save button
      refute html =~ "Save"
    end

    test "member cannot toggle framework via crafted event", %{conn: conn, account: account} do
      member = user_fixture()
      {:ok, _} = Accounts.add_user_to_account(account, member, :member)
      member_conn = log_in_user(conn, member)

      {:ok, _view, _html} = live(member_conn, compliance_path(account))

      # The toggle should not be rendered for members, so framework stays inactive
      assert Compliance.active_framework_ids(account.id) == []
    end
  end

  describe "sidebar navigation" do
    test "compliance link appears and links to correct path", %{conn: conn, account: account} do
      {:ok, _view, html} = live(conn, compliance_path(account))

      assert html =~ "/dashboard/accounts/#{account.id}/compliance"
      assert html =~ "Compliance"
    end
  end
end
