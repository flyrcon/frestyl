# lib/frestyl/story_engine/quick_start_templates.ex
defmodule Frestyl.StoryEngine.QuickStartTemplates do
  @moduledoc """
  Provides quick start templates for different story formats and intents.
  """

  def get_template(format, intent) do
    case {format, intent} do
      {"biography", "personal_professional"} ->
        %{
          title: "My Story",
          subtitle: "A personal journey",
          outline: [
            %{
              title: "Early Years",
              content: "Where did your story begin?",
              prompts: [
                "What's your earliest meaningful memory?",
                "How did your family shape you?",
                "What dreams did you have as a child?"
              ],
              estimated_words: 500
            },
            %{
              title: "Turning Points",
              content: "What moments changed everything?",
              prompts: [
                "When did you first face real adversity?",
                "What decision changed your life's direction?",
                "Who were the people who influenced you most?"
              ],
              estimated_words: 750
            },
            %{
              title: "Current Chapter",
              content: "Where are you now?",
              prompts: [
                "What are you most proud of today?",
                "What lessons have you learned?",
                "Where do you see yourself heading?"
              ],
              estimated_words: 500
            }
          ],
          writing_tips: [
            "Start with a specific moment, not general statements",
            "Show, don't tell - use concrete examples",
            "Include dialogue and sensory details"
          ],
          collaboration_suggestions: [
            "Invite family members to add their perspectives",
            "Share drafts with friends for feedback",
            "Consider interviewing key people from your life"
          ]
        }

      {"case_study", "business_growth"} ->
        %{
          title: "Project Success Story",
          subtitle: "Demonstrating business impact",
          outline: [
            %{
              title: "The Challenge",
              content: "What problem needed solving?",
              prompts: [
                "What was the business impact of this problem?",
                "Who were the stakeholders affected?",
                "What had been tried before?"
              ],
              estimated_words: 400
            },
            %{
              title: "Our Approach",
              content: "How did you tackle it?",
              prompts: [
                "What made your solution unique?",
                "What resources did you need?",
                "What obstacles did you overcome?"
              ],
              estimated_words: 600
            },
            %{
              title: "Results & Impact",
              content: "What changed?",
              prompts: [
                "What were the measurable outcomes?",
                "How did stakeholders benefit?",
                "What would you do differently?"
              ],
              estimated_words: 400
            }
          ],
          data_suggestions: [
            "Include before/after metrics",
            "Add stakeholder quotes",
            "Show visual progress charts"
          ],
          collaboration_suggestions: [
            "Get input from project team members",
            "Interview beneficiaries",
            "Have leadership review for accuracy"
          ]
        }

      {"novel", "creative_expression"} ->
        %{
          title: "Untitled Novel",
          subtitle: "A new story waiting to unfold",
          outline: [
            %{
              title: "Opening Hook",
              content: "Draw readers into your world",
              prompts: [
                "What's happening at the most dramatic moment?",
                "Who is your protagonist and what do they want?",
                "What's at stake from the very beginning?"
              ],
              estimated_words: 2000
            },
            %{
              title: "Character Development",
              content: "Bring your characters to life",
              prompts: [
                "What does your protagonist fear most?",
                "How do supporting characters challenge the main character?",
                "What secrets are your characters hiding?"
              ],
              estimated_words: 5000
            },
            %{
              title: "Plot Development",
              content: "Build tension and conflict",
              prompts: [
                "What obstacles prevent your character from getting what they want?",
                "When does everything fall apart?",
                "How do characters change through adversity?"
              ],
              estimated_words: 15000
            }
          ],
          writing_tips: [
            "Write every day, even if it's just 250 words",
            "Don't edit as you go - finish the first draft first",
            "Read your dialogue out loud to test if it sounds natural"
          ],
          collaboration_suggestions: [
            "Join a writers' critique group",
            "Find a writing partner for accountability",
            "Share chapters with beta readers"
          ]
        }

      {"live_story", "experimental"} ->
        %{
          title: "Live Story Session",
          subtitle: "Real-time collaborative storytelling",
          outline: [
            %{
              title: "Story Setup",
              content: "Establish the world and initial situation",
              prompts: [
                "What's the setting and time period?",
                "Who are the main characters?",
                "What's the initial conflict or question?"
              ],
              live_features: ["audience_polling", "real_time_suggestions", "character_voting"]
            },
            %{
              title: "Interactive Development",
              content: "Let the audience guide the story",
              prompts: [
                "What should happen next?",
                "Which character should we follow?",
                "How should they solve this problem?"
              ],
              live_features: ["branching_choices", "audience_input", "live_reactions"]
            },
            %{
              title: "Collaborative Resolution",
              content: "Bring the story to a satisfying conclusion",
              prompts: [
                "How do we want this to end?",
                "What did we learn together?",
                "What story should we tell next?"
              ],
              live_features: ["collective_ending", "story_archive", "community_feedback"]
            }
          ],
          technical_requirements: [
            "Stable internet connection",
            "Microphone for narration",
            "Screen sharing capability"
          ],
          collaboration_features: [
            "Live audience chat",
            "Real-time story branching",
            "Audience voting on plot points"
          ]
        }

      {format, intent} ->
        # Fallback template for unknown combinations
        %{
          title: "New #{String.capitalize(format)}",
          subtitle: "Created with Story Engine",
          outline: [
            %{
              title: "Getting Started",
              content: "Begin your #{format} here",
              prompts: ["What's your main idea?", "Who is your audience?", "What's your goal?"],
              estimated_words: 500
            }
          ],
          writing_tips: ["Start with what you know", "Write regularly", "Get feedback early"],
          collaboration_suggestions: ["Share with trusted reviewers", "Join relevant communities"]
        }
    end
  end

  def get_ai_prompts(format, section) do
    case {format, section} do
      {"biography", "early_years"} ->
        [
          "Help me brainstorm significant childhood memories",
          "Suggest ways to describe my family background",
          "What details would make this section more engaging?"
        ]

      {"case_study", "challenge"} ->
        [
          "Help me quantify the business impact of this problem",
          "What context should I provide about the industry?",
          "How can I make the stakes feel urgent?"
        ]

      {"novel", "character_development"} ->
        [
          "Help me develop my protagonist's backstory",
          "Suggest character flaws that create conflict",
          "What motivations would drive this character?"
        ]

      _ ->
        [
          "Help me brainstorm ideas for this section",
          "Suggest ways to improve clarity and flow",
          "What details would strengthen this part?"
        ]
    end
  end
end
