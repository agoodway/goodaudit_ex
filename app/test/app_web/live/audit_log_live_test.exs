defmodule GAWeb.AuditLogLiveTest do
  use GAWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import GA.AccountsFixtures

  alias GA.Accounts
  alias GA.Audit
  alias GA.Compliance

  setup %{conn: conn} do
    user = user_fixture()
    {:ok, account} = Accounts.create_account(user, %{name: "Audit Log Test Account"})
    {:ok, _} = Compliance.activate_framework(account.id, "hipaa")
    conn = log_in_user(conn, user)
    %{conn: conn, user: user, account: account}
  end

  defp audit_logs_path(account), do: ~p"/dashboard/accounts/#{account}/audit-logs"

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

  defp scoped_html(view) do
    view |> element("#audit-log-viewer") |> render()
  end

  describe "mount and table rendering" do
    test "renders audit log table with entries", %{conn: conn, account: account} do
      log = create_log(account.id, %{action: "user.login", actor_id: "user-42"})
      {:ok, view, _html} = live(conn, audit_logs_path(account))

      content = scoped_html(view)
      assert content =~ "Audit Logs"
      assert content =~ "user.login"
      assert content =~ "user-42"
      assert content =~ to_string(log.sequence_number)
    end

    test "sidebar link is present and active", %{conn: conn, account: account} do
      {:ok, _view, html} = live(conn, audit_logs_path(account))

      assert html =~ "hero-document-text"
      assert html =~ "Audit Logs"
    end

    test "renders empty state when no entries", %{conn: conn, account: account} do
      {:ok, view, _html} = live(conn, audit_logs_path(account))

      content = scoped_html(view)
      assert content =~ "No audit log entries yet"
    end
  end

  describe "filter application" do
    setup %{account: account} do
      _log_a =
        create_log(account.id, %{
          action: "user.login",
          actor_id: "alice",
          resource_type: "session",
          outcome: "success"
        })

      _log_b =
        create_log(account.id, %{
          action: "record.remove",
          actor_id: "bob",
          resource_type: "document",
          outcome: "failure",
          failure_reason: "unauthorized"
        })

      :ok
    end

    test "filtering by action updates results", %{conn: conn, account: account} do
      {:ok, view, _html} = live(conn, audit_logs_path(account))

      content = scoped_html(view)
      assert content =~ "user.login"
      assert content =~ "record.remove"

      {:ok, view, _html} =
        live(conn, audit_logs_path(account) <> "?action=user.login")

      content = scoped_html(view)
      assert content =~ "user.login"
      refute content =~ "record.remove"
    end

    test "filter event handler triggers push_patch", %{conn: conn, account: account} do
      {:ok, view, _html} = live(conn, audit_logs_path(account))

      view
      |> form("form", %{"action" => "user.login"})
      |> render_change()

      content = scoped_html(view)
      assert content =~ "user.login"
    end

    test "filtering by actor_id updates results", %{conn: conn, account: account} do
      {:ok, view, _html} =
        live(conn, audit_logs_path(account) <> "?actor_id=alice")

      content = scoped_html(view)
      assert content =~ "alice"
      refute content =~ "bob"
    end

    test "filtering by outcome updates results", %{conn: conn, account: account} do
      {:ok, view, _html} =
        live(conn, audit_logs_path(account) <> "?outcome=failure")

      content = scoped_html(view)
      assert content =~ "record.remove"
      refute content =~ "user.login"
    end

    test "invalid outcome filter is ignored", %{conn: conn, account: account} do
      {:ok, view, _html} =
        live(conn, audit_logs_path(account) <> "?outcome=arbitrary_value")

      content = scoped_html(view)
      # Both entries should be visible since invalid outcome is treated as "All"
      assert content =~ "user.login"
      assert content =~ "record.remove"
    end

    test "filtering by resource_type updates results", %{conn: conn, account: account} do
      {:ok, view, _html} =
        live(conn, audit_logs_path(account) <> "?resource_type=session")

      content = scoped_html(view)
      assert content =~ "user.login"
      refute content =~ "record.remove"
    end

    test "empty state shown when no entries match filters", %{conn: conn, account: account} do
      {:ok, view, _html} =
        live(conn, audit_logs_path(account) <> "?action=nonexistent")

      content = scoped_html(view)
      assert content =~ "No entries match the current filters"
    end
  end

  describe "PHI filter" do
    test "phi_accessed filter shows only PHI entries", %{conn: conn, account: account} do
      create_log(account.id, %{
        action: "phi.access",
        extensions: %{"hipaa" => %{"phi_accessed" => true, "user_role" => "doctor"}}
      })

      create_log(account.id, %{
        action: "normal.access",
        extensions: %{"hipaa" => %{"phi_accessed" => false, "user_role" => "admin"}}
      })

      {:ok, view, _html} =
        live(conn, audit_logs_path(account) <> "?phi_accessed=true")

      content = scoped_html(view)
      assert content =~ "phi.access"
      refute content =~ "normal.access"
    end
  end

  describe "cursor pagination" do
    setup %{account: account} do
      logs =
        for i <- 1..3 do
          create_log(account.id, %{
            action: "paginate_action_#{i}",
            actor_id: "actor_#{i}"
          })
        end

      %{logs: logs}
    end

    test "next page advances cursor", %{conn: conn, account: account, logs: logs} do
      first_log = hd(logs)

      {:ok, view, _html} =
        live(conn, audit_logs_path(account) <> "?after_sequence=#{first_log.sequence_number}")

      content = scoped_html(view)
      refute content =~ "paginate_action_1"
      assert content =~ "paginate_action_2"
    end

    test "next_page event with nil cursor is safe", %{conn: conn, account: account} do
      # Create just one entry (no second page, so next_cursor will be nil)
      create_log(account.id, %{action: "solo_entry"})

      {:ok, view, _html} = live(conn, audit_logs_path(account))

      # Simulate crafted event push with no next_cursor
      html = render_click(view, "next_page")
      assert html =~ "solo_entry"
    end

    test "back_to_start event resets cursor", %{conn: conn, account: account} do
      {:ok, view, _html} =
        live(conn, audit_logs_path(account) <> "?after_sequence=999999")

      # Click back_to_start
      html = render_click(view, "back_to_start")
      assert html =~ "paginate_action_1"
    end

    test "back to start resets cursor via URL", %{conn: conn, account: account, logs: _logs} do
      {:ok, _view, html} =
        live(conn, audit_logs_path(account) <> "?after_sequence=999999")

      assert html =~ "No audit log entries" or html =~ "No entries match"

      {:ok, _view, html} = live(conn, audit_logs_path(account))
      assert html =~ "paginate_action_1"
    end
  end

  describe "inline detail expansion" do
    test "clicking row shows detail panel with metadata and checksums", %{
      conn: conn,
      account: account
    } do
      log =
        create_log(account.id, %{
          metadata: %{"ip_address" => "10.0.0.1"},
          extensions: %{
            "hipaa" => %{"phi_accessed" => false, "user_role" => "admin", "session_id" => "sess-1"}
          }
        })

      {:ok, view, _html} = live(conn, audit_logs_path(account))

      html =
        view
        |> element("#log-#{log.id}")
        |> render_click()

      assert html =~ "Checksums"
      assert html =~ log.checksum
      assert html =~ "ip_address"
      assert html =~ "10.0.0.1"
    end

    test "clicking expanded row collapses it", %{conn: conn, account: account} do
      log = create_log(account.id)

      {:ok, view, _html} = live(conn, audit_logs_path(account))

      view |> element("#log-#{log.id}") |> render_click()
      html = view |> element("#log-#{log.id}") |> render_click()

      refute html =~ "Checksums"
    end

    test "detail shows empty state for nil metadata", %{
      conn: conn,
      account: account
    } do
      log =
        create_log(account.id, %{
          metadata: %{}
        })

      {:ok, view, _html} = live(conn, audit_logs_path(account))

      view |> element("#log-#{log.id}") |> render_click()

      content = scoped_html(view)
      assert content =~ "No metadata"
    end

    test "toggle_detail with cross-account log ID returns no data", %{
      conn: conn,
      account: account
    } do
      other_user = user_fixture()
      {:ok, other_account} = Accounts.create_account(other_user, %{name: "Other Account"})
      {:ok, _} = Compliance.activate_framework(other_account.id, "hipaa")
      other_log = create_log(other_account.id, %{action: "secret_action"})

      # Create a log in current account so the table renders
      create_log(account.id, %{action: "visible_action"})

      {:ok, view, _html} = live(conn, audit_logs_path(account))

      # Try to expand the other account's log via crafted event
      html = render_click(view, "toggle_detail", %{"id" => other_log.id})

      refute html =~ "secret_action"
      refute html =~ "Checksums"
    end
  end

  describe "JSON export" do
    test "export redirects to controller download", %{conn: conn, account: account} do
      create_log(account.id, %{action: "export_test", actor_id: "exporter"})

      {:ok, view, _html} = live(conn, audit_logs_path(account))
      assert {:error, {:redirect, %{to: path}}} = render_click(view, "export_json")
      assert path =~ "/audit-logs/export"
    end
  end

  describe "URL query parameter round-trip" do
    test "filter state is preserved in URL and restored on navigation", %{
      conn: conn,
      account: account
    } do
      create_log(account.id, %{action: "user.login", actor_id: "alice"})
      create_log(account.id, %{action: "record.remove", actor_id: "bob"})

      {:ok, view, _html} =
        live(conn, audit_logs_path(account) <> "?action=user.login&actor_id=alice")

      content = scoped_html(view)
      assert content =~ "user.login"
      assert content =~ "alice"
      refute content =~ "record.remove"
    end
  end

  describe "account scoping" do
    test "entries from other accounts are not visible", %{conn: conn, account: account} do
      create_log(account.id, %{action: "visible_action"})

      other_user = user_fixture()
      {:ok, other_account} = Accounts.create_account(other_user, %{name: "Other Account"})
      {:ok, _} = Compliance.activate_framework(other_account.id, "hipaa")
      create_log(other_account.id, %{action: "hidden_action"})

      {:ok, view, _html} = live(conn, audit_logs_path(account))

      content = scoped_html(view)
      assert content =~ "visible_action"
      refute content =~ "hidden_action"
    end
  end
end
