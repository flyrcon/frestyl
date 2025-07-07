# test/frestyl/features/tier_manager_test.exs
defmodule Frestyl.Features.TierManagerTest do
  use ExUnit.Case, async: true

  alias Frestyl.Features.TierManager

  describe "normalize_tier/1" do
    test "normalizes legacy string tiers" do
      assert TierManager.normalize_tier("free") == "personal"
      assert TierManager.normalize_tier("basic") == "personal"
      assert TierManager.normalize_tier("premium") == "professional"
      assert TierManager.normalize_tier("pro") == "creator"
      assert TierManager.normalize_tier("storyteller") == "creator"
      assert TierManager.normalize_tier("business") == "enterprise"
    end

    test "normalizes legacy atom tiers" do
      assert TierManager.normalize_tier(:free) == "personal"
      assert TierManager.normalize_tier(:premium) == "professional"
      assert TierManager.normalize_tier(:storyteller) == "creator"
    end

    test "preserves unified tier names" do
      assert TierManager.normalize_tier("personal") == "personal"
      assert TierManager.normalize_tier("creator") == "creator"
      assert TierManager.normalize_tier("professional") == "professional"
      assert TierManager.normalize_tier("enterprise") == "enterprise"
    end

    test "handles invalid input" do
      assert TierManager.normalize_tier(nil) == "personal"
      assert TierManager.normalize_tier("invalid") == "personal"
      assert TierManager.normalize_tier(123) == "personal"
    end
  end

  describe "tier_priority/1" do
    test "returns correct priority order" do
      assert TierManager.tier_priority("personal") == 0
      assert TierManager.tier_priority("creator") == 1
      assert TierManager.tier_priority("professional") == 2
      assert TierManager.tier_priority("enterprise") == 3
    end

    test "handles legacy tiers through normalization" do
      assert TierManager.tier_priority("free") == 0  # normalizes to personal
      assert TierManager.tier_priority("pro") == 1   # normalizes to creator
    end
  end

  describe "has_tier_access?/2" do
    test "allows access to same or lower tier features" do
      assert TierManager.has_tier_access?("professional", "personal") == true
      assert TierManager.has_tier_access?("professional", "creator") == true
      assert TierManager.has_tier_access?("professional", "professional") == true
      assert TierManager.has_tier_access?("professional", "enterprise") == false
    end
  end

  describe "feature_available?/2" do
    test "returns correct feature availability" do
      assert TierManager.feature_available?("personal", :real_time_collaboration) == false
      assert TierManager.feature_available?("creator", :real_time_collaboration) == true
      assert TierManager.feature_available?("personal", :service_booking) == false
      assert TierManager.feature_available?("creator", :service_booking) == true
      assert TierManager.feature_available?("creator", :white_label) == false
      assert TierManager.feature_available?("enterprise", :white_label) == true
    end
  end

  describe "get_upgrade_suggestion/2" do
    test "suggests appropriate upgrades" do
      suggestion = TierManager.get_upgrade_suggestion("personal", :real_time_collaboration)
      assert suggestion.suggested_tier == "creator"
      assert String.contains?(suggestion.reason, "Creator tier")
    end

    test "returns nil for already available features" do
      suggestion = TierManager.get_upgrade_suggestion("enterprise", :real_time_collaboration)
      assert suggestion == nil
    end
  end
end
