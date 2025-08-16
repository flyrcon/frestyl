# lib/frestyl_web/components/session_components.ex
defmodule FrestylWeb.SessionComponents do
  @moduledoc """
  UI components for the unified session hub interface.
  Handles feature gating, responsive layouts, and real-time updates.
  """

  use Phoenix.Component
  import FrestylWeb.CoreComponents
  alias Phoenix.LiveView.JS

  # Session Control Bar
  def session_control_bar(assigns) do
    ~H"""
    <div class="session-control-bar bg-gray-800 border-b border-gray-700 px-6 py-4">
      <div class="flex items-center justify-between">
        <!-- Left Controls -->
        <div class="flex items-center space-x-4">
          <.session_status_indicator status={@session_state.status} />

          <.control_button
            :if={@permissions.can_record}
            phx-click="toggle_recording"
            active={@session_state.recording}
            class="bg-red-600 hover:bg-red-700"
          >
            <.icon name="hero-stop-circle" :if={@session_state.recording} class="w-4 h-4" />
            <.icon name="hero-play-circle" :if={!@session_state.recording} class="w-4 h-4" />
            <span class="ml-2"><%= if @session_state.recording, do: "Stop", else: "Record" %></span>
          </.control_button>

          <.feature_gate feature={:session_recording} gates={@feature_gates}>
            <:locked>
              <.locked_control_button feature="Recording" />
            </:locked>
          </.feature_gate>

          <.audio_controls
            session_state={@session_state}
            permissions={@permissions}
            feature_gates={@feature_gates}
          />

          <.video_controls
            session_state={@session_state}
            permissions={@permissions}
            feature_gates={@feature_gates}
          />

          <.participant_indicator count={length(@session_state.participants)} />
        </div>

        <!-- Center Info -->
        <div class="flex items-center space-x-4">
          <.session_timer :if={@session_state.started_at} started_at={@session_state.started_at} />
          <.streaming_indicator :if={@session_state.streaming} />
        </div>

        <!-- Right Controls -->
        <div class="flex items-center space-x-3">
          <.layout_selector current={@ui_state.layout} />
          <.settings_button />
          <.upgrade_hint :if={length(@ui_state.feature_hints) > 0} hints={@ui_state.feature_hints} />
        </div>
      </div>
    </div>
    """
  end

  # Session Layout Router
  def session_layout(assigns) do
    ~H"""
    <div class="session-layout flex-1 flex">
      <%= case @mode do %>
        <% :broadcast -> %>
          <.broadcast_layout
            layout={@layout}
            session={@session}
            session_state={@session_state}
            current_user={@current_user}
            permissions={@permissions}
            feature_gates={@feature_gates}
            ui_state={@ui_state}
          />
        <% :consultation -> %>
          <.consultation_layout
            layout={@layout}
            session={@session}
            session_state={@session_state}
            current_user={@current_user}
            permissions={@permissions}
            feature_gates={@feature_gates}
            ui_state={@ui_state}
          />
        <% :tutorial -> %>
          <.tutorial_layout
            layout={@layout}
            session={@session}
            session_state={@session_state}
            current_user={@current_user}
            permissions={@permissions}
            feature_gates={@feature_gates}
            ui_state={@ui_state}
          />
        <% :collaboration -> %>
          <.collaboration_layout
            layout={@layout}
            session={@session}
            session_state={@session_state}
            current_user={@current_user}
            permissions={@permissions}
            feature_gates={@feature_gates}
            ui_state={@ui_state}
          />
      <% end %>
    </div>
    """
  end

  # Broadcast Layout (1-to-many streaming)
  def broadcast_layout(assigns) do
    ~H"""
    <div class="broadcast-layout flex-1 flex">
      <!-- Main Stream Area -->
      <div class="stream-container flex-1 bg-black relative">
        <.video_stream
          stream_id={@session.id}
          quality={@session_state.stream_quality}
          viewer_count={@session_state.viewer_count}
        />

        <!-- Stream Overlay -->
        <div class="absolute top-4 left-4 flex items-center space-x-2">
          <.live_badge />
          <.viewer_count count={@session_state.viewer_count} />
        </div>

        <!-- Host Controls Overlay -->
        <div :if={@permissions.can_host} class="absolute bottom-4 left-4 right-4">
          <.host_controls
            session={@session}
            session_state={@session_state}
            permissions={@permissions}
            feature_gates={@feature_gates}
          />
        </div>
      </div>

      <!-- Chat Sidebar -->
      <.collapsible_panel
        :if={@ui_state.panels.chat == :open}
        class="w-80 bg-gray-800 border-l border-gray-700"
      >
        <.chat_panel session_id={@session.id} current_user={@current_user} />
      </.collapsible_panel>
    </div>
    """
  end

  # Consultation Layout (1-on-1 video calls)
  def consultation_layout(assigns) do
    ~H"""
    <div class="consultation-layout flex-1 flex">
      <!-- Video Area -->
      <div class="video-area flex-1 flex">
        <%= case @layout do %>
          <% :split -> %>
            <div class="flex flex-1">
              <.video_participant participant={get_host(@session_state.participants)} class="flex-1" />
              <.video_participant participant={get_client(@session_state.participants, @current_user)} class="flex-1 border-l border-gray-700" />
            </div>
          <% :focus -> %>
            <div class="flex flex-col flex-1">
              <.video_participant participant={get_focused_participant(@session_state.participants)} class="flex-1" />
              <div class="h-32 flex space-x-2 p-2">
                <.video_participant
                  :for={participant <- @session_state.participants}
                  participant={participant}
                  class="flex-1 rounded-lg overflow-hidden"
                  size="thumbnail"
                />
              </div>
            </div>
        <% end %>

        <!-- Call Controls Overlay -->
        <div class="absolute bottom-6 left-1/2 transform -translate-x-1/2">
          <.call_controls
            session_state={@session_state}
            permissions={@permissions}
            feature_gates={@feature_gates}
          />
        </div>
      </div>

      <!-- Sidebar -->
      <.collapsible_panel
        :if={@ui_state.panels.sidebar == :open}
        class="w-80 bg-gray-800 border-l border-gray-700"
      >
        <.consultation_sidebar
          session={@session}
          session_state={@session_state}
          permissions={@permissions}
          feature_gates={@feature_gates}
        />
      </.collapsible_panel>
    </div>
    """
  end

  # Tutorial Layout (interactive teaching)
  def tutorial_layout(assigns) do
    ~H"""
    <div class="tutorial-layout flex-1 flex">
      <!-- Main Content Area -->
      <div class="content-area flex-1 flex flex-col">
        <!-- Presenter View -->
        <div class="presenter-section flex-1 bg-black">
          <.video_participant
            participant={get_presenter(@session_state.participants)}
            class="w-full h-full"
          />

          <!-- Screen Share Overlay -->
          <.feature_gate feature={:screen_sharing} gates={@feature_gates}>
            <.screen_share_area :if={@session_state.screen_sharing} />
            <:locked>
              <.upgrade_overlay feature="Screen Sharing" />
            </:locked>
          </.feature_gate>
        </div>

        <!-- Interactive Elements -->
        <div class="interactive-bar bg-gray-800 p-4 border-t border-gray-700">
          <.tutorial_controls
            session={@session}
            session_state={@session_state}
            permissions={@permissions}
            feature_gates={@feature_gates}
          />
        </div>
      </div>

      <!-- Student/Audience Panel -->
      <.collapsible_panel class="w-80 bg-gray-800 border-l border-gray-700">
        <.tutorial_sidebar
          session={@session}
          session_state={@session_state}
          current_user={@current_user}
          permissions={@permissions}
        />
      </.collapsible_panel>
    </div>
    """
  end

  # Collaboration Layout (multi-user creative sessions)
  def collaboration_layout(assigns) do
    ~H"""
    <div class="collaboration-layout flex-1 flex">
      <!-- Workspace Area -->
      <div class="workspace-area flex-1 flex flex-col">
        <!-- Collaborative Canvas -->
        <div class="canvas-container flex-1 bg-gray-900 relative">
          <.collaboration_canvas
            workspace={@session_state.workspace}
            cursors={@session_state.cursors}
            session_id={@session.id}
            current_user={@current_user}
          />
        </div>

        <!-- Audio Tracks -->
        <.feature_gate feature={:multi_track_recording} gates={@feature_gates}>
          <.audio_tracks_panel
            session_id={@session.id}
            permissions={@permissions}
            feature_gates={@feature_gates}
          />
          <:locked>
            <.locked_panel feature="Multi-track Recording" />
          </:locked>
        </.feature_gate>
      </div>

      <!-- Participants Panel -->
      <.collapsible_panel
        :if={@ui_state.panels.participants == :open}
        class="w-64 bg-gray-800 border-l border-gray-700"
      >
        <.collaboration_participants
          participants={@session_state.participants}
          current_user={@current_user}
          session_id={@session.id}
        />
      </.collapsible_panel>
    </div>
    """
  end

  # Core UI Components

  def session_status_indicator(assigns) do
    ~H"""
    <div class="flex items-center space-x-2">
      <%= case @status do %>
        <% "active" -> %>
          <div class="w-3 h-3 bg-green-500 rounded-full animate-pulse"></div>
          <span class="text-sm font-medium text-green-400">Live</span>
        <% "scheduled" -> %>
          <div class="w-3 h-3 bg-yellow-500 rounded-full"></div>
          <span class="text-sm font-medium text-yellow-400">Scheduled</span>
        <% _ -> %>
          <div class="w-3 h-3 bg-gray-500 rounded-full"></div>
          <span class="text-sm font-medium text-gray-400">Inactive</span>
      <% end %>
    </div>
    """
  end

  def control_button(assigns) do
    assigns = assign_new(assigns, :active, fn -> false end)
    assigns = assign_new(assigns, :disabled, fn -> false end)

    ~H"""
    <button
      {assigns_to_attributes(assigns, [:active, :disabled])}
      class={[
        "inline-flex items-center px-3 py-2 rounded-md text-sm font-medium transition-colors",
        @active && "ring-2 ring-white ring-opacity-60",
        @disabled && "opacity-50 cursor-not-allowed",
        @class
      ]}
      disabled={@disabled}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  def locked_control_button(assigns) do
    ~H"""
    <div class="relative">
      <button class="inline-flex items-center px-3 py-2 rounded-md text-sm font-medium bg-gray-600 text-gray-400 cursor-not-allowed opacity-60">
        <.icon name="hero-lock-closed" class="w-4 h-4 mr-2" />
        <%= @feature %>
      </button>
      <.upgrade_tooltip feature={@feature} />
    </div>
    """
  end

  def audio_controls(assigns) do
    ~H"""
    <div class="flex items-center space-x-2">
      <.control_button
        phx-click="toggle_audio"
        active={@session_state[:audio_enabled] || false}
        class="bg-gray-600 hover:bg-gray-700"
      >
        <.icon name="hero-microphone" class="w-4 h-4" />
      </.control_button>

      <.feature_gate feature={:audio_effects} gates={@feature_gates}>
        <.control_button
          phx-click="show_audio_effects"
          class="bg-purple-600 hover:bg-purple-700"
        >
          <.icon name="hero-adjustments-horizontal" class="w-4 h-4" />
        </.control_button>
        <:locked>
          <.locked_control_button feature="Audio Effects" />
        </:locked>
      </.feature_gate>
    </div>
    """
  end

  def video_controls(assigns) do
    ~H"""
    <div class="flex items-center space-x-2">
      <.control_button
        phx-click="toggle_video"
        active={@session_state[:video_enabled] || false}
        class="bg-blue-600 hover:bg-blue-700"
      >
        <.icon name="hero-video-camera" class="w-4 h-4" />
      </.control_button>

      <.feature_gate feature={:screen_sharing} gates={@feature_gates}>
        <.control_button
          phx-click="toggle_screen_share"
          active={@session_state[:screen_sharing] || false}
          class="bg-indigo-600 hover:bg-indigo-700"
        >
          <.icon name="hero-computer-desktop" class="w-4 h-4" />
        </.control_button>
        <:locked>
          <.locked_control_button feature="Screen Share" />
        </:locked>
      </.feature_gate>
    </div>
    """
  end

  def participant_indicator(assigns) do
    ~H"""
    <div class="flex items-center space-x-2 px-3 py-2 bg-gray-700 rounded-md">
      <.icon name="hero-users" class="w-4 h-4 text-gray-300" />
      <span class="text-sm font-medium text-gray-300"><%= @count %></span>
    </div>
    """
  end

  def session_timer(assigns) do
    ~H"""
    <div class="flex items-center space-x-2 px-3 py-2 bg-gray-700 rounded-md">
      <.icon name="hero-clock" class="w-4 h-4 text-gray-300" />
      <span
        id="session-timer"
        class="text-sm font-medium text-gray-300 font-mono"
        phx-hook="SessionTimer"
        data-started={@started_at}
      >
        00:00:00
      </span>
    </div>
    """
  end

  def streaming_indicator(assigns) do
    ~H"""
    <div class="flex items-center space-x-2 px-3 py-2 bg-red-600 rounded-md">
      <div class="w-2 h-2 bg-white rounded-full animate-pulse"></div>
      <span class="text-sm font-medium text-white">STREAMING</span>
    </div>
    """
  end

  def layout_selector(assigns) do
    ~H"""
    <div id="layout-selector" class="relative" phx-hook="LayoutSelector">
      <button class="p-2 text-gray-300 hover:text-white transition-colors" phx-click={show_dropdown("layout-menu")}>
        <.icon name="hero-squares-2x2" class="w-5 h-5" />
      </button>

      <div id="layout-menu" class="hidden absolute right-0 mt-2 w-48 bg-gray-800 rounded-md shadow-lg border border-gray-700 z-50">
        <div class="py-1">
          <.layout_option layout="grid" current={@current} />
          <.layout_option layout="focus" current={@current} />
          <.layout_option layout="split" current={@current} />
          <.layout_option layout="presenter" current={@current} />
        </div>
      </div>
    </div>
    """
  end

  def layout_option(assigns) do
    ~H"""
    <button
      phx-click="change_layout"
      phx-value-layout={@layout}
      class={[
        "flex items-center w-full px-4 py-2 text-sm text-left hover:bg-gray-700 transition-colors",
        @layout == @current && "bg-gray-700 text-white"
      ]}
    >
      <.layout_icon layout={@layout} />
      <span class="ml-3 capitalize"><%= @layout %></span>
    </button>
    """
  end

  def layout_icon(%{layout: "grid"} = assigns) do
    ~H"""
    <.icon name="hero-squares-2x2" class="w-4 h-4" />
    """
  end

  def layout_icon(%{layout: "focus"} = assigns) do
    ~H"""
    <.icon name="hero-eye" class="w-4 h-4" />
    """
  end

  def layout_icon(%{layout: "split"} = assigns) do
    ~H"""
    <.icon name="hero-rectangle-group" class="w-4 h-4" />
    """
  end

  def layout_icon(%{layout: "presenter"} = assigns) do
    ~H"""
    <.icon name="hero-presentation-chart-line" class="w-4 h-4" />
    """
  end

  def settings_button(assigns) do
    ~H"""
    <button
      phx-click="show_settings"
      class="p-2 text-gray-300 hover:text-white transition-colors"
    >
      <.icon name="hero-cog-6-tooth" class="w-5 h-5" />
    </button>
    """
  end

  def upgrade_hint(assigns) do
    ~H"""
    <div class="relative">
      <button
        phx-click="show_upgrade_hints"
        class="px-3 py-1 bg-gradient-to-r from-purple-600 to-pink-600 text-white text-xs rounded-full hover:from-purple-700 hover:to-pink-700 transition-colors animate-pulse"
      >
        Upgrade
      </button>
    </div>
    """
  end

  # Feature Gate Component
  def feature_gate(assigns) do
    available = Map.get(assigns.gates, assigns.feature, false)
    assigns = assign(assigns, :available, available)

    ~H"""
    <%= if @available do %>
      <%= render_slot(@inner_block) %>
    <% else %>
      <%= render_slot(@locked) %>
    <% end %>
    """
  end

  # Video Components
  def video_stream(assigns) do
    ~H"""
    <div id="video-stream" class="video-stream w-full h-full bg-black relative" phx-hook="VideoStream" data-stream-id={@stream_id}>
      <video class="w-full h-full object-cover" autoplay muted playsinline></video>

      <!-- Quality Indicator -->
      <div class="absolute top-4 right-4 px-2 py-1 bg-black bg-opacity-60 rounded text-xs text-white">
        <%= @quality %>
      </div>

      <!-- Loading State -->
      <div class="absolute inset-0 flex items-center justify-center bg-gray-800" data-loading>
        <div class="text-center">
          <.icon name="hero-play-circle" class="w-12 h-12 text-gray-400 mb-2" />
          <p class="text-gray-400">Connecting to stream...</p>
        </div>
      </div>
    </div>
    """
  end

  def video_participant(assigns) do
    assigns = assign_new(assigns, :size, fn -> "normal" end)
    assigns = assign_new(assigns, :class, fn -> "" end)

    ~H"""
    <div class={["video-participant bg-gray-800 relative overflow-hidden", @class]}>
      <video
        id={"participant-video-#{@participant.user_id}"}
        class="w-full h-full object-cover"
        phx-hook="ParticipantVideo"
        data-user-id={@participant.user_id}
        autoplay
        muted={@participant.user_id == @current_user.id}
        playsinline
      ></video>

      <!-- Participant Info -->
      <div class="absolute bottom-2 left-2 px-2 py-1 bg-black bg-opacity-60 rounded text-xs text-white">
        <%= @participant.user.name || @participant.user.username %>
      </div>

      <!-- Audio Indicator -->
      <div :if={@participant.audio_muted} class="absolute top-2 right-2 p-1 bg-red-600 rounded-full">
        <.icon name="hero-microphone-slash" class="w-3 h-3 text-white" />
      </div>
    </div>
    """
  end

  def live_badge(assigns) do
    ~H"""
    <div class="flex items-center space-x-1 px-2 py-1 bg-red-600 rounded text-xs font-bold text-white">
      <div class="w-2 h-2 bg-white rounded-full animate-pulse"></div>
      <span>LIVE</span>
    </div>
    """
  end

  def viewer_count(assigns) do
    ~H"""
    <div class="flex items-center space-x-1 px-2 py-1 bg-black bg-opacity-60 rounded text-xs text-white">
      <.icon name="hero-eye" class="w-3 h-3" />
      <span><%= @count %></span>
    </div>
    """
  end

  # Panel Components
  def collapsible_panel(assigns) do
    assigns = assign_new(assigns, :class, fn -> "" end)

    ~H"""
    <div class={["collapsible-panel transition-transform duration-300", @class]}>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  def chat_panel(assigns) do
    ~H"""
    <div class="chat-panel h-full flex flex-col">
      <div class="chat-header p-4 border-b border-gray-700">
        <h3 class="text-lg font-semibold">Chat</h3>
      </div>

      <div id="chat-messages" class="chat-messages flex-1 overflow-y-auto p-4 space-y-3" phx-hook="ChatMessages">
        <!-- Messages will be loaded dynamically -->
      </div>

      <div class="chat-input p-4 border-t border-gray-700">
        <form phx-submit="send_chat_message" class="flex space-x-2">
          <input
            type="text"
            name="message"
            placeholder="Type a message..."
            class="flex-1 px-3 py-2 bg-gray-700 border border-gray-600 rounded-md text-white placeholder-gray-400 focus:outline-none focus:border-blue-500"
            autocomplete="off"
          />
          <button type="submit" class="px-4 py-2 bg-blue-600 hover:bg-blue-700 rounded-md transition-colors">
            <.icon name="hero-paper-airplane" class="w-4 h-4" />
          </button>
        </form>
      </div>
    </div>
    """
  end

  def consultation_sidebar(assigns) do
    ~H"""
    <div class="consultation-sidebar h-full flex flex-col">
      <!-- Session Info -->
      <div class="session-info p-4 border-b border-gray-700">
        <h3 class="text-lg font-semibold mb-2">Session Details</h3>
        <div class="space-y-2 text-sm text-gray-300">
          <div>Duration: <span class="text-white font-mono"><%= format_duration(@session_state.call_duration) %></span></div>
          <div>Participants: <span class="text-white"><%= length(@session_state.participants) %></span></div>
        </div>
      </div>

      <!-- Shared Notes -->
      <.feature_gate feature={:file_sharing} gates={@feature_gates}>
        <div class="shared-notes flex-1 p-4">
          <h4 class="font-semibold mb-3">Shared Notes</h4>
          <textarea
            id="shared-notes"
            class="w-full h-32 p-3 bg-gray-700 border border-gray-600 rounded-md text-white placeholder-gray-400 resize-none focus:outline-none focus:border-blue-500"
            placeholder="Take notes during the call..."
            phx-hook="SharedNotes"
          ></textarea>
        </div>
        <:locked>
          <.locked_panel feature="Shared Notes" />
        </:locked>
      </.feature_gate>

      <!-- Recording Controls -->
      <div class="recording-controls p-4 border-t border-gray-700">
        <.feature_gate feature={:session_recording} gates={@feature_gates}>
          <button
            phx-click="toggle_recording"
            class={[
              "w-full py-2 px-4 rounded-md font-medium transition-colors",
              @session_state.recording && "bg-red-600 hover:bg-red-700" || "bg-gray-600 hover:bg-gray-700"
            ]}
          >
            <%= if @session_state.recording, do: "Stop Recording", else: "Start Recording" %>
          </button>
          <:locked>
            <.locked_button feature="Session Recording" />
          </:locked>
        </.feature_gate>
      </div>
    </div>
    """
  end

  def tutorial_sidebar(assigns) do
    ~H"""
    <div class="tutorial-sidebar h-full flex flex-col">
      <!-- Attendees -->
      <div class="attendees p-4 border-b border-gray-700">
        <h3 class="text-lg font-semibold mb-3">Attendees (<%= length(@session_state.participants) %>)</h3>
        <div class="space-y-2">
          <div
            :for={participant <- @session_state.participants}
            class="flex items-center space-x-3 p-2 bg-gray-700 rounded-md"
          >
            <div class="w-8 h-8 bg-gray-600 rounded-full flex items-center justify-center">
              <span class="text-xs font-medium"><%= String.first(participant.user.name || "?") %></span>
            </div>
            <span class="text-sm"><%= participant.user.name || participant.user.username %></span>
            <div :if={participant.user_id == @session.host_id} class="ml-auto px-2 py-1 bg-blue-600 rounded text-xs">
              Host
            </div>
          </div>
        </div>
      </div>

      <!-- Q&A Panel -->
      <div class="qa-panel flex-1 p-4">
        <h4 class="font-semibold mb-3">Questions & Answers</h4>
        <div class="qa-messages space-y-3 mb-4" style="max-height: 300px; overflow-y: auto;">
          <!-- Q&A messages will be loaded dynamically -->
        </div>

        <form phx-submit="submit_question" class="space-y-2">
          <textarea
            name="question"
            rows="3"
            placeholder="Ask a question..."
            class="w-full p-3 bg-gray-700 border border-gray-600 rounded-md text-white placeholder-gray-400 resize-none focus:outline-none focus:border-blue-500"
          ></textarea>
          <button type="submit" class="w-full py-2 bg-blue-600 hover:bg-blue-700 rounded-md transition-colors">
            Submit Question
          </button>
        </form>
      </div>
    </div>
    """
  end

  def collaboration_participants(assigns) do
    ~H"""
    <div class="collaboration-participants h-full flex flex-col">
      <div class="participants-header p-4 border-b border-gray-700">
        <h3 class="text-lg font-semibold">Collaborators</h3>
      </div>

      <div class="participants-list flex-1 overflow-y-auto p-4 space-y-3">
        <div
          :for={participant <- @participants}
          class="participant-item flex items-center space-x-3 p-3 bg-gray-700 rounded-md"
        >
          <div class="relative">
            <div class="w-8 h-8 bg-gray-600 rounded-full flex items-center justify-center">
              <span class="text-xs font-medium"><%= String.first(participant.user.name || "?") %></span>
            </div>
            <!-- Online indicator -->
            <div class="absolute -bottom-1 -right-1 w-3 h-3 bg-green-500 border-2 border-gray-700 rounded-full"></div>
          </div>

          <div class="flex-1">
            <div class="text-sm font-medium"><%= participant.user.name || participant.user.username %></div>
            <div class="text-xs text-gray-400">Active now</div>
          </div>

          <!-- Collaboration indicators -->
          <div class="flex space-x-1">
            <div :if={participant.recording} class="w-2 h-2 bg-red-500 rounded-full animate-pulse" title="Recording"></div>
            <div :if={participant.editing} class="w-2 h-2 bg-blue-500 rounded-full animate-pulse" title="Editing"></div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Audio Components
  def audio_tracks_panel(assigns) do
    ~H"""
    <div class="audio-tracks-panel bg-gray-800 border-t border-gray-700 p-4">
      <div class="flex items-center justify-between mb-4">
        <h4 class="font-semibold">Audio Tracks</h4>
        <button
          phx-click="add_audio_track"
          class="px-3 py-1 bg-blue-600 hover:bg-blue-700 rounded text-sm transition-colors"
        >
          + Add Track
        </button>
      </div>

      <div id="audio-tracks" class="tracks-container" phx-hook="AudioTracks" data-session-id={@session_id}>
        <!-- Audio tracks will be loaded dynamically -->
        <div class="track-placeholder p-4 border-2 border-dashed border-gray-600 rounded-md text-center text-gray-400">
          <.icon name="hero-musical-note" class="w-8 h-8 mx-auto mb-2" />
          <p>Add your first audio track to start recording</p>
        </div>
      </div>
    </div>
    """
  end

  def collaboration_canvas(assigns) do
    ~H"""
    <div
      id="collaboration-canvas"
      class="collaboration-canvas w-full h-full relative"
      phx-hook="CollaborationCanvas"
      data-session-id={@session_id}
      data-user-id={@current_user.id}
    >
      <!-- Canvas element will be created by the hook -->
      <canvas class="w-full h-full"></canvas>

      <!-- Collaboration cursors -->
      <div
        :for={{user_id, cursor} <- @cursors}
        :if={user_id != @current_user.id}
        class="absolute pointer-events-none"
        style={"left: #{cursor.x}px; top: #{cursor.y}px;"}
      >
        <div class="flex items-center space-x-1">
          <div class="w-3 h-3 bg-blue-500 rounded-full"></div>
          <span class="text-xs bg-blue-500 text-white px-2 py-1 rounded whitespace-nowrap">
            <%= cursor.user_name %>
          </span>
        </div>
      </div>
    </div>
    """
  end

  # Modal Components
  def upgrade_modal(assigns) do
    ~H"""
    <div id="upgrade-modal" class="fixed inset-0 z-50 overflow-y-auto" phx-hook="Modal">
      <div class="flex items-center justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
        <!-- Background overlay -->
        <div class="fixed inset-0 bg-black bg-opacity-75 transition-opacity" phx-click="close_upgrade_modal"></div>

        <!-- Modal panel -->
        <div class="inline-block align-bottom bg-gray-800 rounded-lg px-4 pt-5 pb-4 text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full sm:p-6">
          <div class="text-center">
            <div class="mx-auto flex items-center justify-center h-12 w-12 rounded-full bg-gradient-to-r from-purple-600 to-pink-600">
              <.icon name="hero-star" class="h-6 w-6 text-white" />
            </div>

            <div class="mt-3 sm:mt-5">
              <h3 class="text-lg leading-6 font-medium text-white">
                Upgrade to access <%= humanize(@feature) %>
              </h3>
              <div class="mt-2">
                <p class="text-sm text-gray-300">
                  Get access to <%= humanize(@feature) %> and many more premium features with a Creator or Pro plan.
                </p>
              </div>
            </div>
          </div>

          <div class="mt-5 sm:mt-6 sm:grid sm:grid-cols-2 sm:gap-3 sm:grid-flow-row-dense">
            <button
              phx-click="redirect_to_upgrade"
              class="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-gradient-to-r from-purple-600 to-pink-600 text-base font-medium text-white hover:from-purple-700 hover:to-pink-700 focus:outline-none sm:col-start-2 sm:text-sm"
            >
              Upgrade Now
            </button>
            <button
              phx-click="close_upgrade_modal"
              class="mt-3 w-full inline-flex justify-center rounded-md border border-gray-600 shadow-sm px-4 py-2 bg-gray-700 text-base font-medium text-gray-300 hover:bg-gray-600 focus:outline-none sm:mt-0 sm:col-start-1 sm:text-sm"
            >
              Maybe Later
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Utility Components
  def locked_panel(assigns) do
    ~H"""
    <div class="locked-panel p-8 text-center text-gray-400">
      <.icon name="hero-lock-closed" class="w-12 h-12 mx-auto mb-4" />
      <h4 class="text-lg font-medium mb-2">Unlock <%= @feature %></h4>
      <p class="text-sm mb-4">Upgrade your plan to access this feature</p>
      <button
        phx-click="show_upgrade_modal"
        phx-value-feature={@feature}
        class="px-4 py-2 bg-gradient-to-r from-purple-600 to-pink-600 text-white rounded-md hover:from-purple-700 hover:to-pink-700 transition-colors"
      >
        Upgrade Plan
      </button>
    </div>
    """
  end

  def locked_button(assigns) do
    ~H"""
    <button
      phx-click="show_upgrade_modal"
      phx-value-feature={@feature}
      class="w-full py-2 px-4 bg-gray-600 text-gray-400 rounded-md cursor-not-allowed relative"
      disabled
    >
      <.icon name="hero-lock-closed" class="w-4 h-4 inline mr-2" />
      <%= @feature %>
    </button>
    """
  end

  def upgrade_overlay(assigns) do
    ~H"""
    <div class="absolute inset-0 bg-black bg-opacity-75 flex items-center justify-center">
      <div class="text-center text-white">
        <.icon name="hero-lock-closed" class="w-12 h-12 mx-auto mb-4" />
        <h3 class="text-lg font-semibold mb-2">Unlock <%= @feature %></h3>
        <button
          phx-click="show_upgrade_modal"
          phx-value-feature={@feature}
          class="px-6 py-2 bg-gradient-to-r from-purple-600 to-pink-600 rounded-md hover:from-purple-700 hover:to-pink-700 transition-colors"
        >
          Upgrade to unlock
        </button>
      </div>
    </div>
    """
  end

  def upgrade_tooltip(assigns) do
    ~H"""
    <div class="absolute -top-8 left-1/2 transform -translate-x-1/2 px-2 py-1 bg-black text-white text-xs rounded opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none whitespace-nowrap">
      Upgrade to unlock <%= @feature %>
    </div>
    """
  end

  # Helper Functions
  defp show_dropdown(target) do
    JS.show(to: "##{target}")
    |> JS.add_class("block")
    |> JS.remove_class("hidden")
  end

  defp get_host(participants) do
    Enum.find(participants, &(&1.role == "host")) || List.first(participants)
  end

  defp get_client(participants, current_user) do
    Enum.find(participants, &(&1.user_id != current_user.id && &1.role != "host"))
  end

  defp get_focused_participant(participants) do
    Enum.find(participants, &(&1.speaking)) || get_host(participants)
  end

  defp get_presenter(participants) do
    Enum.find(participants, &(&1.role in ["host", "presenter"])) || List.first(participants)
  end

  defp format_duration(seconds) do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    seconds = rem(seconds, 60)

    if hours > 0 do
      "#{pad_zero(hours)}:#{pad_zero(minutes)}:#{pad_zero(seconds)}"
    else
      "#{pad_zero(minutes)}:#{pad_zero(seconds)}"
    end
  end

  defp pad_zero(num) when num < 10, do: "0#{num}"
  defp pad_zero(num), do: to_string(num)

  defp humanize(atom) when is_atom(atom) do
    atom
    |> to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp humanize(string), do: string

  # Additional missing components
  def screen_share_area(assigns) do
    ~H"""
    <div class="screen-share-overlay absolute inset-0 bg-black bg-opacity-50 flex items-center justify-center">
      <div class="text-center text-white">
        <.icon name="hero-computer-desktop" class="w-16 h-16 mx-auto mb-4" />
        <h3 class="text-lg font-semibold mb-2">Screen Sharing Active</h3>
        <p class="text-gray-300">Your screen is being shared with participants</p>
        <button
          phx-click="stop_screen_share"
          class="mt-4 px-4 py-2 bg-red-600 hover:bg-red-700 rounded transition-colors"
        >
          Stop Sharing
        </button>
      </div>
    </div>
    """
  end

  def tutorial_controls(assigns) do
    ~H"""
    <div class="tutorial-controls flex items-center justify-between">
      <div class="flex items-center space-x-4">
        <!-- Lesson Progress -->
        <div class="lesson-progress flex items-center space-x-2">
          <span class="text-sm text-gray-400">Progress:</span>
          <div class="w-32 h-2 bg-gray-700 rounded-full">
            <div class="h-full bg-blue-600 rounded-full" style={"width: #{@session_state[:lesson_progress] || 0}%"}></div>
          </div>
          <span class="text-sm text-gray-300"><%= @session_state[:lesson_progress] || 0 %>%</span>
        </div>

        <!-- Interactive Tools -->
        <button
          phx-click="toggle_qa"
          class={[
            "px-3 py-1 rounded text-sm transition-colors",
            @session_state[:qa_enabled] && "bg-green-600 text-white" || "bg-gray-600 text-gray-300 hover:bg-gray-500"
          ]}
        >
          Q&A: <%= if @session_state[:qa_enabled], do: "ON", else: "OFF" %>
        </button>

        <button
          phx-click="start_poll"
          class="px-3 py-1 bg-purple-600 hover:bg-purple-700 rounded text-sm transition-colors"
        >
          Start Poll
        </button>
      </div>

      <div class="flex items-center space-x-2">
        <button
          phx-click="previous_section"
          class="p-2 bg-gray-600 hover:bg-gray-500 rounded transition-colors"
        >
          <.icon name="hero-chevron-left" class="w-4 h-4" />
        </button>

        <button
          phx-click="next_section"
          class="p-2 bg-blue-600 hover:bg-blue-700 rounded transition-colors"
        >
          <.icon name="hero-chevron-right" class="w-4 h-4" />
        </button>
      </div>
    </div>
    """
  end

  def host_controls(assigns) do
    ~H"""
    <div class="host-controls bg-black bg-opacity-60 rounded-lg p-4">
      <div class="flex items-center justify-between">
        <div class="flex items-center space-x-4">
          <!-- Stream Status -->
          <div class="flex items-center space-x-2">
            <div class="w-3 h-3 bg-red-500 rounded-full animate-pulse"></div>
            <span class="text-sm font-medium">LIVE</span>
            <span class="text-sm text-gray-300">
              <%= @session_state.viewer_count %> viewers
            </span>
          </div>

          <!-- Stream Duration -->
          <div class="text-sm text-gray-300">
            Duration: <%= format_stream_duration(@session_state) %>
          </div>
        </div>

        <div class="flex items-center space-x-2">
          <button
            phx-click="toggle_chat"
            class="px-3 py-1 bg-gray-700 hover:bg-gray-600 rounded text-sm transition-colors"
          >
            Chat
          </button>

          <button
            phx-click="manage_stream"
            class="px-3 py-1 bg-blue-600 hover:bg-blue-700 rounded text-sm transition-colors"
          >
            Settings
          </button>

          <button
            phx-click="end_stream"
            class="px-3 py-1 bg-red-600 hover:bg-red-700 rounded text-sm transition-colors"
          >
            End Stream
          </button>
        </div>
      </div>
    </div>
    """
  end

  def call_controls(assigns) do
    ~H"""
    <div class="call-controls flex items-center justify-center space-x-4 bg-gray-800 rounded-full px-6 py-3">
      <button
        phx-click="toggle_microphone"
        class={[
          "p-3 rounded-full transition-colors",
          @session_state[:audio_enabled] && "bg-gray-700 hover:bg-gray-600" || "bg-red-600 hover:bg-red-700"
        ]}
      >
        <.icon name={@session_state[:audio_enabled] && "hero-microphone" || "hero-microphone-slash"} class="w-5 h-5" />
      </button>

      <button
        phx-click="toggle_camera"
        class={[
          "p-3 rounded-full transition-colors",
          @session_state[:video_enabled] && "bg-gray-700 hover:bg-gray-600" || "bg-red-600 hover:bg-red-700"
        ]}
      >
        <.icon name={@session_state[:video_enabled] && "hero-video-camera" || "hero-video-camera-slash"} class="w-5 h-5" />
      </button>

      <%= if @feature_gates.screen_sharing do %>
        <button
          phx-click="toggle_screen_share"
          class={[
            "p-3 rounded-full transition-colors",
            @session_state[:screen_sharing] && "bg-blue-600 hover:bg-blue-700" || "bg-gray-700 hover:bg-gray-600"
          ]}
        >
          <.icon name="hero-computer-desktop" class="w-5 h-5" />
        </button>
      <% end %>

      <button
        phx-click="end_call"
        class="p-3 bg-red-600 hover:bg-red-700 rounded-full transition-colors"
      >
        <.icon name="hero-phone-x-mark" class="w-5 h-5" />
      </button>
    </div>
    """
  end

  def tutorial_sidebar(assigns) do
    ~H"""
    <div class="tutorial-sidebar h-full flex flex-col">
      <!-- Attendees -->
      <div class="attendees p-4 border-b border-gray-700">
        <h3 class="text-lg font-semibold mb-3">Attendees (<%= length(@session_state.participants) %>)</h3>
        <div class="space-y-2">
          <div
            :for={participant <- @session_state.participants}
            class="flex items-center space-x-3 p-2 bg-gray-700 rounded-md"
          >
            <div class="w-8 h-8 bg-gray-600 rounded-full flex items-center justify-center">
              <span class="text-xs font-medium"><%= String.first(participant.user.name || "?") %></span>
            </div>
            <span class="text-sm"><%= participant.user.name || participant.user.username %></span>
            <div :if={participant.user_id == @session.host_id} class="ml-auto px-2 py-1 bg-blue-600 rounded text-xs">
              Host
            </div>
          </div>
        </div>
      </div>

      <!-- Q&A Panel -->
      <div class="qa-panel flex-1 p-4">
        <h4 class="font-semibold mb-3">Questions & Answers</h4>
        <div class="qa-messages space-y-3 mb-4" style="max-height: 300px; overflow-y: auto;">
          <!-- Q&A messages will be loaded dynamically -->
        </div>

        <form phx-submit="submit_question" class="space-y-2">
          <textarea
            name="question"
            rows="3"
            placeholder="Ask a question..."
            class="w-full p-3 bg-gray-700 border border-gray-600 rounded-md text-white placeholder-gray-400 resize-none focus:outline-none focus:border-blue-500"
          ></textarea>
          <button type="submit" class="w-full py-2 bg-blue-600 hover:bg-blue-700 rounded-md transition-colors">
            Submit Question
          </button>
        </form>
      </div>
    </div>
    """
  end

  # Helper function for stream duration
  defp format_stream_duration(session_state) do
    # This would calculate duration from session start time
    "00:45:32" # Placeholder
  end
end
