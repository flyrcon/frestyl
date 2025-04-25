defmodule FrestylWeb.Router do
  use FrestylWeb, :router

  import FrestylWeb.UserAuth
  alias FrestylWeb.Plugs.RoleAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {FrestylWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Define new pipelines for roles
  pipeline :require_creator do
    plug RoleAuth, ["creator", "host", "channel_owner", "admin"]
  end

  pipeline :require_host do
    plug RoleAuth, ["host", "channel_owner", "admin"]
  end

  pipeline :require_channel_owner do
    plug RoleAuth, ["channel_owner", "admin"]
  end

  pipeline :require_admin do
    plug RoleAuth, ["admin"]
  end

  scope "/", FrestylWeb do
    pipe_through :browser

    get "/", PageController, :home

    # LiveView routes
    live "/dashboard", DashboardLive, :index
    live "/collaborations", CollaborationLive, :index
    live "/channels/:id/customize", ChannelCustomizationLive, :edit
    live "/events/:id", EventAttendanceLive, :show
    live "/studio", StudioLive, :index

    # Channel routes
    resources "/channels", ChannelController, param: "slug", except: [:show]
    get "/channels/:slug", ChannelController, :show

    # Room routes (nested under channels)
    resources "/channels/:channel_slug/rooms", RoomController, param: "slug", except: [:index]

    # Message routes
    delete "/channels/:channel_slug/rooms/:room_slug/messages/:id", MessageController, :delete

    # Channel membership management
    resources "/channels/:channel_slug/members", MembershipController, only: [:index, :create, :delete]
    put "/channels/:channel_slug/members/:id/role", MembershipController, :update

    # File routes for channels
    get "/channels/:channel_slug/files", FileController, :index
    get "/channels/:channel_slug/files/new", FileController, :new
    post "/channels/:channel_slug/files", FileController, :create
    delete "/channels/:channel_slug/files/:id", FileController, :delete

    # File routes for rooms
    get "/channels/:channel_slug/rooms/:room_slug/files", FileController, :index
    get "/channels/:channel_slug/rooms/:room_slug/files/new", FileController, :new
    post "/channels/:channel_slug/rooms/:room_slug/files", FileController, :create
    delete "/channels/:channel_slug/rooms/:room_slug/files/:id", FileController, :delete

    # Invitation routes
    resources "/channels/:channel_slug/invitations", InvitationController, only: [:index, :create]
    post "/channels/:channel_slug/invitations/:id/cancel", InvitationController, :cancel

    # Session routes
    resources "/sessions", SessionController
    post "/sessions/:id/join", SessionController, :join
    post "/sessions/:id/leave", SessionController, :leave
    post "/sessions/:id/start", SessionController, :start
    post "/sessions/:id/end", SessionController, :end
    get "/sessions/:id/room", SessionController, :room

    # Public invitation routes (no channel_slug needed)
    get "/invitations/:token", InvitationController, :show
    get "/invitations/:token/accept", InvitationController, :accept

    # Search routes
    get "/search", SearchController, :index

    # API routes for AI-powered categorization
    get "/api/channels/suggest-categories", ChannelController, :suggest_categories
  end

  # Media routes
  resources "/media", MediaController, only: [:create, :delete]

  # User profile routes (require authenticated user)
  scope "/", FrestylWeb do
    pipe_through [:browser, :require_authenticated_user]

    # Event routes
    live "/events", EventLive.Index, :index
    live "/events/new", EventLive.Index, :new
    live "/events/:id", EventLive.Show, :show
    live "/events/:id/edit", EventLive.Index, :edit

    # Invitation routes
    get "/invitations/:token/accept", InvitationController, :accept
    get "/invitations/:token/decline", InvitationController, :decline

    # Media handling
    resources "/media", MediaController
    post "/media/:asset_id/version", MediaController, :upload_version
    get "/media/stream/:asset_id/:version_id", MediaController, :stream

    live "/media", MediaLive.Index, :index
    live "/media/new", MediaLive.Index, :new
    live "/media/:id/edit", MediaLive.Index, :edit
    live "/media/:id", MediaLive.Show, :show

    get "/profile", UserProfileController, :show
    get "/profile/edit", UserProfileController, :edit
    put "/profile", UserProfileController, :update

    # Add route for LiveView profile
    live "/profile/live", UserLive.Profile, :show

    # Subscription routes
    get "/subscriptions", SubscriptionController, :index
    get "/subscriptions/new/:plan_id", SubscriptionController, :new
    post "/subscriptions", SubscriptionController, :create
    delete "/subscriptions/:id", SubscriptionController, :cancel

    # Ticket routes
    get "/events/:event_id/tickets", TicketController, :buy
    post "/tickets/checkout", TicketController, :create_checkout
    get "/events/:event_id/tickets/success", TicketController, :success
    get "/my-tickets", TicketController, :my_tickets

    # Account routes
    get "/account/subscription", AccountController, :subscription
  end

  # Creator routes
  scope "/creator", FrestylWeb do
    pipe_through [:browser, :require_authenticated_user, :require_creator]

    # Will be implemented later (content management)
    # resources "/content", ContentController
  end

  # Host routes
  scope "/host", FrestylWeb do
    pipe_through [:browser, :require_authenticated_user, :require_host]

    # Will be implemented later (moderation)
    # resources "/moderation", ModerationController, only: [:index, :show, :update, :delete]
  end

  # Channel owner routes
  scope "/channel", FrestylWeb do
    pipe_through [:browser, :require_authenticated_user, :require_channel_owner]

    # Will be implemented later
    # resources "/channels", ChannelController
    # resources "/invitations", InvitationController
  end

  # Admin routes
  scope "/admin", FrestylWeb do
    pipe_through [:browser, :require_authenticated_user, :require_admin]

    resources "/users", AdminUserController
    # resources "/settings", AdminSettingController, only: [:index, :edit, :update]
  end

  scope "/admin", FrestylWeb.Admin do
    pipe_through [:browser, :require_authenticated_user, :require_admin_user]

    get "/dashboard", DashboardController, :index
    get "/reports", DashboardController, :detailed_report

    # Subscription plan management
    resources "/subscription-plans", SubscriptionPlanController
  end

  # Webhook endpoints
  scope "/webhooks", FrestylWeb do
    post "/stripe", WebhookController, :stripe
  end

  scope "/", FrestylWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

   # API scope for WebRTC signaling and real-time communication
   scope "/api", FrestylWeb do
    pipe_through :api

    resources "/rooms", RoomController, except: [:new, :edit]
    resources "/streams", StreamController, except: [:new, :edit]

    post "/rooms/:id/join", RoomController, :join
    post "/rooms/:id/leave", RoomController, :leave
    post "/streams/:id/start", StreamController, :start
    post "/streams/:id/end", StreamController, :end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:frestyl, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: FrestylWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", FrestylWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{FrestylWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", FrestylWeb do
    pipe_through [:browser, :require_authenticated_user]
  end

  scope "/", FrestylWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{FrestylWeb.UserAuth, :ensure_authenticated}] do
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email
    end
  end

  scope "/", FrestylWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{FrestylWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end

  # Add to router.ex
  pipeline :rate_limited do
    plug FrestylWeb.Plugs.RateLimiter, limit: 5, period: 60_000
  end

  # And then use it in sensitive routes
  scope "/tickets", FrestylWeb do
    pipe_through [:browser, :require_authenticated_user, :rate_limited]

    post "/checkout", TicketController, :create_checkout
  end
end
