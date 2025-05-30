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

  # Public portfolio viewing routes (before authenticated routes)
  scope "/", FrestylWeb do
    pipe_through [:browser]

    # Public portfolio sharing routes
    live "/p/:slug", PortfolioLive.View, :view
    live "/portfolios/:slug", PortfolioLive.View, :view
    live "/portfolios/share/:token", PortfolioLive.View, :shared
  end

  # Authenticated routes
  scope "/", FrestylWeb do
    pipe_through [:browser, :require_auth]

    # UPDATED: :ensure_authenticated has been fixed to work properly
    live_session :require_auth, on_mount: [{FrestylWeb.UserAuth, :ensure_authenticated}] do
      live "/dashboard", DashboardLive, :index

      # Channels - Use slug consistently
      live "/channels", ChannelLive.Index, :index
      live "/channels/new", ChannelLive.Index, :new
      live "/channels/:slug", ChannelLive.Show, :show
      live "/channels/:slug/edit", ChannelLive.Form, :edit
      live "/channels/:slug/media", ChannelLive.MediaTab, :media

      # Channel customization routes
      live "/channels/:slug/customize", ChannelLive.Customize, :edit
      live "/channels/:slug/settings", ChannelLive.Settings, :edit
      live "/channels/:slug/members", ChannelLive.Members, :index
      live "/channels/:slug/analytics", ChannelLive.Analytics, :index

      # Enhanced content management
      live "/channels/:slug/content", ContentLive.Index, :index
      live "/channels/:slug/content/upload", ContentLive.Upload, :new
      live "/channels/:slug/content/:id", ContentLive.Show, :show

      # Sessions - Consistent slug usage
      live "/channels/:slug/sessions", SessionLive.Index, :index
      live "/channels/:slug/sessions/:session_id", StudioLive, :show
      live "/channels/:slug/sessions/:session_id/edit", StudioLive, :edit_session

      # Broadcasts - Consistent slug usage
      live "/channels/:slug/broadcasts", BroadcastLive.Index, :index
      live "/channels/:slug/broadcasts/new", BroadcastLive.Index, :new
      live "/channels/:slug/broadcasts/:id", BroadcastLive.Show, :show
      live "/channels/:slug/broadcasts/:id/edit", BroadcastLive.Show, :edit
      live "/channels/:slug/broadcasts/:id/manage", BroadcastLive.Manage, :show

      # Keep existing broadcast routes with slug consistency
      live "/channels/:slug/broadcasts/:broadcast_id/sound-check", BroadcastLive.SoundCheck, :show
      live "/broadcasts/:broadcast_id/sound-check", BroadcastLive.SoundCheck, :show
      live "/channels/:slug/broadcasts/:broadcast_id/waiting", BroadcastLive.WaitingRoom, :show
      live "/broadcasts/:broadcast_id/waiting", BroadcastLive.WaitingRoom, :show
      live "/channels/:slug/broadcasts/:broadcast_id/live", BroadcastLive.Show, :show
      live "/broadcasts/:broadcast_id/live", BroadcastLive.Show, :show
      live "/channels/:slug/broadcasts/:broadcast_id/manage", BroadcastLive.Manage, :show
      live "/broadcasts/:broadcast_id/manage", BroadcastLive.Manage, :show

      # Studio routes
      live "/channels/:slug/studio", StudioLive.Index, :index
      live "/channels/:slug/go-live", StudioLive.Broadcast, :new

      # Chat
      live "/chat", ChatLive.Show
      live "/chat/channel/:id", ChatLive.Show, :channel
      live "/chat/conversation/:id", ChatLive.Show, :conversation
      live "/chat/:id", ChatLive.Show  # Auto-detect

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

      # Portfolio routes - Clean module names
      live "/portfolios", PortfolioLive.Index, :index
            live "/p/:slug", PortfolioLive.View, :show
      live "/portfolios/:id/edit", PortfolioLive.Edit, :edit

      live "/portfolios/:id/share", PortfolioLive.Share, :share
      live "/portfolios/:id/analytics", PortfolioLive.Analytics, :analytics
      live "/portfolios/:portfolio_id/resume-parser", PortfolioLive.ResumeParser, :parse
      live "/portfolios/:portfolio_id/sections/new", PortfolioLive.SectionEdit, :new
      live "/portfolios/:portfolio_id/sections/:id/edit", PortfolioLive.SectionEdit, :edit

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

    # FIXED: Add missing subscription route
    get "/account/subscription", SubscriptionController, :index

    resources "/subscriptions", SubscriptionController, except: [:new, :create]
    get "/subscriptions/new/:plan_id", SubscriptionController, :new
    post "/subscriptions", SubscriptionController, :create

    resources "/channels", ChannelController, param: "slug", except: [:index, :show]

    get "/broadcasts/:id", BroadcastController, :show
    resources "/channels/:slug/rooms", RoomController, param: "slug", except: [:index]

    delete "/channels/:slug/rooms/:room_slug/messages/:id", MessageController, :delete

    resources "/channels/:slug/members", MembershipController, only: [:index, :create, :delete]
    put "/channels/:slug/members/:id/role", MembershipController, :update

    resources "/channels/:slug/invitations", InvitationController, only: [:index, :create]
    post "/channels/:slug/invitations/:id/cancel", InvitationController, :cancel

    resources "/media", MediaController
    post "/media/:asset_id/version", MediaController, :upload_version
    get "/media/stream/:asset_id/:version_id", MediaController, :stream
    get "/media/:id", MediaController, :download

    get "/channels/:slug/files", FileController, :index
    get "/channels/:slug/files/new", FileController, :new
    post "/channels/:slug/files", FileController, :create
    delete "/channels/:slug/files/:id", FileController, :delete

    get "/channels/:slug/rooms/:room_slug/files", FileController, :index
    get "/channels/:slug/rooms/:room_slug/files/new", FileController, :new
    post "/channels/:slug/rooms/:room_slug/files", FileController, :create
    delete "/channels/:slug/rooms/:room_slug/files/:id", FileController, :delete

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

  defp debug_request(conn, _opts) do
    Logger.info("Processing request: #{conn.request_path} with method #{conn.method}")
    Logger.info("Current user: #{inspect conn.assigns[:current_user]}")
    conn
  end
end
