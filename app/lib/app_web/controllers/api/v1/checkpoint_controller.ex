defmodule GAWeb.Api.V1.CheckpointController do
  @moduledoc """
  Account-scoped checkpoint endpoints.
  """
  use GAWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GA.Audit
  alias GAWeb.Api.V1.CheckpointJSON
  alias GAWeb.Schemas.{CheckpointResponse, ErrorResponse}

  action_fallback GAWeb.FallbackController

  tags(["Checkpoints"])
  security([%{"bearerAuth" => []}])

  operation(:create,
    summary: "Create checkpoint",
    responses: [
      created: {"Checkpoint", "application/json", CheckpointResponse},
      unprocessable_entity: {"No entries", "application/json", ErrorResponse},
      unauthorized: {"Unauthorized", "application/json", ErrorResponse},
      forbidden: {"Forbidden", "application/json", ErrorResponse}
    ]
  )

  def create(conn, _params) do
    account_id = conn.assigns.current_account.id

    with {:ok, checkpoint} <- Audit.create_checkpoint(account_id) do
      conn
      |> put_status(:created)
      |> put_view(json: CheckpointJSON)
      |> render(:show, checkpoint: checkpoint)
    end
  end

  operation(:index,
    summary: "List checkpoints",
    responses: [
      ok: {"Checkpoint list", "application/json", CheckpointResponse},
      unauthorized: {"Unauthorized", "application/json", ErrorResponse}
    ]
  )

  def index(conn, _params) do
    account_id = conn.assigns.current_account.id
    checkpoints = Audit.list_checkpoints(account_id)

    conn
    |> put_view(json: CheckpointJSON)
    |> render(:index, checkpoints: checkpoints)
  end
end
