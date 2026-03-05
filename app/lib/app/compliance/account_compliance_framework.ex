defmodule GA.Compliance.AccountComplianceFramework do
  @moduledoc """
  Account-level framework activation record with per-framework overrides.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @allowed_override_keys ~w(retention_days verification_cadence_hours additional_required_fields)

  schema "account_compliance_frameworks" do
    belongs_to(:account, GA.Accounts.Account)
    field(:framework_id, :string)
    field(:activated_at, :utc_datetime_usec)
    field(:config_overrides, :map, default: %{})

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Validates account-framework associations.
  """
  def changeset(association, attrs, opts \\ []) do
    valid_framework_ids =
      Keyword.get(opts, :valid_framework_ids, Map.keys(GA.Compliance.registry()))

    association
    |> cast(attrs, [:account_id, :framework_id, :activated_at, :config_overrides])
    |> validate_required([:account_id, :framework_id, :activated_at])
    |> validate_inclusion(:framework_id, valid_framework_ids)
    |> validate_config_overrides()
    |> foreign_key_constraint(:account_id)
    |> unique_constraint(:framework_id,
      name: :account_compliance_frameworks_account_id_framework_id_index
    )
  end

  defp validate_config_overrides(changeset) do
    overrides = get_field(changeset, :config_overrides) || %{}

    cond do
      not is_map(overrides) ->
        add_error(changeset, :config_overrides, "must be an object")

      true ->
        normalized = normalize_override_keys(overrides)

        with :ok <- validate_override_keys(normalized),
             :ok <- validate_retention_days(normalized),
             :ok <- validate_verification_cadence(normalized),
             :ok <- validate_additional_required_fields(normalized) do
          put_change(changeset, :config_overrides, normalized)
        else
          {:error, message} -> add_error(changeset, :config_overrides, message)
        end
    end
  end

  defp normalize_override_keys(overrides) do
    Map.new(overrides, fn {key, value} -> {to_string(key), value} end)
  end

  defp validate_override_keys(overrides) do
    unknown_keys =
      overrides
      |> Map.keys()
      |> Enum.reject(&(&1 in @allowed_override_keys))

    case unknown_keys do
      [] -> :ok
      keys -> {:error, "contains unsupported keys: #{Enum.join(keys, ", ")}"}
    end
  end

  defp validate_retention_days(overrides) do
    case Map.get(overrides, "retention_days") do
      nil -> :ok
      value when is_integer(value) and value > 0 -> :ok
      _ -> {:error, "retention_days must be a positive integer"}
    end
  end

  defp validate_verification_cadence(overrides) do
    case Map.get(overrides, "verification_cadence_hours") do
      nil -> :ok
      value when is_integer(value) and value > 0 -> :ok
      _ -> {:error, "verification_cadence_hours must be a positive integer"}
    end
  end

  defp validate_additional_required_fields(overrides) do
    case Map.get(overrides, "additional_required_fields") do
      nil ->
        :ok

      value when is_list(value) ->
        if Enum.all?(value, &valid_override_field?/1) do
          :ok
        else
          {:error, "additional_required_fields must be a list of non-empty strings"}
        end

      _ ->
        {:error, "additional_required_fields must be a list of non-empty strings"}
    end
  end

  defp valid_override_field?(value) when is_binary(value), do: String.trim(value) != ""
  defp valid_override_field?(_value), do: false
end
