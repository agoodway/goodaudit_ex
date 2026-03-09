defmodule GoodauditEx do
  @moduledoc """
  Elixir client for the GoodAudit API, generated from the OpenAPI specification.

  ## Configuration

      config :goodaudit_ex,
        base_url: "https://api.goodaudit.io",
        api_key: "your-api-key"

  ## Usage

      client = GoodauditEx.client(api_key: "sk_...")
      {:ok, result} = GoodauditEx.list_audit_logs(client)
  """

  alias GoodauditEx.Client
  alias GoodauditEx.Schemas

  @doc "Create a new API client."
  def client(opts \\ []), do: Client.new(opts)

  # --- Audit Logs ---

  @doc "List audit log entries with optional filters."
  def list_audit_logs(%Client{} = client, opts \\ []) do
    params =
      Keyword.take(opts, [
        :after_sequence,
        :limit,
        :actor_id,
        :action,
        :resource_type,
        :resource_id,
        :outcome,
        :extensions,
        :from,
        :to,
        :category
      ])

    case Client.request(client, :get, "/api/v1/audit-logs", params: params) do
      {:ok, body} when is_map(body) ->
        {:ok, Schemas.AuditLogListResponse.from_map(body)}

      error ->
        error
    end
  end

  @doc "Create an audit log entry."
  def create_audit_log(%Client{} = client, params) when is_map(params) do
    case Client.request(client, :post, "/api/v1/audit-logs", json: params) do
      {:ok, body} when is_map(body) ->
        {:ok, Schemas.AuditLogResponse.from_map(body)}

      error ->
        error
    end
  end

  @doc "Get a single audit log entry by ID."
  def get_audit_log(%Client{} = client, id) do
    case Client.request(client, :get, "/api/v1/audit-logs/#{id}") do
      {:ok, body} when is_map(body) ->
        {:ok, Schemas.AuditLogResponse.from_map(body)}

      error ->
        error
    end
  end

  # --- Checkpoints ---

  @doc "List checkpoints."
  def list_checkpoints(%Client{} = client) do
    case Client.request(client, :get, "/api/v1/checkpoints") do
      {:ok, body} when is_map(body) ->
        {:ok, Schemas.CheckpointResponse.from_map(body)}

      error ->
        error
    end
  end

  @doc "Create a checkpoint."
  def create_checkpoint(%Client{} = client) do
    case Client.request(client, :post, "/api/v1/checkpoints") do
      {:ok, body} when is_map(body) ->
        {:ok, Schemas.CheckpointResponse.from_map(body)}

      error ->
        error
    end
  end

  # --- Verification ---

  @doc "Verify account chain integrity."
  def verify(%Client{} = client) do
    case Client.request(client, :post, "/api/v1/verify") do
      {:ok, body} when is_map(body) ->
        {:ok, Schemas.VerificationResponse.from_map(body)}

      error ->
        error
    end
  end

  # --- Taxonomies ---

  @doc "List registered framework taxonomies."
  def list_taxonomies(%Client{} = client) do
    case Client.request(client, :get, "/api/v1/taxonomies") do
      {:ok, body} when is_map(body) ->
        {:ok, Schemas.TaxonomyListResponse.from_map(body)}

      error ->
        error
    end
  end

  @doc "Get taxonomy tree for a framework."
  def get_taxonomy(%Client{} = client, framework) do
    case Client.request(client, :get, "/api/v1/taxonomies/#{framework}") do
      {:ok, body} when is_map(body) ->
        {:ok, Schemas.TaxonomyShowResponse.from_map(body)}

      error ->
        error
    end
  end

  # --- Action Mappings ---

  @doc "List action mappings with optional filters."
  def list_action_mappings(%Client{} = client, opts \\ []) do
    params = Keyword.take(opts, [:framework, :custom_action])

    case Client.request(client, :get, "/api/v1/action-mappings", params: params) do
      {:ok, body} when is_map(body) ->
        {:ok, Schemas.ActionMappingListResponse.from_map(body)}

      error ->
        error
    end
  end

  @doc "Create an action mapping."
  def create_action_mapping(%Client{} = client, params) when is_map(params) do
    case Client.request(client, :post, "/api/v1/action-mappings", json: params) do
      {:ok, body} when is_map(body) ->
        {:ok, Schemas.ActionMappingResponse.from_map(body)}

      error ->
        error
    end
  end

  @doc "Validate recent actions for framework strict-mode readiness."
  def validate_action_mappings(%Client{} = client, params) when is_map(params) do
    case Client.request(client, :post, "/api/v1/action-mappings/validate", json: params) do
      {:ok, body} when is_map(body) ->
        {:ok, Schemas.ActionMappingValidateResponse.from_map(body)}

      error ->
        error
    end
  end

  @doc "Update an action mapping's taxonomy path."
  def update_action_mapping(%Client{} = client, id, params) when is_map(params) do
    case Client.request(client, :put, "/api/v1/action-mappings/#{id}", json: params) do
      {:ok, body} when is_map(body) ->
        {:ok, Schemas.ActionMappingResponse.from_map(body)}

      error ->
        error
    end
  end

  @doc "Delete an action mapping."
  def delete_action_mapping(%Client{} = client, id) do
    case Client.request(client, :delete, "/api/v1/action-mappings/#{id}") do
      {:ok, body} when is_map(body) ->
        {:ok, Schemas.ActionMappingResponse.from_map(body)}

      error ->
        error
    end
  end
end
