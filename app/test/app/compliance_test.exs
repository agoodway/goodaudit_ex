defmodule GA.ComplianceTest do
  use GA.DataCase, async: true

  alias GA.Accounts
  alias GA.Compliance

  describe "framework registry" do
    test "returns built-in framework mappings" do
      registry = Compliance.registry()

      assert registry["hipaa"] == GA.Compliance.Frameworks.HIPAA
      assert registry["soc2"] == GA.Compliance.Frameworks.SOC2
      assert registry["pci_dss"] == GA.Compliance.Frameworks.PCIDSS
      assert registry["gdpr"] == GA.Compliance.Frameworks.GDPR
      assert registry["iso_27001"] == GA.Compliance.Frameworks.ISO27001
    end

    test "get_framework/1 resolves known and unknown IDs" do
      assert {:ok, GA.Compliance.Frameworks.SOC2} = Compliance.get_framework("soc2")
      assert {:error, :unknown_framework} = Compliance.get_framework("nope")
    end

    test "required_fields_for_frameworks/1 unions and deduplicates known framework fields" do
      hipaa = GA.Compliance.Frameworks.HIPAA.required_fields()

      combined =
        Compliance.required_fields_for_frameworks(["hipaa", "soc2", "unknown_framework"])

      assert Enum.all?(hipaa, &(&1 in combined))
      assert :actor_id in combined
      refute :phi_accessed in combined
      assert combined == Enum.uniq(combined)
      assert Compliance.required_fields_for_frameworks([]) == []
    end
  end

  describe "framework module callbacks" do
    test "built-in modules expose expected callback values" do
      assert GA.Compliance.Frameworks.HIPAA.name() == "HIPAA"
      assert :actor_id in GA.Compliance.Frameworks.HIPAA.required_fields()

      assert GA.Compliance.Frameworks.HIPAA.extension_schema().required["phi_accessed"] ==
               :boolean

      assert GA.Compliance.Frameworks.HIPAA.default_retention_days() == 2555
      assert GA.Compliance.Frameworks.HIPAA.verification_cadence_hours() == 24

      assert GA.Compliance.Frameworks.SOC2.name() == "SOC 2 Type II"
      assert :actor_id in GA.Compliance.Frameworks.SOC2.required_fields()
      assert GA.Compliance.Frameworks.SOC2.default_retention_days() == 2555

      assert GA.Compliance.Frameworks.PCIDSS.name() == "PCI-DSS v4"
      assert :actor_id in GA.Compliance.Frameworks.PCIDSS.required_fields()
      assert GA.Compliance.Frameworks.PCIDSS.default_retention_days() == 365
      assert GA.Compliance.Frameworks.PCIDSS.verification_cadence_hours() == 12

      assert GA.Compliance.Frameworks.GDPR.name() == "GDPR"
      refute :phi_accessed in GA.Compliance.Frameworks.GDPR.required_fields()
      assert GA.Compliance.Frameworks.GDPR.default_retention_days() == 1825
      assert GA.Compliance.Frameworks.GDPR.verification_cadence_hours() == 48

      assert GA.Compliance.Frameworks.ISO27001.name() == "ISO 27001"
      assert :actor_id in GA.Compliance.Frameworks.ISO27001.required_fields()
      assert GA.Compliance.Frameworks.ISO27001.default_retention_days() == 1095
      assert GA.Compliance.Frameworks.ISO27001.verification_cadence_hours() == 24
    end
  end

  describe "account framework associations" do
    test "activate_framework/3 creates associations and lists active IDs" do
      account = account_fixture()

      assert {:ok, hipaa} = Compliance.activate_framework(account.id, "hipaa")
      assert hipaa.framework == "hipaa"
      assert hipaa.account_id == account.id
      assert hipaa.action_validation_mode == "flexible"
      refute is_nil(hipaa.enabled_at)
      assert hipaa.config_overrides == %{}

      assert {:ok, _soc2} = Compliance.activate_framework(account.id, "soc2")
      assert Compliance.active_framework_ids(account.id) == ["hipaa", "soc2"]

      listed = Compliance.list_active_frameworks(account.id)
      assert Enum.map(listed, & &1.framework) == ["hipaa", "soc2"]
    end

    test "activate_framework/3 rejects unknown framework IDs" do
      account = account_fixture()

      assert {:error, changeset} = Compliance.activate_framework(account.id, "unknown_framework")
      assert "is invalid" in errors_on(changeset).framework
    end

    test "activate_framework/3 rejects duplicate activation for same account + framework" do
      account = account_fixture()
      assert {:ok, _} = Compliance.activate_framework(account.id, "hipaa")

      assert {:error, changeset} = Compliance.activate_framework(account.id, "hipaa")
      assert "has already been taken" in errors_on(changeset).framework
    end

    test "deactivate_framework/2 removes active rows and returns not_found for missing rows" do
      account = account_fixture()
      assert {:ok, association} = Compliance.activate_framework(account.id, "hipaa")

      assert {:ok, deleted} = Compliance.deactivate_framework(account.id, "hipaa")
      assert deleted.id == association.id
      assert Compliance.active_framework_ids(account.id) == []

      assert {:error, :not_found} = Compliance.deactivate_framework(account.id, "hipaa")
    end

    test "activate_framework/3 enforces validation mode values" do
      account = account_fixture()

      assert {:ok, strict} =
               Compliance.activate_framework(account.id, "hipaa",
                 action_validation_mode: "strict"
               )

      assert strict.action_validation_mode == "strict"

      assert {:error, changeset} =
               Compliance.activate_framework(account.id, "soc2",
                 action_validation_mode: "invalid"
               )

      assert "is invalid" in errors_on(changeset).action_validation_mode
    end
  end

  describe "config overrides and effective_config/2" do
    test "validates override keys and value types" do
      account = account_fixture()

      assert {:ok, association} =
               Compliance.activate_framework(account.id, "hipaa",
                 config_overrides: %{"retention_days" => 3650}
               )

      assert association.config_overrides["retention_days"] == 3650

      assert {:error, invalid_key_changeset} =
               Compliance.activate_framework(account.id, "soc2",
                 config_overrides: %{"unsupported_key" => "value"}
               )

      assert "contains unsupported keys: unsupported_key" in errors_on(invalid_key_changeset).config_overrides

      assert {:error, invalid_type_changeset} =
               Compliance.activate_framework(account.id, "soc2",
                 config_overrides: %{"retention_days" => "invalid"}
               )

      assert "retention_days must be a positive integer" in errors_on(invalid_type_changeset).config_overrides
    end

    test "effective_config/2 merges defaults with overrides and additional required fields" do
      account = account_fixture()

      assert {:ok, _association} =
               Compliance.activate_framework(account.id, "hipaa",
                 config_overrides: %{
                   "retention_days" => 3650,
                   "verification_cadence_hours" => 48,
                   "additional_required_fields" => ["department"]
                 }
               )

      assert {:ok, config} = Compliance.effective_config(account.id, "hipaa")

      assert config.retention_days == 3650
      assert config.verification_cadence_hours == 48
      assert :actor_id in config.required_fields
      assert "department" in config.required_fields
    end

    test "effective_config/2 returns not_active when framework is not activated" do
      account = account_fixture()
      assert {:error, :not_active} = Compliance.effective_config(account.id, "hipaa")
    end

    test "effective_config/2 returns framework defaults when config_overrides is empty" do
      account = account_fixture()
      {:ok, _} = Compliance.activate_framework(account.id, "hipaa")

      assert {:ok, config} = Compliance.effective_config(account.id, "hipaa")

      assert config.retention_days == GA.Compliance.Frameworks.HIPAA.default_retention_days()

      assert config.verification_cadence_hours ==
               GA.Compliance.Frameworks.HIPAA.verification_cadence_hours()

      assert :actor_id in config.required_fields
    end
  end

  describe "get_active_framework/2" do
    test "returns association when active" do
      account = account_fixture()
      {:ok, activated} = Compliance.activate_framework(account.id, "hipaa")

      assert {:ok, found} = Compliance.get_active_framework(account.id, "hipaa")
      assert found.id == activated.id
      assert found.framework == "hipaa"
    end

    test "returns not_found when not active" do
      account = account_fixture()
      assert {:error, :not_found} = Compliance.get_active_framework(account.id, "hipaa")
    end
  end

  describe "update_framework_config/3" do
    test "updates validation mode from flexible to strict" do
      account = account_fixture()
      {:ok, _} = Compliance.activate_framework(account.id, "hipaa")

      assert {:ok, updated} =
               Compliance.update_framework_config(account.id, "hipaa", %{
                 action_validation_mode: "strict"
               })

      assert updated.action_validation_mode == "strict"
    end

    test "updates config_overrides retention_days" do
      account = account_fixture()
      {:ok, _} = Compliance.activate_framework(account.id, "hipaa")

      assert {:ok, updated} =
               Compliance.update_framework_config(account.id, "hipaa", %{
                 config_overrides: %{"retention_days" => 3650}
               })

      assert updated.config_overrides["retention_days"] == 3650
    end

    test "rejects invalid override key" do
      account = account_fixture()
      {:ok, _} = Compliance.activate_framework(account.id, "hipaa")

      assert {:error, changeset} =
               Compliance.update_framework_config(account.id, "hipaa", %{
                 config_overrides: %{"bad_key" => "value"}
               })

      assert "contains unsupported keys: bad_key" in errors_on(changeset).config_overrides
    end

    test "returns not_found for non-existent framework" do
      account = account_fixture()

      assert {:error, :not_found} =
               Compliance.update_framework_config(account.id, "hipaa", %{
                 action_validation_mode: "strict"
               })
    end
  end

  describe "count_active_frameworks/1" do
    test "returns 0 with no frameworks" do
      account = account_fixture()
      assert Compliance.count_active_frameworks(account.id) == 0
    end

    test "returns correct count after activating frameworks" do
      account = account_fixture()
      {:ok, _} = Compliance.activate_framework(account.id, "hipaa")
      {:ok, _} = Compliance.activate_framework(account.id, "soc2")

      assert Compliance.count_active_frameworks(account.id) == 2
    end
  end

  defp account_fixture do
    {:ok, account} =
      Accounts.create_account(%{name: "Compliance Account #{System.unique_integer([:positive])}"})

    account
  end
end
