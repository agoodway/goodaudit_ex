defmodule GAWeb.UserSessionHTML do
  @moduledoc false

  use GAWeb, :html

  embed_templates "user_session_html/*"

  defp local_mail_adapter? do
    Application.get_env(:app, GA.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
