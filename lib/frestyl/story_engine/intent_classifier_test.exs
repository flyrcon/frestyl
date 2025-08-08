# test/frestyl/story_engine/intent_classifier_test.exs
defmodule Frestyl.StoryEngine.IntentClassifierTest do
  use Frestyl.DataCase

  alias Frestyl.StoryEngine.IntentClassifier

  describe "intent classification" do
    test "returns correct formats for personal intent" do
      formats = IntentClassifier.get_formats_for_intent("personal_professional")

      assert "biography" in formats
      assert "professional_portfolio" in formats
      assert "article" in formats
    end

    test "filters intents by user tier" do
      personal_intents = IntentClassifier.get_intents_for_user_tier("personal")
      professional_intents = IntentClassifier.get_intents_for_user_tier("professional")

      # Personal tier should not see experimental formats
      refute Map.has_key?(personal_intents, "experimental")

      # Professional tier should see all intents including experimental
      assert Map.has_key?(professional_intents, "experimental")
    end

    test "suggests appropriate intent based on user history" do
      user_preferences = %{recent_intents: ["business_growth", "personal_professional"]}

      suggested = IntentClassifier.suggest_intent_based_on_history(user_preferences)
      assert suggested == "business_growth"
    end

    test "returns recommended formats filtered by tier access" do
      formats = IntentClassifier.get_recommended_formats("creator", "creative_expression")

      # Should include creator-accessible formats
      assert "novel" in formats
      assert "screenplay" in formats

      # Should not include professional-only formats like live_story
      refute "live_story" in formats
    end

    test "returns empty list for unknown intent" do
      formats = IntentClassifier.get_formats_for_intent("unknown_intent")
      assert formats == []
    end

    test "get_intent returns correct intent configuration" do
      intent = IntentClassifier.get_intent("personal_professional")

      assert intent.name == "Share Your Story"
      assert intent.description =~ "Personal narratives"
      assert intent.icon == "👤"
      assert intent.tier_required == "personal"
    end

    test "get_intent returns nil for unknown intent" do
      intent = IntentClassifier.get_intent("unknown_intent")
      assert intent == nil
    end

    test "get_all_intents returns all available intents" do
      all_intents = IntentClassifier.get_all_intents()

      assert Map.has_key?(all_intents, "personal_professional")
      assert Map.has_key?(all_intents, "business_growth")
      assert Map.has_key?(all_intents, "creative_expression")
      assert Map.has_key?(all_intents, "experimental")
    end

    test "creator tier has access to creative and business intents" do
      creator_intents = IntentClassifier.get_intents_for_user_tier("creator")

      assert Map.has_key?(creator_intents, "personal_professional")
      assert Map.has_key?(creator_intents, "business_growth")
      assert Map.has_key?(creator_intents, "creative_expression")
      # Should not have experimental (requires professional)
      refute Map.has_key?(creator_intents, "experimental")
    end

    test "enterprise tier has access to all intents" do
      enterprise_intents = IntentClassifier.get_intents_for_user_tier("enterprise")

      assert Map.has_key?(enterprise_intents, "personal_professional")
      assert Map.has_key?(enterprise_intents, "business_growth")
      assert Map.has_key?(enterprise_intents, "creative_expression")
      assert Map.has_key?(enterprise_intents, "experimental")
    end

    test "handles user history for format recommendations" do
      user_history = ["novel", "screenplay"]
      formats = IntentClassifier.get_recommended_formats("creator", "creative_expression", user_history)

      # Should prioritize formats from history
      assert List.first(formats) in user_history
    end

    test "suggests default intent for new users" do
      empty_preferences = %{recent_intents: []}

      suggested = IntentClassifier.suggest_intent_based_on_history(empty_preferences)
      assert suggested == "personal_professional"
    end
  end
end
