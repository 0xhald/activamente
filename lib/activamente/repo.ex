defmodule Activamente.Repo do
  use Ecto.Repo,
    otp_app: :activamente,
    adapter: Ecto.Adapters.Postgres,
    types: Pgvector.Postgrex
end
