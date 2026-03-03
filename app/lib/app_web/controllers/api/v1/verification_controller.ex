defmodule GAWeb.Api.V1.VerificationController do
  @moduledoc """
  Account-scoped verification endpoint.
  """
  use GAWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GA.Audit
  alias GAWeb.Schemas.{ErrorResponse, VerificationResponse}

  action_fallback GAWeb.FallbackController

  tags(["Verification"])
  security([%{"bearerAuth" => []}])

  operation(:create,
    summary: "Verify account chain integrity",
    responses: [
      ok: {"Verification report", "application/json", VerificationResponse},
      unauthorized: {"Unauthorized", "application/json", ErrorResponse}
    ]
  )

  def create(conn, _params) do
    account_id = conn.assigns.current_account.id

    case Audit.verify_chain(account_id) do
      {:error, reason} -> {:error, reason}
      report -> json(conn, report)
    end
  end
end
