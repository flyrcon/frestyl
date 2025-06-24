# lib/frestyl/stories/multimedia_templates.ex
defmodule Frestyl.Stories.MultimediaTemplates do
  @moduledoc "Rich multimedia story templates with granular media binding"

  def get_template(story_type, narrative_structure) do
    templates()
    |> Map.get(story_type, %{})
    |> Map.get(narrative_structure, default_template())
  end

  def default_template do
    %{
      name: "Basic Story Template",
      description: "A simple template for general storytelling",
      chapters: [
        # ... (content from the artifact)
      ]
    }
  end

  def templates do
    %{
      personal_narrative: %{
        hero_journey: %{
          name: "Multimedia Hero's Journey",
          description: "Tell your transformation story with rich media integration",
          chapters: [
            %{
              title: "The Call",
              purpose: :hook,
              suggested_blocks: [
                %{
                  type: :text,
                  uuid: "call-intro-text",
                  content_prompt: "What moment changed everything? Start with the scene...",
                  media_suggestions: [
                    %{type: :background_audio, purpose: "Set the mood with ambient sound"},
                    %{type: :narration_sync, purpose: "Record yourself telling this part"},
                    %{type: :modal_image, purpose: "Show the 'before' moment"}
                  ]
                },
                %{
                  type: :image,
                  uuid: "call-moment-image",
                  content_prompt: "A photo that captures this pivotal moment",
                  media_suggestions: [
                    %{type: :hover_audio, purpose: "Audio description when hovered"},
                    %{type: :hotspot_trigger, purpose: "Click areas for more details"}
                  ]
                }
              ]
            },
            %{
              title: "The Challenge",
              purpose: :conflict,
              suggested_blocks: [
                %{
                  type: :timeline,
                  uuid: "challenge-timeline",
                  content_prompt: "Map out the obstacles you faced over time",
                  media_suggestions: [
                    %{type: :click_video, purpose: "Video for each timeline point"},
                    %{type: :narration_sync, purpose: "Audio walkthrough of timeline"}
                  ]
                },
                %{
                  type: :card_grid,
                  uuid: "challenge-details",
                  content_prompt: "Break down each major obstacle",
                  media_suggestions: [
                    %{type: :hover_audio, purpose: "Audio detail for each card"},
                    %{type: :modal_image, purpose: "Supporting images/documents"}
                  ]
                }
              ]
            }
          ]
        }
      },

      professional_showcase: %{
        chronological: %{
          name: "Interactive Portfolio Showcase",
          description: "Professional work with detailed media explanations",
          chapters: [
            %{
              title: "Featured Work",
              purpose: :showcase,
              suggested_blocks: [
                %{
                  type: :card_grid,
                  uuid: "projects-grid",
                  content_prompt: "Your best projects with brief descriptions",
                  media_suggestions: [
                    %{type: :hover_audio, purpose: "Quick audio overview on hover"},
                    %{type: :click_video, purpose: "Detailed demo video on click"},
                    %{type: :modal_image, purpose: "Screenshots, mockups, results"}
                  ]
                },
                %{
                  type: :code_showcase,
                  uuid: "code-samples",
                  content_prompt: "Code snippets with explanations",
                  media_suggestions: [
                    %{type: :narration_sync, purpose: "Walk through the code"},
                    %{type: :code_demo, purpose: "Live code execution"}
                  ]
                }
              ]
            }
          ]
        }
      },

      case_study: %{
        problem_solution: %{
          name: "Interactive Case Study",
          description: "Problem-solution narrative with evidence and demos",
          chapters: [
            %{
              title: "The Problem",
              purpose: :context,
              suggested_blocks: [
                %{
                  type: :text,
                  uuid: "problem-description",
                  content_prompt: "Describe the challenge your client/company faced",
                  media_suggestions: [
                    %{type: :background_audio, purpose: "Set serious/urgent mood"},
                    %{type: :modal_image, purpose: "Before screenshots/data"}
                  ]
                },
                %{
                  type: :bullet_list,
                  uuid: "problem-points",
                  content_prompt: "Key pain points and their impact",
                  media_suggestions: [
                    %{type: :hover_audio, purpose: "Detailed explanation for each point"},
                    %{type: :document_overlay, purpose: "Supporting research/data"}
                  ]
                }
              ]
            },
            %{
              title: "The Solution",
              purpose: :resolution,
              suggested_blocks: [
                %{
                  type: :timeline,
                  uuid: "solution-process",
                  content_prompt: "Step-by-step solution development",
                  media_suggestions: [
                    %{type: :click_video, purpose: "Demo video for each step"},
                    %{type: :narration_sync, purpose: "Explain your thought process"}
                  ]
                },
                %{
                  type: :media_showcase,
                  uuid: "results-showcase",
                  content_prompt: "Before/after results and metrics",
                  media_suggestions: [
                    %{type: :inline_video, purpose: "Results demonstration"},
                    %{type: :hover_audio, purpose: "Metric explanations"}
                  ]
                }
              ]
            }
          ]
        }
      }
    }
  end

  def apply_template_to_story(story, template) do
    # Create chapters and content blocks from template
    template.chapters
    |> Enum.with_index()
    |> Enum.each(fn {chapter_template, chapter_index} ->
      {:ok, chapter} = Frestyl.Stories.create_chapter(%{
        story_id: story.id,
        title: chapter_template.title,
        narrative_purpose: chapter_template.purpose,
        position: chapter_index + 1
      })

      # Create suggested content blocks for this chapter
      chapter_template.suggested_blocks
      |> Enum.with_index()
      |> Enum.each(fn {block_template, block_index} ->
        create_content_block_from_template(chapter, block_template, block_index)
      end)
    end)
  end

  defp create_content_block_from_template(chapter, block_template, position) do
    Frestyl.Stories.create_content_block(%{
      chapter_id: chapter.id,
      block_uuid: block_template.uuid,
      block_type: block_template.type,
      position: position,
      content_data: %{
        placeholder_text: block_template.content_prompt,
        media_suggestions: block_template.media_suggestions
      },
      layout_config: get_default_layout_for_block_type(block_template.type),
      interaction_config: get_default_interactions_for_block_type(block_template.type)
    })
  end

  defp get_default_layout_for_block_type(:text) do
    %{
      typography: "story-text",
      max_width: "65ch",
      highlight_sync: true
    }
  end

  defp get_default_layout_for_block_type(:card_grid) do
    %{
      columns: 3,
      gap: "1.5rem",
      hover_elevation: true,
      media_position: "overlay"
    }
  end

  defp get_default_layout_for_block_type(:timeline) do
    %{
      orientation: "vertical",
      show_dates: true,
      interactive_points: true
    }
  end

  defp get_default_layout_for_block_type(_), do: %{}

  defp get_default_interactions_for_block_type(:card_grid) do
    %{
      hover_preview: true,
      click_action: "expand",
      audio_on_hover: false  # User can enable
    }
  end

  defp get_default_interactions_for_block_type(:text) do
    %{
      selectable_segments: true,
      audio_sync_highlight: false,  # User can enable
      click_to_play: false
    }
  end

  defp get_default_interactions_for_block_type(_), do: %{}
end
