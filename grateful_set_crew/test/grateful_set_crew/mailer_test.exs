defmodule GratefulSetCrew.MailerTest do
  use ExUnit.Case

  alias GratefulSetCrew.Mailer

  describe "deliver/1" do
    test "delivers an email and returns success" do
      email = %{
        to: "test@example.com",
        subject: "Test Email",
        body: "This is a test email"
      }

      {:ok, result} = Mailer.deliver(email)

      assert is_map(result)
      assert result.id != nil
      assert is_integer(result.id)
    end

    test "handles emails with various content" do
      email = %{
        to: "user@example.com",
        subject: "Confirmation Instructions",
        body: """
        Hi user@example.com,

        You can confirm your account by visiting the URL below:

        http://example.com/confirm?token=xyz123

        If you didn't create an account with us, please ignore this.
        """
      }

      {:ok, result} = Mailer.deliver(email)
      assert {:ok, %{id: _}} = {:ok, result}
    end

    test "handles emails with special characters" do
      email = %{
        to: "user+test@example.com",
        subject: "Test with special chars: é, ñ, ü",
        body: "Body with émoji and spëcial characters"
      }

      {:ok, result} = Mailer.deliver(email)
      assert result.id != nil
    end
  end
end
