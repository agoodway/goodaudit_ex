defmodule GAWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid Plug.Conn responses.
  """
  use GAWeb, :controller

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(json: GAWeb.ErrorJSON)
    |> render(:"404")
  end

  def call(conn, {:error, :forbidden}) do
    conn
    |> put_status(:forbidden)
    |> put_view(json: GAWeb.ErrorJSON)
    |> render(:"403")
  end

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> put_view(json: GAWeb.ErrorJSON)
    |> render(:"401")
  end

  def call(conn, {:error, :no_entries}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{
      status: 422,
      message: "No audit entries exist yet"
    })
  end

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: GAWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end
end
