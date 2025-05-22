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
    plug FrestylWeb.UserAuth, :fetch_current_user
  end

  # UPDATED: Make sure we fetch_current_user before trying to require it
  pipeline :require_auth do
    plug :debug_request
    plug :require_authenticated_user
  end

  pipeline :media_cache do
    plug FrestylWeb.Plugs.MediaCache
  end

  # UPDATED: Only use the redirect_if_user_is_authenticated plug
  pipeline :redirect_auth do
    plug :redirect_if_user_is_authenticated
  end

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

  pipeline :api_auth do
    plug :fetch_session
    plug :fetch_current_user
    plug FrestylWeb.Plugs.ApiAuth
  end

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

    get "/", PageController, :home

    # UPDATED: Keep live_session configuration for unauthenticated views
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

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
    get "/users/log_in", UserSessionController, :new
    post "/users/log_in", UserSessionController, :create
    post "/login", UserSessionController, :create

    # Event invitations (public routes)
    get "/invitations/:token", InvitationController, :show
    get "/invitations/:token/accept", InvitationController, :accept
    get "/invitations/:token/decline", InvitationController, :decline
  end

  scope "/users", FrestylWeb do
    pipe_through [:browser]

    get "/invitations/:token", UserInvitationController, :show
    get "/invitations/:token/accept", UserInvitationController, :accept
    get "/invitations/:token/decline", UserInvitationController, :decline
  end

  scope "/", FrestylWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete
    delete "/logout", UserSessionController, :delete

    get "/users/new", UserController, :new
    post "/users", UserController, :create
    resources "/users", UserController, except: [:new, :create, :show]
  end

  # Authenticated routes
  scope "/", FrestylWeb do
    pipe_through [:browser, :require_auth]

    # UPDATED: :ensure_authenticated has been fixed to work properly
    live_session :require_auth, on_mount: [{FrestylWeb.UserAuth, :ensure_authenticated}] do
      live "/dashboard", DashboardLive, :index

      # Channels
      live "/channels", ChannelLive.Index, :index
      live "/channels/new", ChannelLive.Index, :new
      live "/channels/:id", ChannelLive.Show, :show
      live "/channels/:id/edit", ChannelLive.Form, :edit
      live "/channels/:id/media", ChannelLive.MediaTab, :media

      # Sessions
      live "/channels/:slug/sessions", SessionLive.Index, :index
      live "/channels/:channel_slug/sessions/:session_id", StudioLive, :show
      live "/channels/:channel_slug/sessions/:session_id/edit", StudioLive, :edit_session

      # Broadcasts
      live "/channels/:channel_slug/broadcasts", BroadcastLive.Index, :index

      # Sound check before joining (both channel context and direct access)
      live "/channels/:channel_slug/broadcasts/:broadcast_id/sound-check", BroadcastLive.SoundCheck, :show
      live "/broadcasts/:broadcast_id/sound-check", BroadcastLive.SoundCheck, :show

      # Waiting room for scheduled broadcasts
      live "/channels/:channel_slug/broadcasts/:broadcast_id/waiting", BroadcastLive.WaitingRoom, :show
      live "/broadcasts/:broadcast_id/waiting", BroadcastLive.WaitingRoom, :show

      # Live broadcast view
      live "/channels/:channel_slug/broadcasts/:broadcast_id/live", BroadcastLive.Show, :show
      live "/broadcasts/:broadcast_id/live", BroadcastLive.Show, :show

      # Host management dashboard
      live "/channels/:channel_id/broadcasts/:broadcast_id/manage", BroadcastLive.Manage, :show
      live "/broadcasts/:broadcast_id/manage", BroadcastLive.Manage, :show

      # Chat
      live "/chat", ChatLive.Index, :index
      live "/chat/:id", ChatLive.Index, :show
      live "/channels/:channel_slug/chat", ChatLive.Show, :show

      # Media
      live "/media", MediaLive.Index, :index
      live "/media/new", MediaLive.Index, :new
      live "/media/upload", MediaLive.Upload, :index
      live "/media/:id", MediaLive.Show, :show
      live "/media/:id/edit", MediaLive.Index, :edit

      # Events
      live "/events", EventLive.Index, :index
      live "/events/new", EventLive.Index, :new
      live "/events/:id", EventLive.Show, :show
      live "/events/:id/edit", EventLive.Index, :edit
      live "/events/:id/attend", EventAttendanceLive, :show

      # Users and Profile
      live "/invite", InviteUserLive, :index
      live "/collaborations", CollaborationLive, :index
      live "/analytics", AnalyticsLive.Dashboard, :index
      live "/analytics/channels/:channel_id", AnalyticsLive.Dashboard, :channel
      live "/analytics/performance", AnalyticsLive.PerformanceDashboard, :index
      live "/analytics/revenue", AnalyticsLive.RevenueDashboard, :index
      live "/analytics/audience", AnalyticsLive.AudienceDashboard, :index
      live "/profile", UserLive.Profile, :show
      live "/users/settings/two_factor", UserLive.TwoFactorSetupLive, :index
      live "/account/sessions", UserLive.SessionManagementLive, :index
      live "/account/privacy", UserLive.PrivacySettingsLive, :index

        # Portfolio routes
      live "/portfolios", PortfolioLive.IndexLive, :index
      live "/portfolios/:id/edit", PortfolioLive.EditLive, :edit
      live "/portfolios/:id/share", PortfolioLive.ShareLive, :share
      live "/portfolios/:id/analytics", PortfolioLive.AnalyticsLive, :analytics
      live "/portfolios/:portfolio_id/resume-parser", PortfolioLive.ResumeParserLive, :parse
    end

    get "/dashboard", DashboardController, :index
    get "/users/log_in_success", UserSessionController, :log_in_success
    get "/users/create_from_2fa", UserSessionController, :create_from_2fa
    get "/session/create_from_liveview", UserSessionController, :create_from_liveview

    # Tickets
    get "/events/:event_id/tickets", TicketController, :buy
    post "/tickets/checkout", TicketController, :create_checkout
    get "/events/:event_id/tickets/success", TicketController, :success
    get "/my-tickets", TicketController, :my_tickets

    get "/search", SearchController, :index

    get "/profile/edit", UserProfileController, :edit
    put "/profile", UserProfileController, :update

    get "/account/subscription", AccountController, :subscription

    resources "/subscriptions", SubscriptionController, except: [:new, :create]
    get "/subscriptions/new/:plan_id", SubscriptionController, :new
    post "/subscriptions", SubscriptionController, :create

    resources "/channels", ChannelController, param: "slug", except: [:index, :show]
    get "/channels/:slug", ChannelController, :show

    get "/broadcasts/:id", BroadcastController, :show
    resources "/channels/:channel_slug/rooms", RoomController, param: "slug", except: [:index]

    delete "/channels/:channel_slug/rooms/:room_slug/messages/:id", MessageController, :delete

    resources "/channels/:channel_slug/members", MembershipController, only: [:index, :create, :delete]
    put "/channels/:channel_slug/members/:id/role", MembershipController, :update

    resources "/channels/:channel_slug/invitations", InvitationController, only: [:index, :create]
    post "/channels/:channel_slug/invitations/:id/cancel", InvitationController, :cancel

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

    resources "/sessions", SessionController, except: [:new, :create, :delete]
    post "/sessions/:id/join", SessionController, :join
    post "/sessions/:id/leave", SessionController, :leave
    post "/sessions/:id/start", SessionController, :start
    post "/sessions/:id/end", SessionController, :end
    get  "/sessions/:id/room", SessionController, :room
    get "/sessions/:id/join", SessionController, :join_form

    get "/broadcasts/:id/register", BroadcastController, :register_form
    post "/broadcasts/:id/register", BroadcastController, :register
    get "/broadcasts/:id/join", BroadcastController, :join
  end

  # API: Public
  scope "/api", FrestylWeb.Api do
    pipe_through [:api]

    post "/auth/login", AuthController, :login
    post "/auth/register", AuthController, :register
    get "/discover", DiscoverController, :index
    get "/channels/public", ChannelController, :public
    post "/upload", UploadController, :create
  end

  # API: Authenticated
  scope "/api", FrestylWeb.Api do
    pipe_through [:api, :api_auth]

    get "/auth/status", AuthController, :status
    post "/auth/verify_2fa", AuthController, :verify_2fa
    post "/auth/verify_backup_code", AuthController, :verify_backup_code
    post "/auth/logout", AuthController, :logout

    get "/users/me", UserController, :me
    resources "/profiles", ProfileController, only: [:index, :show]
    resources "/channels", ChannelController, only: [:index, :show]
    get "/media/public", MediaController, :public
  end

  # API: Auth + 2FA
  scope "/api", FrestylWeb.Api do
    pipe_through [:api, :api_auth, :api_2fa]

    resources "/users", UserController, only: [:update, :delete]
    post "/users/change_password", UserController, :change_password
    post "/users/disable_2fa", UserController, :disable_2fa

    resources "/media", MediaController, except: [:new, :edit]
    post "/media/:id/upload", MediaController, :upload
    delete "/media/:id/versions/:version_id", MediaController, :delete_version

    resources "/settings", SettingsController, only: [:index, :update]
    resources "/subscriptions", SubscriptionController
    get "/billing/history", BillingController, :history
    post "/billing/update_payment", BillingController, :update_payment

    resources "/channels", ChannelController, except: [:index, :show]
    post "/channels/:id/members", ChannelController, :add_member
    delete "/channels/:id/members/:user_id", ChannelController, :remove_member

    resources "/admin/users", AdminUserController
    resources "/admin/settings", AdminSettingsController
    resources "/admin/metrics", AdminMetricsController, only: [:index]
  end

  # Uploads: Separate static route
  scope "/uploads", FrestylWeb do
    pipe_through [:browser, :require_auth, :media_cache]
    get "/*path", MediaController, :serve_file
  end


  scope "/", FrestylWeb do
    pipe_through [:browser]

    # Catch-all route for custom portfolio URLs
    live "/:slug", PortfolioLive.ViewLive, :portfolio
  end

  defp debug_request(conn, _opts) do
    Logger.info("Processing request: #{conn.request_path} with method #{conn.method}")
    Logger.info("Current user: #{inspect conn.assigns[:current_user]}")
    conn
  end
end
