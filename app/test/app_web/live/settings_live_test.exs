defmodule GAWeb.SettingsLiveTest do
  use GAWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import GA.AccountsFixtures

  alias GA.Accounts

  setup %{conn: conn} do
    user = user_fixture()
    {:ok, account} = Accounts.create_account(user, %{name: "Settings Test Account"})
    conn = log_in_user(conn, user)
    %{conn: conn, user: user, account: account}
  end

  defp settings_path(account), do: ~p"/dashboard/accounts/#{account}/settings"
  defp members_path(account), do: ~p"/dashboard/accounts/#{account}/settings/members"
  defp security_path(account), do: ~p"/dashboard/accounts/#{account}/settings/security"

  describe "mount and tab rendering" do
    test "renders settings page with General tab active", %{conn: conn, account: account} do
      {:ok, _view, html} = live(conn, settings_path(account))

      assert html =~ "Account Settings"
      assert html =~ "General"
      assert html =~ "Members"
      assert html =~ "Security"
      assert html =~ account.name
    end

    test "loads account and role correctly", %{conn: conn, account: account} do
      {:ok, _view, html} = live(conn, settings_path(account))

      assert html =~ "Account Name"
      assert html =~ account.id
    end
  end

  describe "role-based tab access" do
    test "owner sees all tabs", %{conn: conn, account: account} do
      {:ok, _view, html} = live(conn, settings_path(account))

      assert html =~ "General"
      assert html =~ "Members"
      assert html =~ "Security"
      assert html =~ "Danger Zone"
    end

    test "admin sees General and Members tabs", %{conn: conn, account: account} do
      admin = user_fixture()
      {:ok, _} = Accounts.add_user_to_account(account, admin, :admin)
      admin_conn = log_in_user(conn, admin)

      {:ok, _view, html} = live(admin_conn, settings_path(account))

      assert html =~ "General"
      assert html =~ "Members"
      refute html =~ "Security"
      refute html =~ "Danger Zone"
    end

    test "member sees General only", %{conn: conn, account: account} do
      member = user_fixture()
      {:ok, _} = Accounts.add_user_to_account(account, member, :member)
      member_conn = log_in_user(conn, member)

      {:ok, _view, html} = live(member_conn, settings_path(account))

      assert html =~ "General"
      refute html =~ ">Members<"
      refute html =~ "Security"
      refute html =~ "Danger Zone"
    end
  end

  describe "role-based redirect" do
    test "member accessing /settings/members redirects to /settings", %{
      conn: conn,
      account: account
    } do
      member = user_fixture()
      {:ok, _} = Accounts.add_user_to_account(account, member, :member)
      member_conn = log_in_user(conn, member)

      assert {:error, {:live_redirect, %{to: to, flash: flash}}} =
               live(member_conn, members_path(account))

      assert to == settings_path(account)
      assert flash["info"] == "You don't have access to that section."
    end

    test "admin accessing /settings/security redirects to /settings", %{
      conn: conn,
      account: account
    } do
      admin = user_fixture()
      {:ok, _} = Accounts.add_user_to_account(account, admin, :admin)
      admin_conn = log_in_user(conn, admin)

      assert {:error, {:live_redirect, %{to: to, flash: flash}}} =
               live(admin_conn, security_path(account))

      assert to == settings_path(account)
      assert flash["info"] == "You don't have access to that section."
    end
  end

  describe "General tab" do
    test "updates account name successfully", %{conn: conn, account: account} do
      {:ok, view, _html} = live(conn, settings_path(account))

      view
      |> form("form", account: %{name: "Updated Account"})
      |> render_submit()

      assert render(view) =~ "Updated Account"

      updated = Accounts.get_account(account.id)
      assert updated.name == "Updated Account"
      assert updated.slug == "updated-account"
    end

    test "shows validation error for empty name", %{conn: conn, account: account} do
      {:ok, view, _html} = live(conn, settings_path(account))

      html =
        view
        |> form("form", account: %{name: ""})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end

    test "displays account ID and slug", %{conn: conn, account: account} do
      {:ok, _view, html} = live(conn, settings_path(account))

      assert html =~ account.id
      assert html =~ account.slug
    end
  end

  describe "Members tab" do
    test "renders members table", %{conn: conn, account: account, user: user} do
      {:ok, view, _html} = live(conn, members_path(account))

      html = render(view)
      assert html =~ user.email
      assert html =~ "owner"
    end

    test "owner can change member role", %{conn: conn, account: account} do
      member = user_fixture()
      {:ok, _} = Accounts.add_user_to_account(account, member, :member)

      {:ok, view, _html} = live(conn, members_path(account))

      membership = Accounts.get_account_user(member, account)

      view
      |> element("select[data-member-id='#{membership.id}']")
      |> render_change(%{"role" => "admin", "member-id" => membership.id})

      updated = Accounts.get_account_user(member, account)
      assert updated.role == :admin
    end

    test "owner can remove member", %{conn: conn, account: account} do
      member = user_fixture()
      {:ok, _} = Accounts.add_user_to_account(account, member, :member)

      {:ok, view, _html} = live(conn, members_path(account))

      membership = Accounts.get_account_user(member, account)

      view
      |> element("button[phx-value-member-id='#{membership.id}']", "Remove")
      |> render_click()

      assert is_nil(Accounts.get_account_user(member, account))
    end

    test "admin sees read-only members table", %{conn: conn, account: account} do
      admin = user_fixture()
      {:ok, _} = Accounts.add_user_to_account(account, admin, :admin)
      admin_conn = log_in_user(conn, admin)

      {:ok, _view, html} = live(admin_conn, members_path(account))

      assert html =~ admin.email
      refute html =~ "Remove"
      refute html =~ "<select"
    end

    test "invite placeholder is shown", %{conn: conn, account: account} do
      {:ok, _view, html} = live(conn, members_path(account))

      assert html =~ "Coming soon"
      assert html =~ "Invite"
    end
  end

  describe "Security tab" do
    test "shows masked HMAC key by default", %{conn: conn, account: account} do
      {:ok, _view, html} = live(conn, security_path(account))

      assert html =~ "hmac_••••••••"
      assert html =~ "Reveal"
    end

    test "reveals HMAC key on click", %{conn: conn, account: account} do
      {:ok, view, _html} = live(conn, security_path(account))

      html =
        view
        |> element("button", "Reveal")
        |> render_click()

      refute html =~ "hmac_••••••••"
      assert html =~ "Hide"
    end

    test "hides HMAC key after reveal", %{conn: conn, account: account} do
      {:ok, view, _html} = live(conn, security_path(account))

      view |> element("button", "Reveal") |> render_click()
      html = view |> element("button", "Hide") |> render_click()

      assert html =~ "hmac_••••••••"
    end

    test "shows rotate modal with typed confirmation", %{conn: conn, account: account} do
      {:ok, view, _html} = live(conn, security_path(account))

      html =
        view
        |> element("#security-settings button[phx-click='show_rotate_modal']")
        |> render_click()

      assert html =~ "Rotate HMAC Key"
      assert html =~ "break chain verification"
    end

    test "rotates HMAC key after typing ROTATE", %{conn: conn, account: account} do
      {:ok, old_key} = Accounts.get_hmac_key(account.id)

      {:ok, view, _html} = live(conn, security_path(account))

      view |> element("button.btn-warning.btn-xs", "Rotate Key") |> render_click()

      view
      |> element("input[phx-keyup='update_rotate_confirmation']")
      |> render_keyup(%{"value" => "ROTATE"})

      view
      |> element("button[phx-click='confirm_rotate']", "Rotate Key")
      |> render_click()

      {:ok, new_key} = Accounts.get_hmac_key(account.id)
      assert new_key != old_key
    end

    test "displays account status badge", %{conn: conn, account: account} do
      {:ok, _view, html} = live(conn, security_path(account))

      assert html =~ "Account Status"
      assert html =~ "Active"
    end
  end

  describe "Danger Zone" do
    test "owner sees danger zone", %{conn: conn, account: account} do
      {:ok, _view, html} = live(conn, settings_path(account))

      assert html =~ "Danger Zone"
      assert html =~ "Delete Account"
    end

    test "non-owner does not see danger zone", %{conn: conn, account: account} do
      admin = user_fixture()
      {:ok, _} = Accounts.add_user_to_account(account, admin, :admin)
      admin_conn = log_in_user(conn, admin)

      {:ok, _view, html} = live(admin_conn, settings_path(account))

      refute html =~ "Danger Zone"
    end

    test "delete account with correct name confirmation", %{conn: conn, account: account} do
      {:ok, view, _html} = live(conn, settings_path(account))

      view |> element("button.btn-error.btn-sm", "Delete Account") |> render_click()

      view
      |> element("input[phx-keyup='update_delete_confirmation']")
      |> render_keyup(%{"value" => account.name})

      view
      |> element("button[phx-click='confirm_delete']", "Delete Account")
      |> render_click()

      assert is_nil(Accounts.get_account(account.id))
    end

    test "delete rejected when name does not match", %{conn: conn, account: account} do
      {:ok, view, _html} = live(conn, settings_path(account))

      view |> element("button.btn-error.btn-sm", "Delete Account") |> render_click()

      html =
        view
        |> element("input[phx-keyup='update_delete_confirmation']")
        |> render_keyup(%{"value" => "wrong name"})

      # Confirm button should be disabled
      assert html =~ "disabled"
    end
  end

  describe "sidebar" do
    test "Settings link points to account-scoped route", %{conn: conn, account: account} do
      {:ok, _view, html} = live(conn, settings_path(account))

      assert html =~ "/dashboard/accounts/#{account.id}/settings"
    end
  end
end
