defmodule GA.Compliance.ExtensionSchemaTest do
  use GA.DataCase, async: true

  alias GA.Compliance.ExtensionSchema

  test "validate/2 accepts valid HIPAA extensions" do
    extensions = %{"hipaa" => %{"phi_accessed" => true, "user_role" => "nurse"}}

    assert {:ok, ^extensions} = ExtensionSchema.validate(["hipaa"], extensions)
  end

  test "validate/2 rejects missing required fields with namespaced errors" do
    assert {:error, changeset} =
             ExtensionSchema.validate(["hipaa"], %{"hipaa" => %{"phi_accessed" => true}})

    assert "hipaa.user_role is required" in errors_on(changeset).extensions
  end

  test "validate/2 rejects wrong field types" do
    assert {:error, changeset} =
             ExtensionSchema.validate(["hipaa"], %{
               "hipaa" => %{"phi_accessed" => "yes", "user_role" => "nurse"}
             })

    assert "hipaa.phi_accessed must be boolean" in errors_on(changeset).extensions
  end

  test "validate/2 rejects unrecognized framework keys" do
    assert {:error, changeset} =
             ExtensionSchema.validate(["hipaa"], %{
               "hipaa" => %{"phi_accessed" => true, "user_role" => "nurse"},
               "unknown_framework" => %{"field" => "value"}
             })

    assert "unknown_framework is not an active framework" in errors_on(changeset).extensions
  end

  test "validate/2 validates multiple frameworks independently" do
    extensions = %{
      "hipaa" => %{"phi_accessed" => true, "user_role" => "admin"},
      "soc2" => %{}
    }

    assert {:ok, ^extensions} = ExtensionSchema.validate(["hipaa", "soc2"], extensions)
  end

  test "validate/2 accepts empty extensions when no frameworks are active" do
    assert {:ok, %{}} = ExtensionSchema.validate([], %{})
  end

  test "validate/3 does not create atoms for unknown additional_required_fields" do
    field_name = "extension_schema_unbounded_atom_field"

    assert_raise ArgumentError, fn -> String.to_existing_atom(field_name) end

    assert {:error, changeset} =
             ExtensionSchema.validate(
               ["hipaa"],
               %{"hipaa" => %{"phi_accessed" => true, "user_role" => "nurse"}},
               %{"hipaa" => [field_name]}
             )

    assert "hipaa.#{field_name} is required" in errors_on(changeset).extensions
    assert_raise ArgumentError, fn -> String.to_existing_atom(field_name) end
  end
end
