defmodule GAWeb.DashboardLiveTest do
  use GAWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import GA.AccountsFixtures

  alias GA.Accounts
  alias GA.Audit
  alias GA.Compliance

  setup %{conn: conn} do
    user = user_fixture()
    {:ok, account} = Accounts.create_account(user, %{name: "Dashboard Test Account"})
    conn = log_in_user(conn, user)
    %{conn: conn, user: user, account: account}
  end

  defp dashboard_path(account) do
    "/dashboard/accounts/#{account.id}"
  end

  defp create_log(account_id) do
    attrs = %{
      actor_id: "actor-#{System.unique_integer([:positive])}",
      action: "create",
      resource_type: "document",
      resource_id: Ecto.UUID.generate(),
      timestamp: DateTime.utc_now(),
      outcome: "success",
      extensions: %{"hipaa" => %{"phi_accessed" => false, "user_role" => "admin"}}
    }

    {:ok, log} = Audit.create_log_entry(account_id, attrs)
    log
  end

  describe "dashboard with empty account" do
    test "renders metric cards with zero values", %{conn: conn, account: account} do
      {:ok, _view, html} = live(conn, dashboard_path(account))

      assert html =~ "Active Frameworks"
      assert html =~ "Chain Status"
      assert html =~ "Audit Logs"
      assert html =~ "API Keys"
      assert html =~ "no logs"
      assert html =~ "none configured"
      assert html =~ "none active"
    end

    test "renders empty activity state", %{conn: conn, account: account} do
      {:ok, _view, html} = live(conn, dashboard_path(account))

      assert html =~ "No audit log entries yet"
    end

    test "getting started checklist shows all incomplete", %{conn: conn, account: account} do
      {:ok, _view, html} = live(conn, dashboard_path(account))

      assert html =~ "Configure Framework"
      assert html =~ "Connect Integrations"
      assert html =~ "Create API Key"
    end
  end

  describe "dashboard with seeded data" do
    setup %{account: account, user: user} do
      # Activate a framework
      {:ok, _} = Compliance.activate_framework(account.id, "hipaa")

      # Create API keys
      account_user = Accounts.get_account_user(user, account)
      {:ok, _} = Accounts.create_api_key(account_user, %{name: "Test Key", type: :public})

      # Create audit logs
      for _ <- 1..3 do
        create_log(account.id)
      end

      :ok
    end

    test "renders real metric values", %{conn: conn, account: account} do
      {:ok, _view, html} = live(conn, dashboard_path(account))

      # Active frameworks count
      assert html =~ "Active Frameworks"
      assert html =~ "configured"

      # Audit logs count
      assert html =~ "Audit Logs"
      assert html =~ "last 30d"

      # API keys count
      assert html =~ "API Keys"
      assert html =~ "active"

      # Chain status should be verified (valid chain)
      assert html =~ "verified"
    end

    test "renders recent activity from audit logs", %{conn: conn, account: account} do
      {:ok, _view, html} = live(conn, dashboard_path(account))

      # Should show audit log actions
      assert html =~ "create"
      # Should not show the empty state
      refute html =~ "No audit log entries yet"
    end

    test "getting started checklist reflects account state", %{conn: conn, account: account} do
      {:ok, _view, html} = live(conn, dashboard_path(account))

      # Step 1 (Configure Framework) should be complete — account has hipaa active
      # Step 3 (Create API Key) should be complete — account has an API key
      # We verify the check icon appears (hero-check-mini)
      assert html =~ "hero-check-mini"
    end
  end
end
