defmodule GAWeb.Plugs.LoadAccount do
  @moduledoc """
  Plug to load and validate account context from URL parameters.
  Must be used after :require_authenticated_user pipeline.
  """
  import Plug.Conn

  alias GA.AccountContext

  @doc false
  def init(opts), do: opts

  @doc false
  def call(conn, _opts) do
    account_id = conn.params["account_id"]
    user = conn.assigns.current_scope.user

    case AccountContext.get_account_for_user(user, account_id) do
      {:ok, account} ->
        conn
        |> assign(:current_account, account)
        |> put_session(:last_account_id, account.id)

      {:error, :not_found} ->
        conn
        |> Phoenix.Controller.put_flash(:error, "Unable to access this account")
        |> Phoenix.Controller.redirect(to: "/dashboard")
        |> halt()
    end
  end
end
