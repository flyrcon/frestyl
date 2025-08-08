# test/frestyl/story_engine/ai_integration_test.exs
defmodule Frestyl.StoryEngine.AIIntegrationTest do
  use Frestyl.DataCase

  alias Frestyl.StoryEngine.AIIntegration

  describe "AI integration features" do
    test "generate_writing_suggestions returns format-specific suggestions" do
      novel_suggestions = AIIntegration.generate_writing_suggestions("novel", "Character walked into room.", %{})
      case_study_suggestions = AIIntegration.generate_writing_suggestions("case_study", "Problem occurred.", %{})

      # Should return different suggestions for different formats
      assert length(novel_suggestions) > 0
      assert length(case_study_suggestions) > 0
      assert novel_suggestions != case_study_suggestions
    end

    test "suggest_story_structure enhances base template" do
      enhanced_template = AIIntegration.suggest_story_structure("novel", "sci-fi adventure story")

      assert Map.has_key?(enhanced_template, :outline)
      assert length(enhanced_template.outline) > 0

      # Should have AI-enhanced prompts
      first_section = hd(enhanced_template.outline)
      assert Map.has_key?(first_section, :ai_enhanced_prompts)
    end

    test "generate_content_prompts returns format-specific prompts" do
      novel_prompts = AIIntegration.generate_content_prompts("novel", "character_development")
      case_study_prompts = AIIntegration.generate_content_prompts("case_study", "challenge")

      assert length(novel_prompts) > 0
      assert length(case_study_prompts) > 0

      # Novel prompts should mention character
      assert Enum.any?(novel_prompts, &String.contains?(&1, "character"))

      # Case study prompts should be business-focused
      assert Enum.any?(case_study_prompts, &String.contains?(&1, "problem"))
    end

    test "analyze_writing_quality returns comprehensive analysis" do
      content = "This is a well-written example with good structure. It has examples and asks questions? The content flows nicely."
      analysis = AIIntegration.analyze_writing_quality(content, "article")

      assert Map.has_key?(analysis, :readability_score)
      assert Map.has_key?(analysis, :structure_score)
      assert Map.has_key?(analysis, :engagement_score)
      assert Map.has_key?(analysis, :suggestions)

      assert is_number(analysis.readability_score)
      assert analysis.readability_score >= 0 and analysis.readability_score <= 100
    end

    test "suggest_collaboration_partners returns format-appropriate suggestions" do
      novel_partners = AIIntegration.suggest_collaboration_partners("story_1", "user_1", "novel")
      screenplay_partners = AIIntegration.suggest_collaboration_partners("story_2", "user_2", "screenplay")

      novel_types = Enum.map(novel_partners, & &1.type)
      screenplay_types = Enum.map(screenplay_partners, & &1.type)

      # Novel should suggest editors and beta readers
      assert "editor" in novel_types
      assert "beta_reader" in novel_types

      # Screenplay should suggest script doctors and producers
      assert "script_doctor" in screenplay_types
      assert "producer" in screenplay_types
    end

    test "readability calculation works for different content lengths" do
      short_content = "Short."
      medium_content = "This is a medium-length sentence with good readability."
      long_content = "This is a very long sentence that goes on and on with many clauses and subclauses that make it difficult to read and understand."

      short_score = AIIntegration.calculate_readability(short_content)
      medium_score = AIIntegration.calculate_readability(medium_content)
      long_score = AIIntegration.calculate_readability(long_content)

      # Medium content should score higher than very long content
      assert medium_score > long_score
      assert short_score >= 0
    end

    test "structure analysis detects case study elements" do
      good_case_study = "The challenge was significant. Our solution involved innovation. The results were impressive."
      poor_case_study = "We did some work and things happened."

      good_score = AIIntegration.analyze_structure(good_case_study, "case_study")
      poor_score = AIIntegration.analyze_structure(poor_case_study, "case_study")

      assert good_score > poor_score
      assert good_score >= 70  # Should detect challenge, solution, results
    end

    test "engagement calculation considers multiple factors" do
      engaging_content = "What makes great content? Here's an example: clear writing that asks questions and provides specific examples."
      boring_content = "Content is good."

      engaging_score = AIIntegration.calculate_engagement(engaging_content)
      boring_score = AIIntegration.calculate_engagement(boring_content)

      assert engaging_score > boring_score
    end

    test "improvement suggestions are helpful and actionable" do
      short_content = "Too short."
      suggestions = AIIntegration.generate_improvement_suggestions(short_content, "article")

      assert length(suggestions) > 0
      assert Enum.any?(suggestions, &String.contains?(&1, "detail"))
    end

    test "personalized prompts adjust for experience level" do
      base_prompts = ["What's your main character's motivation?"]

      beginner_prompts = AIIntegration.personalize_prompts(base_prompts, %{experience_level: "beginner"})
      expert_prompts = AIIntegration.personalize_prompts(base_prompts, %{experience_level: "expert"})

      assert Enum.any?(beginner_prompts, &String.contains?(&1, "personal experience"))
      assert Enum.any?(expert_prompts, &String.contains?(&1, "perspectives"))
    end
  end
end
