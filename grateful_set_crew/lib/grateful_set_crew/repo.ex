defmodule GratefulSetCrew.Repo do
  use Ecto.Repo,
    otp_app: :grateful_set_crew,
    adapter: Ecto.Adapters.SQLite3
end
