# lib/frestyl_web/live/portfolio_live/components/section_modals/blog_articles_modal_component.ex
defmodule FrestylWeb.PortfolioLive.Components.BlogArticlesModalComponent do
  @moduledoc """
  Specialized modal for editing blog/articles sections - publications, metadata, external links
  """
  use FrestylWeb, :live_component
  alias FrestylWeb.PortfolioLive.Components.BaseSectionModalComponent

  def update(assigns, socket) do
    content = get_section_content(assigns.editing_section)

    socket = socket
    |> assign(assigns)
    |> assign(:content, content)
    |> assign(:modal_title, "Edit Blog & Articles")
    |> assign(:modal_description, "Showcase your published content and thought leadership")
    |> assign(:section_type, :blog_articles)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <.live_component
      module={BaseSectionModalComponent}
      id="blog-articles-modal"
      editing_section={@editing_section}
      modal_title={@modal_title}
      modal_description={@modal_description}
      section_type={@section_type}
      myself={@myself}>

      <!-- Blog/Articles Specific Fields -->
      <div class="space-y-6">

        <!-- Section Description -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Section Description</label>
          <textarea
            name="description"
            rows="3"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            placeholder="Overview of your writing and published content..."><%= Map.get(@content, "description", "") %></textarea>
        </div>

        <!-- Display Settings -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Display Style</label>
            <select
              name="display_style"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
              <option value="cards" selected={Map.get(@content, "display_style") == "cards"}>Article Cards</option>
              <option value="list" selected={Map.get(@content, "display_style") == "list"}>Simple List</option>
              <option value="timeline" selected={Map.get(@content, "display_style") == "timeline"}>Timeline</option>
              <option value="featured" selected={Map.get(@content, "display_style") == "featured"}>Featured + Grid</option>
              <option value="magazine" selected={Map.get(@content, "display_style") == "magazine"}>Magazine Style</option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Articles Per Row</label>
            <select
              name="articles_per_row"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
              <option value="1" selected={Map.get(@content, "articles_per_row", 2) == 1}>1 Column</option>
              <option value="2" selected={Map.get(@content, "articles_per_row", 2) == 2}>2 Columns</option>
              <option value="3" selected={Map.get(@content, "articles_per_row", 2) == 3}>3 Columns</option>
            </select>
          </div>
        </div>

        <!-- Articles/Blog Posts -->
        <div class="border rounded-lg p-4 bg-gray-50">
          <div class="flex items-center justify-between mb-4">
            <h4 class="font-medium text-gray-900">Published Articles & Blog Posts</h4>
            <button
              type="button"
              phx-click="add_article"
              phx-target={@myself}
              class="px-3 py-1 bg-indigo-600 text-white text-sm rounded-md hover:bg-indigo-700 transition-colors">
              + Add Article
            </button>
          </div>

          <div class="space-y-6" id="articles-container">
            <%= for {article, index} <- Enum.with_index(Map.get(@content, "articles", [])) do %>
              <div class="border rounded-lg p-4 bg-white relative">
                <!-- Remove button -->
                <button
                  type="button"
                  phx-click="remove_article"
                  phx-target={@myself}
                  phx-value-index={index}
                  class="absolute top-2 right-2 p-1 text-red-500 hover:text-red-700">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                  </svg>
                </button>

                <!-- Article basic info -->
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Article Title</label>
                    <input
                      type="text"
                      name={"articles[#{index}][title]"}
                      value={Map.get(article, "title", "")}
                      placeholder="How to Build Better Web Applications"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-indigo-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Publication/Platform</label>
                    <input
                      type="text"
                      name={"articles[#{index}][publication]"}
                      value={Map.get(article, "publication", "")}
                      placeholder="Medium, Dev.to, Company Blog"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-indigo-500" />
                  </div>
                </div>

                <!-- Article summary -->
                <div class="mb-4">
                  <label class="block text-xs font-medium text-gray-700 mb-1">Article Summary/Excerpt</label>
                  <textarea
                    name={"articles[#{index}][summary]"}
                    rows="3"
                    class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-indigo-500"
                    placeholder="Brief summary of the article content and key takeaways..."><%= Map.get(article, "summary", "") %></textarea>
                </div>

                <!-- Publication details -->
                <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Publication Date</label>
                    <input
                      type="text"
                      name={"articles[#{index}][published_date]"}
                      value={Map.get(article, "published_date", "")}
                      placeholder="March 15, 2023"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-indigo-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Reading Time</label>
                    <input
                      type="text"
                      name={"articles[#{index}][reading_time]"}
                      value={Map.get(article, "reading_time", "")}
                      placeholder="5 min read"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-indigo-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Content Type</label>
                    <select
                      name={"articles[#{index}][content_type]"}
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-indigo-500">
                      <option value="article" selected={Map.get(article, "content_type") == "article"}>Article</option>
                      <option value="tutorial" selected={Map.get(article, "content_type") == "tutorial"}>Tutorial</option>
                      <option value="opinion" selected={Map.get(article, "content_type") == "opinion"}>Opinion/Editorial</option>
                      <option value="case_study" selected={Map.get(article, "content_type") == "case_study"}>Case Study</option>
                      <option value="research" selected={Map.get(article, "content_type") == "research"}>Research</option>
                      <option value="interview" selected={Map.get(article, "content_type") == "interview"}>Interview</option>
                    </select>
                  </div>
                </div>

                <!-- URLs and links -->
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Article URL</label>
                    <input
                      type="url"
                      name={"articles[#{index}][url]"}
                      value={Map.get(article, "url", "")}
                      placeholder="https://medium.com/@you/article-title"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-indigo-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Featured Image URL</label>
                    <input
                      type="url"
                      name={"articles[#{index}][featured_image]"}
                      value={Map.get(article, "featured_image", "")}
                      placeholder="https://example.com/article-cover.jpg"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-indigo-500" />
                  </div>
                </div>

                <!-- Tags and categories -->
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Tags</label>
                    <input
                      type="text"
                      name={"articles[#{index}][tags]"}
                      value={Enum.join(Map.get(article, "tags", []), ", ")}
                      placeholder="JavaScript, React, Web Development"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-indigo-500" />
                    <p class="text-xs text-gray-500 mt-1">Separate tags with commas</p>
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Category</label>
                    <input
                      type="text"
                      name={"articles[#{index}][category]"}
                      value={Map.get(article, "category", "")}
                      placeholder="Technology, Business, Design"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-indigo-500" />
                  </div>
                </div>

                <!-- Engagement metrics -->
                <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-4">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Views/Reads</label>
                    <input
                      type="text"
                      name={"articles[#{index}][views]"}
                      value={Map.get(article, "views", "")}
                      placeholder="1.2k, 5000"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-indigo-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Likes/Claps</label>
                    <input
                      type="text"
                      name={"articles[#{index}][likes]"}
                      value={Map.get(article, "likes", "")}
                      placeholder="150, 500"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-indigo-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Comments</label>
                    <input
                      type="text"
                      name={"articles[#{index}][comments]"}
                      value={Map.get(article, "comments", "")}
                      placeholder="25, 100"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-indigo-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Shares</label>
                    <input
                      type="text"
                      name={"articles[#{index}][shares]"}
                      value={Map.get(article, "shares", "")}
                      placeholder="50, 200"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-indigo-500" />
                  </div>
                </div>

                <!-- Co-authors and collaborators -->
                <div class="mb-4">
                  <div class="flex items-center justify-between mb-2">
                    <label class="block text-xs font-medium text-gray-700">Co-authors/Collaborators</label>
                    <button
                      type="button"
                      phx-click="add_coauthor"
                      phx-target={@myself}
                      phx-value-article-index={index}
                      class="text-xs text-indigo-600 hover:text-indigo-700">
                      + Add Co-author
                    </button>
                  </div>

                  <div class="space-y-2">
                    <%= for {coauthor, coauthor_index} <- Enum.with_index(Map.get(article, "coauthors", [])) do %>
                      <div class="flex items-center space-x-2 bg-gray-50 p-2 rounded">
                        <input
                          type="text"
                          name={"articles[#{index}][coauthors][#{coauthor_index}][name]"}
                          value={Map.get(coauthor, "name", "")}
                          placeholder="Co-author Name"
                          class="flex-1 px-2 py-1 text-xs border border-gray-300 rounded focus:ring-1 focus:ring-indigo-500" />
                        <input
                          type="url"
                          name={"articles[#{index}][coauthors][#{coauthor_index}][profile_url]"}
                          value={Map.get(coauthor, "profile_url", "")}
                          placeholder="https://linkedin.com/in/coauthor"
                          class="flex-1 px-2 py-1 text-xs border border-gray-300 rounded focus:ring-1 focus:ring-indigo-500" />
                        <button
                          type="button"
                          phx-click="remove_coauthor"
                          phx-target={@myself}
                          phx-value-article-index={index}
                          phx-value-coauthor-index={coauthor_index}
                          class="p-1 text-red-500 hover:text-red-700">
                          <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                          </svg>
                        </button>
                      </div>
                    <% end %>

                    <%= if Enum.empty?(Map.get(article, "coauthors", [])) do %>
                      <div class="text-center py-2 text-gray-400 text-xs">
                        No co-authors added
                      </div>
                    <% end %>
                  </div>
                </div>

                <!-- Article flags -->
                <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                  <div class="flex items-center">
                    <input
                      type="checkbox"
                      id={"featured_article_#{index}"}
                      name={"articles[#{index}][featured]"}
                      value="true"
                      checked={Map.get(article, "featured", false)}
                      class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded">
                    <label for={"featured_article_#{index}"} class="ml-2 block text-xs text-gray-900">
                      Featured article
                    </label>
                  </div>
                  <div class="flex items-center">
                    <input
                      type="checkbox"
                      id={"trending_#{index}"}
                      name={"articles[#{index}][trending]"}
                      value="true"
                      checked={Map.get(article, "trending", false)}
                      class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded">
                    <label for={"trending_#{index}"} class="ml-2 block text-xs text-gray-900">
                      Trending/Popular
                    </label>
                  </div>
                  <div class="flex items-center">
                    <input
                      type="checkbox"
                      id={"external_publication_#{index}"}
                      name={"articles[#{index}][external_publication]"}
                      value="true"
                      checked={Map.get(article, "external_publication", true)}
                      class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded">
                    <label for={"external_publication_#{index}"} class="ml-2 block text-xs text-gray-900">
                      External publication
                    </label>
                  </div>
                </div>
              </div>
            <% end %>

            <%= if length(Map.get(@content, "articles", [])) == 0 do %>
              <div class="text-center py-8 text-gray-500">
                <svg class="w-12 h-12 mx-auto mb-3 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.746 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"/>
                </svg>
                <p>No articles added yet</p>
                <p class="text-sm">Click "Add Article" to showcase your published content</p>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Publication Settings -->
        <div class="border rounded-lg p-4 bg-gray-50">
          <h4 class="font-medium text-gray-900 mb-4">Publication Settings</h4>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">RSS Feed URL</label>
              <input
                type="url"
                name="rss_feed"
                value={Map.get(@content, "rss_feed", "")}
                placeholder="https://yourblog.com/rss"
                class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-indigo-500" />
            </div>
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">Newsletter Signup URL</label>
              <input
                type="url"
                name="newsletter_url"
                value={Map.get(@content, "newsletter_url", "")}
                placeholder="https://newsletter.com/subscribe"
                class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-indigo-500" />
            </div>
          </div>
        </div>

        <!-- Display Settings -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div class="flex items-center">
            <input
              type="checkbox"
              id="show_metrics"
              name="show_metrics"
              value="true"
              checked={Map.get(@content, "show_metrics", false)}
              class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded">
            <label for="show_metrics" class="ml-2 block text-sm text-gray-900">
              Show engagement metrics
            </label>
          </div>
          <div class="flex items-center">
            <input
              type="checkbox"
              id="show_publication_dates"
              name="show_publication_dates"
              value="true"
              checked={Map.get(@content, "show_publication_dates", true)}
              class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded">
            <label for="show_publication_dates" class="ml-2 block text-sm text-gray-900">
              Show publication dates
            </label>
          </div>
          <div class="flex items-center">
            <input
              type="checkbox"
              id="show_reading_time"
              name="show_reading_time"
              value="true"
              checked={Map.get(@content, "show_reading_time", true)}
              class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded">
            <label for="show_reading_time" class="ml-2 block text-sm text-gray-900">
              Show reading time
            </label>
          </div>
          <div class="flex items-center">
            <input
              type="checkbox"
              id="enable_tag_filtering"
              name="enable_tag_filtering"
              value="true"
              checked={Map.get(@content, "enable_tag_filtering", false)}
              class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded">
            <label for="enable_tag_filtering" class="ml-2 block text-sm text-gray-900">
              Enable tag filtering
            </label>
          </div>
        </div>

      </div>
    </.live_component>
    """
  end

  def handle_event("add_article", _params, socket) do
    content = socket.assigns.content
    current_articles = Map.get(content, "articles", [])

    new_article = %{
      "title" => "",
      "publication" => "",
      "summary" => "",
      "published_date" => "",
      "reading_time" => "",
      "content_type" => "article",
      "url" => "",
      "featured_image" => "",
      "tags" => [],
      "category" => "",
      "views" => "",
      "likes" => "",
      "comments" => "",
      "shares" => "",
      "coauthors" => [],
      "featured" => false,
      "trending" => false,
      "external_publication" => true
    }

    updated_content = Map.put(content, "articles", current_articles ++ [new_article])

    {:noreply, assign(socket, :content, updated_content)}
  end

  def handle_event("remove_article", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    content = socket.assigns.content
    current_articles = Map.get(content, "articles", [])

    updated_articles = List.delete_at(current_articles, index)
    updated_content = Map.put(content, "articles", updated_articles)

    {:noreply, assign(socket, :content, updated_content)}
  end

  def handle_event("add_coauthor", %{"article-index" => article_index_str}, socket) do
    article_index = String.to_integer(article_index_str)
    content = socket.assigns.content
    current_articles = Map.get(content, "articles", [])

    if article_index < length(current_articles) do
      article = Enum.at(current_articles, article_index)
      current_coauthors = Map.get(article, "coauthors", [])

      new_coauthor = %{
        "name" => "",
        "profile_url" => ""
      }

      updated_coauthors = current_coauthors ++ [new_coauthor]
      updated_article = Map.put(article, "coauthors", updated_coauthors)
      updated_articles = List.replace_at(current_articles, article_index, updated_article)
      updated_content = Map.put(content, "articles", updated_articles)

      {:noreply, assign(socket, :content, updated_content)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("remove_coauthor", %{"article-index" => article_index_str, "coauthor-index" => coauthor_index_str}, socket) do
    article_index = String.to_integer(article_index_str)
    coauthor_index = String.to_integer(coauthor_index_str)
    content = socket.assigns.content
    current_articles = Map.get(content, "articles", [])

    if article_index < length(current_articles) do
      article = Enum.at(current_articles, article_index)
      current_coauthors = Map.get(article, "coauthors", [])

      updated_coauthors = List.delete_at(current_coauthors, coauthor_index)
      updated_article = Map.put(article, "coauthors", updated_coauthors)
      updated_articles = List.replace_at(current_articles, article_index, updated_article)
      updated_content = Map.put(content, "articles", updated_articles)

      {:noreply, assign(socket, :content, updated_content)}
    else
      {:noreply, socket}
    end
  end

  defp get_section_content(section) do
    case section.content do
      content when is_map(content) -> content
      content when is_binary(content) -> %{"description" => content}
      _ -> %{}
    end
  end
end
