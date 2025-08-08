# lib/frestyl_web/live/narrative_beats_live/new.ex
defmodule FrestylWeb.NarrativeBeatsLive.New do
  use FrestylWeb, :live_view

  alias Frestyl.{NarrativeBeats, Stories}
  alias Frestyl.Features.TierManager

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    # Check tier access
    if TierManager.feature_available?(user.subscription_tier, :narrative_beats) do
      # Get user's existing stories for sync options
      existing_stories = Stories.list_user_stories(user.id, limit: 20)

      socket =
        socket
        |> assign(:page_title, "Create Narrative Beats Session")
        |> assign(:existing_stories, existing_stories)
        |> assign(:step, :basic_info)
        |> assign(:session_data, %{})
        |> assign(:selected_story, nil)
        |> assign(:story_analysis, nil)

      {:ok, socket}
    else
      {:ok, redirect(socket, to: ~p"/narrative-beats")}
    end
  end

  def handle_event("next_step", %{"session" => session_params}, socket) do
    updated_data = Map.merge(socket.assigns.session_data, session_params)

    case socket.assigns.step do
      :basic_info ->
        {:noreply,
         socket
         |> assign(:session_data, updated_data)
         |> assign(:step, :story_sync)}

      :story_sync ->
        {:noreply,
         socket
         |> assign(:session_data, updated_data)
         |> assign(:step, :musical_preferences)}

      :musical_preferences ->
        {:noreply, create_session(socket, updated_data)}
    end
  end

  def handle_event("select_story", %{"story_id" => story_id}, socket) do
    story = Enum.find(socket.assigns.existing_stories, &(&1.id == story_id))

    if story do
      # Analyze story for musical mapping suggestions
      analysis = analyze_story_for_music(story)

      {:noreply,
       socket
       |> assign(:selected_story, story)
       |> assign(:story_analysis, analysis)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("skip_story_sync", _params, socket) do
    {:noreply,
     socket
     |> assign(:selected_story, nil)
     |> assign(:step, :musical_preferences)}
  end

  defp create_session(socket, session_data) do
    user = socket.assigns.current_user

    # Create studio session first
    studio_session_params = %{
      "name" => session_data["title"],
      "session_type" => "narrative_beats",
      "privacy" => session_data["privacy"] || "private"
    }

    case Frestyl.Sessions.create_session(studio_session_params, user) do
      {:ok, studio_session} ->
        # Create narrative beats session
        narrative_session_params = Map.merge(session_data, %{
          "session_id" => studio_session.id,
          "created_by_id" => user.id
        })

        case NarrativeBeats.create_session(narrative_session_params, user, studio_session.id) do
          {:ok, narrative_session} ->
            # If story was selected, sync it
            if socket.assigns.selected_story do
              sync_story_with_session(narrative_session, socket.assigns.selected_story)
            end

            socket
            |> put_flash(:info, "Narrative Beats session created successfully!")
            |> push_navigate(to: ~p"/narrative-beats/#{narrative_session.id}")

          {:error, changeset} ->
            socket
            |> put_flash(:error, "Failed to create session: #{inspect(changeset.errors)}")
        end

      {:error, _changeset} ->
        socket
        |> put_flash(:error, "Failed to create studio session")
    end
  end

  defp analyze_story_for_music(story) do
    %{
      suggested_characters: extract_characters_for_instruments(story),
      suggested_emotions: extract_emotions_for_progressions(story),
      suggested_sections: extract_plot_points_for_sections(story),
      estimated_duration: calculate_estimated_duration(story),
      recommended_bpm: suggest_bpm_from_story_pace(story),
      recommended_key: suggest_key_from_story_mood(story)
    }
  end

  defp extract_characters_for_instruments(story) do
    case story.character_data do
      %{"characters" => characters} when is_list(characters) ->
        Enum.map(characters, fn character ->
          %{
            name: character["name"],
            suggested_instrument: suggest_instrument_for_character(character),
            importance: character["importance"] || 0.5,
            emotional_range: character["personality"] || %{}
          }
        end)
      _ -> []
    end
  end

  defp extract_emotions_for_progressions(story) do
    # Extract emotions from story content and sections
    emotions = case story.sections do
      sections when is_list(sections) ->
        Enum.flat_map(sections, fn section ->
          [section["mood"], section["emotion"], section["tone"]]
        end)
      _ -> []
    end

    emotions
    |> Enum.filter(& &1)
    |> Enum.uniq()
    |> Enum.map(fn emotion ->
      %{
        name: emotion,
        suggested_progression: suggest_progression_for_emotion(emotion),
        tension_level: calculate_emotion_tension(emotion)
      }
    end)
  end

  defp extract_plot_points_for_sections(story) do
    case story.outline do
      %{"sections" => sections} when is_list(sections) ->
        Enum.with_index(sections, fn section, index ->
          %{
            name: section["title"] || "Section #{index + 1}",
            plot_point: section["content"] || section["summary"],
            suggested_type: suggest_section_type(section, index, length(sections)),
            estimated_duration: section["estimated_duration"] || 16
          }
        end)
      _ -> []
    end
  end

  defp suggest_instrument_for_character(character) do
    role = character["role"] || "supporting"
    personality = character["personality"] || %{}

    cond do
      role == "protagonist" -> "piano"
      role == "antagonist" -> "synthesizer"
      personality["energy"] == "high" -> "drums"
      personality["mood"] == "calm" -> "flute"
      personality["complexity"] == "high" -> "violin"
      true -> "guitar"
    end
  end

  defp suggest_progression_for_emotion(emotion) do
    case String.downcase(emotion) do
      emotion when emotion in ["happy", "joy", "triumph"] -> ["C", "Am", "F", "G"]
      emotion when emotion in ["sad", "melancholy", "loss"] -> ["Am", "F", "C", "G"]
      emotion when emotion in ["tense", "conflict", "danger"] -> ["F#dim", "G", "Am", "Bb"]
      emotion when emotion in ["peaceful", "calm", "serene"] -> ["C", "F", "G", "C"]
      emotion when emotion in ["mysterious", "unknown", "magic"] -> ["Am", "Bb", "F", "Dm"]
      _ -> ["C", "Am", "F", "G"]
    end
  end

  defp calculate_emotion_tension(emotion) do
    case String.downcase(emotion) do
      emotion when emotion in ["tense", "conflict", "danger", "climax"] -> 0.8
      emotion when emotion in ["sad", "melancholy", "dramatic"] -> 0.6
      emotion when emotion in ["happy", "joy", "excited"] -> 0.4
      emotion when emotion in ["peaceful", "calm", "serene"] -> 0.2
      _ -> 0.5
    end
  end

  defp suggest_section_type(section, index, total_sections) do
    cond do
      index == 0 -> "intro"
      index == total_sections - 1 -> "outro"
      section["tension"] && section["tension"] > 0.7 -> "climax"
      rem(index, 2) == 0 -> "verse"
      true -> "bridge"
    end
  end

  defp calculate_estimated_duration(story) do
    # Base duration calculation on story length and complexity
    word_count = story.current_word_count || 1000
    sections_count = length(story.sections || [])

    # Rough formula: 1 minute per 100 words, minimum 2 minutes
    base_duration = max(word_count / 100, 2)

    # Adjust for number of sections
    section_factor = max(sections_count / 5, 1)

    round(base_duration * section_factor)
  end

  defp suggest_bpm_from_story_pace(story) do
    # Analyze story pace from metadata
    pace = get_in(story.format_metadata, ["pace"]) || "medium"

    case pace do
      "fast" -> 140
      "medium" -> 120
      "slow" -> 90
      _ -> 120
    end
  end

  defp suggest_key_from_story_mood(story) do
    # Suggest key based on overall story mood
    mood = get_in(story.format_metadata, ["mood"]) || "neutral"

    case mood do
      mood when mood in ["happy", "uplifting", "triumphant"] -> "C"
      mood when mood in ["sad", "melancholy", "tragic"] -> "Am"
      mood when mood in ["mysterious", "dark", "suspenseful"] -> "Em"
      mood when mood in ["romantic", "nostalgic"] -> "F"
      mood when mood in ["epic", "heroic"] -> "G"
      _ -> "C"
    end
  end

  defp sync_story_with_session(narrative_session, story) do
    # Use the StoryTimelineSync module to sync the story
    alias Frestyl.NarrativeBeats.StoryTimelineSync

    Task.start(fn ->
      case StoryTimelineSync.sync_story_with_music(story.id, narrative_session.id) do
        {:ok, _result} ->
          # Broadcast success
          Phoenix.PubSub.broadcast(
            Frestyl.PubSub,
            "narrative_beats:#{narrative_session.id}",
            {:story_synced, story}
          )

        {:error, reason} ->
          # Log error
          require Logger
          Logger.error("Failed to sync story with narrative beats session: #{inspect(reason)}")
      end
    end)
  end

  def render(assigns) do
    ~H"""
    <div class="narrative-beats-new max-w-4xl mx-auto py-8 px-6">
      <!-- Progress Steps -->
      <div class="mb-8">
        <div class="flex items-center justify-center">
          <%= for {step, index} <- Enum.with_index([:basic_info, :story_sync, :musical_preferences]) do %>
            <div class="flex items-center">
              <div class={[
                "w-8 h-8 rounded-full flex items-center justify-center text-sm font-medium",
                if(step == @step, do: "bg-purple-600 text-white", else: "bg-gray-200 text-gray-600")
              ]}>
                <%= index + 1 %>
              </div>

              <%= if index < 2 do %>
                <div class="w-16 h-1 bg-gray-200 mx-2"></div>
              <% end %>
            </div>
          <% end %>
        </div>

        <div class="text-center mt-4">
          <h2 class="text-xl font-semibold">
            <%= case @step do %>
              <% :basic_info -> %> Session Information
              <% :story_sync -> %> Story Synchronization
              <% :musical_preferences -> %> Musical Preferences
            <% end %>
          </h2>
        </div>
      </div>

      <!-- Step Content -->
      <%= case @step do %>
        <% :basic_info -> %>
          <.basic_info_step session_data={@session_data} />

        <% :story_sync -> %>
          <.story_sync_step
            existing_stories={@existing_stories}
            selected_story={@selected_story}
            story_analysis={@story_analysis}
          />

        <% :musical_preferences -> %>
          <.musical_preferences_step
            session_data={@session_data}
            story_analysis={@story_analysis}
          />
      <% end %>
    </div>
    """
  end

  defp basic_info_step(assigns) do
    ~H"""
    <div class="bg-white rounded-lg border p-8">
      <form phx-submit="next_step">
        <div class="space-y-6">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Session Title</label>
            <input
              type="text"
              name="session[title]"
              value={@session_data["title"] || ""}
              required
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-purple-500 focus:border-purple-500"
              placeholder="My Story's Soundtrack"
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Description</label>
            <textarea
              name="session[description]"
              rows="4"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-purple-500 focus:border-purple-500"
              placeholder="Describe your musical vision..."
            ><%= @session_data["description"] || "" %></textarea>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Privacy</label>
              <select
                name="session[privacy]"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-purple-500 focus:border-purple-500"
              >
                <option value="private" selected={@session_data["privacy"] == "private"}>Private</option>
                <option value="invite_only" selected={@session_data["privacy"] == "invite_only"}>Invite Only</option>
                <option value="public" selected={@session_data["privacy"] == "public"}>Public</option>
              </select>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Collaboration Mode</label>
              <select
                name="session[collaboration_mode]"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-purple-500 focus:border-purple-500"
              >
                <option value="owner_only">Solo Work</option>
                <option value="invite_only" selected>Invite Collaborators</option>
                <option value="open">Open Collaboration</option>
              </select>
            </div>
          </div>
        </div>

        <div class="flex justify-end mt-8">
          <button
            type="submit"
            class="bg-purple-600 text-white px-6 py-3 rounded-lg hover:bg-purple-700 transition-colors"
          >
            Continue to Story Sync
          </button>
        </div>
      </form>
    </div>
    """
  end

  defp story_sync_step(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="bg-gradient-to-r from-purple-50 to-pink-50 border border-purple-200 rounded-lg p-6">
        <h3 class="text-lg font-semibold text-purple-900 mb-2">Sync with Existing Story</h3>
        <p class="text-purple-700">
          Connect your Narrative Beats session with an existing story to automatically map characters to instruments and emotions to musical progressions.
        </p>
      </div>

      <div class="bg-white rounded-lg border">
        <div class="p-6 border-b">
          <h3 class="text-lg font-semibold">Your Stories</h3>
        </div>

        <div class="p-6">
          <%= if Enum.empty?(@existing_stories) do %>
            <div class="text-center py-8">
              <div class="mx-auto w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mb-4">
                <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.746 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"/>
                </svg>
              </div>
              <h3 class="text-lg font-medium text-gray-900 mb-2">No stories yet</h3>
              <p class="text-gray-500 mb-4">You haven't created any stories yet. You can still create a Narrative Beats session and add story elements manually.</p>
            </div>
          <% else %>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <%= for story <- @existing_stories do %>
                <div class={[
                  "border rounded-lg p-4 cursor-pointer transition-all hover:shadow-lg",
                  if(@selected_story && @selected_story.id == story.id,
                    do: "border-purple-500 bg-purple-50",
                    else: "border-gray-200 hover:border-purple-300")
                ]}>
                  <div phx-click="select_story" phx-value-story_id={story.id}>
                    <h4 class="font-semibold text-gray-900 mb-2"><%= story.title %></h4>
                    <p class="text-sm text-gray-600 mb-3 line-clamp-2">
                      <%= story.description || "No description available" %>
                    </p>

                    <div class="flex justify-between items-center text-xs text-gray-500">
                      <span><%= String.capitalize(story.story_type) %></span>
                      <span><%= story.current_word_count || 0 %> words</span>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>

          <!-- Story Analysis Preview -->
          <%= if @story_analysis do %>
            <div class="mt-6 p-4 bg-green-50 border border-green-200 rounded-lg">
              <h4 class="font-semibold text-green-900 mb-3">Story Analysis Complete!</h4>

              <div class="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm">
                <div>
                  <div class="font-medium text-green-800">Characters Found</div>
                  <div class="text-green-700"><%= length(@story_analysis.suggested_characters) %> characters</div>
                </div>

                <div>
                  <div class="font-medium text-green-800">Emotions Detected</div>
                  <div class="text-green-700"><%= length(@story_analysis.suggested_emotions) %> emotions</div>
                </div>

                <div>
                  <div class="font-medium text-green-800">Suggested Duration</div>
                  <div class="text-green-700"><%= @story_analysis.estimated_duration %> minutes</div>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>

      <div class="flex justify-between">
        <button
          phx-click="skip_story_sync"
          class="px-6 py-3 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 transition-colors"
        >
          Skip Story Sync
        </button>

        <form phx-submit="next_step">
          <input type="hidden" name="session[synced_story_id]" value={@selected_story && @selected_story.id} />
          <button
            type="submit"
            class="bg-purple-600 text-white px-6 py-3 rounded-lg hover:bg-purple-700 transition-colors"
          >
            Continue to Musical Preferences
          </button>
        </form>
      </div>
    </div>
    """
  end

  defp musical_preferences_step(assigns) do
    ~H"""
    <div class="bg-white rounded-lg border p-8">
      <form phx-submit="next_step">
        <div class="space-y-6">
          <!-- Basic Musical Settings -->
          <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">BPM (Tempo)</label>
              <input
                type="number"
                name="session[bpm]"
                value={@session_data["bpm"] || (@story_analysis && @story_analysis.recommended_bpm) || 120}
                min="60"
                max="200"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-purple-500 focus:border-purple-500"
              />
              <%= if @story_analysis do %>
                <div class="text-xs text-green-600 mt-1">
                  Suggested: <%= @story_analysis.recommended_bpm %> BPM
                </div>
              <% end %>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Key Signature</label>
              <select
                name="session[key_signature]"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-purple-500 focus:border-purple-500"
              >
                <%= for key <- ["C", "G", "D", "A", "E", "F", "Bb", "Am", "Em", "Dm"] do %>
                  <option
                    value={key}
                    selected={key == (@session_data["key_signature"] || (@story_analysis && @story_analysis.recommended_key) || "C")}
                  >
                    <%= key %> <%= if String.contains?(key, "m"), do: "Minor", else: "Major" %>
                  </option>
                <% end %>
              </select>
              <%= if @story_analysis do %>
                <div class="text-xs text-green-600 mt-1">
                  Suggested: <%= @story_analysis.recommended_key %>
                </div>
              <% end %>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Time Signature</label>
              <select
                name="session[time_signature]"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-purple-500 focus:border-purple-500"
              >
                <option value="4/4" selected>4/4 (Standard)</option>
                <option value="3/4">3/4 (Waltz)</option>
                <option value="6/8">6/8 (Compound)</option>
                <option value="2/4">2/4 (March)</option>
              </select>
            </div>
          </div>

          <!-- Story Analysis Integration -->
          <%= if @story_analysis do %>
            <div class="border-t pt-6">
              <h3 class="text-lg font-semibold mb-4">Story Integration Preview</h3>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <!-- Characters Preview -->
                <div class="space-y-3">
                  <h4 class="font-medium text-gray-900">Character → Instrument Mappings</h4>
                  <div class="space-y-2">
                    <%= for character <- Enum.take(@story_analysis.suggested_characters, 5) do %>
                      <div class="flex justify-between items-center p-2 bg-gray-50 rounded">
                        <span class="text-sm font-medium"><%= character.name %></span>
                        <span class="text-sm text-purple-600"><%= String.capitalize(character.suggested_instrument) %></span>
                      </div>
                    <% end %>
                    <%= if length(@story_analysis.suggested_characters) > 5 do %>
                      <div class="text-sm text-gray-500 text-center">
                        +<%= length(@story_analysis.suggested_characters) - 5 %> more characters
                      </div>
                    <% end %>
                  </div>
                </div>

                <!-- Emotions Preview -->
                <div class="space-y-3">
                  <h4 class="font-medium text-gray-900">Emotion → Chord Progressions</h4>
                  <div class="space-y-2">
                    <%= for emotion <- Enum.take(@story_analysis.suggested_emotions, 5) do %>
                      <div class="p-2 bg-gray-50 rounded">
                        <div class="text-sm font-medium"><%= String.capitalize(emotion.name) %></div>
                        <div class="text-xs text-gray-600">
                          <%= Enum.join(emotion.suggested_progression, " - ") %>
                        </div>
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>
            </div>
          <% end %>

          <!-- Advanced Options -->
          <div class="border-t pt-6">
            <h3 class="text-lg font-semibold mb-4">Advanced Options</h3>

            <div class="space-y-4">
              <div class="flex items-center">
                <input
                  type="checkbox"
                  name="session[auto_generate_sections]"
                  value="true"
                  checked={@story_analysis != nil}
                  class="mr-3"
                />
                <div>
                  <div class="font-medium text-gray-900">Auto-generate Musical Sections</div>
                  <div class="text-sm text-gray-600">Automatically create musical sections based on story plot points</div>
                </div>
              </div>

              <div class="flex items-center">
                <input
                  type="checkbox"
                  name="session[enable_ai_suggestions]"
                  value="true"
                  checked
                  class="mr-3"
                />
                <div>
                  <div class="font-medium text-gray-900">Enable AI Music Suggestions</div>
                  <div class="text-sm text-gray-600">Get AI-powered chord progressions and arrangement suggestions</div>
                </div>
              </div>

              <div class="flex items-center">
                <input
                  type="checkbox"
                  name="session[real_time_collaboration]"
                  value="true"
                  checked
                  class="mr-3"
                />
                <div>
                  <div class="font-medium text-gray-900">Real-time Collaboration</div>
                  <div class="text-sm text-gray-600">Allow multiple users to work simultaneously</div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div class="flex justify-between mt-8">
          <button
            type="button"
            phx-click="previous_step"
            class="px-6 py-3 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 transition-colors"
          >
            Back
          </button>

          <button
            type="submit"
            class="bg-purple-600 text-white px-6 py-3 rounded-lg hover:bg-purple-700 transition-colors"
          >
            Create Narrative Beats Session
          </button>
        </div>
      </form>
    </div>
    """
  end
end
