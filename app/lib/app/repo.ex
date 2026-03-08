defmodule GA.Repo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :app,
    adapter: Ecto.Adapters.Postgres
end
