defmodule GA.Compliance.ActionMappingTest do
  use GA.DataCase, async: false

  alias GA.Accounts
  alias GA.Audit
  alias GA.Compliance.ActionMapping

  describe "CRUD" do
    test "create_mapping/2 validates framework/path, enforces uniqueness, and supports list/update/delete" do
      account = account_fixture()
      other_account = account_fixture()

      assert {:ok, mapping} =
               ActionMapping.create_mapping(account.id, %{
                 custom_action: "patient_chart_viewed",
                 framework: "hipaa",
                 taxonomy_path: "access.phi.phi_read"
               })

      assert mapping.framework == "hipaa"
      assert mapping.taxonomy_version == "1.0.0"

      assert {:error, changeset} =
               ActionMapping.create_mapping(account.id, %{
                 custom_action: "bad_framework",
                 framework: "unknown",
                 taxonomy_path: "access.phi.phi_read"
               })

      assert "is invalid" in errors_on(changeset).framework

      assert {:error, changeset} =
               ActionMapping.create_mapping(account.id, %{
                 custom_action: "bad_path",
                 framework: "hipaa",
                 taxonomy_path: "access.phi.nonexistent"
               })

      assert "is invalid" in errors_on(changeset).taxonomy_path

      assert {:error, changeset} =
               ActionMapping.create_mapping(account.id, %{
                 custom_action: "patient_chart_viewed",
                 framework: "hipaa",
                 taxonomy_path: "access.phi.phi_read"
               })

      assert "has already been taken" in errors_on(changeset).custom_action

      assert {:ok, _other_mapping} =
               ActionMapping.create_mapping(other_account.id, %{
                 custom_action: "patient_chart_viewed",
                 framework: "hipaa",
                 taxonomy_path: "access.phi.phi_read"
               })

      assert [listed] = ActionMapping.list_mappings(account.id)
      assert listed.id == mapping.id
      assert [hipaa_only] = ActionMapping.list_mappings(account.id, framework: "hipaa")
      assert hipaa_only.id == mapping.id

      assert [action_only] =
               ActionMapping.list_mappings(account.id, custom_action: "patient_chart_viewed")

      assert action_only.id == mapping.id

      assert {:ok, updated} =
               ActionMapping.update_mapping(account.id, mapping.id, %{
                 taxonomy_path: "access.phi.phi_write"
               })

      assert updated.taxonomy_path == "access.phi.phi_write"
      assert updated.taxonomy_version == "1.0.0"

      assert {:error, :not_found} =
               ActionMapping.update_mapping(other_account.id, mapping.id, %{
                 taxonomy_path: "access.phi.phi_delete"
               })

      assert {:error, changeset} =
               ActionMapping.update_mapping(account.id, mapping.id, %{
                 taxonomy_path: "nonexistent.path"
               })

      assert "is invalid" in errors_on(changeset).taxonomy_path

      assert {:error, :not_found} = ActionMapping.delete_mapping(other_account.id, mapping.id)
      assert {:ok, deleted} = ActionMapping.delete_mapping(account.id, mapping.id)
      assert deleted.id == mapping.id
      assert ActionMapping.list_mappings(account.id) == []
    end
  end

  describe "resolve_actions/3 and validate_actions/2" do
    test "resolves canonical + mapped actions and reports dry-run gaps" do
      account = account_fixture()

      assert {:ok, _} =
               ActionMapping.create_mapping(account.id, %{
                 custom_action: "patient_chart_viewed",
                 framework: "hipaa",
                 taxonomy_path: "access.phi.phi_read"
               })

      assert {:ok, _} =
               ActionMapping.create_mapping(account.id, %{
                 custom_action: "nurse_login",
                 framework: "hipaa",
                 taxonomy_path: "access.system.login"
               })

      assert {:ok, resolved} = ActionMapping.resolve_actions(account.id, "hipaa", "access.*")
      assert "phi_read" in resolved.taxonomy_actions
      assert "session_timeout" in resolved.taxonomy_actions
      assert resolved.mapped_actions == ["nurse_login", "patient_chart_viewed"]

      assert {:error, :unknown_framework} =
               ActionMapping.resolve_actions(account.id, "unknown", "access.*")

      assert {:error, :invalid_path} =
               ActionMapping.resolve_actions(account.id, "hipaa", "access.nonexistent.*")

      assert {:ok, _} = Audit.create_log_entry(account.id, valid_attrs(%{action: "phi_read"}))

      assert {:ok, _} =
               Audit.create_log_entry(account.id, valid_attrs(%{action: "patient_chart_viewed"}))

      assert {:ok, _} = Audit.create_log_entry(account.id, valid_attrs(%{action: "custom_event"}))

      assert {:ok, report} = ActionMapping.validate_actions(account.id, "hipaa")
      assert "phi_read" in report.recognized
      assert "patient_chart_viewed" in report.recognized
      assert report.unmapped == ["custom_event"]
    end
  end

  defp account_fixture do
    {:ok, account} =
      Accounts.create_account(%{
        name: "Action Mapping Account #{System.unique_integer([:positive])}"
      })

    account
  end

  defp valid_attrs(overrides \\ %{}) do
    defaults = %{
      actor_id: Ecto.UUID.generate(),
      action: "read",
      resource_type: "patient",
      resource_id: Ecto.UUID.generate(),
      timestamp: ~U[2026-03-04 16:00:00Z],
      outcome: "success",
      extensions: %{},
      metadata: %{"source" => "action_mapping_test"}
    }

    Map.merge(defaults, overrides)
  end
end
