# lib/frestyl_web/router.ex
defmodule FrestylWeb.Router do
  use FrestylWeb, :router
  require Logger

  import Phoenix.LiveView.Router
  import FrestylWeb.UserAuth
  alias FrestylWeb.Plugs.{RoleAuth, RateLimiter}

  # ----------------
  # PIPELINES
  # ----------------

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {FrestylWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user # This plug assigns the current_user
  end

  # Authentication pipelines
  pipeline :require_auth do
    plug :debug_request
    # This plug redirects unauthenticated users to login
    plug :require_authenticated_user
  end

  # Add this new pipeline for media caching
  pipeline :media_cache do
    plug FrestylWeb.Plugs.MediaCache
  end

  # This pipeline redirects authenticated users away from public auth pages
  pipeline :redirect_auth do
    plug :redirect_if_user_is_authenticated
  end

  # Role-specific pipelines
  pipeline :require_creator do
    plug :require_authenticated_user
    plug RoleAuth, ["creator", "host", "channel_owner", "admin"]
  end

  pipeline :require_host do
    plug :require_authenticated_user
    plug RoleAuth, ["host", "channel_owner", "admin"]
  end

  pipeline :require_channel_owner do
    plug :require_authenticated_user
    plug RoleAuth, ["host", "channel_owner", "admin"]
  end

  pipeline :require_admin do
    plug :require_authenticated_user
    plug RoleAuth, ["admin"]
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # API Authentication pipeline - for authenticating API requests
  pipeline :api_auth do
    plug :fetch_session
    plug :fetch_current_user
    # If no current_user present, try API token auth
    plug FrestylWeb.Plugs.ApiAuth
  end

  # API 2FA verification pipeline - ensures 2FA is verified if enabled
  pipeline :api_2fa do
    plug FrestylWeb.Plugs.API2FACheck
  end

  pipeline :rate_limited do
    plug RateLimiter, limit: 5, period: 60_000
  end

  # ----------------
  # SCOPES
  # ----------------

  # Public routes
  scope "/", FrestylWeb do
    pipe_through [:browser]

    # Home page
    get "/", PageController, :home

    # LiveView auth session for unauthenticated users
    # This session uses the on_mount hook to redirect authenticated users
    live_session :redirect_auth, on_mount: [{FrestylWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/register", UserRegistrationLive, :new
      live "/login", UserLoginLive, :new
      live "/users/log_in", UserLoginLive, :new
      live "/users/two_factor", UserLive.TwoFactorVerifyLive, :index
      live "/users/register", UserRegistrationLive, :new
      live "/users/confirm", UserConfirmationInstructionsLive, :new
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    # Auth submission endpoints (controller-based)
    # These typically don't need the redirect_auth plug as they handle redirects internally
    # Applying :redirect_auth to the GET requests for forms
    get "/users/register", UserRegistrationController, :new, pipeline_through: [:redirect_auth]
    post "/users/register", UserRegistrationController, :create
    get "/users/log_in", UserSessionController, :new, pipeline_through: [:redirect_auth]
    post "/users/log_in", UserSessionController, :create
    post "/login", UserSessionController, :create

    # Event invitations (public routes)
    get "/invitations/:token", InvitationController, :show
    get "/invitations/:token", InvitationController, :accpet
    get "/invitations/:token/accept", InvitationController, :accept
    get "/invitations/:token/decline", InvitationController, :decline
  end

  # User invitations (public routes)
  scope "/users", FrestylWeb do
    pipe_through [:browser]

    # User account invitations - these don't require auth
    get "/invitations/:token", UserInvitationController, :show
    get "/invitations/:token/accept", UserInvitationController, :accept
    get "/invitations/:token/decline", UserInvitationController, :decline
  end

  # Routes available to everyone (no auth check)
  scope "/", FrestylWeb do
    pipe_through [:browser]

    # Logout route
    delete "/users/log_out", UserSessionController, :delete
    delete "/logout", UserSessionController, :delete

    # Legacy controller routes - consider moving to authenticated if needed
    get "/users/new", UserController, :new
    post "/users", UserController, :create
    resources "/users", UserController, except: [:new, :create, :show]
  end

  # All authenticated routes
  scope "/", FrestylWeb do
    # This pipeline ensures only authenticated users can access routes within this scope
    pipe_through [:browser, :require_auth]

    # LiveView authenticated session
    # This session uses the on_mount hook to ensure authentication
    # IMPORTANT: Place live_session BEFORE controller routes for the same path
    live_session :require_auth, on_mount: [{FrestylWeb.UserAuth, :ensure_authenticated}] do
      # DASHBOARD - Primary landing page (LiveView takes precedence)
      live "/", DashboardLive, :index
      live "/dashboard", DashboardLive, :index # This will now be matched before the GET /dashboard below

      # CHANNELS
      live "/channels", ChannelLive.Index, :index
      live "/channels/new", ChannelLive.Index, :new
      live "/channels/:id", ChannelLive.Show, :show
      live "/channels/:id/edit", ChannelLive.Form, :edit
      live "/channels/:id/media", ChannelLive.MediaTab, :media

      # CHAT
      live "/chat", ChatLive.Index, :index
      live "/chat/:channel_id", ChatLive.Show, :show

      # MEDIA
      live "/media", MediaLive.Index, :index
      live "/media/new", MediaLive.Index, :new
      live "/media/upload", MediaLive.Upload, :index
      live "/media/:id", MediaLive.Show, :show
      live "/media/:id/edit", MediaLive.Index, :edit

      # EVENTS
      live "/events", EventLive.Index, :index
      live "/events/new", EventLive.Index, :new
      live "/events/:id", EventLive.Show, :show
      live "/events/:id/edit", EventLive.Index, :edit
      live "/events/:id/attend", EventAttendanceLive, :show

      # USERS
      live "/invite", InviteUserLive, :index

      # COLLABORATIONS
      live "/collaborations", CollaborationLive, :index

      # ANALYTICS
      live "/analytics", AnalyticsLive.Dashboard, :index
      live "/analytics/channels/:channel_id", AnalyticsLive.Dashboard, :channel
      live "/analytics/performance", AnalyticsLive.PerformanceDashboard, :index
      live "/analytics/revenue", AnalyticsLive.RevenueDashboard, :index
      live "/analytics/audience", AnalyticsLive.AudienceDashboard, :index

      # PROFILE
      live "/profile", UserLive.Profile, :show

      # SECURITY AND PRIVACY SETTINGS
      live "/users/settings/two_factor", UserLive.TwoFactorSetupLive, :index
      live "/account/sessions", UserLive.SessionManagementLive, :index
      live "/account/privacy", UserLive.PrivacySettingsLive, :index
    end

    # Dashboard controller endpoint (will only be reached if the LiveView route is not matched)
    # This route is still protected by the :require_auth pipeline on the scope.
    get "/dashboard", DashboardController, :index

    # Other authenticated controller routes
    get "/users/log_in_success", UserSessionController, :log_in_success
    get "/users/create_from_2fa", UserSessionController, :create_from_2fa
    get "/session/create_from_liveview", UserSessionController, :create_from_liveview

    # TICKETS
    get "/events/:event_id/tickets", TicketController, :buy
    post "/tickets/checkout", TicketController, :create_checkout
    get "/events/:event_id/tickets/success", TicketController, :success
    get "/my-tickets", TicketController, :my_tickets

    # SEARCH
    get "/search", SearchController, :index

    # PROFILE
    get "/profile/edit", UserProfileController, :edit
    put "/profile", UserProfileController, :update

    # ACCOUNT
    get "/account/subscription", AccountController, :subscription

    # SUBSCRIPTIONS
    resources "/subscriptions", SubscriptionController, except: [:new, :create]
    get "/subscriptions/new/:plan_id", SubscriptionController, :new
    post "/subscriptions", SubscriptionController, :create

    # CHANNELS (Controller-based for backward compatibility)
    resources "/channels", ChannelController, param: "slug", except: [:index, :show]
    get "/channels/:slug", ChannelController, :show

    # ROOMS (nested under channel)
    resources "/channels/:channel_slug/rooms", RoomController, param: "slug", except: [:index]

    # MESSAGES
    delete "/channels/:channel_slug/rooms/:room_slug/messages/:id", MessageController, :delete

    # MEMBERSHIP
    resources "/channels/:channel_slug/members", MembershipController, only: [:index, :create, :delete]
    put "/channels/:channel_slug/members/:id/role", MembershipController, :update

    # INVITATIONS (auth-required)
    resources "/channels/:channel_slug/invitations", InvitationController, only: [:index, :create]
    post "/channels/:channel_slug/invitations/:id/cancel", InvitationController, :cancel

    # MEDIA FILES (global + nested)
    resources "/media", MediaController
    post "/media/:asset_id/version", MediaController, :upload_version
    get "/media/stream/:asset_id/:version_id", MediaController, :stream
    get "/media/:id", MediaController, :download

    get "/channels/:channel_slug/files", FileController, :index
    get "/channels/:channel_slug/files/new", FileController, :new
    post "/channels/:channel_slug/files", FileController, :create
    delete "/channels/:channel_slug/files/:id", FileController, :delete

    get "/channels/:channel_slug/rooms/:room_slug/files", FileController, :index
    get "/channels/:channel_slug/rooms/:room_slug/files/new", FileController, :new
    post "/channels/:channel_slug/rooms/:room_slug/files", FileController, :create
    delete "/channels/:channel_slug/rooms/:room_slug/files/:id", FileController, :delete

    # SESSIONS (careful with naming - these aren't user sessions)
    resources "/sessions", SessionController, except: [:new, :create, :delete]
    post "/sessions/:id/join", SessionController, :join
    post "/sessions/:id/leave", SessionController, :leave
    post "/sessions/:id/start", SessionController, :start
    post "/sessions/:id/end", SessionController, :end
    get  "/sessions/:id/room", SessionController, :room
  end

  # Public API routes - no authentication required
  scope "/api", FrestylWeb.Api do
    pipe_through [:api]

    # Authentication
    post "/auth/login", AuthController, :login
    post "/auth/register", AuthController, :register

    # Public content
    get "/discover", DiscoverController, :index
    get "/channels/public", ChannelController, :public
  end

  # API routes that require authentication but not 2FA
  scope "/api", FrestylWeb.Api do
    pipe_through [:api, :api_auth]

    # Authentication status and 2FA verification
    get "/auth/status", AuthController, :status
    post "/auth/verify_2fa", AuthController, :verify_2fa
    post "/auth/verify_backup_code", AuthController, :verify_backup_code
    post "/auth/logout", AuthController, :logout

    # Basic user data and public profiles
    get "/users/me", UserController, :me
    resources "/profiles", ProfileController, only: [:index, :show]

    # Public content browsing
    resources "/channels", ChannelController, only: [:index, :show]
    get "/media/public", MediaController, :public
  end

  # API routes that require both authentication and 2FA verification
  scope "/api", FrestylWeb.Api do
    pipe_through [:api, :api_auth, :api_2fa]

    # User account management (sensitive operations)
    resources "/users", UserController, only: [:update, :delete]
    post "/users/change_password", UserController, :change_password
    post "/users/disable_2fa", UserController, :disable_2fa

    # Media management
    resources "/media", MediaController, except: [:new, :edit]
    post "/media/:id/upload", MediaController, :upload
    delete "/media/:id/versions/:version_id", MediaController, :delete_version

    # Account settings
    resources "/settings", SettingsController, only: [:index, :update]
    resources "/subscriptions", SubscriptionController
    get "/billing/history", BillingController, :history
    post "/billing/update_payment", BillingController, :update_payment

    # Channel management
    resources "/channels", ChannelController, except: [:index, :show]
    post "/channels/:id/members", ChannelController, :add_member
    delete "/channels/:id/members/:user_id", ChannelController, :remove_member

    # Admin operations (if user has admin role)
    resources "/admin/users", AdminUserController
    resources "/admin/settings", AdminSettingsController
    resources "/admin/metrics", AdminMetricsController, only: [:index]
  end

  # IMPORTANT: Move the uploads route outside of any other scope
  # This creates a separate scope at the root level
  scope "/uploads", FrestylWeb do
    pipe_through [:browser, :require_auth, :media_cache]

    get "/*path", MediaController, :serve_file
  end

  defp debug_request(conn, _opts) do
    Logger.info("Processing request: #{conn.request_path} with method #{conn.method}")
    Logger.info("Current user: #{inspect conn.assigns[:current_user]}")
    conn
  end
end
