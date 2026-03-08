defmodule GAWeb.ErrorJSON do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on JSON requests.

  See config/config.exs.
  """

  @doc false
  def render("401.json", _assigns) do
    %{errors: %{detail: "Unauthorized - valid API key required"}}
  end

  @doc false
  def render("403.json", _assigns) do
    %{errors: %{detail: "Forbidden - insufficient permissions"}}
  end

  @doc false
  def render("404.json", _assigns) do
    %{errors: %{detail: "Not Found"}}
  end

  @doc false
  def render(template, _assigns) do
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end
end
