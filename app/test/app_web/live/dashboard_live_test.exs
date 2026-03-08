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

  defp create_log(account_id, overrides \\ %{}) do
    attrs =
      Map.merge(
        %{
          actor_id: "actor-#{System.unique_integer([:positive])}",
          action: "create",
          resource_type: "document",
          resource_id: Ecto.UUID.generate(),
          timestamp: DateTime.utc_now(),
          outcome: "success",
          extensions: %{"hipaa" => %{"phi_accessed" => false, "user_role" => "admin"}}
        },
        overrides
      )

    {:ok, log} = Audit.create_log_entry(account_id, attrs)
    log
  end

  describe "dashboard with empty account" do
    test "renders metric cards with zero values", %{conn: conn, account: account} do
      {:ok, view, _html} = live(conn, dashboard_path(account))
      html = render(view)

      assert html =~ "Active Frameworks"
      assert html =~ "Chain Status"
      assert html =~ "Audit Logs"
      assert html =~ "API Keys"
      assert html =~ "no logs"
      assert html =~ "none configured"
      assert html =~ "none active"
      # Assert zero values
      assert html =~ ">0</span>"
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
      refute html =~ "hero-check-mini"
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
      {:ok, view, _html} = live(conn, dashboard_path(account))
      html = render(view)

      # Active frameworks: 1
      assert html =~ ">1</span>"
      assert html =~ "configured"

      # Audit logs: 3
      assert html =~ ">3</span>"
      assert html =~ "last 30d"

      # API keys: 1
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

      # Step 1 (Configure Framework) and Step 3 (Create API Key) should be complete
      # Assert exactly 2 check icons are rendered
      check_count =
        html
        |> String.split("hero-check-mini")
        |> length()
        |> Kernel.-(1)

      assert check_count == 2
    end
  end

  describe "dashboard with broken chain" do
    setup %{account: account} do
      {:ok, _} = Compliance.activate_framework(account.id, "hipaa")

      # Create a valid log first
      log = create_log(account.id)

      # Insert a second log with wrong previous_checksum to break the chain
      %Audit.Log{}
      |> Ecto.Changeset.change(%{
        account_id: account.id,
        sequence_number: log.sequence_number + 1,
        checksum: String.duplicate("a", 64),
        previous_checksum: String.duplicate("b", 64),
        actor_id: "breaker",
        action: "create",
        resource_type: "test",
        resource_id: Ecto.UUID.generate(),
        timestamp: DateTime.utc_now(),
        outcome: "success",
        user_id: "breaker",
        user_role: "admin"
      })
      |> GA.Repo.insert!()

      :ok
    end

    test "renders broken chain status", %{conn: conn, account: account} do
      {:ok, view, _html} = live(conn, dashboard_path(account))
      html = render(view)

      assert html =~ "broken"
      assert html =~ "status-dot--error"
    end
  end

  describe "format_number/1" do
    test "formats small numbers without commas" do
      assert GAWeb.DashboardLive.format_number(0) == "0"
      assert GAWeb.DashboardLive.format_number(999) == "999"
    end

    test "formats thousands with commas" do
      assert GAWeb.DashboardLive.format_number(1000) == "1,000"
      assert GAWeb.DashboardLive.format_number(1234) == "1,234"
    end

    test "formats millions with commas" do
      assert GAWeb.DashboardLive.format_number(1_234_567) == "1,234,567"
    end
  end

  describe "relative_time/1" do
    test "returns 'just now' for times within 60 seconds" do
      assert GAWeb.DashboardLive.relative_time(DateTime.utc_now()) == "just now"
    end

    test "returns minutes ago" do
      time = DateTime.add(DateTime.utc_now(), -120, :second)
      assert GAWeb.DashboardLive.relative_time(time) == "2 min ago"
    end

    test "returns hours ago" do
      time = DateTime.add(DateTime.utc_now(), -7200, :second)
      assert GAWeb.DashboardLive.relative_time(time) == "2 hours ago"
    end

    test "returns days ago" do
      time = DateTime.add(DateTime.utc_now(), -172_800, :second)
      assert GAWeb.DashboardLive.relative_time(time) == "2 days ago"
    end

    test "returns formatted date for old times" do
      time = DateTime.add(DateTime.utc_now(), -90, :day)
      result = GAWeb.DashboardLive.relative_time(time)
      # Should be a formatted date like "Dec 08, 2025"
      assert result =~ ~r/^\w{3} \d{2}, \d{4}$/
    end
  end
end
