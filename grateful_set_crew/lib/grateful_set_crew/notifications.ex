defmodule GratefulSetCrew.Notifications do
  @moduledoc """
  The Notifications context.
  """

  import Ecto.Query, warn: false
  alias GratefulSetCrew.Repo
  alias GratefulSetCrew.Notifications.{Notification, SystemLog}

  ## Notifications

  @doc """
  Returns the list of notifications for a user.
  """
  def list_notifications_by_user(user_id) do
    Repo.all(from n in Notification, where: n.user_id == ^user_id, order_by: [desc: :inserted_at])
  end

  @doc """
  Returns unread notifications for a user.
  """
  def list_unread_notifications(user_id) do
    Repo.all(from n in Notification, where: n.user_id == ^user_id and n.read == false)
  end

  @doc """
  Gets a single notification.
  """
  def get_notification!(id) do
    Repo.get!(Notification, id)
  end

  @doc """
  Creates a notification.
  """
  def create_notification(attrs \\ %{}) do
    with {:ok, notification} <- %Notification{}
    |> Notification.changeset(attrs)
    |> Repo.insert() do
      # Broadcast the new notification
      broadcast_notification_created(notification)
      {:ok, notification}
    else
      error -> error
    end
  end

  defp broadcast_notification_created(notification) do
    Phoenix.PubSub.broadcast(
      GratefulSetCrew.PubSub,
      "notifications:#{notification.user_id}",
      {:notification_created, notification}
    )
  end

  @doc """
  Updates a notification.
  """
  def update_notification(%Notification{} = notification, attrs) do
    notification
    |> Notification.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Mark notification as read.
  """
  def mark_notification_read(%Notification{} = notification) do
    update_notification(notification, %{read: true})
  end

  @doc """
  Deletes a notification.
  """
  def delete_notification(%Notification{} = notification) do
    Repo.delete(notification)
  end

  ## System Logs

  @doc """
  Returns the list of system logs.
  """
  def list_system_logs(limit \\ 100) do
    Repo.all(from sl in SystemLog, order_by: [desc: :inserted_at], limit: ^limit)
  end

  @doc """
  Returns system logs for a specific event type.
  """
  def list_system_logs_by_event(event_type, limit \\ 50) do
    Repo.all(from sl in SystemLog, where: sl.event_type == ^event_type, order_by: [desc: :inserted_at], limit: ^limit)
  end

  @doc """
  Returns system logs for a job.
  """
  def list_system_logs_by_job(job_id) do
    Repo.all(from sl in SystemLog, where: sl.job_id == ^job_id, order_by: [desc: :inserted_at])
  end

  @doc """
  Gets a single system log.
  """
  def get_system_log!(id) do
    Repo.get!(SystemLog, id)
  end

  @doc """
  Creates a system log.
  """
  def create_system_log(attrs \\ %{}) do
    with {:ok, log} <- %SystemLog{}
    |> SystemLog.changeset(attrs)
    |> Repo.insert() do
      # Broadcast the new log
      broadcast_system_log_created(log)
      {:ok, log}
    else
      error -> error
    end
  end

  defp broadcast_system_log_created(log) do
    Phoenix.PubSub.broadcast(
      GratefulSetCrew.PubSub,
      "system_logs:new",
      {:system_log_created, log}
    )
  end

  @doc """
  Shorthand for logging with event_type and details.
  """
  def log(event_type, details \\ %{}, user_id \\ nil, job_id \\ nil) do
    create_system_log(%{
      event_type: event_type,
      details: details,
      user_id: user_id,
      job_id: job_id
    })
  end

  @doc """
  Shorthand for creating a notification and logging.
  """
  def notify(user_id, title, body, type \\ "info", link \\ nil, details \\ %{}) do
    create_notification(%{
      user_id: user_id,
      title: title,
      body: body,
      type: type,
      link: link
    })

    log("notification.created", Map.merge(details, %{
      title: title,
      type: type
    }), user_id)
  end

  @doc """
  Deletes a system log.
  """
  def delete_system_log(%SystemLog{} = system_log) do
    Repo.delete(system_log)
  end
end
