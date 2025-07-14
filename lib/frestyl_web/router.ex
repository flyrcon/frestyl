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

  pipeline :require_auth do
    plug :debug_request
    plug :require_authenticated_user
  end

  pipeline :media_cache do
    plug FrestylWeb.Plugs.MediaCache
  end

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

  pipeline :admin do
    plug :require_admin_user
  end

  pipeline :rate_limited do
    plug RateLimiter, limit: 5, period: 60_000
  end

  # ----------------
  # SCOPES
  # ----------------

  # In router.ex
  scope "/", FrestylWeb do
    live "/services", ServiceLive.Index, :index
    live "/services/new", ServiceLive.New, :new
    live "/services/:id", ServiceLive.Show, :show
    live "/services/:id/edit", ServiceLive.Edit, :edit
    live "/book/:id", ServiceLive.Book, :book
  end

  # Public routes
  scope "/", FrestylWeb do
    pipe_through [:browser]

    get "/", PageController, :home

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

    # Non-LiveView user authentication routes
    post "/users/register", UserRegistrationController, :create
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

    resources "/users", UserController, except: [:new, :create, :show]

    # Public portfolio routes
    # Public portfolio viewing

    live "/p/:slug", PortfolioLive.Show, :public_view


    # Shared portfolio access via token
    live "/share/:token", PortfolioLive.SharedView, :shared

    # Portfolio export endpoints
    get "/p/:slug/export", PortfolioController, :export_pdf
    get "/p/:slug/resume", PortfolioController, :export_resume
  end


  # Authenticated routes
  scope "/", FrestylWeb do
    pipe_through [:browser, :require_auth]

    live_session :require_auth, on_mount: [{FrestylWeb.UserAuth, :ensure_authenticated}] do

    live "/", PortfolioHubLive, :index           # Main landing page
    live "/dashboard", DashboardLive, :index     # General dashboard

    # Onboarding routes
    live "/onboarding", OnboardingLive, :index
    live "/onboarding/resume-upload", OnboardingLive.ResumeUpload, :upload


    # Main dashboard/hub routes - MUST come before generic routes

    live "/hub", PortfolioHubLive, :index        # Portfolio hub
    live "/hub/welcome", PortfolioHubLive, :welcome  # Welcome page

    # Enhanced Portfolio Hub with Chat
    live "/hub", PortfolioHubLiveEnhanced, :index
    live "/hub/:section", PortfolioHubLiveEnhanced, :section




      # Studio routes
    live "/studio", StudioLive.Index, :index
    live "/studio/:slug", StudioLive.Show, :show
    live "/studio/:id", StudioLive.Show, :show
    live "/studio/workspace/:workspace_id", StudioLive.Workspace, :show

    # Story Lab Routes
    live "/lab", LabLive.Index, :index
    live "/lab/story-engine", LabLive.StoryEngine, :index
    live "/lab/templates", LabLive.Templates, :index
    live "/lab/experiments", LabLive.Experiments, :index

    # Portfolio dashboard route
    get "/portfolios/dashboard", PortfolioController, :dashboard

    # Portfolio management dashboard
    live "/portfolios", PortfolioLive.Index, :index

    # In router.ex, add this route:
    live "/live_preview/:id/:preview_token", PortfolioLive.LivePreview

    # Portfolio CRUD operations - SPECIFIC ROUTES FIRST
    live "/portfolios/new", PortfolioLive.New, :new
    live "/portfolios/templates", PortfolioLive.Templates, :index  # ADD THIS
    live "/portfolios/stories", PortfolioLive.Stories, :index     # ADD THIS
    live "/portfolios/stories/new", PortfolioLive.New, :story     # ADD THIS

    # Generic routes LAST
    live "/portfolios/:id", PortfolioLive.Show, :show
    live "/portfolios/:id/edit_fixed", PortfolioLive.PortfolioEditorFixed, :edit
    live "/portfolios/:id/edit", PortfolioLive.PortfolioEditor, :edit
    live "/portfolios/:id/enhance/:type", PortfolioLive.PortfolioEditor, :enhance
    live "/portfolios/:id/edit-legacy", PortfolioLive.Edit, :edit
    live "/portfolios/:id/settings", PortfolioLive.Settings, :settings


    # Portfolio analytics and insights
    live "/portfolios/:id/analytics", PortfolioLive.AnalyticsLive, :analytics
    live "/portfolios/:id/insights", PortfolioLive.InsightsLive, :insights

    # Portfolio collaboration
    live "/portfolios/:id/collaborate", PortfolioLive.CollaborationLive, :collaborate
    live "/portfolios/:id/shares", PortfolioLive.SharesLive, :shares

    # Portfolio sections management
    live "/portfolios/:portfolio_id/sections/:id/edit", PortfolioLive.SectionEdit, :edit

    # Media management
    post "/portfolios/:id/media/upload", PortfolioController, :upload_media
    delete "/portfolios/:id/media/:media_id", PortfolioController, :delete_media

    # Portfolio templates and themes
    live "/portfolios/:id/themes", PortfolioLive.ThemesLive, :themes
    live "/portfolios/:id/customization", PortfolioLive.CustomizationLive, :customization

    # Import/Export functionality
    live "/portfolios/:id/import", PortfolioLive.ImportLive, :import
    post "/portfolios/:id/import/resume", PortfolioController, :import_resume
    get "/portfolios/:id/export/:format", PortfolioController, :export

    # Channels routes - CLEANED UP
    live "/channels", ChannelLive.Index, :index
    live "/channels/new", ChannelLive.Index, :new
    live "/channels/:id/edit", ChannelLive.Index, :edit  # ID-based editing from index

    # Main channel show route (handles both ID and slug)
    live "/channels/:id_or_slug", ChannelLive.Show, :show

    # Channel management routes (all use slug)
    live "/channels/:slug/edit", ChannelLive.Show, :edit
    live "/channels/:slug/customize", ChannelLive.Customize, :edit
    live "/channels/:slug/settings", ChannelLive.Settings, :edit
    live "/channels/:slug/members", ChannelLive.Members, :index
    live "/channels/:slug/analytics", ChannelLive.Analytics, :index

    # Channel content management
    live "/channels/:slug/content", ContentLive.Index, :index
    live "/channels/:slug/content/upload", ContentLive.Upload, :new
    live "/channels/:slug/content/:id", ContentLive.Show, :show

    # Sessions routes
    live "/channels/:slug/sessions", SessionLive.Index, :index
    live "/channels/:slug/sessions/:session_id", StudioLive, :show
    live "/channels/:slug/sessions/:session_id/edit", StudioLive, :edit_session

    # Broadcasts routes
    live "/channels/:slug/broadcasts", BroadcastLive.Index, :index
    live "/channels/:slug/broadcasts/new", BroadcastLive.Index, :new
    live "/channels/:slug/broadcasts/:id", BroadcastLive.Show, :show
    live "/channels/:slug/broadcasts/:id/edit", BroadcastLive.Show, :edit
    live "/channels/:slug/broadcasts/:id/manage", BroadcastLive.Manage, :show
    live "/channels/:slug/broadcasts/:id/sound-check", BroadcastLive.SoundCheck, :show
    live "/channels/:slug/broadcasts/:id/waiting", BroadcastLive.WaitingRoom, :show
    live "/channels/:slug/broadcasts/:id/live", BroadcastLive.Show, :live

    # Studio routes
    live "/channels/:slug/studio", StudioLive.Index, :index
    live "/channels/:slug/go-live", StudioLive.Broadcast, :new

    # Content Management Routes (moved from /media to avoid conflict with SupremeDiscovery)
    live "/content/media", MediaLive.Index, :index
    live "/content/media/new", MediaLive.Index, :new
    live "/content/media/:id/edit", MediaLive.Index, :edit
    live "/content/media/:id", MediaLive.Show, :show
    live "/content/media/:id/show/edit", MediaLive.Show, :edit

    # Keep existing broadcast routes with slug consistency
    live "/broadcasts/:broadcast_id/sound-check", BroadcastLive.SoundCheck, :show
    live "/broadcasts/:broadcast_id/waiting", BroadcastLive.WaitingRoom, :show
    live "/broadcasts/:broadcast_id/live", BroadcastLive.Show, :show
    live "/broadcasts/:broadcast_id/manage", BroadcastLive.Manage, :show

    # Streaming route
    live "/streaming", StreamingLive.Index, :index

    # Chat
    live "/chat", ChatLive.Show
    live "/chat/channel/:id", ChatLive.Show, :channel
    live "/chat/conversation/:id", ChatLive.Show, :conversation
    live "/chat/:id", ChatLive.Show  # Auto-detect

    # 🚀 REVOLUTIONARY DISCOVERY INTERFACE ROUTES (now at /media)
    live "/media", MediaLive.SupremeDiscovery, :index
    live "/media/:id", SupremeDiscoveryLive, :show
    live "/media/:id/expand", SupremeDiscoveryLive, :expand

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
    live "/account/subscription", SubscriptionLive.Index, :index # Moved to LiveView

  end

    get "/dashboard", DashboardController, :index # Keep for non-LiveView access if needed
    get "/users/log_in_success", UserSessionController, :log_in_success
    get "/users/create_from_2fa", UserSessionController, :create_from_2fa
    get "/session/create_from_liveview", UserSessionController, :create_from_liveview

    # 🎨 DYNAMIC THEME MANAGEMENT ROUTES
    post "/api/themes/switch", ThemeController, :switch_theme
    get "/api/themes/dynamic", ThemeController, :get_dynamic_theme

    # Chat API endpoints
    get "/api/chat/conversations", ChatController, :conversations
    get "/api/chat/messages/:conversation_id", ChatController, :messages
    post "/api/chat/messages", ChatController, :send_message
    patch "/api/chat/conversations/:id/read", ChatController, :mark_read

    # 🌟 REAL-TIME REACTION ROUTES
    post "/api/content/media/:id/react", MediaController, :react
    delete "/api/content/media/:id/unreact", MediaController, :unreact

    # 💬 COMMENT SYSTEM ROUTES
    post "/api/content/media/:id/comment", MediaController, :comment
    put "/api/comments/:id", MediaController, :update_comment
    delete "/api/comments/:id", MediaController, :delete_comment

    # 📁 FILE MANAGEMENT ROUTES
    post "/upload", UploadController, :create
    get "/content/media/:id/download", MediaController, :download
    get "/content/media/:id/stream", MediaController, :stream

    # 📊 ANALYTICS ROUTES
    post "/api/content/media/:id/view", MediaController, :record_view
    get "/api/analytics/dashboard", AnalyticsController, :dashboard

    # Tickets
    get "/events/:event_id/tickets", TicketController, :buy
    post "/tickets/checkout", TicketController, :create_checkout
    get "/events/:event_id/tickets/success", TicketController, :success
    get "/my-tickets", TicketController, :my_tickets

    get "/search", SearchController, :index

    get "/profile/edit", UserProfileController, :edit
    put "/profile", UserProfileController, :update

    resources "/subscriptions", SubscriptionController, except: [:new, :create]
    get "/subscriptions/new/:plan_id", SubscriptionController, :new
    post "/subscriptions", SubscriptionController, :create

    resources "/channels", ChannelController, param: "slug", except: [:index, :show]
    get "/channels/:slug", ChannelController, :show # Ensure this is after resource for :show

    get "/broadcasts/:id", BroadcastController, :show
    resources "/channels/:slug/rooms", RoomController, param: "slug", except: [:index]

    delete "/channels/:slug/rooms/:room_slug/messages/:id", MessageController, :delete

    resources "/channels/:slug/members", MembershipController, only: [:index, :create, :delete]
    put "/channels/:slug/members/:id/role", MembershipController, :update

    resources "/channels/:slug/invitations", InvitationController, only: [:index, :create]
    post "/channels/:slug/invitations/:id/cancel", InvitationController, :cancel

    # Content Media resources (moved to /content/media)
    resources "/content/media", MediaController
    post "/content/media/:asset_id/version", MediaController, :upload_version
    get "/content/media/stream/:asset_id/:version_id", MediaController, :stream
    get "/content/media/:id", MediaController, :download

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


  scope "/admin", FrestylWeb.AdminLive, as: :admin do
    pipe_through [:browser, :require_authenticated_user, :admin]

    live "/", Dashboard, :show
    live "/users", Dashboard, :users
    live "/channels", Dashboard, :channels
    live "/analytics", Dashboard, :analytics
    live "/roles", Dashboard, :roles

    live "/portfolios", PortfolioLive.AdminIndex, :index
    live "/portfolios/:id", PortfolioLive.AdminShow, :show
    live "/portfolios/:id/moderate", PortfolioLive.AdminModerate, :moderate

  end



  # API: Public
  scope "/api", FrestylWeb.Api do
    pipe_through [:api]

    post "/auth/login", AuthController, :login
    post "/auth/register", AuthController, :register
    get "/discover", DiscoverController, :index
    get "/channels/public", ChannelController, :public
    post "/upload", UploadController, :create

    # 🌌 REVOLUTIONARY DISCOVERY API ROUTES (now at /api/media/discover)
    get "/media/discover", SupremeDiscoveryController, :index
    get "/media/discover/:id", SupremeDiscoveryController, :show
  end

  # API: Authenticated
  scope "/api", FrestylWeb.Api do
    pipe_through [:api, :api_auth]

    get "/auth/status", AuthController, :status
    post "/auth/verify_2fa", AuthController, :verify_2fa
    post "/auth/verify_backup_code", AuthController, :verify_backup_code
    post "/auth/logout", AuthController, :logout

    # Media API endpoints (updated paths to reflect content/media)
    get "/content/media/discover", Api.MediaController, :discover
    get "/content/media/:id", Api.MediaController, :show
    post "/content/media/:id/react", Api.MediaController, :react

    # PDF Export endpoints
    post "/portfolios/:slug/export", PdfExportController, :export
    get "/portfolios/:slug/export/preview", PdfExportController, :preview
    get "/exports/download/:filename", PdfExportController, :download

    # Resume parsing endpoint (if needed for AJAX uploads)
    post "/resume/parse", ResumeController, :parse

    # User preferences API
    get "/user/theme", Api.UserController, :get_theme
    put "/user/theme", Api.UserController, :set_theme

    # 🎨 THEME API ROUTES
    get "/themes", ThemeController, :list
    post "/themes/preference", ThemeController, :set_preference

    # 🚀 ENHANCED MEDIA API (updated paths to reflect content/media)
    resources "/content/media", MediaController, except: [:new, :edit]

    # 🌟 REAL-TIME API (updated paths to reflect content/media)
    post "/content/media/:id/reactions", ReactionController, :create
    get "/content/media/:id/reactions", ReactionController, :index

    # 💬 COMMENT API (updated paths to reflect content/media)
    post "/content/media/:id/comments", CommentController, :create
    get "/content/media/:id/comments", CommentController, :index

    get "/users/me", UserController, :me
    resources "/profiles", ProfileController, only: [:index, :show]
    resources "/channels", ChannelController, only: [:index, :show]
    get "/content/media/public", MediaController, :public
  end

  # API: Auth + 2FA
  scope "/api", FrestylWeb.Api do
    pipe_through [:api, :api_auth, :api_2fa]

    # Portfolio API endpoints
    resources "/portfolios", PortfolioController, except: [:new, :edit] do
      resources "/sections", SectionController
      resources "/media", MediaController
      get "/analytics", PortfolioController, :analytics
      post "/duplicate", PortfolioController, :duplicate
    end

    # Portfolio sharing API
    post "/portfolios/:id/shares", ShareController, :create
    get "/portfolios/:id/shares", ShareController, :index
    delete "/shares/:token", ShareController, :delete

    resources "/users", UserController, only: [:update, :delete]
    post "/users/change_password", UserController, :change_password
    post "/users/disable_2fa", UserController, :disable_2fa

    resources "/content/media", MediaController, except: [:new, :edit] # Updated path
    post "/content/media/:id/upload", MediaController, :upload # Updated path
    delete "/content/media/:id/versions/:version_id", MediaController, :delete_version # Updated path

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

  scope "/api/webhooks", FrestylWeb do
   pipe_through :api

   post "/stripe", StripeWebhookController, :handle
  end

    # ADD: Portfolio download routes (protected)
  scope "/downloads", FrestylWeb do
    pipe_through [:browser, :require_authenticated_user]

    # PDF exports
    get "/pdf/:user_id/:filename", PortfolioDownloadsController, :download_pdf
    get "/export/:filename", PortfolioDownloadsController, :download_export

    # Export management API
    get "/exports", PortfolioDownloadsController, :list_exports
    delete "/exports/cleanup", PortfolioDownloadsController, :cleanup_exports
  end

    # File serving for exports
  scope "/exports" do
    pipe_through :browser

    # Serve generated PDF files
    get "/:filename", FrestylWeb.PdfExportController, :download
  end

  # Uploads: Separate static route
  scope "/uploads", FrestylWeb do
    pipe_through [:browser, :require_auth, :media_cache]
    get "/*path", MediaController, :serve_file

    get "/portfolios/*path", PortfolioDownloadsController, :serve_static
  end

  defp debug_request(conn, _opts) do
    Logger.info("Processing request: #{conn.request_path} with method #{conn.method}")
    Logger.info("Current user: #{inspect conn.assigns[:current_user]}")
    conn
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:frestyl, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: FrestylWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview

      # 🔧 DISCOVERY DEVELOPMENT TOOLS
      live "/discover/debug", SupremeDiscoveryLive, :debug
      get "/themes/preview", ThemeController, :preview_all
    end
  end

  defp require_admin_user(conn, _opts) do
    case conn.assigns.current_user do
      %{is_admin: true} ->
        conn

      %{admin_roles: roles} when is_list(roles) and length(roles) > 0 ->
        conn

      _ ->
        conn
        |> Phoenix.Controller.put_flash(:error, "Admin access required")
        |> Phoenix.Controller.redirect(to: "/")
        |> halt()
    end
  end
end
