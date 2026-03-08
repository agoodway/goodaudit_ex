defmodule GAWeb.PageController do
  @moduledoc false

  use GAWeb, :controller

  @doc false
  def home(conn, _params) do
    render(conn, :home)
  end
end
