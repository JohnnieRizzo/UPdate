defmodule GratefulSetCrewWeb.Router do
  use GratefulSetCrewWeb, :router

  import GratefulSetCrewWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {GratefulSetCrewWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :require_auth do
    plug :require_authenticated_user
  end

  pipeline :require_crew do
    plug :require_authenticated_user
    plug :require_crew_role
  end

  pipeline :require_crew_onboarded do
    plug :require_authenticated_user
    plug :require_crew_role
    plug :require_orientation_complete
  end

  pipeline :require_client do
    plug :require_authenticated_user
    plug :require_client_role
  end

  pipeline :require_admin do
    plug :require_authenticated_user
    plug :require_admin_role
  end

  scope "/", GratefulSetCrewWeb do
    pipe_through :browser

    live "/", HomeLive, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", GratefulSetCrewWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:grateful_set_crew, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: GratefulSetCrewWeb.Telemetry
    end
  end

  ## Authentication routes

  scope "/", GratefulSetCrewWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
  end

  scope "/", GratefulSetCrewWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
    get "/users/settings/confirm-email/:token", UserSettingsController, :confirm_email
  end

  scope "/", GratefulSetCrewWeb do
    pipe_through [:browser]

    get "/users/log-in", UserSessionController, :new
    get "/users/log-in/:token", UserSessionController, :confirm
    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end

  ## Onboarding routes (crew only, not yet complete)
  scope "/onboarding", GratefulSetCrewWeb do
    pipe_through [:browser, :require_crew, :require_orientation_incomplete]

    live "/", OnboardingLive, :index
  end

  ## Crew routes (requires crew role + completed orientation)
  scope "/crew", GratefulSetCrewWeb do
    pipe_through [:browser, :require_crew_onboarded]

    live "/dashboard", CrewLive.Dashboard, :index
    live "/profile", CrewLive.Profile, :index
    live "/earnings", CrewLive.Earnings, :index
    live "/jobs", CrewLive.Jobs, :index
  end

  ## Client routes (requires client role)
  scope "/client", GratefulSetCrewWeb do
    pipe_through [:browser, :require_client]

    live "/dashboard", ClientLive.Dashboard, :index
    live "/jobs/new", ClientLive.PostJob, :new
    live "/jobs/:id/edit", ClientLive.PostJob, :edit
    live "/jobs", ClientLive.Jobs, :index
  end

  ## Admin routes (requires admin role)
  scope "/admin", GratefulSetCrewWeb do
    pipe_through [:browser, :require_admin]

    live "/dashboard", AdminLive.Dashboard, :index
  end

  ## Stripe webhook routes (no authentication required)
  scope "/webhooks", GratefulSetCrewWeb do
    pipe_through [:api]

    post "/stripe", StripeWebhookController, :handle
  end
end
