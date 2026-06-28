defmodule GratefulSetCrewWeb.Components.StatusBadge do
  use Phoenix.Component

  @doc """
  Renders a status badge with consistent styling across the application.

  ## Examples

      <.status_badge status="available" />
      <.status_badge status="pending" label="Waiting for approval" />
  """
  def status_badge(assigns) do
    ~H"""
    <span class={badge_class(@status)}>
      <%= @label || String.capitalize(@status) %>
    </span>
    """
  end

  defp badge_class(status) do
    case status do
      "available" ->
        "inline-block px-3 py-1 rounded-full text-sm font-medium bg-green-100 text-green-800"

      "offline" ->
        "inline-block px-3 py-1 rounded-full text-sm font-medium bg-gray-100 text-gray-800"

      "open" ->
        "inline-block px-3 py-1 rounded-full text-sm font-medium bg-yellow-100 text-yellow-800"

      "assigned" ->
        "inline-block px-3 py-1 rounded-full text-sm font-medium bg-blue-100 text-blue-800"

      "completed" ->
        "inline-block px-3 py-1 rounded-full text-sm font-medium bg-green-100 text-green-800"

      "cancelled" ->
        "inline-block px-3 py-1 rounded-full text-sm font-medium bg-red-100 text-red-800"

      "pending" ->
        "inline-block px-3 py-1 rounded-full text-sm font-medium bg-yellow-100 text-yellow-800"

      "failed" ->
        "inline-block px-3 py-1 rounded-full text-sm font-medium bg-red-100 text-red-800"

      "matching" ->
        "inline-block px-3 py-1 rounded-full text-sm font-medium bg-purple-100 text-purple-800"

      _ ->
        "inline-block px-3 py-1 rounded-full text-sm font-medium bg-gray-100 text-gray-800"
    end
  end

  @doc """
  Renders a pill-style status indicator (smaller, more compact).
  """
  def status_pill(assigns) do
    ~H"""
    <span class={pill_class(@status)}>
      <%= status_icon(@status) %> <%= @label || String.capitalize(@status) %>
    </span>
    """
  end

  defp pill_class(status) do
    case status do
      "available" ->
        "inline-flex items-center gap-1 px-2 py-1 rounded text-xs font-medium bg-green-100 text-green-800"

      "offline" ->
        "inline-flex items-center gap-1 px-2 py-1 rounded text-xs font-medium bg-gray-100 text-gray-800"

      "open" ->
        "inline-flex items-center gap-1 px-2 py-1 rounded text-xs font-medium bg-yellow-100 text-yellow-800"

      "assigned" ->
        "inline-flex items-center gap-1 px-2 py-1 rounded text-xs font-medium bg-blue-100 text-blue-800"

      "completed" ->
        "inline-flex items-center gap-1 px-2 py-1 rounded text-xs font-medium bg-green-100 text-green-800"

      "cancelled" ->
        "inline-flex items-center gap-1 px-2 py-1 rounded text-xs font-medium bg-red-100 text-red-800"

      "pending" ->
        "inline-flex items-center gap-1 px-2 py-1 rounded text-xs font-medium bg-yellow-100 text-yellow-800"

      "failed" ->
        "inline-flex items-center gap-1 px-2 py-1 rounded text-xs font-medium bg-red-100 text-red-800"

      "matching" ->
        "inline-flex items-center gap-1 px-2 py-1 rounded text-xs font-medium bg-purple-100 text-purple-800"

      _ ->
        "inline-flex items-center gap-1 px-2 py-1 rounded text-xs font-medium bg-gray-100 text-gray-800"
    end
  end

  defp status_icon(status) do
    case status do
      "available" -> "●"
      "offline" -> "●"
      "open" -> "⊙"
      "assigned" -> "✓"
      "completed" -> "✓"
      "cancelled" -> "✕"
      "pending" -> "⏳"
      "failed" -> "✕"
      "matching" -> "⟲"
      _ -> "•"
    end
  end

  @doc """
  Renders a horizontal rule with consistent styling.
  """
  def divider(assigns) do
    ~H"""
    <div class="border-t border-gray-200 my-6"></div>
    """
  end

  @doc """
  Renders a card container with consistent styling.
  """
  def card(assigns) do
    ~H"""
    <div class="rounded-lg bg-white p-6 shadow hover:shadow-lg transition-shadow">
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  @doc """
  Renders a section header with consistent styling.
  """
  def section_header(assigns) do
    ~H"""
    <h2 class="text-2xl font-bold text-gray-900 mb-6"><%= @label %></h2>
    """
  end

  @doc """
  Renders a metric card for dashboard displays.
  """
  def metric_card(assigns) do
    ~H"""
    <div class="rounded-lg bg-white p-6 shadow">
      <h3 class="text-lg font-semibold text-gray-900"><%= @label %></h3>
      <p class={metric_value_class(@color)}>
        <%= @value %>
      </p>
      <%= if @subtitle do %>
        <p class="mt-2 text-sm text-gray-600"><%= @subtitle %></p>
      <% end %>
    </div>
    """
  end

  defp metric_value_class(color) do
    case color do
      "green" -> "mt-2 text-3xl font-bold text-green-600"
      "blue" -> "mt-2 text-3xl font-bold text-blue-600"
      "yellow" -> "mt-2 text-3xl font-bold text-yellow-600"
      "purple" -> "mt-2 text-3xl font-bold text-purple-600"
      "red" -> "mt-2 text-3xl font-bold text-red-600"
      _ -> "mt-2 text-3xl font-bold text-gray-600"
    end
  end
end
