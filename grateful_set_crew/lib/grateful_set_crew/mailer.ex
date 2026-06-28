defmodule GratefulSetCrew.Mailer do
  @moduledoc """
  Simple email module that logs emails to the console and optionally writes to a file.
  This is suitable for development. For production, implement a real email service.
  """

  require Logger

  def deliver(email) do
    Logger.info("""
    ====== EMAIL ======
    To: #{email.to}
    Subject: #{email.subject}
    Body: #{email.body}
    ==================
    """)

    # Return the email with text_body for test compatibility
    email_with_id = Map.merge(email, %{
      id: :rand.uniform(1_000_000),
      text_body: email.body
    })

    {:ok, email_with_id}
  end
end
