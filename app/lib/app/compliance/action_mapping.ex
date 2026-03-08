defmodule GA.Compliance.ActionMapping do
  @moduledoc """
  Account-scoped custom action mappings into framework taxonomy paths.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, warn: false

  alias GA.Audit.Log
  alias GA.Compliance.Taxonomy
  alias GA.Repo

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          account_id: Ecto.UUID.t() | nil,
          account: GA.Accounts.Account.t() | Ecto.Association.NotLoaded.t() | nil,
          custom_action: String.t() | nil,
          framework: String.t() | nil,
          taxonomy_path: String.t() | nil,
          taxonomy_version: String.t() | nil,
          created_at: DateTime.t() | nil
        }

  @type resolve_result :: %{
          taxonomy_actions: [String.t()],
          mapped_actions: [String.t()]
        }

  schema "account_action_mappings" do
    belongs_to(:account, GA.Accounts.Account)
    field(:custom_action, :string)
    field(:framework, :string)
    field(:taxonomy_path, :string)
    field(:taxonomy_version, :string)

    timestamps(type: :utc_datetime_usec, inserted_at: :created_at, updated_at: false)
  end

  @doc """
  Base mapping changeset.
  """
  def changeset(mapping, attrs) do
    mapping
    |> cast(attrs, [:account_id, :custom_action, :framework, :taxonomy_path, :taxonomy_version])
    |> validate_required([
      :account_id,
      :custom_action,
      :framework,
      :taxonomy_path,
      :taxonomy_version
    ])
    |> validate_length(:custom_action, min: 1, max: 255)
    |> validate_format(:taxonomy_version, ~r/^\d+\.\d+\.\d+$/)
    |> foreign_key_constraint(:account_id)
    |> unique_constraint(:custom_action,
      name: :account_action_mappings_account_id_custom_action_framework_inde
    )
  end

  @doc """
  Creates a new mapping after framework and taxonomy validation.
  """
  @spec create_mapping(String.t(), map() | keyword()) ::
          {:ok, t()} | {:error, Ecto.Changeset.t()}
  def create_mapping(account_id, attrs)
      when is_binary(account_id) and (is_map(attrs) or is_list(attrs)) do
    attrs = normalize_attrs(attrs)
    framework = get_attr(attrs, :framework)
    taxonomy_path = get_attr(attrs, :taxonomy_path)

    with {:ok, module} <- Taxonomy.get(framework),
         {:ok, [_action]} <- resolve_exact_path(module, taxonomy_path) do
      attrs =
        attrs
        |> Map.put("account_id", account_id)
        |> Map.put("framework", framework)
        |> Map.put("taxonomy_path", taxonomy_path)
        |> Map.put("taxonomy_version", module.taxonomy_version())

      %__MODULE__{}
      |> changeset(attrs)
      |> Repo.insert()
    else
      {:error, :unknown_framework} ->
        {:error, framework_error_changeset(account_id, attrs)}

      {:error, :invalid_path} ->
        {:error, taxonomy_path_error_changeset(account_id, attrs)}
    end
  end

  def create_mapping(_account_id, _attrs) do
    {:error, changeset(%__MODULE__{}, %{})}
  end

  @doc """
  Lists mappings for an account, optionally filtered by framework/custom action.
  """
  @spec list_mappings(String.t(), keyword() | map()) :: [t()]
  def list_mappings(account_id, opts \\ [])

  def list_mappings(account_id, opts)
      when is_binary(account_id) and (is_list(opts) or is_map(opts)) do
    framework = get_opt(opts, :framework)
    custom_action = get_opt(opts, :custom_action)

    from(mapping in __MODULE__,
      where: mapping.account_id == ^account_id,
      order_by: [asc: mapping.framework, asc: mapping.custom_action]
    )
    |> maybe_filter(framework, fn query, value ->
      where(query, [mapping], mapping.framework == ^value)
    end)
    |> maybe_filter(custom_action, fn query, value ->
      where(query, [mapping], mapping.custom_action == ^value)
    end)
    |> Repo.all()
  end

  def list_mappings(_account_id, _opts), do: []

  @doc """
  Updates the taxonomy path for an account-scoped mapping.
  """
  @spec update_mapping(String.t(), String.t(), map() | keyword()) ::
          {:ok, t()} | {:error, Ecto.Changeset.t() | :not_found}
  def update_mapping(account_id, mapping_id, attrs)
      when is_binary(account_id) and is_binary(mapping_id) and (is_map(attrs) or is_list(attrs)) do
    case Repo.get_by(__MODULE__, id: mapping_id, account_id: account_id) do
      nil ->
        {:error, :not_found}

      %__MODULE__{} = mapping ->
        attrs = normalize_attrs(attrs)
        taxonomy_path = get_attr(attrs, :taxonomy_path)

        with {:ok, module} <- Taxonomy.get(mapping.framework),
             {:ok, [_action]} <- resolve_exact_path(module, taxonomy_path) do
          mapping
          |> change()
          |> put_change(:taxonomy_path, taxonomy_path)
          |> put_change(:taxonomy_version, module.taxonomy_version())
          |> validate_required([:taxonomy_path, :taxonomy_version])
          |> Repo.update()
        else
          {:error, :unknown_framework} ->
            {:error, add_error(change(mapping), :framework, "is invalid")}

          {:error, :invalid_path} ->
            {:error, add_error(change(mapping), :taxonomy_path, "is invalid")}
        end
    end
  end

  def update_mapping(_account_id, _mapping_id, _attrs), do: {:error, :not_found}

  @doc """
  Deletes a mapping when it belongs to the account.
  """
  @spec delete_mapping(String.t(), String.t()) :: {:ok, t()} | {:error, :not_found}
  def delete_mapping(account_id, mapping_id)
      when is_binary(account_id) and is_binary(mapping_id) do
    case Repo.get_by(__MODULE__, id: mapping_id, account_id: account_id) do
      nil -> {:error, :not_found}
      mapping -> Repo.delete(mapping)
    end
  end

  def delete_mapping(_account_id, _mapping_id), do: {:error, :not_found}

  @doc """
  Resolves canonical and mapped actions for a framework taxonomy pattern.
  """
  @spec resolve_actions(String.t(), String.t(), String.t()) ::
          {:ok, resolve_result()} | {:error, :unknown_framework | :invalid_path}
  def resolve_actions(account_id, framework, taxonomy_pattern)
      when is_binary(account_id) and is_binary(framework) and is_binary(taxonomy_pattern) do
    with {:ok, module} <- Taxonomy.get(framework),
         {:ok, taxonomy_actions} <- Taxonomy.resolve_path(module, taxonomy_pattern) do
      mapped_actions =
        list_mappings(account_id, framework: framework)
        |> Enum.filter(&taxonomy_path_matches_pattern?(&1.taxonomy_path, taxonomy_pattern))
        |> Enum.map(& &1.custom_action)
        |> Enum.uniq()
        |> Enum.sort()

      {:ok,
       %{
         taxonomy_actions: taxonomy_actions,
         mapped_actions: mapped_actions
       }}
    end
  end

  def resolve_actions(_account_id, _framework, _taxonomy_pattern), do: {:error, :invalid_path}

  @doc """
  Returns a dry-run report of recent action recognition for a framework.
  """
  @spec validate_actions(String.t(), String.t()) ::
          {:ok, %{recognized: [String.t()], unmapped: [String.t()]}}
          | {:error, :unknown_framework}
  def validate_actions(account_id, framework)
      when is_binary(account_id) and is_binary(framework) do
    with {:ok, module} <- Taxonomy.get(framework) do
      canonical_actions = MapSet.new(module.actions())

      mapped_actions =
        list_mappings(account_id, framework: framework)
        |> Enum.map(& &1.custom_action)
        |> MapSet.new()

      observed_actions =
        from(log in Log,
          where: log.account_id == ^account_id,
          order_by: [desc: log.sequence_number],
          limit: 1000,
          select: log.action
        )
        |> Repo.all()
        |> Enum.uniq()

      {recognized, unmapped} =
        Enum.split_with(observed_actions, fn action ->
          MapSet.member?(canonical_actions, action) or MapSet.member?(mapped_actions, action)
        end)

      {:ok,
       %{
         recognized: Enum.sort(recognized),
         unmapped: Enum.sort(unmapped)
       }}
    end
  end

  def validate_actions(_account_id, _framework), do: {:error, :unknown_framework}

  @doc """
  Checks whether a custom action is mapped for an account/framework pair.
  """
  @spec mapped_action?(String.t(), String.t(), String.t()) :: boolean()
  def mapped_action?(account_id, framework, custom_action)
      when is_binary(account_id) and is_binary(framework) and is_binary(custom_action) do
    from(mapping in __MODULE__,
      where:
        mapping.account_id == ^account_id and
          mapping.framework == ^framework and
          mapping.custom_action == ^custom_action,
      select: 1,
      limit: 1
    )
    |> Repo.one()
    |> Kernel.==(1)
  end

  def mapped_action?(_account_id, _framework, _custom_action), do: false

  defp resolve_exact_path(_module, taxonomy_path) when not is_binary(taxonomy_path),
    do: {:error, :invalid_path}

  defp resolve_exact_path(module, taxonomy_path) do
    case String.ends_with?(taxonomy_path, ".*") do
      true -> {:error, :invalid_path}
      false -> Taxonomy.resolve_path(module, taxonomy_path)
    end
  end

  defp taxonomy_path_matches_pattern?(taxonomy_path, pattern) do
    mapping_parts = String.split(taxonomy_path, ".", trim: true)
    pattern_parts = String.split(pattern, ".", trim: true)

    case pattern_parts do
      [category, "*"] ->
        match?([^category, _, _], mapping_parts)

      [category, subcategory, "*"] ->
        match?([^category, ^subcategory, _], mapping_parts)

      [category, subcategory, action] ->
        mapping_parts == [category, subcategory, action]

      _ ->
        false
    end
  end

  defp framework_error_changeset(account_id, attrs) do
    %__MODULE__{}
    |> changeset(
      attrs
      |> Map.put("account_id", account_id)
      |> Map.put_new("taxonomy_version", "0.0.0")
      |> Map.put_new("taxonomy_path", "invalid.path")
      |> Map.put_new("custom_action", "invalid")
    )
    |> add_error(:framework, "is invalid")
  end

  defp taxonomy_path_error_changeset(account_id, attrs) do
    framework = get_attr(attrs, :framework)

    %__MODULE__{}
    |> changeset(
      attrs
      |> Map.put("account_id", account_id)
      |> Map.put_new("framework", framework || "hipaa")
      |> Map.put_new("taxonomy_version", "1.0.0")
      |> Map.put_new("custom_action", "invalid")
      |> Map.put_new("taxonomy_path", "invalid.path")
    )
    |> add_error(:taxonomy_path, "is invalid")
  end

  defp normalize_attrs(attrs) when is_list(attrs) do
    attrs
    |> Map.new()
    |> normalize_attrs()
  end

  defp normalize_attrs(attrs) when is_map(attrs) do
    Map.new(attrs, fn {key, value} -> {to_string(key), value} end)
  end

  defp get_attr(attrs, key) when is_map(attrs) do
    case Map.fetch(attrs, key) do
      {:ok, value} -> value
      :error -> Map.get(attrs, Atom.to_string(key))
    end
  end

  defp get_opt(opts, key) when is_list(opts), do: Keyword.get(opts, key)

  defp get_opt(opts, key) when is_map(opts) do
    case Map.fetch(opts, key) do
      {:ok, value} -> value
      :error -> Map.get(opts, Atom.to_string(key))
    end
  end

  defp get_opt(_opts, _key), do: nil

  defp maybe_filter(query, nil, _fun), do: query
  defp maybe_filter(query, value, fun), do: fun.(query, value)
end
