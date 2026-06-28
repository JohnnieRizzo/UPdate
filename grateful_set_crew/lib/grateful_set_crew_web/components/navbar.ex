defmodule GratefulSetCrewWeb.Components.Navbar do
  use Phoenix.Component

  @doc """
  Renders the main navigation bar.
  Requires: current_user (optional)
  """
  def navbar(assigns) do
    ~H"""
    <nav class="text-white shadow-lg">
      <div class="max-w-7xl mx-auto px-6 py-8">
        <div class="flex items-center justify-between">
          <!-- Logo -->
          <div class="flex items-center gap-2">
            <a href="/">
              <img src="/images/icon-no-text.png" alt="GratefulSetCrew" class="h-48 w-auto" />
            </a>
          </div>

          <!-- Navigation Links -->
          <div class="hidden md:flex items-center gap-8">
            <%= if @current_user do %>
              <!-- Authenticated Navigation -->
              <div class="flex items-center gap-6">
                <%= case @current_user.role do %>
                  <% "crew" -> %>
                    <a
                      href="/crew/dashboard"
                      class="hover:text-gold transition-colors"
                    >
                      Dashboard
                    </a>
                    <a
                      href="/crew/profile"
                      class="hover:text-gold transition-colors"
                    >
                      Profile
                    </a>
                    <a
                      href="/crew/earnings"
                      class="hover:text-gold transition-colors"
                    >
                      Earnings
                    </a>

                  <% "client" -> %>
                    <a
                      href="/client/dashboard"
                      class="hover:text-gold transition-colors"
                    >
                      My Jobs
                    </a>

                  <% "admin" -> %>
                    <a
                      href="/admin/dashboard"
                      class="hover:text-gold transition-colors"
                    >
                      Admin
                    </a>

                  <% _ -> %>
                <% end %>

                <!-- User Menu -->
                <div class="flex items-center gap-4 pl-6 border-l border-gray-600">
                  <span class="text-sm"><%= @current_user.email %></span>
                  <.logout_button />
                </div>
              </div>
            <% else %>
              <!-- Unauthenticated Navigation -->
              <div class="flex items-center gap-4">
                <a
                  href="/users/log-in"
                  class="hover:text-gold transition-colors"
                >
                  Login
                </a>
                <a
                  href="/users/register"
                  class="bg-orange-cta hover:bg-orange-600 px-6 py-2 rounded-lg font-semibold transition-colors"
                >
                  Sign Up
                </a>
              </div>
            <% end %>
          </div>

          <!-- Mobile Menu Button -->
          <button
            class="md:hidden text-white hover:text-gold"
            phx-click="toggle_mobile_menu"
          >
            ☰
          </button>
        </div>
      </div>
    </nav>
    """
  end

  defp logout_button(assigns) do
    ~H"""
    <form method="post" action="/users/log-out" class="inline">
      <input type="hidden" name="_method" value="delete" />
      <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
      <button
        type="submit"
        class="bg-orange-cta hover:bg-orange-600 px-4 py-2 rounded font-semibold transition-colors text-sm"
      >
        Logout
      </button>
    </form>
    """
  end
end
