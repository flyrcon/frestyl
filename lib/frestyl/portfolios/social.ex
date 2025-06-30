# lib/frestyl/portfolios/social.ex
defmodule Frestyl.Portfolios.Social do
  @moduledoc """
  Context for managing social media integrations and analytics.
  """

  import Ecto.Query, warn: false
  alias Frestyl.Repo
  alias Frestyl.Portfolios.{
    SocialIntegration, SocialPost, AccessRequest, SharingAnalytic, Portfolio
  }

  # ============================================================================
  # SOCIAL INTEGRATION FUNCTIONS
  # ============================================================================

  def list_portfolio_social_integrations(portfolio_id) do
    SocialIntegration
    |> where([s], s.portfolio_id == ^portfolio_id)
    |> order_by([s], s.platform)
    |> Repo.all()
  end

  def get_social_integration!(id), do: Repo.get!(SocialIntegration, id)

  def get_social_integration_by_platform(portfolio_id, platform) do
    SocialIntegration
    |> where([s], s.portfolio_id == ^portfolio_id and s.platform == ^platform)
    |> Repo.one()
  end

  def create_social_integration(attrs \\ %{}) do
    %SocialIntegration{}
    |> SocialIntegration.changeset(attrs)
    |> Repo.insert()
  end

  def update_social_integration(%SocialIntegration{} = integration, attrs) do
    integration
    |> SocialIntegration.changeset(attrs)
    |> Repo.update()
  end

  def sync_social_integration(%SocialIntegration{} = integration, sync_data) do
    integration
    |> SocialIntegration.sync_changeset(sync_data)
    |> Repo.update()
  end

  def delete_social_integration(%SocialIntegration{} = integration) do
    Repo.delete(integration)
  end

  # ============================================================================
  # SOCIAL POSTS FUNCTIONS
  # ============================================================================

  def list_social_posts(integration_id, limit \\ 10) do
    SocialPost
    |> where([p], p.social_integration_id == ^integration_id)
    |> order_by([p], desc: p.posted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def create_social_post(attrs \\ %{}) do
    %SocialPost{}
    |> SocialPost.changeset(attrs)
    |> Repo.insert()
  end

  def update_social_post(%SocialPost{} = post, attrs) do
    post
    |> SocialPost.changeset(attrs)
    |> Repo.update()
  end

  def delete_old_posts(integration_id, keep_count \\ 10) do
    posts_to_delete =
      SocialPost
      |> where([p], p.social_integration_id == ^integration_id)
      |> order_by([p], desc: p.posted_at)
      |> offset(^keep_count)
      |> select([p], p.id)
      |> Repo.all()

    SocialPost
    |> where([p], p.id in ^posts_to_delete)
    |> Repo.delete_all()
  end

  # ============================================================================
  # OAUTH & PLATFORM INTEGRATION
  # ============================================================================

  def get_oauth_url(platform, portfolio_id, redirect_uri) do
    case platform do
      :linkedin -> get_linkedin_oauth_url(portfolio_id, redirect_uri)
      :twitter -> get_twitter_oauth_url(portfolio_id, redirect_uri)
      :instagram -> get_instagram_oauth_url(portfolio_id, redirect_uri)
      :github -> get_github_oauth_url(portfolio_id, redirect_uri)
      _ -> {:error, "Unsupported platform"}
    end
  end

  defp get_linkedin_oauth_url(portfolio_id, redirect_uri) do
    client_id = Application.get_env(:frestyl, :linkedin)[:client_id]
    scope = "r_liteprofile,r_emailaddress,w_member_social"
    state = encode_state(portfolio_id, :linkedin)

    query_params = URI.encode_query(%{
      response_type: "code",
      client_id: client_id,
      redirect_uri: redirect_uri,
      state: state,
      scope: scope
    })

    {:ok, "https://www.linkedin.com/oauth/v2/authorization?#{query_params}"}
  end

  defp get_twitter_oauth_url(portfolio_id, redirect_uri) do
    client_id = Application.get_env(:frestyl, :twitter)[:client_id]
    scope = "tweet.read,users.read,offline.access"
    state = encode_state(portfolio_id, :twitter)

    query_params = URI.encode_query(%{
      response_type: "code",
      client_id: client_id,
      redirect_uri: redirect_uri,
      state: state,
      scope: scope,
      code_challenge_method: "S256",
      code_challenge: generate_code_challenge()
    })

    {:ok, "https://twitter.com/i/oauth2/authorize?#{query_params}"}
  end

  defp get_instagram_oauth_url(portfolio_id, redirect_uri) do
    client_id = Application.get_env(:frestyl, :instagram)[:client_id]
    scope = "user_profile,user_media"
    state = encode_state(portfolio_id, :instagram)

    query_params = URI.encode_query(%{
      client_id: client_id,
      redirect_uri: redirect_uri,
      state: state,
      scope: scope,
      response_type: "code"
    })

    {:ok, "https://api.instagram.com/oauth/authorize?#{query_params}"}
  end

  defp get_github_oauth_url(portfolio_id, redirect_uri) do
    client_id = Application.get_env(:frestyl, :github)[:client_id]
    scope = "read:user,public_repo"
    state = encode_state(portfolio_id, :github)

    query_params = URI.encode_query(%{
      client_id: client_id,
      redirect_uri: redirect_uri,
      state: state,
      scope: scope
    })

    {:ok, "https://github.com/login/oauth/authorize?#{query_params}"}
  end

  defp encode_state(portfolio_id, platform) do
    data = %{portfolio_id: portfolio_id, platform: platform, timestamp: System.system_time(:second)}
    data |> Jason.encode!() |> Base.url_encode64(padding: false)
  end

  defp generate_code_challenge do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  def handle_oauth_callback(platform, code, state, redirect_uri) do
    with {:ok, state_data} <- decode_state(state),
         {:ok, tokens} <- exchange_code_for_tokens(platform, code, redirect_uri),
         {:ok, profile} <- fetch_user_profile(platform, tokens),
         {:ok, integration} <- create_or_update_integration(state_data, platform, tokens, profile) do
      {:ok, integration}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp decode_state(state) do
    try do
      state
      |> Base.url_decode64!(padding: false)
      |> Jason.decode!()
      |> then(&{:ok, &1})
    rescue
      _ -> {:error, "Invalid state parameter"}
    end
  end

  defp exchange_code_for_tokens(platform, code, redirect_uri) do
    case platform do
      :linkedin -> exchange_linkedin_code(code, redirect_uri)
      :twitter -> exchange_twitter_code(code, redirect_uri)
      :instagram -> exchange_instagram_code(code, redirect_uri)
      :github -> exchange_github_code(code, redirect_uri)
      _ -> {:error, "Unsupported platform"}
    end
  end

  defp exchange_linkedin_code(code, redirect_uri) do
    config = Application.get_env(:frestyl, :linkedin)

    body = %{
      grant_type: "authorization_code",
      code: code,
      redirect_uri: redirect_uri,
      client_id: config[:client_id],
      client_secret: config[:client_secret]
    }

    case HTTPoison.post("https://www.linkedin.com/oauth/v2/accessToken",
                       URI.encode_query(body),
                       [{"Content-Type", "application/x-www-form-urlencoded"}]) do
      {:ok, %{status_code: 200, body: response_body}} ->
        Jason.decode(response_body)
      {:ok, %{status_code: status}} ->
        {:error, "OAuth failed with status #{status}"}
      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  defp exchange_twitter_code(code, redirect_uri) do
    config = Application.get_env(:frestyl, :twitter)

    body = %{
      grant_type: "authorization_code",
      code: code,
      redirect_uri: redirect_uri,
      client_id: config[:client_id],
      code_verifier: config[:code_verifier] # Store this during the initial request
    }

    auth_header = "Basic " <> Base.encode64("#{config[:client_id]}:#{config[:client_secret]}")

    case HTTPoison.post("https://api.twitter.com/2/oauth2/token",
                       URI.encode_query(body),
                       [{"Authorization", auth_header},
                        {"Content-Type", "application/x-www-form-urlencoded"}]) do
      {:ok, %{status_code: 200, body: response_body}} ->
        Jason.decode(response_body)
      {:ok, %{status_code: status}} ->
        {:error, "OAuth failed with status #{status}"}
      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  defp exchange_instagram_code(code, redirect_uri) do
    config = Application.get_env(:frestyl, :instagram)

    body = %{
      client_id: config[:client_id],
      client_secret: config[:client_secret],
      grant_type: "authorization_code",
      redirect_uri: redirect_uri,
      code: code
    }

    case HTTPoison.post("https://api.instagram.com/oauth/access_token",
                       URI.encode_query(body),
                       [{"Content-Type", "application/x-www-form-urlencoded"}]) do
      {:ok, %{status_code: 200, body: response_body}} ->
        Jason.decode(response_body)
      {:ok, %{status_code: status}} ->
        {:error, "OAuth failed with status #{status}"}
      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  defp exchange_github_code(code, redirect_uri) do
    config = Application.get_env(:frestyl, :github)

    body = %{
      client_id: config[:client_id],
      client_secret: config[:client_secret],
      code: code,
      redirect_uri: redirect_uri
    }

    case HTTPoison.post("https://github.com/login/oauth/access_token",
                       Jason.encode!(body),
                       [{"Accept", "application/json"},
                        {"Content-Type", "application/json"}]) do
      {:ok, %{status_code: 200, body: response_body}} ->
        Jason.decode(response_body)
      {:ok, %{status_code: status}} ->
        {:error, "OAuth failed with status #{status}"}
      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  defp fetch_user_profile(platform, tokens) do
    access_token = tokens["access_token"]

    case platform do
      :linkedin -> fetch_linkedin_profile(access_token)
      :twitter -> fetch_twitter_profile(access_token)
      :instagram -> fetch_instagram_profile(access_token)
      :github -> fetch_github_profile(access_token)
      _ -> {:error, "Unsupported platform"}
    end
  end

  defp fetch_linkedin_profile(access_token) do
    headers = [{"Authorization", "Bearer #{access_token}"}]

    with {:ok, %{body: profile_body}} <-
           HTTPoison.get("https://api.linkedin.com/v2/people/~", headers),
         {:ok, profile} <- Jason.decode(profile_body),
         {:ok, %{body: email_body}} <-
           HTTPoison.get("https://api.linkedin.com/v2/emailAddress?q=members&projection=(elements*(handle~))", headers),
         {:ok, email_data} <- Jason.decode(email_body) do

      email = get_in(email_data, ["elements", Access.at(0), "handle~", "emailAddress"])

      formatted_profile = %{
        platform_user_id: profile["id"],
        username: profile["localizedFirstName"] <> " " <> profile["localizedLastName"],
        display_name: profile["localizedFirstName"] <> " " <> profile["localizedLastName"],
        profile_url: "https://linkedin.com/in/#{profile["id"]}",
        avatar_url: get_in(profile, ["profilePicture", "displayImage~", "elements", Access.at(-1), "identifiers", Access.at(0), "identifier"]),
        bio: profile["headline"],
        verified: false,
        email: email
      }

      {:ok, formatted_profile}
    else
      error -> {:error, "Failed to fetch LinkedIn profile: #{inspect(error)}"}
    end
  end

  defp fetch_twitter_profile(access_token) do
    headers = [{"Authorization", "Bearer #{access_token}"}]

    case HTTPoison.get("https://api.twitter.com/2/users/me?user.fields=profile_image_url,description,public_metrics,verified", headers) do
      {:ok, %{body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"data" => user}} ->
            formatted_profile = %{
              platform_user_id: user["id"],
              username: user["username"],
              display_name: user["name"],
              profile_url: "https://twitter.com/#{user["username"]}",
              avatar_url: user["profile_image_url"],
              follower_count: get_in(user, ["public_metrics", "followers_count"]),
              bio: user["description"],
              verified: user["verified"] || false
            }
            {:ok, formatted_profile}
          {:ok, response} ->
            {:error, "Unexpected Twitter API response: #{inspect(response)}"}
          {:error, reason} ->
            {:error, "Failed to parse Twitter response: #{inspect(reason)}"}
        end
      {:error, reason} ->
        {:error, "Failed to fetch Twitter profile: #{inspect(reason)}"}
    end
  end

  defp fetch_instagram_profile(access_token) do
    params = URI.encode_query(%{
      fields: "id,username,account_type,media_count",
      access_token: access_token
    })

    case HTTPoison.get("https://graph.instagram.com/me?#{params}") do
      {:ok, %{body: body}} ->
        case Jason.decode(body) do
          {:ok, user} ->
            formatted_profile = %{
              platform_user_id: user["id"],
              username: user["username"],
              display_name: user["username"],
              profile_url: "https://instagram.com/#{user["username"]}",
              avatar_url: nil, # Instagram Basic Display API doesn't provide profile pictures
              follower_count: 0, # Not available in Basic Display API
              bio: nil,
              verified: false
            }
            {:ok, formatted_profile}
          {:error, reason} ->
            {:error, "Failed to parse Instagram response: #{inspect(reason)}"}
        end
      {:error, reason} ->
        {:error, "Failed to fetch Instagram profile: #{inspect(reason)}"}
    end
  end

  defp fetch_github_profile(access_token) do
    headers = [{"Authorization", "token #{access_token}"}, {"User-Agent", "Frestyl-App"}]

    case HTTPoison.get("https://api.github.com/user", headers) do
      {:ok, %{body: body}} ->
        case Jason.decode(body) do
          {:ok, user} ->
            formatted_profile = %{
              platform_user_id: to_string(user["id"]),
              username: user["login"],
              display_name: user["name"] || user["login"],
              profile_url: user["html_url"],
              avatar_url: user["avatar_url"],
              follower_count: user["followers"],
              bio: user["bio"],
              verified: false
            }
            {:ok, formatted_profile}
          {:error, reason} ->
            {:error, "Failed to parse GitHub response: #{inspect(reason)}"}
        end
      {:error, reason} ->
        {:error, "Failed to fetch GitHub profile: #{inspect(reason)}"}
    end
  end

  defp create_or_update_integration(state_data, platform, tokens, profile) do
    portfolio_id = state_data["portfolio_id"]

    integration_attrs = %{
      portfolio_id: portfolio_id,
      platform: platform,
      platform_user_id: profile[:platform_user_id],
      username: profile[:username],
      display_name: profile[:display_name],
      profile_url: profile[:profile_url],
      avatar_url: profile[:avatar_url],
      follower_count: profile[:follower_count] || 0,
      bio: profile[:bio],
      verified: profile[:verified] || false,
      access_token: tokens["access_token"],
      refresh_token: tokens["refresh_token"],
      token_expires_at: calculate_token_expiry(tokens),
      last_sync_at: DateTime.utc_now(),
      sync_status: :active
    }

    case get_social_integration_by_platform(portfolio_id, platform) do
      nil ->
        create_social_integration(integration_attrs)
      existing_integration ->
        update_social_integration(existing_integration, integration_attrs)
    end
  end

  defp calculate_token_expiry(tokens) do
    case tokens["expires_in"] do
      nil -> nil
      seconds when is_integer(seconds) ->
        DateTime.utc_now() |> DateTime.add(seconds, :second)
      seconds when is_binary(seconds) ->
        case Integer.parse(seconds) do
          {int_seconds, _} -> DateTime.utc_now() |> DateTime.add(int_seconds, :second)
          :error -> nil
        end
    end
  end

  # ============================================================================
  # SYNC FUNCTIONS
  # ============================================================================

  def sync_all_integrations do
    SocialIntegration
    |> where([s], s.auto_sync_enabled == true and s.sync_status == :active)
    |> Repo.all()
    |> Enum.each(&sync_integration_posts/1)
  end

  def sync_integration_posts(%SocialIntegration{} = integration) do
    case fetch_recent_posts(integration) do
      {:ok, posts} ->
        Enum.each(posts, &create_or_update_social_post/1)
        delete_old_posts(integration.id, integration.max_posts)
        update_sync_status(integration, :active, nil)
      {:error, reason} ->
        update_sync_status(integration, :error, reason)
    end
  end

  defp fetch_recent_posts(%SocialIntegration{platform: :linkedin} = integration) do
    headers = [{"Authorization", "Bearer #{integration.access_token}"}]

    case HTTPoison.get("https://api.linkedin.com/v2/shares?q=owners&owners=urn:li:person:#{integration.platform_user_id}&count=#{integration.max_posts}", headers) do
      {:ok, %{body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"elements" => posts}} ->
            formatted_posts = Enum.map(posts, fn post ->
              %{
                social_integration_id: integration.id,
                platform_post_id: post["id"],
                content: get_in(post, ["specificContent", "com.linkedin.ugc.ShareContent", "shareCommentary", "text"]) || "",
                post_url: "https://linkedin.com/feed/update/#{post["id"]}",
                posted_at: parse_linkedin_timestamp(post["created"]["time"]),
                post_type: "text",
                likes_count: 0, # Would need additional API calls
                comments_count: 0,
                shares_count: 0
              }
            end)
            {:ok, formatted_posts}
          {:error, reason} ->
            {:error, "Failed to parse LinkedIn posts: #{inspect(reason)}"}
        end
      {:error, reason} ->
        {:error, "Failed to fetch LinkedIn posts: #{inspect(reason)}"}
    end
  end

  defp fetch_recent_posts(%SocialIntegration{platform: :twitter} = integration) do
    headers = [{"Authorization", "Bearer #{integration.access_token}"}]
    params = URI.encode_query(%{
      "user.fields" => "public_metrics",
      "tweet.fields" => "created_at,public_metrics,attachments",
      "max_results" => integration.max_posts
    })

    case HTTPoison.get("https://api.twitter.com/2/users/#{integration.platform_user_id}/tweets?#{params}", headers) do
      {:ok, %{body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"data" => tweets}} ->
            formatted_posts = Enum.map(tweets, fn tweet ->
              %{
                social_integration_id: integration.id,
                platform_post_id: tweet["id"],
                content: tweet["text"],
                post_url: "https://twitter.com/#{integration.username}/status/#{tweet["id"]}",
                posted_at: parse_twitter_timestamp(tweet["created_at"]),
                post_type: determine_tweet_type(tweet),
                likes_count: get_in(tweet, ["public_metrics", "like_count"]) || 0,
                comments_count: get_in(tweet, ["public_metrics", "reply_count"]) || 0,
                shares_count: get_in(tweet, ["public_metrics", "retweet_count"]) || 0
              }
            end)
            {:ok, formatted_posts}
          {:error, reason} ->
            {:error, "Failed to parse Twitter posts: #{inspect(reason)}"}
        end
      {:error, reason} ->
        {:error, "Failed to fetch Twitter posts: #{inspect(reason)}"}
    end
  end

  defp fetch_recent_posts(%SocialIntegration{platform: :instagram} = integration) do
    params = URI.encode_query(%{
      fields: "id,caption,media_type,media_url,thumbnail_url,timestamp,permalink",
      limit: integration.max_posts,
      access_token: integration.access_token
    })

    case HTTPoison.get("https://graph.instagram.com/#{integration.platform_user_id}/media?#{params}") do
      {:ok, %{body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"data" => posts}} ->
            formatted_posts = Enum.map(posts, fn post ->
              %{
                social_integration_id: integration.id,
                platform_post_id: post["id"],
                content: post["caption"] || "",
                media_urls: [post["media_url"] || post["thumbnail_url"]],
                post_url: post["permalink"],
                posted_at: parse_instagram_timestamp(post["timestamp"]),
                post_type: String.downcase(post["media_type"] || "image"),
                likes_count: 0, # Not available in Basic Display API
                comments_count: 0,
                shares_count: 0
              }
            end)
            {:ok, formatted_posts}
          {:error, reason} ->
            {:error, "Failed to parse Instagram posts: #{inspect(reason)}"}
        end
      {:error, reason} ->
        {:error, "Failed to fetch Instagram posts: #{inspect(reason)}"}
    end
  end

  defp fetch_recent_posts(%SocialIntegration{platform: :github} = integration) do
    headers = [{"Authorization", "token #{integration.access_token}"}, {"User-Agent", "Frestyl-App"}]

    case HTTPoison.get("https://api.github.com/users/#{integration.username}/events/public?per_page=#{integration.max_posts}", headers) do
      {:ok, %{body: body}} ->
        case Jason.decode(body) do
          {:ok, events} ->
            formatted_posts = events
            |> Enum.filter(&(&1["type"] in ["PushEvent", "CreateEvent", "ReleaseEvent"]))
            |> Enum.map(fn event ->
              %{
                social_integration_id: integration.id,
                platform_post_id: event["id"],
                content: format_github_event_content(event),
                post_url: format_github_event_url(event),
                posted_at: parse_github_timestamp(event["created_at"]),
                post_type: "text",
                likes_count: 0,
                comments_count: 0,
                shares_count: 0
              }
            end)
            {:ok, formatted_posts}
          {:error, reason} ->
            {:error, "Failed to parse GitHub events: #{inspect(reason)}"}
        end
      {:error, reason} ->
        {:error, "Failed to fetch GitHub events: #{inspect(reason)}"}
    end
  end

  defp create_or_update_social_post(post_attrs) do
    case Repo.get_by(SocialPost,
                     social_integration_id: post_attrs.social_integration_id,
                     platform_post_id: post_attrs.platform_post_id) do
      nil ->
        create_social_post(post_attrs)
      existing_post ->
        update_social_post(existing_post, post_attrs)
    end
  end

  defp update_sync_status(integration, status, error_message) do
    update_data = %{
      sync_status: status,
      last_sync_at: DateTime.utc_now(),
      last_error: error_message
    }

    sync_social_integration(integration, update_data)
  end

  # Helper functions for parsing timestamps and content
  defp parse_linkedin_timestamp(timestamp) when is_integer(timestamp) do
    DateTime.from_unix!(timestamp, :millisecond)
  end

  defp parse_twitter_timestamp(timestamp) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, datetime, _} -> datetime
      {:error, _} -> DateTime.utc_now()
    end
  end

  defp parse_instagram_timestamp(timestamp) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, datetime, _} -> datetime
      {:error, _} -> DateTime.utc_now()
    end
  end

  defp parse_github_timestamp(timestamp) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, datetime, _} -> datetime
      {:error, _} -> DateTime.utc_now()
    end
  end

  defp determine_tweet_type(tweet) do
    cond do
      Map.has_key?(tweet, "attachments") -> "image"
      String.contains?(tweet["text"], "http") -> "link"
      true -> "text"
    end
  end

  defp format_github_event_content(%{"type" => "PushEvent", "payload" => payload} = event) do
    commits = length(payload["commits"] || [])
    repo_name = event["repo"]["name"]
    "Pushed #{commits} commit#{if commits != 1, do: "s"} to #{repo_name}"
  end

  defp format_github_event_content(%{"type" => "CreateEvent", "payload" => payload} = event) do
    repo_name = event["repo"]["name"]
    ref_type = payload["ref_type"]
    "Created #{ref_type} in #{repo_name}"
  end

  defp format_github_event_content(%{"type" => "ReleaseEvent", "payload" => payload} = event) do
    repo_name = event["repo"]["name"]
    release_name = payload["release"]["tag_name"]
    "Released #{release_name} in #{repo_name}"
  end

  defp format_github_event_content(event) do
    "#{event["type"]} in #{event["repo"]["name"]}"
  end

  defp format_github_event_url(event) do
    "https://github.com/#{event["repo"]["name"]}"
  end

  # ============================================================================
  # ACCESS REQUEST FUNCTIONS
  # ============================================================================

  def list_portfolio_access_requests(portfolio_id) do
    AccessRequest
    |> where([r], r.portfolio_id == ^portfolio_id)
    |> order_by([r], desc: r.inserted_at)
    |> Repo.all()
  end

  def get_access_request!(id), do: Repo.get!(AccessRequest, id)

  def create_access_request(attrs \\ %{}) do
    %AccessRequest{}
    |> AccessRequest.changeset(attrs)
    |> Repo.insert()
  end

  def approve_access_request(%AccessRequest{} = request, admin_user_id, admin_response \\ nil) do
    attrs = %{
      status: :approved,
      admin_response: admin_response,
      reviewed_by_user_id: admin_user_id,
      reviewed_at: DateTime.utc_now()
    }

    request
    |> AccessRequest.approval_changeset(attrs)
    |> Repo.update()
  end

  def deny_access_request(%AccessRequest{} = request, admin_user_id, admin_response \\ nil) do
    attrs = %{
      status: :denied,
      admin_response: admin_response,
      reviewed_by_user_id: admin_user_id,
      reviewed_at: DateTime.utc_now()
    }

    request
    |> AccessRequest.approval_changeset(attrs)
    |> Repo.update()
  end

  def get_access_request_by_token(token) do
    AccessRequest
    |> where([r], r.access_token == ^token and r.status == :approved)
    |> where([r], r.expires_at > ^DateTime.utc_now())
    |> Repo.one()
  end

  # ============================================================================
  # ANALYTICS FUNCTIONS
  # ============================================================================

  def track_event(portfolio_id, event_type, event_data \\ %{}) do
    attrs = Map.merge(%{
      portfolio_id: portfolio_id,
      event_type: event_type,
      session_id: event_data[:session_id],
      visitor_id: event_data[:visitor_id] || generate_visitor_id(),
      ip_address: event_data[:ip_address],
      user_agent: event_data[:user_agent],
      referrer_url: event_data[:referrer_url],
      platform: event_data[:platform],
      device_type: detect_device_type(event_data[:user_agent]),
      browser: detect_browser(event_data[:user_agent])
    }, event_data)

    %SharingAnalytic{}
    |> SharingAnalytic.changeset(attrs)
    |> Repo.insert()
  end

  def get_portfolio_analytics(portfolio_id, date_range \\ 30) do
    start_date = DateTime.utc_now() |> DateTime.add(-date_range * 24 * 60 * 60, :second)

    base_query = from s in SharingAnalytic,
      where: s.portfolio_id == ^portfolio_id and s.inserted_at >= ^start_date

    %{
      total_views: get_total_views(base_query),
      unique_visitors: get_unique_visitors(base_query),
      social_shares: get_social_shares(base_query),
      top_referrers: get_top_referrers(base_query),
      device_breakdown: get_device_breakdown(base_query),
      daily_views: get_daily_views(base_query),
      lead_generation: get_lead_metrics(base_query)
    }
  end

  defp get_total_views(query) do
    query
    |> where([s], s.event_type == :portfolio_viewed)
    |> select([s], count(s.id))
    |> Repo.one()
  end

  defp get_unique_visitors(query) do
    query
    |> where([s], s.event_type == :portfolio_viewed)
    |> distinct([s], s.visitor_id)
    |> select([s], count(s.visitor_id))
    |> Repo.one()
  end

  defp get_social_shares(query) do
    query
    |> where([s], s.event_type == :social_share_clicked)
    |> group_by([s], s.platform)
    |> select([s], {s.platform, count(s.id)})
    |> Repo.all()
    |> Enum.into(%{})
  end

  defp get_top_referrers(query) do
    query
    |> where([s], not is_nil(s.referrer_url))
    |> group_by([s], s.referrer_url)
    |> select([s], {s.referrer_url, count(s.id)})
    |> order_by([s], desc: count(s.id))
    |> limit(10)
    |> Repo.all()
  end

  defp get_device_breakdown(query) do
    query
    |> group_by([s], s.device_type)
    |> select([s], {s.device_type, count(s.id)})
    |> Repo.all()
    |> Enum.into(%{})
  end

  defp get_daily_views(query) do
    query
    |> where([s], s.event_type == :portfolio_viewed)
    |> group_by([s], fragment("DATE(?)", s.inserted_at))
    |> select([s], {fragment("DATE(?)", s.inserted_at), count(s.id)})
    |> order_by([s], fragment("DATE(?)", s.inserted_at))
    |> Repo.all()
  end

  defp get_lead_metrics(query) do
    query
    |> where([s], s.is_potential_lead == true)
    |> group_by([s], s.conversion_action)
    |> select([s], {s.conversion_action, count(s.id), avg(s.lead_score)})
    |> Repo.all()
  end

  defp generate_visitor_id do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end

  defp detect_device_type(user_agent) when is_binary(user_agent) do
    cond do
      String.contains?(user_agent, ["Mobile", "Android", "iPhone"]) -> "mobile"
      String.contains?(user_agent, "Tablet") -> "tablet"
      true -> "desktop"
    end
  end
  defp detect_device_type(_), do: "unknown"

  defp detect_browser(user_agent) when is_binary(user_agent) do
    cond do
      String.contains?(user_agent, "Chrome") -> "chrome"
      String.contains?(user_agent, "Firefox") -> "firefox"
      String.contains?(user_agent, "Safari") -> "safari"
      String.contains?(user_agent, "Edge") -> "edge"
      true -> "other"
    end
  end
  defp detect_browser(_), do: "unknown"
end
