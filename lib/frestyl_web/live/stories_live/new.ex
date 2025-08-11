# lib/frestyl_web/live/stories_live/new.ex

defmodule FrestylWeb.StoriesLive.New do
  use FrestylWeb, :live_view

  alias Frestyl.Stories
  alias Frestyl.Stories.EnhancedStoryStructure

  @impl true
  def mount(_params, _session, socket) do
    changeset = Stories.change_enhanced_story(%EnhancedStoryStructure{})

    socket = socket
    |> assign(:changeset, changeset)
    |> assign(:page_title, "New Story")
    |> assign(:selected_story_type, nil)
    |> assign(:step, :basics)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    assign(socket, :page_title, "New Story")
  end

  @impl true
  def handle_event("story_type_selected", %{"story_type" => story_type}, socket) do
    {:noreply, assign(socket, :selected_story_type, story_type)}
  end

  @impl true
  def handle_event("create_story", %{"enhanced_story_structure" => story_params}, socket) do
    current_user = socket.assigns.current_user

    # Add selected story type to params
    enhanced_params = Map.put(story_params, "story_type", socket.assigns.selected_story_type)

    case Stories.create_enhanced_story(enhanced_params, current_user) do
      {:ok, story} ->
        {:noreply, socket
         |> put_flash(:info, "Story created successfully")
         |> redirect(to: ~p"/stories/#{story.id}/edit")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  @impl true
  def handle_event("next_step", _params, socket) do
    next_step = case socket.assigns.step do
      :basics -> :template
      :template -> :customize
      :customize -> :review
    end

    {:noreply, assign(socket, :step, next_step)}
  end

  @impl true
  def handle_event("prev_step", _params, socket) do
    prev_step = case socket.assigns.step do
      :template -> :basics
      :customize -> :template
      :review -> :customize
    end

    {:noreply, assign(socket, :step, prev_step)}
  end

  defp story_type_options do
    %{
      "novel" => %{
        name: "Novel",
        description: "Long-form fiction with chapters and character development",
        icon: "📚",
        examples: "Fantasy epics, romance novels, thrillers"
      },
      "screenplay" => %{
        name: "Screenplay",
        description: "Scripts for films, TV shows, or stage productions",
        icon: "🎬",
        examples: "Feature films, TV episodes, stage plays"
      },
      "case_study" => %{
        name: "Case Study",
        description: "Business analysis and problem-solving documentation",
        icon: "📊",
        examples: "Business cases, research studies, project analyses"
      },
      "blog_series" => %{
        name: "Blog Series",
        description: "Multi-part blog content for online publication",
        icon: "📝",
        examples: "Tutorial series, thought leadership, educational content"
      },
      "article" => %{
        name: "Article",
        description: "Single-piece journalism or informational content",
        icon: "📰",
        examples: "News articles, opinion pieces, how-to guides"
      },
      "short_story" => %{
        name: "Short Story",
        description: "Brief fictional narratives focused on a single event",
        icon: "📖",
        examples: "Flash fiction, anthology pieces, literary shorts"
      }
    }
  end
end
