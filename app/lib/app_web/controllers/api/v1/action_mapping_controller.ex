defmodule GAWeb.Api.V1.ActionMappingController do
  @moduledoc """
  Account-scoped action mapping endpoints.
  """

  use GAWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GA.Compliance.ActionMapping
  alias GAWeb.Api.V1.ActionMappingJSON

  alias GAWeb.Schemas.{
    ActionMappingListResponse,
    ActionMappingRequest,
    ActionMappingResponse,
    ActionMappingValidateResponse,
    ErrorResponse
  }

  action_fallback GAWeb.FallbackController

  tags(["Action Mappings"])
  security([%{"bearerAuth" => []}])

  operation(:index,
    summary: "List action mappings",
    parameters: [
      framework: [in: :query, schema: %OpenApiSpex.Schema{type: :string}, required: false],
      custom_action: [in: :query, schema: %OpenApiSpex.Schema{type: :string}, required: false]
    ],
    responses: [
      ok: {"Action mappings", "application/json", ActionMappingListResponse},
      unauthorized: {"Unauthorized", "application/json", ErrorResponse}
    ]
  )

  def index(conn, params) do
    account_id = conn.assigns.current_account.id

    mappings =
      ActionMapping.list_mappings(account_id,
        framework: present_string(params["framework"]),
        custom_action: present_string(params["custom_action"])
      )

    conn
    |> put_view(json: ActionMappingJSON)
    |> render(:index, mappings: mappings)
  end

  operation(:create,
    summary: "Create action mapping",
    request_body: {"Action mapping payload", "application/json", ActionMappingRequest, required: true},
    responses: [
      created: {"Action mapping", "application/json", ActionMappingResponse},
      unprocessable_entity: {"Validation error", "application/json", ErrorResponse},
      unauthorized: {"Unauthorized", "application/json", ErrorResponse},
      forbidden: {"Forbidden", "application/json", ErrorResponse}
    ]
  )

  def create(conn, attrs) do
    account_id = conn.assigns.current_account.id

    with {:ok, mapping} <- ActionMapping.create_mapping(account_id, attrs) do
      conn
      |> put_status(:created)
      |> put_view(json: ActionMappingJSON)
      |> render(:show, mapping: mapping)
    end
  end

  operation(:update,
    summary: "Update action mapping taxonomy path",
    parameters: [
      id: [in: :path, schema: %OpenApiSpex.Schema{type: :string, format: :uuid}, required: true]
    ],
    request_body:
      {"Action mapping payload", "application/json",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{
           taxonomy_path: %OpenApiSpex.Schema{type: :string}
         },
         required: [:taxonomy_path]
       }, required: true},
    responses: [
      ok: {"Action mapping", "application/json", ActionMappingResponse},
      not_found: {"Not found", "application/json", ErrorResponse},
      unprocessable_entity: {"Validation error", "application/json", ErrorResponse},
      unauthorized: {"Unauthorized", "application/json", ErrorResponse},
      forbidden: {"Forbidden", "application/json", ErrorResponse}
    ]
  )

  def update(conn, %{"id" => id} = attrs) do
    account_id = conn.assigns.current_account.id

    with {:ok, mapping} <- ActionMapping.update_mapping(account_id, id, attrs) do
      conn
      |> put_view(json: ActionMappingJSON)
      |> render(:show, mapping: mapping)
    end
  end

  operation(:delete,
    summary: "Delete action mapping",
    parameters: [
      id: [in: :path, schema: %OpenApiSpex.Schema{type: :string, format: :uuid}, required: true]
    ],
    responses: [
      ok: {"Deleted mapping", "application/json", ActionMappingResponse},
      not_found: {"Not found", "application/json", ErrorResponse},
      unauthorized: {"Unauthorized", "application/json", ErrorResponse},
      forbidden: {"Forbidden", "application/json", ErrorResponse}
    ]
  )

  def delete(conn, %{"id" => id}) do
    account_id = conn.assigns.current_account.id

    with {:ok, mapping} <- ActionMapping.delete_mapping(account_id, id) do
      conn
      |> put_view(json: ActionMappingJSON)
      |> render(:show, mapping: mapping)
    end
  end

  operation(:validate,
    summary: "Validate recent actions for framework strict-mode readiness",
    request_body:
      {"Validation request", "application/json",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{framework: %OpenApiSpex.Schema{type: :string}},
         required: [:framework]
       }, required: true},
    responses: [
      ok: {"Validation report", "application/json", ActionMappingValidateResponse},
      unprocessable_entity: {"Validation error", "application/json", ErrorResponse},
      unauthorized: {"Unauthorized", "application/json", ErrorResponse}
    ]
  )

  def validate(conn, %{"framework" => framework}) do
    account_id = conn.assigns.current_account.id

    case ActionMapping.validate_actions(account_id, framework) do
      {:ok, report} ->
        conn
        |> put_view(json: ActionMappingJSON)
        |> render(:validate, report: report)

      {:error, :unknown_framework} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: 422, message: "Unknown framework: #{framework}"})
    end
  end

  def validate(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{status: 422, message: "framework is required"})
  end

  defp present_string(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp present_string(_), do: nil
end
