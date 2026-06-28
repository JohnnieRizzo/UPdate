defmodule GratefulSetCrewWeb.UserSessionHTML do
  use GratefulSetCrewWeb, :html

  embed_templates "user_session_html/*"

  defp local_mail_adapter? do
    Application.get_env(:grateful_set_crew, GratefulSetCrew.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
