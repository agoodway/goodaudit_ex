defmodule GA.Compliance do
  @moduledoc """
  Context for account-scoped compliance framework profiles.
  """

  import Ecto.Query, warn: false

  alias GA.Compliance.AccountComplianceFramework
  alias GA.Compliance.ActionMapping
  alias GA.Repo

  @registry %{
    "hipaa" => GA.Compliance.Frameworks.HIPAA,
    "soc2" => GA.Compliance.Frameworks.SOC2,
    "pci_dss" => GA.Compliance.Frameworks.PCIDSS,
    "gdpr" => GA.Compliance.Frameworks.GDPR,
    "iso_27001" => GA.Compliance.Frameworks.ISO27001,
    "iso27001" => GA.Compliance.Frameworks.ISO27001
  }

  @doc """
  Returns the built-in framework registry keyed by framework ID.
  """
  def registry, do: @registry

  @doc """
  Resolves a framework ID to its module.
  """
  def get_framework(framework_id) when is_binary(framework_id) do
    case Map.fetch(@registry, framework_id) do
      {:ok, module} -> {:ok, module}
      :error -> {:error, :unknown_framework}
    end
  end

  def get_framework(_framework_id), do: {:error, :unknown_framework}

  @doc """
  Returns a deduplicated union of required fields across framework IDs.
  Unknown IDs are skipped.
  """
  def required_fields_for_frameworks(framework_ids) when is_list(framework_ids) do
    framework_ids
    |> Enum.reduce([], fn framework_id, acc ->
      case get_framework(framework_id) do
        {:ok, module} -> acc ++ module.required_fields()
        {:error, :unknown_framework} -> acc
      end
    end)
    |> Enum.uniq()
  end

  def required_fields_for_frameworks(_framework_ids), do: []

  @doc """
  Returns active framework association records for an account.
  """
  def list_active_frameworks(account_id) when is_binary(account_id) do
    from(association in AccountComplianceFramework,
      where: association.account_id == ^account_id,
      order_by: [asc: association.enabled_at, asc: association.framework]
    )
    |> Repo.all()
  end

  def list_active_frameworks(_account_id), do: []

  @doc """
  Returns active framework ID strings for an account.
  """
  def active_framework_ids(account_id) when is_binary(account_id) do
    from(association in AccountComplianceFramework,
      where: association.account_id == ^account_id,
      order_by: [asc: association.enabled_at, asc: association.framework],
      select: association.framework
    )
    |> Repo.all()
  end

  def active_framework_ids(_account_id), do: []

  @doc """
  Activates a compliance framework for an account.
  """
  def activate_framework(account_id, framework, opts \\ [])

  def activate_framework(account_id, framework, opts)
      when is_binary(account_id) and is_binary(framework) do
    attrs = %{
      account_id: account_id,
      framework: framework,
      action_validation_mode: action_validation_mode_from_opts(opts),
      enabled_at: DateTime.utc_now() |> DateTime.truncate(:microsecond),
      config_overrides: config_overrides_from_opts(opts)
    }

    %AccountComplianceFramework{}
    |> AccountComplianceFramework.changeset(attrs, valid_framework_ids: Map.keys(@registry))
    |> Repo.insert()
  end

  def activate_framework(_account_id, _framework, _opts) do
    %AccountComplianceFramework{}
    |> AccountComplianceFramework.changeset(%{}, valid_framework_ids: Map.keys(@registry))
    |> then(&{:error, &1})
  end

  @doc """
  Deactivates a framework for an account.
  """
  def deactivate_framework(account_id, framework) when is_binary(account_id) and is_binary(framework) do
    case Repo.get_by(AccountComplianceFramework,
           account_id: account_id,
           framework: framework
         ) do
      nil -> {:error, :not_found}
      association -> Repo.delete(association)
    end
  end

  def deactivate_framework(_account_id, _framework), do: {:error, :not_found}

  @doc """
  Returns the effective runtime config for an active framework association.
  """
  def effective_config(account_id, framework) when is_binary(account_id) and is_binary(framework) do
    with {:ok, module} <- get_framework(framework),
         %AccountComplianceFramework{} = association <-
           Repo.get_by(AccountComplianceFramework,
             account_id: account_id,
             framework: framework
           ) do
      overrides = association.config_overrides || %{}

      required_fields =
        module.required_fields()
        |> Kernel.++(Map.get(overrides, "additional_required_fields", []))
        |> Enum.uniq()

      {:ok,
       %{
         retention_days: Map.get(overrides, "retention_days", module.default_retention_days()),
         verification_cadence_hours:
           Map.get(overrides, "verification_cadence_hours", module.verification_cadence_hours()),
         required_fields: required_fields
       }}
    else
      nil -> {:error, :not_active}
      {:error, :unknown_framework} -> {:error, :unknown_framework}
    end
  end

  def effective_config(_account_id, _framework), do: {:error, :not_active}

  @doc """
  Validates an action against all strict-mode frameworks enabled for an account.
  """
  @spec validate_action_for_strict_frameworks(String.t(), String.t() | nil) ::
          :ok | {:error, Ecto.Changeset.t()}
  def validate_action_for_strict_frameworks(account_id, action)
      when is_binary(account_id) and is_binary(action) do
    strict_frameworks =
      from(association in AccountComplianceFramework,
        where:
          association.account_id == ^account_id and
            association.action_validation_mode == "strict",
        select: association.framework
      )
      |> Repo.all()
      |> Enum.uniq()

    unknown_frameworks =
      Enum.reduce(strict_frameworks, [], fn framework, acc ->
        with {:ok, module} <- GA.Compliance.Taxonomy.get(framework),
             false <- action in module.actions(),
             false <- ActionMapping.mapped_action?(account_id, framework, action) do
          [framework | acc]
        else
          _ -> acc
        end
      end)
      |> Enum.sort()

    case unknown_frameworks do
      [] ->
        :ok

      frameworks ->
        {:error, strict_action_error_changeset(action, frameworks)}
    end
  end

  def validate_action_for_strict_frameworks(_account_id, _action), do: :ok

  defp config_overrides_from_opts(opts) when is_list(opts),
    do: Keyword.get(opts, :config_overrides, %{})

  defp config_overrides_from_opts(opts) when is_map(opts),
    do: Map.get(opts, :config_overrides, %{})

  defp config_overrides_from_opts(_opts), do: %{}

  defp action_validation_mode_from_opts(opts) when is_list(opts),
    do: opts |> Keyword.get(:action_validation_mode, "flexible") |> to_string()

  defp action_validation_mode_from_opts(opts) when is_map(opts),
    do: opts |> Map.get(:action_validation_mode, "flexible") |> to_string()

  defp action_validation_mode_from_opts(_opts), do: "flexible"

  defp strict_action_error_changeset(action, frameworks) do
    %GA.Audit.Log{}
    |> Ecto.Changeset.change(%{action: action})
    |> Ecto.Changeset.add_error(
      :action,
      "is not recognized by strict-mode frameworks: #{Enum.join(frameworks, ", ")}"
    )
  end
end
