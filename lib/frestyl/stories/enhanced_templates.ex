# lib/frestyl/stories/enhanced_templates.ex
defmodule Frestyl.Stories.EnhancedTemplates do
  @moduledoc """
  Comprehensive story template system supporting novels, screenplays, comics,
  customer stories, and visual storyboards with AI integration.
  """

  def get_template(story_type, narrative_structure) do
    enhanced_templates()
    |> Map.get(story_type, %{})
    |> Map.get(narrative_structure, default_template())
  end

  def get_all_story_types do
    Map.keys(enhanced_templates())
  end

  def get_structures_for_type(story_type) do
    enhanced_templates()
    |> Map.get(story_type, %{})
    |> Map.keys()
  end

  def enhanced_templates do
    %{
      # EXISTING TEMPLATES (Enhanced)
      personal_narrative: %{
        chronological: personal_chronological_template(),
        hero_journey: enhanced_hero_journey_template()
      },

      professional_showcase: %{
        chronological: professional_chronological_template(),
        skills_first: skills_first_template()
      },

      case_study: %{
        problem_solution: problem_solution_template(),
        before_after: before_after_template()
      },

      creative_portfolio: %{
        artistic: artistic_template()
      },

      # NEW NOVEL WRITING TEMPLATES
      novel: %{
        three_act: novel_three_act_template(),
        hero_journey: novel_hero_journey_template(),
        seven_point: novel_seven_point_template(),
        character_driven: character_driven_novel_template(),
        mystery: mystery_novel_template(),
        romance: romance_novel_template(),
        sci_fi_fantasy: sci_fi_fantasy_template()
      },

      # SCREENPLAY TEMPLATES
      screenplay: %{
        feature_film: feature_screenplay_template(),
        short_film: short_screenplay_template(),
        tv_episode: tv_episode_template(),
        web_series: web_series_template(),
        documentary: documentary_template()
      },

      # COMIC BOOK TEMPLATES
      comic_book: %{
        single_issue: single_issue_comic_template(),
        story_arc: story_arc_comic_template(),
        graphic_novel: graphic_novel_template(),
        webcomic: webcomic_template()
      },

      # CUSTOMER EXPERIENCE TEMPLATES
      customer_story: %{
        journey_map: customer_journey_template(),
        testimonial: customer_testimonial_template(),
        case_study: customer_case_study_template(),
        success_story: customer_success_template()
      },

      # VISUAL STORYBOARD TEMPLATES
      storyboard: %{
        film_sequence: film_storyboard_template(),
        animation: animation_storyboard_template(),
        commercial: commercial_storyboard_template(),
        music_video: music_video_storyboard_template()
      }
    }
  end

  # PERSONAL NARRATIVE TEMPLATES
  defp personal_chronological_template do
    %{
      name: "Personal Story - Chronological",
      description: "Tell your story in chronological order with life milestones",
      story_type: :personal_narrative,
      narrative_structure: "chronological",
      requires_tier: nil,
      features: [:timeline, :photo_integration, :audio_recording],
      chapters: [
        %{
          title: "Early Years",
          type: :life_stage,
          purpose: :foundation,
          suggested_content: "Childhood memories, family background, formative experiences"
        },
        %{
          title: "Coming of Age",
          type: :life_stage,
          purpose: :development,
          suggested_content: "School years, first challenges, discovering identity"
        },
        %{
          title: "The Journey",
          type: :life_stage,
          purpose: :growth,
          suggested_content: "Career, relationships, major life decisions"
        },
        %{
          title: "Where I Am Now",
          type: :life_stage,
          purpose: :reflection,
          suggested_content: "Current perspective, lessons learned, future hopes"
        }
      ]
    }
  end

  defp enhanced_hero_journey_template do
    %{
      name: "Personal Hero's Journey",
      description: "Frame your life story as a transformative adventure",
      story_type: :personal_narrative,
      narrative_structure: "hero_journey",
      requires_tier: "creator",
      features: [:character_development, :transformation_tracking, :ai_suggestions],
      chapters: [
        %{
          title: "Ordinary World",
          type: :hero_stage,
          purpose: :setup,
          description: "Your life before the big change",
          guidance: "Describe your normal routine, comfort zone, and what you took for granted"
        },
        %{
          title: "The Call",
          type: :hero_stage,
          purpose: :catalyst,
          description: "The moment everything changed",
          guidance: "What opportunity, challenge, or realization disrupted your normal life?"
        },
        %{
          title: "Crossing the Threshold",
          type: :hero_stage,
          purpose: :commitment,
          description: "Taking the leap into the unknown",
          guidance: "The moment you decided to embrace change despite your fears"
        },
        %{
          title: "Tests and Trials",
          type: :hero_stage,
          purpose: :challenges,
          description: "The obstacles you faced",
          guidance: "What difficulties tested your resolve? Who helped or hindered you?"
        },
        %{
          title: "The Transformation",
          type: :hero_stage,
          purpose: :climax,
          description: "Your moment of greatest growth",
          guidance: "When did you realize you had fundamentally changed?"
        },
        %{
          title: "Return with Wisdom",
          type: :hero_stage,
          purpose: :resolution,
          description: "How you've applied your growth",
          guidance: "What wisdom do you now share? How do you help others on their journey?"
        }
      ]
    }
  end

  # PROFESSIONAL SHOWCASE TEMPLATES
  defp professional_chronological_template do
    %{
      name: "Professional Journey",
      description: "Showcase your career progression and achievements",
      story_type: :professional_showcase,
      narrative_structure: "chronological",
      requires_tier: nil,
      features: [:portfolio_integration, :achievement_tracking, :skills_mapping],
      chapters: [
        %{
          title: "Getting Started",
          type: :career_stage,
          purpose: :foundation,
          suggested_content: "Education, first jobs, early learning experiences"
        },
        %{
          title: "Building Skills",
          type: :career_stage,
          purpose: :development,
          suggested_content: "Key projects, skill development, mentors and influences"
        },
        %{
          title: "Major Achievements",
          type: :career_stage,
          purpose: :highlights,
          suggested_content: "Breakthrough projects, leadership roles, recognition"
        },
        %{
          title: "Current Focus",
          type: :career_stage,
          purpose: :present,
          suggested_content: "Current role, expertise, what drives you now"
        },
        %{
          title: "Looking Forward",
          type: :career_stage,
          purpose: :vision,
          suggested_content: "Goals, aspirations, how others can connect with you"
        }
      ]
    }
  end

  defp skills_first_template do
    %{
      name: "Skills-First Portfolio",
      description: "Lead with your technical capabilities and expertise",
      story_type: :professional_showcase,
      narrative_structure: "skills_first",
      requires_tier: nil,
      features: [:skills_showcase, :project_highlights, :technical_demos],
      chapters: [
        %{
          title: "Core Expertise",
          type: :skills_section,
          purpose: :competency,
          suggested_content: "Your strongest technical skills and specializations"
        },
        %{
          title: "Project Showcase",
          type: :portfolio_section,
          purpose: :demonstration,
          suggested_content: "Key projects that demonstrate your skills in action"
        },
        %{
          title: "Problem-Solving Approach",
          type: :methodology_section,
          purpose: :process,
          suggested_content: "How you approach challenges and deliver solutions"
        },
        %{
          title: "Professional Background",
          type: :experience_section,
          purpose: :credibility,
          suggested_content: "Career history and educational background"
        },
        %{
          title: "Let's Work Together",
          type: :contact_section,
          purpose: :call_to_action,
          suggested_content: "How to hire you or collaborate with you"
        }
      ]
    }
  end

  # CASE STUDY TEMPLATES
  defp problem_solution_template do
    %{
      name: "Problem → Solution Case Study",
      description: "Document how you solved a specific challenge",
      story_type: :case_study,
      narrative_structure: "problem_solution",
      requires_tier: nil,
      features: [:metrics_tracking, :before_after, :methodology],
      chapters: [
        %{
          title: "The Challenge",
          type: :problem_definition,
          purpose: :context,
          suggested_content: "What problem needed solving? Why was it important?"
        },
        %{
          title: "Research & Analysis",
          type: :investigation,
          purpose: :understanding,
          suggested_content: "How did you understand the problem? What did you discover?"
        },
        %{
          title: "Solution Design",
          type: :solution_development,
          purpose: :approach,
          suggested_content: "What solution did you design? What were your key decisions?"
        },
        %{
          title: "Implementation",
          type: :execution,
          purpose: :action,
          suggested_content: "How did you execute? What challenges arose during implementation?"
        },
        %{
          title: "Results & Impact",
          type: :outcomes,
          purpose: :success,
          suggested_content: "What were the measurable results? What was the broader impact?"
        },
        %{
          title: "Lessons Learned",
          type: :reflection,
          purpose: :insights,
          suggested_content: "What would you do differently? What insights can others apply?"
        }
      ]
    }
  end

  defp before_after_template do
    %{
      name: "Before & After Transformation",
      description: "Show dramatic improvement or change over time",
      story_type: :case_study,
      narrative_structure: "before_after",
      requires_tier: nil,
      features: [:visual_comparison, :metrics_tracking, :timeline],
      chapters: [
        %{
          title: "The Starting Point",
          type: :baseline,
          purpose: :context,
          suggested_content: "What was the original state? What metrics were you tracking?"
        },
        %{
          title: "The Transformation Process",
          type: :methodology,
          purpose: :approach,
          suggested_content: "What methods did you use? What was your systematic approach?"
        },
        %{
          title: "The Results",
          type: :outcomes,
          purpose: :success,
          suggested_content: "What changed? Show the dramatic improvement with data"
        },
        %{
          title: "Sustaining Success",
          type: :maintenance,
          purpose: :durability,
          suggested_content: "How do you maintain the improvements? What systems are in place?"
        }
      ]
    }
  end

  # CREATIVE PORTFOLIO TEMPLATE
  defp artistic_template do
    %{
      name: "Creative Portfolio",
      description: "Showcase your artistic work and creative process",
      story_type: :creative_portfolio,
      narrative_structure: "artistic",
      requires_tier: nil,
      features: [:media_showcase, :creative_process, :artistic_evolution],
      chapters: [
        %{
          title: "Creative Vision",
          type: :artistic_statement,
          purpose: :philosophy,
          suggested_content: "What drives your creativity? What themes do you explore?"
        },
        %{
          title: "Featured Works",
          type: :portfolio_showcase,
          purpose: :demonstration,
          suggested_content: "Your best pieces with context about the creative process"
        },
        %{
          title: "Creative Process",
          type: :methodology,
          purpose: :insight,
          suggested_content: "How do you approach creative projects? What's your workflow?"
        },
        %{
          title: "Artistic Journey",
          type: :evolution,
          purpose: :growth,
          suggested_content: "How has your art evolved? What influences shaped your style?"
        },
        %{
          title: "Connect & Collaborate",
          type: :engagement,
          purpose: :connection,
          suggested_content: "How can others engage with your work or collaborate?"
        }
      ]
    }
  end

  # NOVEL TEMPLATES
  defp novel_three_act_template do
    %{
      name: "Novel - Three Act Structure",
      description: "Classic novel structure with detailed character and world development",
      story_type: :novel,
      narrative_structure: "three_act",
      requires_tier: "creator",
      features: [:character_development, :world_building, :timeline, :ai_suggestions],
      chapters: [
        %{
          title: "Act I - Setup",
          type: :act,
          purpose: :setup,
          target_word_count: 25000,
          suggested_scenes: [
            %{title: "Opening Hook", purpose: :hook, ai_prompt: "dramatic opening scene"},
            %{title: "Character Introduction", purpose: :character_intro, ai_prompt: "introduce protagonist"},
            %{title: "Inciting Incident", purpose: :catalyst, ai_prompt: "event that changes everything"}
          ],
          development_tools: [:character_sheets, :world_building, :research_notes]
        },
        %{
          title: "Act II - Confrontation",
          type: :act,
          purpose: :development,
          target_word_count: 50000,
          suggested_scenes: [
            %{title: "First Plot Point", purpose: :escalation, ai_prompt: "raise the stakes"},
            %{title: "Midpoint Reversal", purpose: :twist, ai_prompt: "major revelation"},
            %{title: "Crisis Point", purpose: :climax_build, ai_prompt: "darkest moment"}
          ],
          development_tools: [:subplot_tracking, :character_arcs, :conflict_escalation]
        },
        %{
          title: "Act III - Resolution",
          type: :act,
          purpose: :resolution,
          target_word_count: 25000,
          suggested_scenes: [
            %{title: "Climax", purpose: :climax, ai_prompt: "final confrontation"},
            %{title: "Resolution", purpose: :resolution, ai_prompt: "tie up loose ends"}
          ],
          development_tools: [:resolution_tracker, :theme_reinforcement]
        }
      ],
      development_system: novel_development_system()
    }
  end

  defp character_driven_novel_template do
    %{
      name: "Character-Driven Novel",
      description: "Focus on character development and internal journey",
      story_type: :novel,
      narrative_structure: "character_driven",
      requires_tier: "creator",
      features: [:advanced_character_development, :psychology_tools, :relationship_mapping],
      chapters: [
        %{
          title: "Character Introduction",
          type: :character_focus,
          purpose: :character_establishment,
          development_tools: [:character_psychology, :backstory_generator, :motivation_tracker]
        },
        %{
          title: "Internal Conflict",
          type: :character_focus,
          purpose: :internal_journey,
          development_tools: [:emotional_arc, :belief_system, :character_growth]
        },
        %{
          title: "Character Transformation",
          type: :character_focus,
          purpose: :character_resolution,
          development_tools: [:transformation_tracker, :new_equilibrium]
        }
      ],
      development_system: character_focused_development_system()
    }
  end

  # NOVEL TEMPLATES
  defp novel_hero_journey_template do
    %{
      name: "Novel - Hero's Journey",
      description: "Classic monomyth structure for transformative fiction",
      story_type: :novel,
      narrative_structure: "hero_journey",
      requires_tier: "creator",
      features: [:character_development, :world_building, :mythic_structure, :ai_suggestions],
      target_word_count: 80000,
      chapters: [
        %{
          title: "The Ordinary World",
          type: :hero_stage,
          purpose: :setup,
          target_word_count: 5000,
          description: "Establish the hero's normal life before the adventure",
          writing_prompts: [
            "What does your hero's typical day look like?",
            "What are they missing or yearning for?",
            "What assumptions about life will be challenged?"
          ]
        },
        %{
          title: "The Call to Adventure",
          type: :hero_stage,
          purpose: :catalyst,
          target_word_count: 3000,
          description: "The inciting incident that disrupts the ordinary world",
          writing_prompts: [
            "What event forces your hero to consider change?",
            "How does this call relate to their deepest needs?",
            "What makes this opportunity both attractive and frightening?"
          ]
        },
        %{
          title: "Refusal of the Call",
          type: :hero_stage,
          purpose: :resistance,
          target_word_count: 2000,
          description: "The hero's hesitation or initial rejection",
          writing_prompts: [
            "What fears or obligations hold them back?",
            "What would they lose by accepting the call?",
            "How do others react to their potential departure?"
          ]
        },
        %{
          title: "Meeting the Mentor",
          type: :hero_stage,
          purpose: :guidance,
          target_word_count: 4000,
          description: "Encounter with the wise figure who provides aid",
          writing_prompts: [
            "Who has the wisdom your hero needs?",
            "What magical aid or practical advice do they provide?",
            "How does the mentor's own journey mirror the hero's?"
          ]
        },
        %{
          title: "Crossing the First Threshold",
          type: :hero_stage,
          purpose: :commitment,
          target_word_count: 6000,
          description: "The hero commits to the adventure",
          writing_prompts: [
            "What finally pushes them to act?",
            "What guardian or obstacle must they overcome?",
            "How do they leave their old world behind?"
          ]
        },
        %{
          title: "Tests, Allies, and Enemies",
          type: :hero_stage,
          purpose: :development,
          target_word_count: 15000,
          description: "The hero learns the rules of the special world",
          writing_prompts: [
            "What challenges test their resolve?",
            "Who becomes their trusted allies?",
            "What enemies emerge to oppose them?"
          ]
        },
        %{
          title: "Approach to the Inmost Cave",
          type: :hero_stage,
          purpose: :preparation,
          target_word_count: 8000,
          description: "Preparing for the major challenge in the special world",
          writing_prompts: [
            "What is the hero's greatest fear or challenge?",
            "How do they prepare for this confrontation?",
            "What internal conflicts must they resolve?"
          ]
        },
        %{
          title: "The Ordeal",
          type: :hero_stage,
          purpose: :crisis,
          target_word_count: 10000,
          description: "The crisis point where the hero faces their greatest fear",
          writing_prompts: [
            "What does your hero fear they might lose?",
            "How do they confront their deepest fears?",
            "What must they sacrifice to succeed?"
          ]
        },
        %{
          title: "The Reward",
          type: :hero_stage,
          purpose: :victory,
          target_word_count: 6000,
          description: "The hero survives and gains something from the experience",
          writing_prompts: [
            "What wisdom or power do they gain?",
            "How have they changed through this trial?",
            "What new challenges does this victory create?"
          ]
        },
        %{
          title: "The Road Back",
          type: :hero_stage,
          purpose: :return_journey,
          target_word_count: 8000,
          description: "The hero begins the journey back to the ordinary world",
          writing_prompts: [
            "What pursuit or conflict follows them?",
            "How do they commit to completing the journey?",
            "What do they carry back with them?"
          ]
        },
        %{
          title: "Resurrection",
          type: :hero_stage,
          purpose: :final_test,
          target_word_count: 8000,
          description: "A final test where everything is at stake",
          writing_prompts: [
            "What is the final purification or test?",
            "How do they apply everything they've learned?",
            "What would happen if they fail now?"
          ]
        },
        %{
          title: "Return with the Elixir",
          type: :hero_stage,
          purpose: :resolution,
          target_word_count: 5000,
          description: "The hero returns home transformed and able to help others",
          writing_prompts: [
            "What gift do they bring back to their community?",
            "How has their ordinary world changed?",
            "What wisdom can they share with others?"
          ]
        }
      ],
      development_system: hero_journey_development_system()
    }
  end

  defp novel_seven_point_template do
    %{
      name: "Novel - Seven Point Story Structure",
      description: "Dan Wells' seven point story structure for tight plotting",
      story_type: :novel,
      narrative_structure: "seven_point",
      requires_tier: "creator",
      features: [:plot_structure, :character_arcs, :pacing_control],
      target_word_count: 80000,
      chapters: [
        %{
          title: "Hook",
          type: :plot_point,
          purpose: :engagement,
          target_word_count: 8000,
          description: "Start with an engaging scene that introduces your character in their normal world",
          structure_notes: "Show the character's starting state - this mirrors the Resolution"
        },
        %{
          title: "Plot Turn 1",
          type: :plot_point,
          purpose: :catalyst,
          target_word_count: 12000,
          description: "Something happens that changes the character's situation",
          structure_notes: "Force your character out of their comfort zone"
        },
        %{
          title: "Pinch Point 1",
          type: :plot_point,
          purpose: :pressure,
          target_word_count: 15000,
          description: "Apply pressure and introduce the opposition force",
          structure_notes: "Show the antagonist's power and the stakes involved"
        },
        %{
          title: "Midpoint",
          type: :plot_point,
          purpose: :transformation,
          target_word_count: 15000,
          description: "The character moves from reaction to action",
          structure_notes: "Character shift from reactive to proactive behavior"
        },
        %{
          title: "Pinch Point 2",
          type: :plot_point,
          purpose: :crisis,
          target_word_count: 15000,
          description: "Apply more pressure, show the antagonist's power again",
          structure_notes: "Squeeze the character harder, raise the stakes"
        },
        %{
          title: "Plot Turn 2",
          type: :plot_point,
          purpose: :revelation,
          target_word_count: 10000,
          description: "The character gains the final piece of information needed",
          structure_notes: "Provide the key insight or tool needed for resolution"
        },
        %{
          title: "Resolution",
          type: :plot_point,
          purpose: :conclusion,
          target_word_count: 5000,
          description: "The character resolves the conflict and reaches their new state",
          structure_notes: "Show how the character has changed since the Hook"
        }
      ]
    }
  end

  defp mystery_novel_template do
    %{
      name: "Mystery Novel",
      description: "Classic mystery structure with clues, red herrings, and revelation",
      story_type: :novel,
      narrative_structure: "mystery",
      requires_tier: "creator",
      features: [:clue_tracking, :suspect_management, :red_herrings, :revelation_planning],
      target_word_count: 70000,
      chapters: [
        %{
          title: "The Crime",
          type: :mystery_stage,
          purpose: :inciting_incident,
          target_word_count: 8000,
          description: "Establish the crime and introduce the detective",
          mystery_elements: ["crime scene", "initial evidence", "detective introduction"]
        },
        %{
          title: "First Investigation",
          type: :mystery_stage,
          purpose: :initial_clues,
          target_word_count: 12000,
          description: "Gather initial evidence and interview key witnesses",
          mystery_elements: ["witness interviews", "physical evidence", "initial suspects"]
        },
        %{
          title: "Complications",
          type: :mystery_stage,
          purpose: :misdirection,
          target_word_count: 15000,
          description: "Introduce red herrings and false leads",
          mystery_elements: ["red herrings", "false suspects", "contradictory evidence"]
        },
        %{
          title: "Deeper Investigation",
          type: :mystery_stage,
          purpose: :revelations,
          target_word_count: 15000,
          description: "Uncover hidden connections and motives",
          mystery_elements: ["hidden motives", "secret relationships", "breakthrough clues"]
        },
        %{
          title: "The Trap",
          type: :mystery_stage,
          purpose: :confrontation,
          target_word_count: 12000,
          description: "Set up the final confrontation with the perpetrator",
          mystery_elements: ["trap setup", "final evidence", "suspect cornered"]
        },
        %{
          title: "Revelation",
          type: :mystery_stage,
          purpose: :solution,
          target_word_count: 8000,
          description: "Reveal the solution and explain how the crime was solved",
          mystery_elements: ["full explanation", "motive revealed", "method exposed"]
        }
      ]
    }
  end

  defp romance_novel_template do
    %{
      name: "Romance Novel",
      description: "Classic romance structure with relationship development and emotional beats",
      story_type: :novel,
      narrative_structure: "romance",
      requires_tier: "creator",
      features: [:relationship_tracking, :emotional_beats, :character_chemistry],
      target_word_count: 75000,
      chapters: [
        %{
          title: "Meet Cute",
          type: :romance_stage,
          purpose: :introduction,
          target_word_count: 8000,
          description: "Introduce both main characters and their initial meeting",
          romance_elements: ["character introduction", "initial attraction", "conflict setup"]
        },
        %{
          title: "Getting to Know You",
          type: :romance_stage,
          purpose: :development,
          target_word_count: 15000,
          description: "Characters learn about each other, attraction grows",
          romance_elements: ["character development", "shared experiences", "growing attraction"]
        },
        %{
          title: "The First Kiss",
          type: :romance_stage,
          purpose: :escalation,
          target_word_count: 12000,
          description: "Physical and emotional intimacy increases",
          romance_elements: ["first physical intimacy", "emotional vulnerability", "relationship deepening"]
        },
        %{
          title: "Complications",
          type: :romance_stage,
          purpose: :conflict,
          target_word_count: 15000,
          description: "External or internal conflicts threaten the relationship",
          romance_elements: ["relationship obstacles", "misunderstandings", "external pressures"]
        },
        %{
          title: "The Black Moment",
          type: :romance_stage,
          purpose: :crisis,
          target_word_count: 10000,
          description: "The relationship appears to be over",
          romance_elements: ["separation", "deepest conflict", "apparent relationship end"]
        },
        %{
          title: "Grand Gesture",
          type: :romance_stage,
          purpose: :reconciliation,
          target_word_count: 10000,
          description: "One character makes a grand gesture to win back the other",
          romance_elements: ["grand romantic gesture", "declaration of love", "sacrifice for love"]
        },
        %{
          title: "Happily Ever After",
          type: :romance_stage,
          purpose: :resolution,
          target_word_count: 5000,
          description: "The couple reunites and commits to their future together",
          romance_elements: ["reunion", "commitment", "future together"]
        }
      ]
    }
  end

  defp sci_fi_fantasy_template do
    %{
      name: "Science Fiction/Fantasy Novel",
      description: "Speculative fiction with world-building and genre elements",
      story_type: :novel,
      narrative_structure: "sci_fi_fantasy",
      requires_tier: "creator",
      features: [:world_building, :magic_system, :technology_tracking, :species_cultures],
      target_word_count: 90000,
      chapters: [
        %{
          title: "World Introduction",
          type: :speculative_stage,
          purpose: :world_building,
          target_word_count: 10000,
          description: "Introduce the speculative elements and world",
          genre_elements: ["world establishment", "rules of reality", "protagonist introduction"]
        },
        %{
          title: "The Inciting Incident",
          type: :speculative_stage,
          purpose: :catalyst,
          target_word_count: 8000,
          description: "Something disrupts the established order",
          genre_elements: ["disruption of normal", "quest begins", "stakes established"]
        },
        %{
          title: "Journey Begins",
          type: :speculative_stage,
          purpose: :adventure_start,
          target_word_count: 15000,
          description: "The protagonist begins their quest or journey",
          genre_elements: ["leaving familiar", "first challenges", "world expansion"]
        },
        %{
          title: "Trials and Discoveries",
          type: :speculative_stage,
          purpose: :development,
          target_word_count: 20000,
          description: "Face challenges while learning about the world and powers",
          genre_elements: ["power development", "world secrets", "ally/enemy encounters"]
        },
        %{
          title: "Revelation",
          type: :speculative_stage,
          purpose: :understanding,
          target_word_count: 15000,
          description: "Major truth about the world or conflict is revealed",
          genre_elements: ["hidden truth", "power revelation", "enemy exposed"]
        },
        %{
          title: "Final Battle",
          type: :speculative_stage,
          purpose: :climax,
          target_word_count: 15000,
          description: "Confrontation with the main antagonist or resolution of conflict",
          genre_elements: ["ultimate confrontation", "powers tested", "fate decided"]
        },
        %{
          title: "New World Order",
          type: :speculative_stage,
          purpose: :resolution,
          target_word_count: 7000,
          description: "Show how the world has changed and the protagonist's new role",
          genre_elements: ["world changed", "protagonist transformed", "future implications"]
        }
      ]
    }
  end

  defp hero_journey_development_system do
    %{
      character_tools: [
        :hero_archetype_development,
        :mentor_relationship_mapping,
        :ally_enemy_tracking,
        :internal_external_journey_balance
      ],
      plot_tools: [
        :threshold_guardian_design,
        :ordeal_structure,
        :elixir_definition,
        :call_refusal_motivation
      ],
      thematic_tools: [
        :transformation_tracking,
        :symbolic_elements,
        :mythic_resonance,
        :universal_themes
      ]
    }
  end

  # SCREENPLAY TEMPLATES
  defp feature_screenplay_template do
    %{
      name: "Feature Film Screenplay",
      description: "Industry-standard 90-120 page screenplay format",
      story_type: :screenplay,
      narrative_structure: "feature_film",
      requires_tier: "creator",
      features: [:screenplay_formatting, :scene_breakdown, :character_dialogue, :collaboration],
      formatting: screenplay_formatting_rules(),
      chapters: [
        %{
          title: "Act I",
          type: :act,
          purpose: :setup,
          target_pages: 30,
          scenes: [
            %{title: "Cold Open", format: :scene, location: "EXT/INT", time: "DAY/NIGHT"},
            %{title: "Inciting Incident", format: :scene, beats: [:hook, :character_intro, :world_setup]}
          ]
        },
        %{
          title: "Act II-A",
          type: :act,
          purpose: :development,
          target_pages: 30,
          scenes: [
            %{title: "First Plot Point", format: :scene, conflict_level: :rising},
            %{title: "Obstacles", format: :montage, purpose: :character_development}
          ]
        },
        %{
          title: "Act II-B",
          type: :act,
          purpose: :confrontation,
          target_pages: 30,
          scenes: [
            %{title: "Midpoint", format: :scene, purpose: :revelation},
            %{title: "All Is Lost", format: :scene, emotional_tone: :despair}
          ]
        },
        %{
          title: "Act III",
          type: :act,
          purpose: :resolution,
          target_pages: 20,
          scenes: [
            %{title: "Climax", format: :action_sequence},
            %{title: "Resolution", format: :denouement}
          ]
        }
      ],
      collaboration_tools: [:script_notes, :revision_tracking, :read_through_mode]
    }
  end

    # SCREENPLAY TEMPLATES
  defp short_screenplay_template do
    %{
      name: "Short Film Screenplay",
      description: "15-30 page screenplay for short film production",
      story_type: :screenplay,
      narrative_structure: "short_film",
      requires_tier: "creator",
      features: [:screenplay_formatting, :scene_breakdown, :festival_ready],
      target_pages: 20,
      chapters: [
        %{
          title: "Opening",
          type: :screenplay_section,
          purpose: :hook,
          target_pages: 3,
          description: "Establish character and situation quickly",
          screenplay_notes: "Short films need immediate engagement"
        },
        %{
          title: "Development",
          type: :screenplay_section,
          purpose: :conflict,
          target_pages: 12,
          description: "Develop the central conflict or situation",
          screenplay_notes: "Keep focus tight - one main story thread"
        },
        %{
          title: "Resolution",
          type: :screenplay_section,
          purpose: :conclusion,
          target_pages: 5,
          description: "Resolve the conflict with emotional impact",
          screenplay_notes: "Strong endings are crucial for short films"
        }
      ],
      formatting: short_film_formatting_rules()
    }
  end

  defp tv_episode_template do
    %{
      name: "TV Episode Screenplay",
      description: "Television episode with act breaks and commercial considerations",
      story_type: :screenplay,
      narrative_structure: "tv_episode",
      requires_tier: "creator",
      features: [:act_breaks, :commercial_timing, :series_continuity],
      target_pages: 50,
      chapters: [
        %{
          title: "Teaser",
          type: :tv_section,
          purpose: :hook,
          target_pages: 3,
          description: "Cold open to grab audience attention",
          tv_notes: "Hook viewers before the title sequence"
        },
        %{
          title: "Act I",
          type: :tv_section,
          purpose: :setup,
          target_pages: 12,
          description: "Establish episode conflict and character goals",
          tv_notes: "Build to first commercial break"
        },
        %{
          title: "Act II",
          type: :tv_section,
          purpose: :complications,
          target_pages: 15,
          description: "Develop conflicts and raise stakes",
          tv_notes: "Contains the midpoint and second act break"
        },
        %{
          title: "Act III",
          type: :tv_section,
          purpose: :climax,
          target_pages: 12,
          description: "Climax and resolution of episode conflict",
          tv_notes: "Resolve episode arc while advancing season arc"
        },
        %{
          title: "Tag",
          type: :tv_section,
          purpose: :epilogue,
          target_pages: 3,
          description: "Brief scene after resolution, often comedic",
          tv_notes: "Optional scene that adds character moment"
        }
      ]
    }
  end

  defp web_series_template do
    %{
      name: "Web Series Episode",
      description: "Short-form digital content optimized for online viewing",
      story_type: :screenplay,
      narrative_structure: "web_series",
      requires_tier: "creator",
      features: [:digital_optimization, :social_shareability, :binge_structure],
      target_pages: 8,
      chapters: [
        %{
          title: "Hook",
          type: :web_section,
          purpose: :immediate_engagement,
          target_pages: 1,
          description: "Immediate visual or dialogue hook",
          web_notes: "First 5 seconds are crucial for retention"
        },
        %{
          title: "Setup",
          type: :web_section,
          purpose: :context,
          target_pages: 2,
          description: "Quick character and situation establishment",
          web_notes: "Assume viewers might start mid-series"
        },
        %{
          title: "Conflict",
          type: :web_section,
          purpose: :tension,
          target_pages: 3,
          description: "Central conflict or comedic situation",
          web_notes: "Keep it simple and focused"
        },
        %{
          title: "Resolution",
          type: :web_section,
          purpose: :payoff,
          target_pages: 2,
          description: "Quick resolution with cliffhanger potential",
          web_notes: "End with reason to watch next episode"
        }
      ]
    }
  end

  defp documentary_template do
    %{
      name: "Documentary Screenplay",
      description: "Non-fiction storytelling with interview and narrative structure",
      story_type: :screenplay,
      narrative_structure: "documentary",
      requires_tier: "creator",
      features: [:interview_integration, :archival_footage, :narrative_documentary],
      target_pages: 60,
      chapters: [
        %{
          title: "Opening Statement",
          type: :documentary_section,
          purpose: :thesis,
          target_pages: 8,
          description: "Establish the documentary's central question or thesis",
          doc_notes: "Hook viewers with compelling opening"
        },
        %{
          title: "Background & Context",
          type: :documentary_section,
          purpose: :foundation,
          target_pages: 12,
          description: "Provide necessary background information",
          doc_notes: "Mix interviews with archival footage"
        },
        %{
          title: "Investigation/Exploration",
          type: :documentary_section,
          purpose: :development,
          target_pages: 25,
          description: "Deep dive into the subject matter",
          doc_notes: "Multiple perspectives and evidence"
        },
        %{
          title: "Revelation/Climax",
          type: :documentary_section,
          purpose: :discovery,
          target_pages: 10,
          description: "Key revelation or most compelling evidence",
          doc_notes: "Emotional or intellectual peak"
        },
        %{
          title: "Resolution/Impact",
          type: :documentary_section,
          purpose: :conclusion,
          target_pages: 5,
          description: "What this means and call to action",
          doc_notes: "Leave audience with clear takeaway"
        }
      ]
    }
  end

  # COMIC BOOK TEMPLATES
  defp story_arc_comic_template do
    %{
      name: "Comic Story Arc",
      description: "Multi-issue story spanning 4-6 comic books",
      story_type: :comic_book,
      narrative_structure: "story_arc",
      requires_tier: "creator",
      features: [:multi_issue_planning, :artist_collaboration, :continuity_tracking],
      total_issues: 5,
      page_count: 110,
      chapters: [
        %{
          title: "Issue #1: Setup",
          type: :comic_issue,
          purpose: :introduction,
          pages: 22,
          description: "Introduce characters, world, and central conflict",
          comic_elements: ["character introductions", "world establishment", "conflict setup"]
        },
        %{
          title: "Issue #2: Rising Action",
          type: :comic_issue,
          purpose: :development,
          pages: 22,
          description: "Develop characters and escalate conflict",
          comic_elements: ["character development", "plot advancement", "new threats"]
        },
        %{
          title: "Issue #3: Complications",
          type: :comic_issue,
          purpose: :complications,
          pages: 22,
          description: "Introduce major obstacles and setbacks",
          comic_elements: ["major setbacks", "character revelations", "stakes raised"]
        },
        %{
          title: "Issue #4: Crisis",
          type: :comic_issue,
          purpose: :climax_build,
          pages: 22,
          description: "Build to climax, major character moments",
          comic_elements: ["crisis point", "character growth", "setup for finale"]
        },
        %{
          title: "Issue #5: Resolution",
          type: :comic_issue,
          purpose: :conclusion,
          pages: 22,
          description: "Climax and resolution of story arc",
          comic_elements: ["final battle", "character resolution", "story conclusion"]
        }
      ]
    }
  end

  defp graphic_novel_template do
    %{
      name: "Graphic Novel",
      description: "Long-form visual narrative in single volume",
      story_type: :comic_book,
      narrative_structure: "graphic_novel",
      requires_tier: "creator",
      features: [:extended_narrative, :chapter_structure, :thematic_depth],
      page_count: 120,
      chapters: [
        %{
          title: "Part I: Foundation",
          type: :graphic_section,
          purpose: :setup,
          pages: 30,
          description: "Establish world, characters, and central themes",
          narrative_focus: "Character establishment and world-building"
        },
        %{
          title: "Part II: Development",
          type: :graphic_section,
          purpose: :conflict,
          pages: 40,
          description: "Develop conflicts and character relationships",
          narrative_focus: "Relationship dynamics and rising tension"
        },
        %{
          title: "Part III: Crisis",
          type: :graphic_section,
          purpose: :climax,
          pages: 30,
          description: "Major conflicts reach climax",
          narrative_focus: "Confrontation and character testing"
        },
        %{
          title: "Part IV: Resolution",
          type: :graphic_section,
          purpose: :conclusion,
          pages: 20,
          description: "Resolve conflicts and show character growth",
          narrative_focus: "Resolution and thematic conclusion"
        }
      ]
    }
  end

  defp webcomic_template do
    %{
      name: "Webcomic Series",
      description: "Digital comic optimized for online reading",
      story_type: :comic_book,
      narrative_structure: "webcomic",
      requires_tier: "creator",
      features: [:digital_optimization, :scroll_friendly, :social_sharing],
      strip_count: 100,
      chapters: [
        %{
          title: "Character Introduction Arc",
          type: :webcomic_arc,
          purpose: :introduction,
          strips: 20,
          description: "Introduce main characters and basic premise",
          webcomic_notes: "Hook readers quickly, establish posting schedule"
        },
        %{
          title: "World Building Arc",
          type: :webcomic_arc,
          purpose: :expansion,
          strips: 25,
          description: "Expand the world and character relationships",
          webcomic_notes: "Build reader investment in characters"
        },
        %{
          title: "First Major Story Arc",
          type: :webcomic_arc,
          purpose: :main_story,
          strips: 35,
          description: "First major storyline with beginning, middle, end",
          webcomic_notes: "Satisfying arc that can hook new readers"
        },
        %{
          title: "Character Development Arc",
          type: :webcomic_arc,
          purpose: :growth,
          strips: 20,
          description: "Focus on character growth and relationships",
          webcomic_notes: "Deepen reader connection to characters"
        }
      ]
    }
  end

  defp short_film_formatting_rules do
    %{
      scene_heading: %{format: "INT./EXT. LOCATION - TIME", caps: true},
      action_lines: %{margins: {1.5, 7.5}, concise: true},
      character_names: %{position: "center", caps: true},
      dialogue: %{margins: {2.5, 6.5}, natural: true},
      page_count: %{target: "15-30 pages", rule: "1 page = 1 minute"}
    }
  end

  # COMIC BOOK TEMPLATES
  defp single_issue_comic_template do
    %{
      name: "Single Issue Comic",
      description: "22-page comic book with panel layouts and artist collaboration",
      story_type: :comic_book,
      narrative_structure: "single_issue",
      requires_tier: "creator",
      features: [:panel_layouts, :artist_collaboration, :visual_scripting, :lettering_notes],
      page_count: 22,
      chapters: [
        %{
          title: "Pages 1-5: Opening",
          type: :comic_section,
          purpose: :hook,
          pages: 5,
          panels: [
            %{
              page: 1,
              panel: 1,
              type: :splash_page,
              description: "Full-page establishing shot",
              artist_notes: "dramatic composition, set the tone",
              ai_visual_prompt: "epic establishing shot of [setting]"
            },
            %{
              page: 2,
              panel: 1,
              type: :medium_shot,
              description: "Character introduction",
              dialogue: ["Character dialogue here"],
              artist_notes: "show character personality through body language"
            }
          ]
        },
        %{
          title: "Pages 6-16: Development",
          type: :comic_section,
          purpose: :development,
          pages: 11,
          layout_suggestions: [:six_panel_grid, :splash_moments, :action_sequences]
        },
        %{
          title: "Pages 17-22: Climax & Resolution",
          type: :comic_section,
          purpose: :resolution,
          pages: 6,
          visual_focus: [:action_climax, :emotional_resolution, :setup_next_issue]
        }
      ],
      collaboration_system: comic_collaboration_system()
    }
  end

  # CUSTOMER STORY TEMPLATES
  defp customer_journey_template do
    %{
      name: "Customer Journey Story",
      description: "Map customer experience from awareness to advocacy",
      story_type: :customer_story,
      narrative_structure: "journey_map",
      requires_tier: nil,
      features: [:journey_mapping, :touchpoint_analysis, :emotion_tracking, :data_integration],
      chapters: [
        %{
          title: "Awareness Stage",
          type: :journey_stage,
          purpose: :discovery,
          touchpoints: [:social_media, :search, :referral],
          customer_actions: ["becomes aware of problem", "searches for solutions"],
          emotions: [:curiosity, :concern],
          pain_points: [:information_overload, :too_many_options],
          opportunities: [:clear_messaging, :helpful_content]
        },
        %{
          title: "Consideration Stage",
          type: :journey_stage,
          purpose: :evaluation,
          touchpoints: [:website, :reviews, :demos],
          customer_actions: ["compares options", "reads reviews", "requests demo"],
          emotions: [:hope, :skepticism],
          pain_points: [:complex_pricing, :unclear_benefits],
          opportunities: [:social_proof, :clear_value_prop]
        },
        %{
          title: "Decision Stage",
          type: :journey_stage,
          purpose: :conversion,
          touchpoints: [:sales_team, :trial, :onboarding],
          customer_actions: ["makes purchase", "starts using product"],
          emotions: [:excitement, :anxiety],
          pain_points: [:difficult_setup, :learning_curve],
          opportunities: [:smooth_onboarding, :quick_wins]
        },
        %{
          title: "Advocacy Stage",
          type: :journey_stage,
          purpose: :retention_growth,
          touchpoints: [:support, :community, :referrals],
          customer_actions: ["recommends to others", "provides testimonials"],
          emotions: [:satisfaction, :loyalty],
          opportunities: [:referral_programs, :case_studies]
        }
      ],
      analytics_integration: [:conversion_tracking, :sentiment_analysis, :touchpoint_optimization]
    }
  end

    defp customer_testimonial_template do
    %{
      name: "Customer Testimonial Story",
      description: "Compelling customer success testimonial with narrative structure",
      story_type: :customer_story,
      narrative_structure: "testimonial",
      requires_tier: nil,
      features: [:quote_integration, :before_after, :social_proof],
      chapters: [
        %{
          title: "The Challenge",
          type: :testimonial_section,
          purpose: :problem_identification,
          suggested_content: "What problem was the customer facing before your solution?",
          elements: ["pain points", "previous attempts", "impact on business"]
        },
        %{
          title: "The Discovery",
          type: :testimonial_section,
          purpose: :solution_discovery,
          suggested_content: "How did they find your company/product?",
          elements: ["research process", "evaluation criteria", "first impressions"]
        },
        %{
          title: "The Experience",
          type: :testimonial_section,
          purpose: :implementation,
          suggested_content: "What was their experience implementing your solution?",
          elements: ["onboarding process", "support quality", "initial results"]
        },
        %{
          title: "The Results",
          type: :testimonial_section,
          purpose: :outcomes,
          suggested_content: "What measurable results did they achieve?",
          elements: ["quantified benefits", "ROI metrics", "business impact"]
        },
        %{
          title: "The Recommendation",
          type: :testimonial_section,
          purpose: :endorsement,
          suggested_content: "Why would they recommend your solution to others?",
          elements: ["key benefits", "differentiators", "advice to prospects"]
        }
      ]
    }
  end

  defp customer_case_study_template do
    %{
      name: "Customer Case Study",
      description: "Detailed analysis of customer success with data and insights",
      story_type: :customer_story,
      narrative_structure: "case_study",
      requires_tier: nil,
      features: [:data_visualization, :methodology_tracking, :roi_calculation],
      chapters: [
        %{
          title: "Executive Summary",
          type: :case_study_section,
          purpose: :overview,
          suggested_content: "Brief overview of the customer, challenge, solution, and results",
          elements: ["company background", "key metrics", "solution summary"]
        },
        %{
          title: "The Challenge",
          type: :case_study_section,
          purpose: :problem_analysis,
          suggested_content: "Detailed analysis of the customer's business challenge",
          elements: ["root cause analysis", "business impact", "requirements definition"]
        },
        %{
          title: "The Solution",
          type: :case_study_section,
          purpose: :methodology,
          suggested_content: "How your solution addressed their specific needs",
          elements: ["solution design", "implementation plan", "customizations"]
        },
        %{
          title: "Implementation",
          type: :case_study_section,
          purpose: :execution,
          suggested_content: "Timeline and process of implementing the solution",
          elements: ["project timeline", "key milestones", "challenges overcome"]
        },
        %{
          title: "Results & ROI",
          type: :case_study_section,
          purpose: :measurement,
          suggested_content: "Quantified results and return on investment",
          elements: ["performance metrics", "cost savings", "ROI calculation"]
        },
        %{
          title: "Lessons Learned",
          type: :case_study_section,
          purpose: :insights,
          suggested_content: "Key insights and best practices from the engagement",
          elements: ["success factors", "best practices", "scalability insights"]
        }
      ]
    }
  end

  defp customer_success_template do
    %{
      name: "Customer Success Story",
      description: "Narrative-driven success story highlighting transformation",
      story_type: :customer_story,
      narrative_structure: "success_story",
      requires_tier: nil,
      features: [:transformation_focus, :narrative_flow, :emotional_connection],
      chapters: [
        %{
          title: "Meet the Customer",
          type: :success_section,
          purpose: :introduction,
          suggested_content: "Introduce the customer and their business context",
          elements: ["company profile", "industry context", "key stakeholders"]
        },
        %{
          title: "The Turning Point",
          type: :success_section,
          purpose: :catalyst,
          suggested_content: "What event or realization prompted them to seek a solution?",
          elements: ["triggering event", "decision drivers", "urgency factors"]
        },
        %{
          title: "The Journey",
          type: :success_section,
          purpose: :process,
          suggested_content: "Their experience working with your team/solution",
          elements: ["collaboration process", "milestone achievements", "relationship building"]
        },
        %{
          title: "The Transformation",
          type: :success_section,
          purpose: :change,
          suggested_content: "How their business/situation fundamentally improved",
          elements: ["operational changes", "cultural shifts", "capability improvements"]
        },
        %{
          title: "Looking Forward",
          type: :success_section,
          purpose: :future,
          suggested_content: "Their ongoing success and future plans",
          elements: ["sustained benefits", "growth plans", "expanded partnership"]
        }
      ]
    }
  end

  # VISUAL STORYBOARD TEMPLATES
  defp film_storyboard_template do
    %{
      name: "Film Sequence Storyboard",
      description: "Visual planning for film sequences with AI-generated imagery",
      story_type: :storyboard,
      narrative_structure: "film_sequence",
      requires_tier: "creator",
      features: [:ai_image_generation, :shot_composition, :camera_movement, :timing_notes],
      chapters: [
        %{
          title: "Sequence Setup",
          type: :storyboard_section,
          purpose: :establishment,
          shots: [
            %{
              shot_number: 1,
              shot_type: :wide_shot,
              description: "Establishing shot of location",
              ai_prompt: "cinematic wide shot of [location], [lighting], [mood]",
              camera_movement: :static,
              duration: "3 seconds",
              notes: "Set the scene and mood"
            },
            %{
              shot_number: 2,
              shot_type: :medium_shot,
              description: "Character enters frame",
              ai_prompt: "medium shot of [character] entering [location], [emotion]",
              camera_movement: :pan_right,
              duration: "2 seconds",
              notes: "Follow character movement"
            }
          ]
        }
      ],
      ai_generation_system: storyboard_ai_system()
    }
  end

    # STORYBOARD TEMPLATES
  defp animation_storyboard_template do
    %{
      name: "Animation Storyboard",
      description: "Detailed visual planning for animated content with timing notes",
      story_type: :storyboard,
      narrative_structure: "animation",
      requires_tier: "creator",
      features: [:timing_notes, :character_animation, :camera_movement, :effect_planning],
      chapters: [
        %{
          title: "Character Introduction Sequence",
          type: :animation_section,
          purpose: :character_intro,
          shots: [
            %{
              shot_number: 1,
              shot_type: :establishing_shot,
              description: "Wide shot establishing the world/environment",
              animation_notes: "Hold for 3 seconds, slow pan across environment",
              timing: "0:00-0:03"
            },
            %{
              shot_number: 2,
              shot_type: :character_reveal,
              description: "Character enters frame or is revealed",
              animation_notes: "Character walk cycle, anticipation pose before action",
              timing: "0:03-0:06"
            }
          ]
        },
        %{
          title: "Action Sequence",
          type: :animation_section,
          purpose: :dynamic_action,
          shots: [
            %{
              shot_number: 3,
              shot_type: :action_shot,
              description: "Character performs main action",
              animation_notes: "Squash and stretch principles, motion blur on fast movement",
              timing: "0:06-0:10"
            }
          ]
        },
        %{
          title: "Emotional Beat",
          type: :animation_section,
          purpose: :character_emotion,
          shots: [
            %{
              shot_number: 4,
              shot_type: :close_up,
              description: "Close-up on character's emotional reaction",
              animation_notes: "Subtle facial animation, hold on key expressions",
              timing: "0:10-0:13"
            }
          ]
        }
      ]
    }
  end

  defp commercial_storyboard_template do
    %{
      name: "Commercial Storyboard",
      description: "Advertisement storyboard with product focus and call-to-action",
      story_type: :storyboard,
      narrative_structure: "commercial",
      requires_tier: "creator",
      features: [:product_showcase, :brand_integration, :cta_placement, :time_constraints],
      target_duration: "30 seconds",
      chapters: [
        %{
          title: "Hook (0-5 seconds)",
          type: :commercial_section,
          purpose: :attention_grab,
          shots: [
            %{
              shot_number: 1,
              shot_type: :attention_grabber,
              description: "Eye-catching opening that stops scroll/channel surfing",
              commercial_notes: "Must grab attention in first 2 seconds",
              timing: "0:00-0:02"
            },
            %{
              shot_number: 2,
              shot_type: :problem_setup,
              description: "Show the problem or need the product solves",
              commercial_notes: "Relatable situation for target audience",
              timing: "0:02-0:05"
            }
          ]
        },
        %{
          title: "Product Introduction (5-15 seconds)",
          type: :commercial_section,
          purpose: :product_showcase,
          shots: [
            %{
              shot_number: 3,
              shot_type: :product_reveal,
              description: "Introduce the product as the solution",
              commercial_notes: "Clear product shot with logo visible",
              timing: "0:05-0:08"
            },
            %{
              shot_number: 4,
              shot_type: :product_demo,
              description: "Show product in use/benefits",
              commercial_notes: "Demonstrate key features/benefits clearly",
              timing: "0:08-0:15"
            }
          ]
        },
        %{
          title: "Call to Action (15-30 seconds)",
          type: :commercial_section,
          purpose: :conversion,
          shots: [
            %{
              shot_number: 5,
              shot_type: :lifestyle_shot,
              description: "Show improved life/situation with product",
              commercial_notes: "Aspirational imagery for target audience",
              timing: "0:15-0:22"
            },
            %{
              shot_number: 6,
              shot_type: :cta_card,
              description: "Clear call-to-action with brand logo",
              commercial_notes: "Website, phone number, or store location",
              timing: "0:22-0:30"
            }
          ]
        }
      ]
    }
  end

  defp music_video_storyboard_template do
    %{
      name: "Music Video Storyboard",
      description: "Visual storytelling synchronized to music with performance elements",
      story_type: :storyboard,
      narrative_structure: "music_video",
      requires_tier: "creator",
      features: [:music_sync, :performance_shots, :narrative_elements, :visual_effects],
      chapters: [
        %{
          title: "Opening/Intro",
          type: :music_video_section,
          purpose: :intro,
          music_timing: "0:00-0:30",
          shots: [
            %{
              shot_number: 1,
              shot_type: :atmospheric_shot,
              description: "Mood-setting opening before vocals start",
              music_notes: "Sync to instrumental intro, build atmosphere",
              timing: "0:00-0:15"
            },
            %{
              shot_number: 2,
              shot_type: :artist_intro,
              description: "First appearance of main artist/performer",
              music_notes: "Sync to first vocal entrance",
              timing: "0:15-0:30"
            }
          ]
        },
        %{
          title: "Verse 1",
          type: :music_video_section,
          purpose: :story_setup,
          music_timing: "0:30-1:00",
          shots: [
            %{
              shot_number: 3,
              shot_type: :performance_shot,
              description: "Artist performing verse, establishing narrative",
              music_notes: "Match lip sync, establish story elements",
              timing: "0:30-0:45"
            },
            %{
              shot_number: 4,
              shot_type: :narrative_shot,
              description: "Story elements that support the lyrics",
              music_notes: "Visual metaphors for lyrical content",
              timing: "0:45-1:00"
            }
          ]
        },
        %{
          title: "Chorus",
          type: :music_video_section,
          purpose: :energy_peak,
          music_timing: "1:00-1:30",
          shots: [
            %{
              shot_number: 5,
              shot_type: :high_energy_performance,
              description: "Dynamic performance shots with movement",
              music_notes: "Match energy of chorus, faster cuts",
              timing: "1:00-1:15"
            },
            %{
              shot_number: 6,
              shot_type: :visual_climax,
              description: "Most visually striking moment",
              music_notes: "Peak visual impact at chorus climax",
              timing: "1:15-1:30"
            }
          ]
        },
        %{
          title: "Bridge/Breakdown",
          type: :music_video_section,
          purpose: :contrast,
          music_timing: "2:30-3:00",
          shots: [
            %{
              shot_number: 7,
              shot_type: :intimate_moment,
              description: "Quieter, more intimate or different visual approach",
              music_notes: "Contrast with chorus energy, match music shift",
              timing: "2:30-3:00"
            }
          ]
        },
        %{
          title: "Final Chorus/Outro",
          type: :music_video_section,
          purpose: :resolution,
          music_timing: "3:00-3:30",
          shots: [
            %{
              shot_number: 8,
              shot_type: :climactic_performance,
              description: "Final high-energy performance sequence",
              music_notes: "Build to final moment, resolve narrative",
              timing: "3:00-3:30"
            }
          ]
        }
      ]
    }
  end

  # DEVELOPMENT SYSTEMS
  defp novel_development_system do
    %{
      character_tools: [
        :character_sheets,
        :relationship_mapping,
        :character_arc_tracking,
        :dialogue_voice_consistency,
        :backstory_generator
      ],
      world_building: [
        :location_database,
        :culture_development,
        :history_timeline,
        :magic_system_rules,
        :technology_specs
      ],
      plot_tools: [
        :subplot_tracking,
        :foreshadowing_tracker,
        :plot_hole_detection,
        :pacing_analysis,
        :theme_reinforcement
      ],
      ai_assistance: [
        :writing_prompts,
        :scene_suggestions,
        :character_consistency_check,
        :plot_analysis,
        :style_enhancement
      ]
    }
  end

  defp character_focused_development_system do
    %{
      psychology_tools: [
        :personality_analysis,
        :motivation_tracker,
        :belief_system_mapping,
        :emotional_arc_planning,
        :psychological_profiling
      ],
      relationship_tools: [
        :dynamic_mapping,
        :conflict_sources,
        :alliance_tracking,
        :romantic_subplot_planning,
        :family_tree_builder
      ],
      growth_tracking: [
        :transformation_milestones,
        :internal_conflict_resolution,
        :character_voice_evolution,
        :goal_achievement_tracker
      ]
    }
  end

  defp comic_collaboration_system do
    %{
      writer_tools: [
        :script_formatting,
        :panel_descriptions,
        :dialogue_balloons,
        :pacing_notes
      ],
      artist_tools: [
        :layout_sketches,
        :character_model_sheets,
        :environment_references,
        :style_guides
      ],
      collaboration_features: [
        :version_control,
        :approval_workflow,
        :revision_tracking,
        :asset_sharing
      ],
      production_pipeline: [
        :script_approval,
        :pencil_stage,
        :ink_stage,
        :color_stage,
        :lettering_stage,
        :final_approval
      ]
    }
  end

  defp storyboard_ai_system do
    %{
      image_generation: [
        :shot_composition,
        :character_consistency,
        :environment_continuity,
        :lighting_mood,
        :camera_angles
      ],
      prompt_enhancement: [
        :style_consistency,
        :technical_specifications,
        :artistic_direction,
        :brand_guidelines
      ],
      iteration_tools: [
        :variation_generation,
        :style_transfer,
        :composition_adjustment,
        :mood_modification
      ]
    }
  end

  defp screenplay_formatting_rules do
    %{
      scene_heading: %{
        format: "INT./EXT. LOCATION - TIME",
        examples: ["INT. COFFEE SHOP - DAY", "EXT. CITY STREET - NIGHT"]
      },
      action_lines: %{
        margins: {1.5, 7.5},
        style: "present_tense",
        max_lines: 4
      },
      character_names: %{
        position: "center",
        caps: true,
        margin: 3.7
      },
      dialogue: %{
        margins: {2.5, 6.5},
        character_margin: 3.7,
        parenthetical_margin: 3.1
      },
      transitions: %{
        position: "right",
        caps: true,
        examples: ["CUT TO:", "FADE IN:", "FADE OUT:"]
      }
    }
  end

  def default_template do
    %{
      name: "Basic Story Template",
      description: "A simple template for general storytelling",
      story_type: :personal_narrative,
      narrative_structure: "chronological",
      requires_tier: nil,
      chapters: [
        %{title: "Beginning", purpose: :setup, type: :intro},
        %{title: "Middle", purpose: :development, type: :content},
        %{title: "End", purpose: :resolution, type: :conclusion}
      ]
    }
  end

  # AI Integration Helper Functions
  def generate_ai_suggestions(story_type, current_content, context) do
    case story_type do
      :novel -> generate_novel_suggestions(current_content, context)
      :screenplay -> generate_screenplay_suggestions(current_content, context)
      :comic_book -> generate_comic_suggestions(current_content, context)
      :storyboard -> generate_storyboard_suggestions(current_content, context)
      _ -> generate_general_suggestions(current_content, context)
    end
  end

  defp generate_novel_suggestions(content, context) do
    %{
      character_development: "Consider exploring [character]'s backstory to add depth",
      plot_advancement: "This scene could benefit from higher stakes",
      pacing: "Consider breaking this into two scenes for better pacing",
      dialogue: "This dialogue could be more character-specific",
      world_building: "Add sensory details to make this setting more vivid"
    }
  end

  defp generate_screenplay_suggestions(content, context) do
    %{
      formatting: "Scene heading should specify INT./EXT.",
      dialogue: "Consider making this dialogue more conversational",
      action: "Action lines should be more concise and visual",
      structure: "This scene might work better earlier in the act",
      character: "Show don't tell - use action instead of exposition"
    }
  end

  defp generate_comic_suggestions(content, context) do
    %{
      panel_layout: "Consider a splash panel for this dramatic moment",
      pacing: "This action sequence needs more panels for clarity",
      dialogue: "Balloon placement might cover important artwork",
      visual_storytelling: "This exposition could be shown visually instead",
      page_turn: "Great page turn reveal opportunity here"
    }
  end

  defp generate_storyboard_suggestions(content, context) do
    %{
      shot_composition: "Try a low angle to make character more imposing",
      camera_movement: "A dolly shot here would enhance the emotion",
      continuity: "Check eyeline direction for this conversation",
      pacing: "This moment needs a close-up for emotional impact",
      transitions: "Consider a match cut to the next scene"
    }
  end

  defp generate_general_suggestions(content, context) do
    %{
      structure: "Consider the story structure and pacing",
      character: "Develop character motivations further",
      conflict: "Raise the stakes to increase tension",
      theme: "Strengthen the thematic elements",
      engagement: "Hook the audience earlier in the story"
    }
  end
end
