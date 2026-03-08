defmodule GAWeb.Api.V1.AuditLogController do
  @moduledoc """
  Account-scoped audit log endpoints.
  """
  use GAWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GA.Audit
  alias GAWeb.Api.V1.AuditLogJSON

  alias GAWeb.Schemas.{
    AuditLogListResponse,
    AuditLogRequest,
    AuditLogResponse,
    ErrorResponse
  }

  action_fallback GAWeb.FallbackController

  tags(["Audit Logs"])
  security([%{"bearerAuth" => []}])

  operation(:create,
    summary: "Create audit log entry",
    request_body: {"Audit log payload", "application/json", AuditLogRequest, required: true},
    responses: [
      created: {"Audit log entry", "application/json", AuditLogResponse},
      unprocessable_entity:
        {"Validation error (example: {\"errors\": {\"extensions\": [\"hipaa.user_role is required\"]}})",
         "application/json", ErrorResponse},
      unauthorized: {"Unauthorized", "application/json", ErrorResponse},
      forbidden: {"Forbidden", "application/json", ErrorResponse}
    ]
  )

  def create(conn, attrs) when is_map(attrs) do
    account_id = conn.assigns.current_account.id

    with {:ok, log} <- Audit.create_log_entry(account_id, attrs) do
      conn
      |> put_status(:created)
      |> put_view(json: AuditLogJSON)
      |> render(:show, log: log)
    end
  end

  operation(:index,
    summary: "List audit log entries",
    parameters: [
      after_sequence: [in: :query, schema: %OpenApiSpex.Schema{type: :integer}, required: false],
      limit: [in: :query, schema: %OpenApiSpex.Schema{type: :integer}, required: false],
      actor_id: [in: :query, schema: %OpenApiSpex.Schema{type: :string}, required: false],
      action: [in: :query, schema: %OpenApiSpex.Schema{type: :string}, required: false],
      resource_type: [in: :query, schema: %OpenApiSpex.Schema{type: :string}, required: false],
      resource_id: [in: :query, schema: %OpenApiSpex.Schema{type: :string}, required: false],
      outcome: [in: :query, schema: %OpenApiSpex.Schema{type: :string}, required: false],
      extensions: [
        in: :query,
        schema: %OpenApiSpex.Schema{type: :string},
        required: false,
        description: "JSON object for extensions containment filtering"
      ],
      from: [
        in: :query,
        schema: %OpenApiSpex.Schema{type: :string, format: :"date-time"},
        required: false
      ],
      to: [
        in: :query,
        schema: %OpenApiSpex.Schema{type: :string, format: :"date-time"},
        required: false
      ],
      category: [
        in: :query,
        schema: %OpenApiSpex.Schema{type: :string},
        required: false,
        description: "Taxonomy category filter in framework:pattern format (e.g. hipaa:access.*)"
      ]
    ],
    responses: [
      ok: {"Audit log list", "application/json", AuditLogListResponse},
      unprocessable_entity: {"Invalid category filter", "application/json", ErrorResponse},
      unauthorized: {"Unauthorized", "application/json", ErrorResponse}
    ]
  )

  def index(conn, params) do
    account_id = conn.assigns.current_account.id
    opts = build_list_opts(params)

    case Audit.list_logs(account_id, opts) do
      {:error, :invalid_category_format} ->
        invalid_category_response(conn, "Invalid category format. Expected 'framework:pattern'")

      {:error, :unknown_framework} ->
        category = present_string(params["category"]) || ""
        [framework | _rest] = String.split(category, ":", parts: 2)
        invalid_category_response(conn, "Unknown framework: #{framework}")

      {:error, :invalid_category_path} ->
        invalid_category_response(conn, "Invalid category path for framework taxonomy")

      {logs, next_cursor} ->
        conn
        |> put_view(json: AuditLogJSON)
        |> render(:index, logs: logs, next_cursor: next_cursor)
    end
  end

  operation(:show,
    summary: "Get a single audit log entry",
    parameters: [
      id: [in: :path, schema: %OpenApiSpex.Schema{type: :string, format: :uuid}, required: true]
    ],
    responses: [
      ok: {"Audit log entry", "application/json", AuditLogResponse},
      not_found: {"Not found", "application/json", ErrorResponse},
      unauthorized: {"Unauthorized", "application/json", ErrorResponse}
    ]
  )

  def show(conn, %{"id" => id}) do
    account_id = conn.assigns.current_account.id

    with {:ok, log} <- Audit.get_log(account_id, id) do
      conn
      |> put_view(json: AuditLogJSON)
      |> render(:show, log: log)
    end
  end

  defp build_list_opts(params) do
    [
      {:after_sequence, parse_integer(params["after_sequence"])},
      {:limit, parse_integer(params["limit"])},
      {:actor_id, present_string(params["actor_id"])},
      {:action, present_string(params["action"])},
      {:resource_type, present_string(params["resource_type"])},
      {:resource_id, present_string(params["resource_id"])},
      {:outcome, present_string(params["outcome"])},
      {:extensions, parse_extensions(params["extensions"])},
      {:from, parse_datetime(params["from"])},
      {:to, parse_datetime(params["to"])},
      {:category, present_string(params["category"])}
    ]
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp parse_integer(value) when is_integer(value), do: value

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _ -> nil
    end
  end

  defp parse_integer(_), do: nil

  defp parse_extensions(%{} = extensions), do: extensions

  defp parse_extensions(value) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, %{} = extensions} -> extensions
      _ -> nil
    end
  end

  defp parse_extensions(_), do: nil

  defp parse_datetime(%DateTime{} = datetime), do: datetime

  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> datetime
      _ -> nil
    end
  end

  defp parse_datetime(_), do: nil

  defp present_string(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp present_string(_), do: nil

  defp invalid_category_response(conn, message) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{status: 422, message: message})
  end
end
