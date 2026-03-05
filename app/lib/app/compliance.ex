defmodule GA.Compliance do
  @moduledoc """
  Context for account-scoped compliance framework profiles.
  """

  import Ecto.Query, warn: false

  alias GA.Compliance.AccountComplianceFramework
  alias GA.Repo

  @registry %{
    "hipaa" => GA.Compliance.Frameworks.HIPAA,
    "soc2" => GA.Compliance.Frameworks.SOC2,
    "pci_dss" => GA.Compliance.Frameworks.PCIDSS,
    "gdpr" => GA.Compliance.Frameworks.GDPR,
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
      order_by: [asc: association.activated_at, asc: association.framework_id]
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
      order_by: [asc: association.activated_at, asc: association.framework_id],
      select: association.framework_id
    )
    |> Repo.all()
  end

  def active_framework_ids(_account_id), do: []

  @doc """
  Activates a compliance framework for an account.
  """
  def activate_framework(account_id, framework_id, opts \\ [])

  def activate_framework(account_id, framework_id, opts)
      when is_binary(account_id) and is_binary(framework_id) do
    attrs = %{
      account_id: account_id,
      framework_id: framework_id,
      activated_at: DateTime.utc_now() |> DateTime.truncate(:microsecond),
      config_overrides: config_overrides_from_opts(opts)
    }

    %AccountComplianceFramework{}
    |> AccountComplianceFramework.changeset(attrs, valid_framework_ids: Map.keys(@registry))
    |> Repo.insert()
  end

  def activate_framework(_account_id, _framework_id, _opts) do
    %AccountComplianceFramework{}
    |> AccountComplianceFramework.changeset(%{}, valid_framework_ids: Map.keys(@registry))
    |> then(&{:error, &1})
  end

  @doc """
  Deactivates a framework for an account.
  """
  def deactivate_framework(account_id, framework_id)
      when is_binary(account_id) and is_binary(framework_id) do
    case Repo.get_by(AccountComplianceFramework,
           account_id: account_id,
           framework_id: framework_id
         ) do
      nil -> {:error, :not_found}
      association -> Repo.delete(association)
    end
  end

  def deactivate_framework(_account_id, _framework_id), do: {:error, :not_found}

  @doc """
  Returns the effective runtime config for an active framework association.
  """
  def effective_config(account_id, framework_id)
      when is_binary(account_id) and is_binary(framework_id) do
    with {:ok, module} <- get_framework(framework_id),
         %AccountComplianceFramework{} = association <-
           Repo.get_by(AccountComplianceFramework,
             account_id: account_id,
             framework_id: framework_id
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

  def effective_config(_account_id, _framework_id), do: {:error, :not_active}

  defp config_overrides_from_opts(opts) when is_list(opts),
    do: Keyword.get(opts, :config_overrides, %{})

  defp config_overrides_from_opts(opts) when is_map(opts),
    do: Map.get(opts, :config_overrides, %{})

  defp config_overrides_from_opts(_opts), do: %{}
end
