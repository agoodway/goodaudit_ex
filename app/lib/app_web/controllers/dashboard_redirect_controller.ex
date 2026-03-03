defmodule GAWeb.DashboardRedirectController do
  @moduledoc """
  Redirects /dashboard to /dashboard/accounts/:default_account_id.
  """
  use GAWeb, :controller

  alias GA.AccountContext

  @doc false
  def index(conn, _params) do
    user = conn.assigns.current_scope.user

    case AccountContext.get_default_account(user, get_session(conn)) do
      {:ok, account} ->
        redirect(conn, to: "/dashboard/accounts/#{account.id}")

      {:error, :no_accounts} ->
        conn
        |> put_flash(:error, "You don't have access to any accounts. Please contact support.")
        |> redirect(to: "/")
    end
  end
end
