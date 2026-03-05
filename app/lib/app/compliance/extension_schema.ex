defmodule GA.Compliance.ExtensionSchema do
  @moduledoc """
  Validates framework-namespaced audit extensions.
  """

  import Ecto.Changeset, only: [add_error: 3, change: 2]

  alias GA.Audit.Log
  alias GA.Compliance

  @type_errors %{
    string: "string",
    boolean: "boolean",
    integer: "integer",
    float: "float",
    number: "number",
    map: "object",
    array: "array"
  }

  @spec validate([String.t()], map() | nil) :: {:ok, map()} | {:error, Ecto.Changeset.t()}
  def validate(framework_ids, extensions), do: validate(framework_ids, extensions, %{})

  @spec validate([String.t()], map() | nil, map()) ::
          {:ok, map()} | {:error, Ecto.Changeset.t()}
  def validate(framework_ids, extensions, additional_required_by_framework)
      when is_list(framework_ids) do
    normalized_framework_ids =
      framework_ids
      |> Enum.map(&to_string/1)
      |> Enum.uniq()
      |> Enum.sort()

    normalized_additional_required =
      normalize_additional_required_fields(additional_required_by_framework)

    with {:ok, normalized_extensions} <- normalize_extensions(extensions) do
      errors =
        []
        |> validate_unknown_frameworks(normalized_framework_ids, normalized_extensions)
        |> validate_framework_extensions(
          normalized_framework_ids,
          normalized_extensions,
          normalized_additional_required
        )

      if errors == [] do
        {:ok, normalized_extensions}
      else
        {:error, build_error_changeset(normalized_extensions, errors)}
      end
    else
      {:error, error} ->
        {:error, build_error_changeset(%{}, [error])}
    end
  end

  def validate(_framework_ids, _extensions, _additional_required_by_framework) do
    {:error, build_error_changeset(%{}, ["framework list must be an array"])}
  end

  defp normalize_extensions(nil), do: {:ok, %{}}
  defp normalize_extensions(%{} = extensions), do: {:ok, stringify_keys_deep(extensions)}
  defp normalize_extensions(_extensions), do: {:error, "extensions must be an object"}

  defp normalize_additional_required_fields(%{} = additional_required_by_framework) do
    Map.new(additional_required_by_framework, fn {framework_id, fields} ->
      {to_string(framework_id), normalize_additional_required_list(fields)}
    end)
  end

  defp normalize_additional_required_fields(_), do: %{}

  defp normalize_additional_required_list(fields) when is_list(fields) do
    fields
    |> Enum.map(&to_string/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp normalize_additional_required_list(_), do: []

  defp validate_unknown_frameworks(errors, framework_ids, extensions) do
    extensions
    |> Map.keys()
    |> Enum.sort()
    |> Enum.reduce(errors, fn framework_key, acc ->
      if framework_key in framework_ids do
        acc
      else
        acc ++ ["#{framework_key} is not an active framework"]
      end
    end)
  end

  defp validate_framework_extensions(
         errors,
         framework_ids,
         extensions,
         additional_required_by_framework
       ) do
    Enum.reduce(framework_ids, errors, fn framework_id, acc ->
      framework_extensions = Map.get(extensions, framework_id, %{})

      case Compliance.get_framework(framework_id) do
        {:ok, module} ->
          case framework_extensions do
            %{} ->
              framework_schema = normalize_framework_schema(module.extension_schema())
              additional_required = Map.get(additional_required_by_framework, framework_id, [])

              acc
              |> validate_unknown_extension_fields(
                framework_id,
                framework_extensions,
                framework_schema,
                additional_required
              )
              |> validate_required_extension_fields(
                framework_id,
                framework_extensions,
                framework_schema,
                additional_required
              )
              |> validate_extension_field_types(
                framework_id,
                framework_extensions,
                framework_schema,
                additional_required
              )

            _ ->
              acc ++ ["#{framework_id} must be an object"]
          end

        {:error, :unknown_framework} ->
          acc ++ ["#{framework_id} is not a recognized framework"]
      end
    end)
  end

  defp validate_unknown_extension_fields(
         errors,
         framework_id,
         framework_extensions,
         framework_schema,
         additional_required
       ) do
    allowed_fields =
      framework_schema.required
      |> Map.keys()
      |> Kernel.++(Map.keys(framework_schema.optional))
      |> Kernel.++(additional_required)
      |> Enum.uniq()

    framework_extensions
    |> Map.keys()
    |> Enum.sort()
    |> Enum.reduce(errors, fn field, acc ->
      if field in allowed_fields do
        acc
      else
        acc ++ ["#{framework_id}.#{field} is not allowed"]
      end
    end)
  end

  defp validate_required_extension_fields(
         errors,
         framework_id,
         framework_extensions,
         framework_schema,
         additional_required
       ) do
    required_fields =
      framework_schema.required
      |> Map.keys()
      |> Kernel.++(additional_required)
      |> Enum.uniq()
      |> Enum.sort()

    Enum.reduce(required_fields, errors, fn field, acc ->
      case Map.fetch(framework_extensions, field) do
        :error -> acc ++ ["#{framework_id}.#{field} is required"]
        {:ok, nil} -> acc ++ ["#{framework_id}.#{field} is required"]
        {:ok, _value} -> acc
      end
    end)
  end

  defp validate_extension_field_types(
         errors,
         framework_id,
         framework_extensions,
         framework_schema,
         additional_required
       ) do
    field_types =
      framework_schema.required
      |> Map.merge(framework_schema.optional)
      |> Map.merge(Map.new(additional_required, &{&1, :any}))

    field_types
    |> Enum.sort_by(fn {field, _type} -> field end)
    |> Enum.reduce(errors, fn {field, type}, acc ->
      case Map.fetch(framework_extensions, field) do
        {:ok, nil} ->
          acc

        {:ok, value} ->
          if valid_type?(value, type) do
            acc
          else
            acc ++ ["#{framework_id}.#{field} must be #{type_label(type)}"]
          end

        :error ->
          acc
      end
    end)
  end

  defp normalize_framework_schema(%{} = schema) do
    required =
      schema
      |> Map.get(:required, Map.get(schema, "required", %{}))
      |> normalize_schema_fields()

    optional =
      schema
      |> Map.get(:optional, Map.get(schema, "optional", %{}))
      |> normalize_schema_fields()

    %{required: required, optional: optional}
  end

  defp normalize_framework_schema(_), do: %{required: %{}, optional: %{}}

  defp normalize_schema_fields(%{} = fields) do
    Map.new(fields, fn {field, type} ->
      {to_string(field), normalize_field_type(type)}
    end)
  end

  defp normalize_schema_fields(_), do: %{}

  defp normalize_field_type(%{type: type}), do: normalize_field_type(type)
  defp normalize_field_type(type) when type in [:string, :boolean, :integer, :float, :number, :map, :array], do: type
  defp normalize_field_type("string"), do: :string
  defp normalize_field_type("boolean"), do: :boolean
  defp normalize_field_type("integer"), do: :integer
  defp normalize_field_type("float"), do: :float
  defp normalize_field_type("number"), do: :number
  defp normalize_field_type("map"), do: :map
  defp normalize_field_type("object"), do: :map
  defp normalize_field_type("array"), do: :array
  defp normalize_field_type(_), do: :any

  defp valid_type?(_value, :any), do: true
  defp valid_type?(value, :string), do: is_binary(value)
  defp valid_type?(value, :boolean), do: is_boolean(value)
  defp valid_type?(value, :integer), do: is_integer(value)
  defp valid_type?(value, :float), do: is_float(value)
  defp valid_type?(value, :number), do: is_number(value)
  defp valid_type?(value, :map), do: is_map(value)
  defp valid_type?(value, :array), do: is_list(value)
  defp valid_type?(_value, _type), do: true

  defp type_label(type), do: Map.get(@type_errors, type, "the expected type")

  defp build_error_changeset(extensions, errors) do
    Enum.reduce(errors, change(%Log{}, %{extensions: extensions}), fn error, changeset ->
      add_error(changeset, :extensions, error)
    end)
  end

  defp stringify_keys_deep(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {to_string(key), stringify_keys_deep(value)} end)
  end

  defp stringify_keys_deep(list) when is_list(list), do: Enum.map(list, &stringify_keys_deep/1)
  defp stringify_keys_deep(value), do: value
end
