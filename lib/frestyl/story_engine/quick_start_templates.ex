# lib/frestyl/story_engine/quick_start_templates.ex - Enhanced Template System
defmodule Frestyl.StoryEngine.QuickStartTemplates do
  @moduledoc """
  Enhanced quick start template system with comprehensive story initialization
  """

  def get_template(format, intent) do
    templates()
    |> Map.get("#{format}_#{intent}", default_template(format))
  end

  def get_template_by_id(template_id) do
    all_templates()
    |> Enum.find(&(&1.id == template_id))
  end

  def list_templates_by_category(category) do
    all_templates()
    |> Enum.filter(&(&1.category == category))
  end

  defp templates do
    %{
      # Novel Templates
      "novel_creative_expression" => %{
        id: "novel_hero_journey",
        title: "Untitled Novel",
        format: "novel",
        intent: "creative_expression",
        category: "Creative",
        description: "Epic storytelling with the classic hero's journey structure",
        sections: [
          %{id: 1, type: "chapter", title: "Chapter 1: The Ordinary World", content: "", order: 1},
          %{id: 2, type: "chapter", title: "Chapter 2: The Call to Adventure", content: "", order: 2},
          %{id: 3, type: "chapter", title: "Chapter 3: Refusal of the Call", content: "", order: 3}
        ],
        outline: %{
          structure: "hero_journey",
          beats: [
            %{title: "Ordinary World", description: "Establish the hero's normal life"},
            %{title: "Call to Adventure", description: "The inciting incident"},
            %{title: "Refusal of the Call", description: "Hero hesitates"},
            %{title: "Meeting the Mentor", description: "Wise guidance appears"},
            %{title: "Crossing the Threshold", description: "Point of no return"},
            %{title: "Tests and Trials", description: "Challenges in the new world"},
            %{title: "Ordeal", description: "The greatest fear"},
            %{title: "Reward", description: "Success and growth"},
            %{title: "The Road Back", description: "Return journey begins"},
            %{title: "Resurrection", description: "Final test"},
            %{title: "Return with Elixir", description: "Hero transformed"}
          ]
        },
        character_data: %{
          characters: [
            %{
              id: 1,
              name: "Protagonist",
              role: "hero",
              description: "The main character on their journey",
              arc: "transformation"
            }
          ]
        },
        estimated_time: "3-6 months",
        target_word_count: 80000,
        ai_prompts: [
          "What makes your hero unique?",
          "What ordinary world will they leave behind?",
          "What call to adventure will change everything?"
        ]
      },

      # Screenplay Templates
      "screenplay_creative_expression" => %{
        id: "screenplay_three_act",
        title: "Untitled Screenplay",
        format: "screenplay",
        intent: "creative_expression",
        category: "Creative",
        description: "Professional screenplay with three-act structure",
        sections: [
          %{id: 1, type: "scene", title: "Scene 1", content: "FADE IN:\n\nEXT. LOCATION - DAY\n\n", order: 1}
        ],
        outline: %{
          structure: "three_act",
          acts: [
            %{
              title: "Act I - Setup",
              pages: "1-30",
              description: "Establish world, characters, and inciting incident",
              scenes: ["Opening Image", "Setup", "Inciting Incident", "Plot Point 1"]
            },
            %{
              title: "Act II - Confrontation",
              pages: "30-90",
              description: "Rising action, obstacles, and character development",
              scenes: ["Rising Action", "Midpoint", "All Is Lost", "Plot Point 2"]
            },
            %{
              title: "Act III - Resolution",
              pages: "90-120",
              description: "Climax and resolution",
              scenes: ["Climax", "Falling Action", "Resolution"]
            }
          ]
        },
        character_data: %{
          characters: [
            %{
              id: 1,
              name: "PROTAGONIST",
              description: "Main character driving the story",
              voice: "Determined, witty"
            }
          ]
        },
        format_metadata: %{
          page_count_target: 120,
          genre: "Drama",
          logline: ""
        },
        estimated_time: "2-4 months",
        ai_prompts: [
          "What's your logline in one sentence?",
          "Who is your protagonist and what do they want?",
          "What's the central conflict?"
        ]
      },

      # Case Study Templates
      "case_study_business_growth" => %{
        id: "case_study_problem_solution",
        title: "Business Case Study",
        format: "case_study",
        intent: "business_growth",
        category: "Business",
        description: "Professional case study with proven problem-solution structure",
        sections: [
          %{id: 1, type: "summary", title: "Executive Summary", content: "", order: 1},
          %{id: 2, type: "problem", title: "Problem Statement", content: "", order: 2},
          %{id: 3, type: "solution", title: "Solution Approach", content: "", order: 3},
          %{id: 4, type: "results", title: "Results & Impact", content: "", order: 4},
          %{id: 5, type: "lessons", title: "Lessons Learned", content: "", order: 5}
        ],
        outline: %{
          structure: "problem_solution",
          framework: [
            %{section: "Executive Summary", questions: ["What was achieved?", "What was the impact?"]},
            %{section: "Problem Statement", questions: ["What challenge did you face?", "Why was it important?"]},
            %{section: "Solution Approach", questions: ["How did you solve it?", "What was your methodology?"]},
            %{section: "Results & Impact", questions: ["What were the outcomes?", "How do you measure success?"]},
            %{section: "Lessons Learned", questions: ["What would you do differently?", "What advice would you give?"]}
          ]
        },
        format_metadata: %{
          stakeholders: [],
          metrics: [],
          timeline: %{},
          budget_impact: ""
        },
        estimated_time: "2-4 hours",
        target_word_count: 2500,
        ai_prompts: [
          "What business problem were you solving?",
          "What was your approach or methodology?",
          "What measurable results did you achieve?"
        ]
      },

      # Article Templates
      "article_personal_professional" => %{
        id: "article_thought_leadership",
        title: "Untitled Article",
        format: "article",
        intent: "personal_professional",
        category: "Professional",
        description: "Thought leadership article to establish expertise",
        sections: [
          %{id: 1, type: "introduction", title: "Introduction", content: "", order: 1},
          %{id: 2, type: "main_point", title: "Main Point", content: "", order: 2},
          %{id: 3, type: "conclusion", title: "Conclusion", content: "", order: 3}
        ],
        outline: %{
          structure: "persuasive",
          elements: [
            %{title: "Hook", description: "Attention-grabbing opening"},
            %{title: "Thesis", description: "Your main argument or insight"},
            %{title: "Supporting Points", description: "Evidence and examples"},
            %{title: "Call to Action", description: "What should readers do?"}
          ]
        },
        format_metadata: %{
          target_audience: "",
          publication_goals: [],
          seo_keywords: []
        },
        estimated_time: "2-4 hours",
        target_word_count: 1500,
        ai_prompts: [
          "What unique insight do you want to share?",
          "Who is your target audience?",
          "What action should readers take?"
        ]
      },

      # Live Story Templates
      "live_story_experimental" => %{
        id: "live_story_interactive",
        title: "Interactive Live Story",
        format: "live_story",
        intent: "experimental",
        category: "Experimental",
        description: "Real-time interactive storytelling with audience participation",
        sections: [
          %{id: 1, type: "setup", title: "Story Setup", content: "", order: 1},
          %{id: 2, type: "choice_point", title: "First Choice", content: "", order: 2}
        ],
        outline: %{
          structure: "branching_narrative",
          choice_points: [
            %{
              id: 1,
              prompt: "What should the character do?",
              options: ["Option A", "Option B"],
              consequences: %{}
            }
          ]
        },
        format_metadata: %{
          streaming_platform: "",
          audience_size_limit: 100,
          interaction_mode: "voting",
          session_duration: "60 minutes"
        },
        estimated_time: "1-2 hours prep + live session",
        ai_prompts: [
          "What's your story premise?",
          "What choices will you give the audience?",
          "How will different paths affect the story?"
        ]
      }
    }
  end

  defp all_templates do
    templates()
    |> Map.values()
    |> Enum.concat(additional_templates())
  end

  defp additional_templates do
    [
      # Popular Templates
      %{
        id: "memoir_personal",
        name: "Personal Memoir",
        description: "Share your life story with rich detail and emotional depth",
        category: "Personal",
        icon: "📖",
        gradient: "bg-gradient-to-br from-green-500 to-teal-500",
        estimated_time: "1-3 months",
        sections_count: 8,
        format: "memoir",
        intent: "personal_professional"
      },
      %{
        id: "marketing_story_business",
        name: "Marketing Story",
        description: "Compelling brand narrative that converts",
        category: "Business",
        icon: "📈",
        gradient: "bg-gradient-to-br from-green-500 to-emerald-500",
        estimated_time: "1-2 hours",
        sections_count: 5,
        format: "marketing_story",
        intent: "business_growth"
      },
      %{
        id: "short_story_creative",
        name: "Short Story",
        description: "Complete narrative in under 5,000 words",
        category: "Creative",
        icon: "📝",
        gradient: "bg-gradient-to-br from-purple-500 to-pink-500",
        estimated_time: "2-6 hours",
        sections_count: 3,
        format: "short_story",
        intent: "creative_expression"
      }
    ]
  end

  defp default_template(format) do
    %{
      id: "default_#{format}",
      title: "New #{String.capitalize(format)}",
      format: format,
      intent: "general",
      category: "General",
      description: "Basic template for #{format}",
      sections: [
        %{id: 1, type: "section", title: "Getting Started", content: "", order: 1}
      ],
      outline: %{structure: "basic"},
      estimated_time: "varies",
      ai_prompts: ["What story do you want to tell?"]
    }
  end
end
