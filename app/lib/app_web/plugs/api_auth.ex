defmodule GAWeb.Plugs.ApiAuth do
  @moduledoc """
  Bearer token authentication for API requests.
  Validates API keys and loads user/account context.
  """
  import Plug.Conn
  import Phoenix.Controller

  alias GA.Accounts

  @doc false
  def init(opts), do: opts

  @doc """
  Main plug function - dispatches based on opts.
  """
  def call(conn, :require_write_access), do: require_write_access(conn, [])
  def call(conn, opts), do: require_api_auth(conn, opts)

  @doc """
  Requires API authentication via bearer token.
  Extracts token from Authorization header, verifies it, and loads context.
  """
  def require_api_auth(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, api_key} <- Accounts.verify_api_token(token),
         :ok <- check_user_confirmed(api_key.account_user.user),
         :ok <- check_account_active(api_key.account_user.account) do
      _ = Accounts.touch_api_key(api_key)

      conn
      |> assign(:current_api_key, api_key)
      |> assign(:current_account_user, api_key.account_user)
      |> assign(:current_user, api_key.account_user.user)
      |> assign(:current_account, api_key.account_user.account)
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> put_view(json: GAWeb.ErrorJSON)
        |> render(:"401")
        |> halt()
    end
  end

  @doc """
  Requires write access (private API key with sk_ prefix).
  Must be used after require_api_auth.
  """
  def require_write_access(conn, _opts) do
    api_key = conn.assigns[:current_api_key]

    if api_key && api_key.type == :private do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> put_view(json: GAWeb.ErrorJSON)
      |> render(:"403")
      |> halt()
    end
  end

  defp check_user_confirmed(%{confirmed_at: nil}), do: {:error, :unconfirmed}
  defp check_user_confirmed(_user), do: :ok

  defp check_account_active(%{status: :active}), do: :ok
  defp check_account_active(_), do: {:error, :account_suspended}
end
