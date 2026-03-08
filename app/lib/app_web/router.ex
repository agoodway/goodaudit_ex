defmodule GAWeb.Router do
  use GAWeb, :router

  import GAWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {GAWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  # Base API pipeline - no auth, just JSON + OpenAPI spec injection
  pipeline :api do
    plug :accepts, ["json"]
    plug CORSPlug
    plug OpenApiSpex.Plug.PutApiSpec, module: GAWeb.ApiSpec
  end

  # Authenticated API - requires valid API key
  pipeline :api_authenticated do
    plug :accepts, ["json"]
    plug CORSPlug
    plug OpenApiSpex.Plug.PutApiSpec, module: GAWeb.ApiSpec
    plug GAWeb.Plugs.ApiAuth, :require_api_auth
  end

  # Write access - requires private API key (sk_...)
  pipeline :api_write do
    plug :accepts, ["json"]
    plug CORSPlug
    plug OpenApiSpex.Plug.PutApiSpec, module: GAWeb.ApiSpec
    plug GAWeb.Plugs.ApiAuth, :require_api_auth
    plug GAWeb.Plugs.ApiAuth, :require_write_access
  end

  pipeline :load_account do
    plug GAWeb.Plugs.LoadAccount
  end

  scope "/", GAWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # ============================================
  # Dashboard Routes
  # ============================================

  # Account-scoped dashboard (LiveView)
  scope "/dashboard/accounts/:account_id", GAWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :account_scoped,
      on_mount: [
        {GAWeb.UserAuth, :mount_current_scope},
        {GAWeb.UserAuth, :ensure_authenticated},
        {GAWeb.UserAuth, :load_account_context}
      ],
      layout: {GAWeb.Layouts, :dashboard} do
      live "/", DashboardLive, :index
      live "/audit-logs", AuditLogLive.Index, :index
      live "/api-keys", ApiKeyLive.Index, :index
    end
  end

  # /dashboard redirect to default account
  scope "/", GAWeb do
    pipe_through [:browser, :require_authenticated_user]
    get "/dashboard", DashboardRedirectController, :index
  end

  # ============================================
  # OpenAPI Documentation (no auth required)
  # ============================================
  scope "/api/v1" do
    pipe_through :api

    get "/openapi", OpenApiSpex.Plug.RenderSpec, []
    get "/docs", OpenApiSpex.Plug.SwaggerUI, path: "/api/v1/openapi"
  end

  # ============================================
  # API Routes - Read (authenticated)
  # ============================================
  scope "/api/v1", GAWeb.Api.V1, as: :api_v1 do
    pipe_through :api_authenticated

    resources "/audit-logs", AuditLogController, only: [:index, :show]
    get "/taxonomies", TaxonomyController, :index
    get "/taxonomies/:framework", TaxonomyController, :show
    get "/action-mappings", ActionMappingController, :index
    post "/action-mappings/validate", ActionMappingController, :validate
    resources "/checkpoints", CheckpointController, only: [:index]
    post "/verify", VerificationController, :create
  end

  # ============================================
  # API Routes - Write (authenticated + write access)
  # ============================================
  scope "/api/v1", GAWeb.Api.V1, as: :api_v1 do
    pipe_through :api_write

    resources "/audit-logs", AuditLogController, only: [:create]
    post "/action-mappings", ActionMappingController, :create
    put "/action-mappings/:id", ActionMappingController, :update
    delete "/action-mappings/:id", ActionMappingController, :delete
    resources "/checkpoints", CheckpointController, only: [:create]
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:app, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: GAWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", GAWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
  end

  scope "/", GAWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
    get "/users/settings/confirm-email/:token", UserSettingsController, :confirm_email
  end

  scope "/", GAWeb do
    pipe_through [:browser]

    get "/users/log-in", UserSessionController, :new
    get "/users/log-in/:token", UserSessionController, :confirm
    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
