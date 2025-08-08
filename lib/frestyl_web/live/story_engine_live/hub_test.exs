# test/frestyl_web/live/story_engine_live/hub_test.exs

defmodule FrestylWeb.StoryEngineLive.HubTest do
  use FrestylWeb.ConnCase

  import Phoenix.LiveViewTest
  import Frestyl.AccountsFixtures
  import Frestyl.StoriesFixtures

  describe "Story Engine Hub" do
    setup do
      user = user_fixture()
      %{user: user}
    end

    test "displays story engine interface for authenticated user", %{conn: conn, user: user} do
      {:ok, view, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/story-engine")

      assert html =~ "Story Engine"
      assert html =~ "What's your story goal?"
      assert has_element?(view, ".intent-category")
    end

    test "shows intent-based format selection", %{conn: conn, user: user} do
      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/story-engine")

      # Select business intent
      view |> element(".intent-category[phx-value-intent='business_growth']") |> render_click()

      # Should show business-related formats
      assert has_element?(view, "[phx-value-format='case_study']")
      assert has_element?(view, "[phx-value-format='data_story']")
    end

    test "creates story from format selection", %{conn: conn, user: user} do
      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/story-engine")

      # Click on biography format
      view |> element("[phx-value-format='biography']") |> render_click()

      # Should redirect to story editor
      assert_redirected(view, ~p"/stories/#{story_id}/edit")
    end

    test "shows upgrade modal for premium formats", %{conn: conn, user: user} do
      # User with personal tier trying to access professional format
      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/story-engine")

      # Try to access professional-tier format
      view |> element("[phx-value-format='live_story']") |> render_click()

      # Should show upgrade modal
      assert_push_event(view, "show_upgrade_modal", %{required_tier: "professional"})
    end

    test "tracks user preferences", %{conn: conn, user: user} do
      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/story-engine")

      # Select intent and create story
      view |> element(".intent-category[phx-value-intent='creative_expression']") |> render_click()
      view |> element("[phx-value-format='novel']") |> render_click()

      # Check that preferences were tracked
      preferences = Frestyl.StoryEngine.UserPreferences.get_or_create_preferences(user.id)
      assert "creative_expression" in preferences.recent_intents
      assert preferences.format_usage_stats["novel"] == 1
    end
  end
end
