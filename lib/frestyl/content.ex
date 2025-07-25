# lib/frestyl/content.ex - Enhanced Content Context
defmodule Frestyl.Content do
  @moduledoc """
  Advanced content management with intelligent document types, guided workflows,
  and rich media integration for collaborative writing.
  """

  import Ecto.Query, warn: false
  alias Frestyl.Repo
  alias Frestyl.Accounts.User
  alias Frestyl.Sessions
  alias Frestyl.Media

  alias Frestyl.Content.{
    Document, DocumentBlock, MediaAttachment, DocumentVersion,
    DocumentTemplate, WritingAssistant, CollaborationBranch
  }

  # ==================
  # INTELLIGENT DOCUMENT TYPES
  # ==================

  @document_types %{
    # ARTICLES - Thought Leadership & Content Marketing
    "thought_leadership" => %{
      name: "Thought Leadership Article",
      category: "article",
      description: "Establish expertise and influence in your field",
      workflow: :authority_building,
      target_audience: "industry_professionals",
      recommended_length: %{min: 1200, ideal: 2500, max: 4000},
      guided_questions: [
        "What industry trend or challenge will you address?",
        "What unique perspective or solution do you offer?",
        "What evidence or examples support your position?",
        "What action do you want readers to take?"
      ],
      default_blocks: [
        %{type: "hook", placeholder: "Start with a provocative question or surprising statistic..."},
        %{type: "thesis", placeholder: "State your unique perspective clearly..."},
        %{type: "evidence_section", heading: "The Current Landscape"},
        %{type: "solution_section", heading: "A Better Approach"},
        %{type: "case_study", placeholder: "Real-world example or data..."},
        %{type: "call_to_action", placeholder: "What should readers do next?"}
      ],
      seo_optimization: true,
      social_optimization: true,
      authority_signals: ["author_bio", "credentials", "citations"]
    },

    "content_marketing" => %{
      name: "Content Marketing Article",
      category: "article",
      description: "Drive engagement and conversions for your brand",
      workflow: :conversion_focused,
      target_audience: "potential_customers",
      recommended_length: %{min: 800, ideal: 1500, max: 2500},
      guided_questions: [
        "What problem does your audience face?",
        "How does your product/service solve this?",
        "What valuable insights can you share?",
        "How will you measure success?"
      ],
      default_blocks: [
        %{type: "problem_statement", placeholder: "Identify the pain point your audience faces..."},
        %{type: "value_proposition", placeholder: "Explain your unique solution..."},
        %{type: "educational_content", placeholder: "Provide actionable insights..."},
        %{type: "social_proof", placeholder: "Customer testimonials or case studies..."},
        %{type: "soft_cta", placeholder: "Gentle call-to-action..."}
      ],
      conversion_tracking: true,
      a_b_testing: true,
      lead_magnets: ["downloadable_guide", "email_signup", "demo_request"]
    },

    "investigative_journalism" => %{
      name: "Investigative Article",
      category: "article",
      description: "In-depth reporting and fact-finding journalism",
      workflow: :investigative,
      target_audience: "general_public",
      recommended_length: %{min: 2000, ideal: 4000, max: 8000},
      guided_questions: [
        "What is the central question or mystery?",
        "What sources and evidence do you have?",
        "What are the broader implications?",
        "How will you verify all claims?"
      ],
      default_blocks: [
        %{type: "lede", placeholder: "Compelling opening that sets the scene..."},
        %{type: "nut_graf", placeholder: "Why this story matters now..."},
        %{type: "evidence_section", placeholder: "Present findings methodically..."},
        %{type: "source_quotes", placeholder: "Key interviews and statements..."},
        %{type: "conclusion", placeholder: "Implications and next steps..."}
      ],
      fact_checking: :mandatory,
      source_protection: true,
      legal_review: true
    },

    # BOOKS - Comprehensive Fiction & Non-Fiction
    "literary_fiction" => %{
      name: "Literary Fiction",
      category: "book",
      description: "Character-driven narrative with artistic merit",
      workflow: :character_focused,
      target_length: %{min: 70000, ideal: 90000, max: 120000},
      guided_questions: [
        "Who is your protagonist and what do they want?",
        "What internal conflict drives the story?",
        "What themes will you explore?",
        "How will your character change?"
      ],
      default_blocks: [
        %{type: "character_sketch", placeholder: "Develop your main character..."},
        %{type: "opening_scene", placeholder: "Begin in the middle of action..."},
        %{type: "inciting_incident", placeholder: "What sets the story in motion?"},
        %{type: "rising_action", placeholder: "Build tension and conflict..."},
        %{type: "climax", placeholder: "The turning point..."},
        %{type: "resolution", placeholder: "How does it end?"}
      ],
      character_tracking: true,
      theme_development: true,
      literary_devices: true
    },

    "business_book" => %{
      name: "Business/Self-Help Book",
      category: "book",
      description: "Practical advice and strategies for professional growth",
      workflow: :framework_based,
      target_length: %{min: 45000, ideal: 65000, max: 85000},
      guided_questions: [
        "What specific problem are you solving?",
        "What is your unique framework or methodology?",
        "What evidence supports your approach?",
        "How can readers implement your ideas?"
      ],
      default_blocks: [
        %{type: "problem_identification", placeholder: "What challenge do readers face?"},
        %{type: "framework_introduction", placeholder: "Your systematic approach..."},
        %{type: "chapter_outline", placeholder: "Step-by-step breakdown..."},
        %{type: "case_studies", placeholder: "Real-world examples..."},
        %{type: "implementation_guide", placeholder: "How to apply the concepts..."},
        %{type: "resources", placeholder: "Additional tools and references..."}
      ],
      case_study_integration: true,
      actionable_takeaways: true,
      worksheet_generation: true
    },

    "children_picture_book" => %{
      name: "Children's Picture Book",
      category: "book",
      description: "Illustrated stories for young readers",
      workflow: :visual_narrative,
      target_length: %{min: 200, ideal: 500, max: 1000},
      age_range: "3-8",
      guided_questions: [
        "What lesson or emotion will you convey?",
        "How will text and images work together?",
        "What will happen on each page spread?",
        "How will you engage young readers?"
      ],
      default_blocks: [
        %{type: "title_page", placeholder: "Your book title..."},
        %{type: "page_spread", placeholder: "Page 1-2 text...", image_required: true},
        %{type: "page_spread", placeholder: "Page 3-4 text...", image_required: true},
        %{type: "climax_spread", placeholder: "The exciting moment...", image_required: true},
        %{type: "resolution_spread", placeholder: "How it ends...", image_required: true}
      ],
      illustration_notes: true,
      reading_level_analysis: true,
      page_layout_suggestions: true
    },

    "technical_manual" => %{
      name: "Technical Manual/Documentation",
      category: "book",
      description: "Instructional content for software, products, or processes",
      workflow: :procedural,
      target_length: %{flexible: true},
      guided_questions: [
        "Who is your target user?",
        "What tasks need to be accomplished?",
        "What prior knowledge can you assume?",
        "How will you handle troubleshooting?"
      ],
      default_blocks: [
        %{type: "overview", placeholder: "What this manual covers..."},
        %{type: "prerequisites", placeholder: "What users need to know first..."},
        %{type: "step_by_step", placeholder: "Detailed procedures..."},
        %{type: "code_example", placeholder: "Code snippets with explanations..."},
        %{type: "troubleshooting", placeholder: "Common issues and solutions..."},
        %{type: "api_reference", placeholder: "Technical specifications..."}
      ],
      code_syntax_highlighting: true,
      screenshot_integration: true,
      version_control: :strict
    },

    # SPECIALIZED FORMATS
    "screenwriting" => %{
      name: "Screenplay",
      category: "script",
      description: "Film, TV, or streaming content scripts",
      workflow: :three_act_structure,
      formatting: :industry_standard,
      guided_questions: [
        "What's the central conflict or goal?",
        "Who are your main characters?",
        "What's the visual storytelling approach?",
        "How does each scene advance the plot?"
      ],
      default_blocks: [
        %{type: "title_page"},
        %{type: "fade_in"},
        %{type: "scene_heading", placeholder: "EXT. LOCATION - DAY"},
        %{type: "action", placeholder: "Visual description of what we see..."},
        %{type: "character_name", placeholder: "CHARACTER"},
        %{type: "dialogue", placeholder: "What they say..."},
        %{type: "parenthetical", placeholder: "(how they say it)"}
      ],
      character_tracking: true,
      page_timing: true, # 1 page = 1 minute
      industry_formatting: :strict
    },

    "academic_paper" => %{
      name: "Academic Research Paper",
      category: "academic",
      description: "Peer-reviewed research and scholarly articles",
      workflow: :scientific_method,
      citation_style: "apa", # or mla, chicago, etc.
      guided_questions: [
        "What is your research question?",
        "What methodology will you use?",
        "What are your hypotheses?",
        "How will you analyze the data?"
      ],
      default_blocks: [
        %{type: "title_page"},
        %{type: "abstract", max_words: 250},
        %{type: "keywords", placeholder: "5-10 relevant keywords..."},
        %{type: "introduction", placeholder: "Background and research question..."},
        %{type: "literature_review", placeholder: "Previous research..."},
        %{type: "methodology", placeholder: "How you conducted the research..."},
        %{type: "results", placeholder: "What you found..."},
        %{type: "discussion", placeholder: "What it means..."},
        %{type: "conclusion", placeholder: "Implications and future research..."},
        %{type: "references"}
      ],
      citation_management: true,
      peer_review_mode: true,
      plagiarism_checking: true
    },

    "poetry_collection" => %{
      name: "Poetry Collection",
      category: "creative",
      description: "Curated collection of poems with thematic unity",
      workflow: :thematic_curation,
      guided_questions: [
        "What theme or emotion connects these poems?",
        "How will you organize the collection?",
        "What forms or styles will you use?",
        "How do individual poems contribute to the whole?"
      ],
      default_blocks: [
        %{type: "collection_title"},
        %{type: "epigraph", placeholder: "Optional opening quote..."},
        %{type: "section_break", placeholder: "Section I: [Theme]"},
        %{type: "poem_title", placeholder: "Individual poem title..."},
        %{type: "stanza", placeholder: "First stanza..."},
        %{type: "stanza_break"},
        %{type: "stanza", placeholder: "Second stanza..."}
      ],
      audio_recording: true, # For spoken word
      meter_analysis: true,
      thematic_organization: true
    }
  }

  # ==================
  # INTELLIGENT WRITING ASSISTANT
  # ==================

  @doc """
  Analyzes user input and suggests the most appropriate document type and template.
  """
  def suggest_document_type(user_input, context \\ %{}) do
    # Analyze keywords, intent, and context
    suggestions = @document_types
    |> Enum.map(fn {key, config} ->
      %{
        type: key,
        config: config,
        relevance_score: calculate_relevance_score(user_input, config, context)
      }
    end)
    |> Enum.sort_by(& &1.relevance_score, :desc)
    |> Enum.take(3)

    %{
      primary_suggestion: List.first(suggestions),
      alternatives: Enum.drop(suggestions, 1),
      confidence: calculate_confidence(List.first(suggestions)),
      guided_questions: get_clarifying_questions(user_input, suggestions)
    }
  end

  @doc """
  Creates a guided workflow based on document type and user responses.
  """
  def create_guided_workflow(document_type, user_responses \\ %{}) do
    config = @document_types[document_type]

    %{
      document_type: document_type,
      workflow_steps: generate_workflow_steps(config, user_responses),
      progress_tracking: %{
        current_step: 1,
        total_steps: length(config.default_blocks),
        completion_percentage: 0
      },
      adaptive_suggestions: generate_adaptive_suggestions(config, user_responses),
      success_metrics: define_success_metrics(config)
    }
  end

  # ==================
  # ENHANCED DOCUMENT MANAGEMENT
  # ==================

  @doc """
  Creates a new document with intelligent template selection.
  """
  def create_document(attrs, user, session_id \\ nil) do
    # Determine document type if not specified
    document_type = attrs["document_type"] ||
      suggest_primary_document_type(attrs["initial_content"] || attrs["title"] || "")

    config = @document_types[document_type]

    document_attrs = %{
      title: attrs["title"] || generate_default_title(document_type),
      document_type: document_type,
      metadata: %{
        workflow: config.workflow,
        target_audience: config[:target_audience],
        recommended_length: config[:recommended_length] || config[:target_length],
        creation_context: %{
          session_id: session_id,
          guided_setup: attrs["guided_setup"] || false,
          template_version: "1.0"
        }
      },
      status: "draft",
      user_id: user.id,
      session_id: session_id,
      collaboration_settings: %{
        mode: attrs["collaboration_mode"] || "open",
        permissions: attrs["permissions"] || %{},
        branch_strategy: "hybrid"
      }
    }

    Repo.transaction(fn ->
      with {:ok, document} <- create_base_document(document_attrs),
           {:ok, _blocks} <- create_default_blocks(document, config),
           {:ok, _version} <- create_initial_version(document, user) do

        # Subscribe to real-time updates
        Phoenix.PubSub.subscribe(
          Frestyl.PubSub,
          "document:#{document.id}"
        )

        document
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def get_user_document_history(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    from(d in Document,
      where: d.user_id == ^user_id,
      order_by: [desc: d.updated_at],
      limit: ^limit,
      preload: [:blocks]
    )
    |> Repo.all()
  end

  def get_latest_version(document_id) do
    from(v in DocumentVersion,
      where: v.document_id == ^document_id,
      order_by: [desc: v.inserted_at],
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Updates document content with block-based operations and media attachments.
  """
  def update_document_content(document_id, operations, user, opts \\ []) do
    conflict_resolution = opts[:conflict_resolution] || "smart"
    create_snapshot = opts[:create_snapshot] || false

    Repo.transaction(fn ->
      document = get_document_with_blocks(document_id)

      # Apply operations with conflict detection
      {updated_blocks, conflicts} = apply_block_operations(
        document.blocks,
        operations,
        user.id
      )

      # Handle conflicts based on strategy
      resolved_blocks = case {conflicts, conflict_resolution} do
        {[], _} -> updated_blocks
        {conflicts, "smart"} -> smart_resolve_conflicts(updated_blocks, conflicts, user.id)
        {conflicts, "manual"} -> {:needs_manual_resolution, conflicts}
        {_conflicts, "last_writer_wins"} -> updated_blocks
      end

      case resolved_blocks do
        {:needs_manual_resolution, conflicts} ->
          {:error, {:conflicts, conflicts}}

        resolved_blocks ->
          # Update blocks in database
          {:ok, _} = update_document_blocks(document, resolved_blocks)

          # Create version snapshot if requested
          if create_snapshot do
            create_version_snapshot(document, user, "Content update")
          end

          # Broadcast real-time updates
          broadcast_document_update(document_id, resolved_blocks, user.id)

          {:ok, resolved_blocks}
      end
    end)
  end

  @doc """
  Adds media attachment to a specific document block.
  """
  def add_media_attachment(document_id, block_id, media_attrs, user) do
    Repo.transaction(fn ->
      with {:ok, document} <- get_document_if_accessible(document_id, user.id),
           {:ok, block} <- get_document_block(block_id),
           {:ok, media_file} <- maybe_create_media_file(media_attrs, user),
           {:ok, attachment} <- create_media_attachment(block, media_file, media_attrs) do

        # Update block metadata
        updated_metadata = Map.put(
          block.metadata || %{},
          :media_attachments,
          [attachment | (block.metadata[:media_attachments] || [])]
        )

        update_block_metadata(block, updated_metadata)

        # Broadcast update
        broadcast_media_attachment_added(document_id, block_id, attachment)

        attachment
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  # Media attachment functions
  defp maybe_create_media_file(media_attrs, user) do
    if media_attrs["file_data"] do
      Media.create_media_file(media_attrs, user, media_attrs["session_id"])
    else
      {:ok, nil}
    end
  end

  defp create_media_attachment(block, media_file, media_attrs) do
    attachment_attrs = %{
      block_id: block.id,
      media_file_id: media_file && media_file.id,
      attachment_type: media_attrs["attachment_type"] || "inline",
      relationship: media_attrs["relationship"] || "supports",
      position: media_attrs["position"] || %{},
      metadata: media_attrs["metadata"] || %{}
    }

    %MediaAttachment{}
    |> MediaAttachment.changeset(attachment_attrs)
    |> Repo.insert()
  end

  defp update_block_metadata(block, updated_metadata) do
    block
    |> DocumentBlock.changeset(%{metadata: updated_metadata})
    |> Repo.update()
  end

  defp broadcast_media_attachment_added(document_id, block_id, attachment) do
    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "document:#{document_id}",
      {:media_attachment_added, %{block_id: block_id, attachment: attachment}}
    )
  end

  @doc """
  Creates a new branch for collaborative editing.
  """
  def create_collaboration_branch(document_id, branch_name, user, opts \\ []) do
    source_version = opts[:source_version] || "latest"

    branch_attrs = %{
      document_id: document_id,
      name: branch_name,
      created_by_id: user.id,
      source_version: source_version,
      status: "active",
      metadata: %{
        purpose: opts[:purpose] || "collaboration",
        access_level: opts[:access_level] || "collaborator"
      }
    }

    %CollaborationBranch{}
    |> CollaborationBranch.changeset(branch_attrs)
    |> Repo.insert()
  end

  @doc """
  Merges a collaboration branch back to main with smart conflict resolution.
  """
  def merge_collaboration_branch(branch_id, user, merge_strategy \\ "smart") do
    Repo.transaction(fn ->
      with {:ok, branch} <- get_collaboration_branch(branch_id),
           {:ok, conflicts} <- detect_merge_conflicts(branch),
           {:ok, resolution} <- resolve_merge_conflicts(conflicts, merge_strategy, user),
           {:ok, merged_document} <- apply_merge_resolution(branch, resolution) do

        # Update branch status
        update_branch_status(branch, "merged")

        # Create merge commit
        create_merge_version(merged_document, branch, user)

        # Notify collaborators
        notify_branch_merged(branch, user)

        merged_document
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp get_document_if_accessible(document_id, user_id) do
    case Repo.get(Document, document_id) do
      nil -> {:error, :not_found}
      document ->
        # Add access control logic here if needed
        {:ok, document}
    end
  end

  defp get_document_block(block_id) do
    case Repo.get(DocumentBlock, block_id) do
      nil -> {:error, :not_found}
      block -> {:ok, block}
    end
  end

  defp get_document_with_blocks(document_id) do
    Repo.get!(Document, document_id)
    |> Repo.preload([:blocks, :media_attachments])
  end

  @doc """
  Gets document data optimized for mobile editing.
  """
  def get_document_for_mobile(document_id, user_id) do
    document = get_document_with_blocks(document_id)

    %{
      document: document,
      mobile_config: %{
        toolbar_mode: "contextual",
        gesture_controls: true,
        voice_input: true,
        offline_capability: true,
        smart_suggestions: true
      },
      editing_context: %{
        active_block: nil,
        selection: nil,
        collaborative_cursors: get_collaborative_cursors(document_id),
        pending_operations: []
      },
      media_integration: %{
        camera_access: true,
        audio_recording: true,
        quick_upload: true,
        ai_transcription: true
      }
    }
  end

  # Document workflow and suggestion functions
  defp suggest_primary_document_type(input_text) do
    keywords = String.downcase(input_text)

    cond do
      String.contains?(keywords, ["blog", "article", "post"]) -> "blog_post"
      String.contains?(keywords, ["book", "chapter", "novel"]) -> "book_chapter"
      String.contains?(keywords, ["script", "screenplay", "film"]) -> "screenplay"
      String.contains?(keywords, ["poem", "poetry", "verse"]) -> "poetry"
      String.contains?(keywords, ["research", "paper", "academic"]) -> "academic_paper"
      String.contains?(keywords, ["story", "fiction", "tale"]) -> "short_story"
      true -> "plain_text"
    end
  end

  defp generate_default_title(document_type) do
    case document_type do
      "blog_post" -> "Untitled Blog Post"
      "book_chapter" -> "Untitled Chapter"
      "screenplay" -> "Untitled Screenplay"
      "poetry" -> "Untitled Poem"
      "academic_paper" -> "Untitled Research Paper"
      "short_story" -> "Untitled Story"
      _ -> "Untitled Document"
    end
  end

  defp get_clarifying_questions(user_input, suggestions) do
    case List.first(suggestions) do
      %{type: "blog_post"} -> [
        "What's the main topic or theme?",
        "Who is your target audience?",
        "What's the key takeaway for readers?"
      ]
      %{type: "book_chapter"} -> [
        "What genre is your book?",
        "What happens in this chapter?",
        "Which characters are featured?"
      ]
      %{type: "screenplay"} -> [
        "What genre is your screenplay?",
        "What's the central conflict?",
        "Who are the main characters?"
      ]
      _ -> [
        "What's the main purpose of this document?",
        "Who will be reading this?",
        "What key points do you want to cover?"
      ]
    end
  end

  defp calculate_confidence(suggestion) do
    # Simple confidence calculation based on keyword matches
    if suggestion, do: 85, else: 50
  end

  # Workflow generation functions
  defp generate_adaptive_suggestions(config, user_responses) do
    base_suggestions = config[:suggestions] || []

    # Customize suggestions based on user responses
    Enum.map(base_suggestions, fn suggestion ->
      case user_responses["experience_level"] do
        "beginner" -> Map.put(suggestion, :detail_level, "high")
        "advanced" -> Map.put(suggestion, :detail_level, "low")
        _ -> suggestion
      end
    end)
  end

  defp define_success_metrics(config) do
    document_type = config[:document_type]

    case document_type do
      "blog_post" -> %{
        word_count: {800, 2000},
        readability_score: 60,
        sections_completed: ["introduction", "body", "conclusion"]
      }
      "book_chapter" -> %{
        word_count: {2000, 5000},
        character_development: true,
        plot_advancement: true
      }
      "screenplay" -> %{
        page_count: {1, 10},
        scene_count: {1, 5},
        character_arcs: true
      }
      _ -> %{
        word_count: {500, 1500},
        structure_complete: true
      }
    end
  end

  # Step generation functions
  defp format_step_title(block_type) do
    case block_type do
      "title" -> "Write Your Title"
      "subtitle" -> "Add a Subtitle"
      "paragraph" -> "Write Body Content"
      "heading" -> "Create Section Heading"
      "quote" -> "Add a Quote"
      "code" -> "Insert Code Block"
      _ -> "Complete This Section"
    end
  end

  defp get_step_guidance(block_type, config) do
    case block_type do
      "title" -> "Create a compelling title that captures your main idea. Keep it concise but descriptive."
      "subtitle" -> "Add a subtitle that provides more context or hooks the reader."
      "paragraph" -> "Write your main content here. Focus on one key idea per paragraph."
      "heading" -> "Use headings to organize your content and guide readers through your ideas."
      "quote" -> "Include relevant quotes to support your points or add authority to your content."
      "code" -> "Add code examples with proper formatting and clear explanations."
      _ -> "Complete this section with relevant content."
    end
  end

  defp estimate_step_time(block_type) do
    case block_type do
      "title" -> 5
      "subtitle" -> 3
      "paragraph" -> 15
      "heading" -> 2
      "quote" -> 5
      "code" -> 20
      _ -> 10
    end
  end

  defp get_step_examples(block_type, config) do
    case block_type do
      "title" -> [
        "How to Build Better Apps with Phoenix LiveView",
        "The Complete Guide to Collaborative Writing",
        "10 Tips for Effective Team Communication"
      ]
      "paragraph" -> [
        "Start with a clear topic sentence that introduces your main point...",
        "Use concrete examples to illustrate abstract concepts...",
        "Connect your ideas with smooth transitions between paragraphs..."
      ]
      _ -> []
    end
  end

  defp calculate_relevance_score(user_input, config, context) do
    keywords = extract_keywords(user_input)

    # Score based on various factors
    keyword_score = calculate_keyword_relevance(keywords, config)
    context_score = calculate_context_relevance(context, config)
    intent_score = calculate_intent_relevance(user_input, config)

    # Weighted average
    (keyword_score * 0.4) + (context_score * 0.3) + (intent_score * 0.3)
  end

  defp calculate_keyword_relevance(keywords, config) do
    config_keywords = [
      config.name,
      config.description,
      config.category,
      config[:target_audience]
    ]
    |> Enum.filter(& &1)
    |> Enum.join(" ")
    |> String.downcase()
    |> String.split()

    overlap = MapSet.intersection(
      MapSet.new(keywords),
      MapSet.new(config_keywords)
    )

    MapSet.size(overlap) / max(length(keywords), 1) * 100
  end

  defp extract_keywords(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^\w\s]/, "")
    |> String.split()
    |> Enum.filter(&(String.length(&1) > 2))
  end

  defp generate_workflow_steps(config, user_responses) do
    config.default_blocks
    |> Enum.with_index()
    |> Enum.map(fn {block, index} ->
      %{
        step: index + 1,
        block_type: block.type,
        title: format_step_title(block.type),
        description: block[:placeholder] || "",
        required: !block[:optional],
        guidance: get_step_guidance(block.type, config),
        estimated_time: estimate_step_time(block.type),
        examples: get_step_examples(block.type, config)
      }
    end)
  end

  defp create_base_document(attrs) do
    %Document{}
    |> Document.changeset(attrs)
    |> Repo.insert()
  end

  defp create_default_blocks(document, config) do
    config.default_blocks
    |> Enum.with_index()
    |> Enum.map(fn {block_config, index} ->
      block_attrs = %{
        document_id: document.id,
        block_type: block_config.type,
        content: block_config[:content] || "",
        position: index,
        metadata: %{
          placeholder: block_config[:placeholder],
          required: !block_config[:optional],
          max_words: block_config[:max_words]
        }
      }

      %DocumentBlock{}
      |> DocumentBlock.changeset(block_attrs)
      |> Repo.insert()
    end)
    |> Enum.reduce({:ok, []}, fn
      {:ok, block}, {:ok, acc} -> {:ok, [block | acc]}
      {:error, reason}, _ -> {:error, reason}
      _, {:error, reason} -> {:error, reason}
    end)
  end

  defp create_initial_version(document, user) do
    version_attrs = %{
      document_id: document.id,
      version_number: "1.0.0",
      created_by_id: user.id,
      message: "Initial document creation",
      is_major: true,
      metadata: %{
        blocks_checksum: calculate_blocks_checksum(document.id),
        word_count: 0,
        creation_method: "guided_template"
      }
    }

    %DocumentVersion{}
    |> DocumentVersion.changeset(version_attrs)
    |> Repo.insert()
  end

  defp broadcast_document_update(document_id, blocks, user_id) do
    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "document:#{document_id}",
      {:document_updated, %{blocks: blocks, user_id: user_id}}
    )
  end

  # Mobile-specific functions
  defp get_collaborative_cursors(document_id) do
    # Return cursor positions for collaborative editing
    # This would integrate with your Presence system
    %{}
  end

  # Block operations and conflict resolution
  defp apply_block_operations(document, operations, user_id) do
    # Apply operations to blocks and detect conflicts
    updated_blocks = Enum.reduce(operations, document.blocks, fn operation, blocks ->
      apply_single_operation(blocks, operation, user_id)
    end)

    conflicts = detect_block_conflicts(document.blocks, updated_blocks, operations)
    {updated_blocks, conflicts}
  end

  defp apply_single_operation(blocks, operation, user_id) do
    case operation.type do
      "enhanced_update" ->
        Enum.map(blocks, fn block ->
          if block.id == operation.block_id do
            %{block | content: operation.content, updated_at: DateTime.utc_now()}
          else
            block
          end
        end)

      "block_insert" ->
        new_block = %DocumentBlock{
          id: Ecto.UUID.generate(),
          block_type: operation.block_type || "paragraph",
          content: operation.content,
          position: operation.position,
          document_id: operation.document_id
        }
        insert_block_at_position(blocks, new_block, operation.position)

      "block_delete" ->
        Enum.reject(blocks, &(&1.id == operation.block_id))

      _ ->
        blocks
    end
  end

  defp detect_block_conflicts(original_blocks, updated_blocks, operations) do
    # Simple conflict detection - you can make this more sophisticated
    []
  end

  defp smart_resolve_conflicts(updated_blocks, conflicts, user_id) do
    # Implement smart conflict resolution logic
    updated_blocks
  end

  defp update_document_blocks(document, blocks) do
    # Update blocks in the database
    Enum.each(blocks, fn block ->
      if block.id do
        Repo.update(DocumentBlock.changeset(block, %{}))
      else
        Repo.insert(DocumentBlock.changeset(%DocumentBlock{}, Map.from_struct(block)))
      end
    end)

    {:ok, blocks}
  end

  # Version control functions
  defp create_version_snapshot(document, user, message) do
    version_attrs = %{
      document_id: document.id,
      version_number: generate_version_number(document.id),
      created_by_id: user.id,
      message: message,
      is_major: false,
      metadata: %{
        blocks_count: length(document.blocks),
        word_count: calculate_word_count(document.blocks),
        created_at: DateTime.utc_now()
      }
    }

    %DocumentVersion{}
    |> DocumentVersion.changeset(version_attrs)
    |> Repo.insert()
  end

  defp generate_version_number(document_id) do
    last_version = Repo.one(
      from v in DocumentVersion,
      where: v.document_id == ^document_id,
      order_by: [desc: v.inserted_at],
      limit: 1
    )

    case last_version do
      nil -> "1.0.0"
      %{version_number: version} -> increment_version(version)
    end
  end

  defp increment_version(version_string) do
    [major, minor, patch] = String.split(version_string, ".") |> Enum.map(&String.to_integer/1)
    "#{major}.#{minor}.#{patch + 1}"
  end

  defp calculate_blocks_checksum(document_id) do
    blocks = Repo.all(from b in DocumentBlock, where: b.document_id == ^document_id)
    content = Enum.map(blocks, & &1.content) |> Enum.join("")
    :crypto.hash(:md5, content) |> Base.encode16()
  end

  defp calculate_word_count(blocks) do
    blocks
    |> Enum.map(&(&1.content || ""))
    |> Enum.join(" ")
    |> String.split()
    |> length()
  end

  # Collaboration branch functions
  defp get_collaboration_branch(branch_id) do
    case Repo.get(CollaborationBranch, branch_id) do
      nil -> {:error, :not_found}
      branch -> {:ok, branch}
    end
  end

  defp detect_merge_conflicts(branch) do
    # Implement conflict detection logic
    {:ok, []}
  end

  defp resolve_merge_conflicts(conflicts, strategy, user) do
    # Implement conflict resolution
    {:ok, %{strategy: strategy, resolved_by: user.id}}
  end

  defp apply_merge_resolution(branch, resolution) do
    # Apply the merge resolution
    document = get_document_with_blocks(branch.document_id)
    {:ok, document}
  end

  defp update_branch_status(branch, status) do
    branch
    |> CollaborationBranch.changeset(%{status: status})
    |> Repo.update()
  end

  defp create_merge_version(document, branch, user) do
    create_version_snapshot(document, user, "Merged branch: #{branch.name}")
  end

  defp notify_branch_merged(branch, user) do
    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "document:#{branch.document_id}",
      {:branch_merged, %{branch: branch, user: user}}
    )
  end

  # Relevance calculation functions
  defp calculate_context_relevance(context, config) do
    # Calculate how well the context matches the document type
    50 # Default score
  end

  defp calculate_intent_relevance(user_input, config) do
    # Calculate how well user intent matches document type
    50 # Default score
  end

  # Helper function for inserting blocks at position
  defp insert_block_at_position(blocks, new_block, position) do
    {before, after_blocks} = Enum.split(blocks, position)
    before ++ [new_block] ++ after_blocks
  end

  def list_published_content(account, filters \\ %{}) do
    from(d in Document,
      join: s in Syndication, on: s.document_id == d.id,
      where: s.account_id == ^account.id and s.syndication_status == "published",
      order_by: [desc: s.syndicated_at],
      preload: [:sections, syndications: s]
    )
    |> apply_content_filters(filters)
    |> Repo.all()
  end

  def get_published_content(document_id, account) do
    from(d in Document,
      join: s in Syndication, on: s.document_id == d.id,
      where: d.id == ^document_id and s.account_id == ^account.id,
      preload: [:sections, syndications: s]
    )
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      document -> {:ok, document}
    end
  end

  def get_document_for_collaboration(document_id, account) do
    from(d in Document,
      join: s in Syndication, on: s.document_id == d.id,
      where: d.id == ^document_id and s.account_id == ^account.id,
      preload: [:sections, :collaboration_campaign],
      distinct: d.id
    )
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      document -> {:ok, document}
    end
  end

  defp apply_content_filters(query, filters) when map_size(filters) == 0, do: query
  defp apply_content_filters(query, filters) do
    Enum.reduce(filters, query, fn {key, value}, acc ->
      case key do
        :status -> where(acc, [d], d.publish_status == ^value)
        :platform -> where(acc, [d, s], s.platform == ^value)
        _ -> acc
      end
    end)
  end

    @doc """
  Gets featured collaborations for Frestyl Official discovery feed.
  """
  def get_featured_collaborations(opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)

    # Mock data - replace with actual collaboration tracking
    [
      %{
        id: 1,
        title: "Music Video Collaboration",
        description: "Indie artist seeking videographer for music video project",
        type: "Creative Partnership",
        emoji: "🎬",
        participants_count: 3,
        created_at: DateTime.utc_now(),
        genres: ["music_audio", "video_film"],
        collaboration_type: "co_creation"
      },
      %{
        id: 2,
        title: "React App Development",
        description: "Frontend developer looking for backend partner",
        type: "Technical Collaboration",
        emoji: "💻",
        participants_count: 2,
        created_at: DateTime.add(DateTime.utc_now(), -3600, :second),
        genres: ["tech_development"],
        collaboration_type: "pair_programming"
      },
      %{
        id: 3,
        title: "Podcast Co-hosting",
        description: "Marketing podcast seeks co-host with business expertise",
        type: "Content Collaboration",
        emoji: "🎙️",
        participants_count: 5,
        created_at: DateTime.add(DateTime.utc_now(), -7200, :second),
        genres: ["business_finance", "writing_content"],
        collaboration_type: "co_creation"
      },
      %{
        id: 4,
        title: "Children's Book Illustration",
        description: "Author seeking illustrator for picture book series",
        type: "Creative Partnership",
        emoji: "📚",
        participants_count: 2,
        created_at: DateTime.add(DateTime.utc_now(), -10800, :second),
        genres: ["writing_content", "visual_arts"],
        collaboration_type: "co_creation"
      },
      %{
        id: 5,
        title: "Language Exchange Circle",
        description: "Spanish-English conversation practice group",
        type: "Learning Partnership",
        emoji: "🗣️",
        participants_count: 8,
        created_at: DateTime.add(DateTime.utc_now(), -14400, :second),
        genres: ["languages_communication"],
        collaboration_type: "language_exchange"
      }
    ]
    |> Enum.take(limit)
  end

  @doc """
  Gets channel spotlights for discovery feed.
  """
  def get_channel_spotlights(opts \\ []) do
    limit = Keyword.get(opts, :limit, 3)

    # Mock data - replace with actual channel analytics
    [
      %{
        id: 1,
        name: "UI/UX Designers Hub",
        description: "Community for user experience and interface designers",
        member_count: "2.1k",
        activity_level: "high",
        growth_rate: "+15% this week",
        genres: ["visual_arts", "tech_development"],
        featured_reason: "Most active design community"
      },
      %{
        id: 2,
        name: "JavaScript Learners",
        description: "Learn JavaScript through collaboration and peer support",
        member_count: "4.7k",
        activity_level: "very_high",
        growth_rate: "+22% this week",
        genres: ["tech_development"],
        featured_reason: "Excellent beginner support"
      },
      %{
        id: 3,
        name: "Indie Music Producers",
        description: "Independent musicians collaborating and sharing techniques",
        member_count: "1.8k",
        activity_level: "high",
        growth_rate: "+18% this week",
        genres: ["music_audio"],
        featured_reason: "High-quality collaborations"
      },
      %{
        id: 4,
        name: "Food Photography Masters",
        description: "Culinary artists perfecting food photography and styling",
        member_count: "956",
        activity_level: "moderate",
        growth_rate: "+12% this week",
        genres: ["food_culinary", "visual_arts"],
        featured_reason: "Stunning portfolio showcases"
      },
      %{
        id: 5,
        name: "Startup Founders Circle",
        description: "Entrepreneurs sharing insights and building together",
        member_count: "3.2k",
        activity_level: "high",
        growth_rate: "+25% this week",
        genres: ["business_finance"],
        featured_reason: "High-value networking"
      }
    ]
    |> Enum.take(limit)
  end

  @doc """
  Gets latest platform news for Frestyl Official.
  """
  def get_latest_platform_news(opts \\ []) do
    limit = Keyword.get(opts, :limit, 3)

    # Mock data - replace with actual CMS/news system
    [
      %{
        id: 1,
        title: "New Collaboration Tools Released",
        summary: "Real-time editing and video chat now available in all channels",
        published_at: DateTime.add(DateTime.utc_now(), -86400, :second),
        type: "feature_release",
        author: "Frestyl Team",
        read_time: "2 min read"
      },
      %{
        id: 2,
        title: "Community Challenge: #30DaysOfCreativity",
        summary: "Join thousands of creators in our month-long creative challenge",
        published_at: DateTime.add(DateTime.utc_now(), -172800, :second),
        type: "community_event",
        author: "Community Team",
        read_time: "3 min read"
      },
      %{
        id: 3,
        title: "Genre-Based Channel Discovery Now Live",
        summary: "Find channels and collaborators based on your interests and skills",
        published_at: DateTime.add(DateTime.utc_now(), -259200, :second),
        type: "feature_release",
        author: "Product Team",
        read_time: "4 min read"
      },
      %{
        id: 4,
        title: "Creator Spotlight: Sarah's Design Journey",
        summary: "How one designer built a community of 500+ collaborators",
        published_at: DateTime.add(DateTime.utc_now(), -345600, :second),
        type: "creator_spotlight",
        author: "Editorial Team",
        read_time: "5 min read"
      }
    ]
    |> Enum.take(limit)
  end

  @doc """
  Gets trending projects for discovery feed.
  """
  def get_trending_projects(opts \\ []) do
    limit = Keyword.get(opts, :limit, 6)

    # Mock data - replace with actual portfolio/project analytics
    [
      %{
        id: 1,
        title: "Minimalist Portfolio Design",
        description: "Clean, modern portfolio showcasing UX design work",
        thumbnail_url: "https://via.placeholder.com/300x200",
        creator: %{name: "Sarah Chen", avatar_url: "https://via.placeholder.com/40x40"},
        views_count: "1.2k",
        likes_count: 89,
        created_at: DateTime.utc_now(),
        genres: ["visual_arts"],
        collaboration_opportunities: ["design_review", "portfolio_feedback"]
      },
      %{
        id: 2,
        title: "AI-Powered Music Generator",
        description: "Machine learning project that creates original melodies",
        thumbnail_url: "https://via.placeholder.com/300x200",
        creator: %{name: "Marcus Johnson", avatar_url: "https://via.placeholder.com/40x40"},
        views_count: "3.4k",
        likes_count: 156,
        created_at: DateTime.add(DateTime.utc_now(), -3600, :second),
        genres: ["tech_development", "music_audio"],
        collaboration_opportunities: ["code_review", "music_collaboration"]
      },
      %{
        id: 3,
        title: "Sustainable Living Blog",
        description: "Weekly posts about zero-waste lifestyle and eco-friendly tips",
        thumbnail_url: "https://via.placeholder.com/300x200",
        creator: %{name: "Emma Rodriguez", avatar_url: "https://via.placeholder.com/40x40"},
        views_count: "2.8k",
        likes_count: 203,
        created_at: DateTime.add(DateTime.utc_now(), -7200, :second),
        genres: ["writing_content", "sustainability_environment"],
        collaboration_opportunities: ["co_writing", "guest_posting"]
      },
      %{
        id: 4,
        title: "Indie Game Development Showcase",
        description: "2D platformer built with Unity, looking for feedback",
        thumbnail_url: "https://via.placeholder.com/300x200",
        creator: %{name: "Alex Kim", avatar_url: "https://via.placeholder.com/40x40"},
        views_count: "956",
        likes_count: 67,
        created_at: DateTime.add(DateTime.utc_now(), -10800, :second),
        genres: ["gaming_interactive", "tech_development"],
        collaboration_opportunities: ["game_testing", "art_collaboration"]
      },
      %{
        id: 5,
        title: "Culinary Adventures Series",
        description: "Exploring international cuisines with detailed recipe guides",
        thumbnail_url: "https://via.placeholder.com/300x200",
        creator: %{name: "Chef Maria Santos", avatar_url: "https://via.placeholder.com/40x40"},
        views_count: "1.7k",
        likes_count: 134,
        created_at: DateTime.add(DateTime.utc_now(), -14400, :second),
        genres: ["food_culinary", "writing_content"],
        collaboration_opportunities: ["recipe_exchange", "cooking_videos"]
      },
      %{
        id: 6,
        title: "Language Learning App Prototype",
        description: "React Native app for Spanish conversation practice",
        thumbnail_url: "https://via.placeholder.com/300x200",
        creator: %{name: "David Wilson", avatar_url: "https://via.placeholder.com/40x40"},
        views_count: "1.1k",
        likes_count: 78,
        created_at: DateTime.add(DateTime.utc_now(), -18000, :second),
        genres: ["tech_development", "languages_communication"],
        collaboration_opportunities: ["app_testing", "language_exchange"]
      }
    ]
    |> Enum.take(limit)
  end

  @doc """
  Gets popular learning content for discovery feed.
  """
  def get_popular_learning_content(opts \\ []) do
    limit = Keyword.get(opts, :limit, 4)

    # Mock data - replace with actual learning content tracking
    [
      %{
        id: 1,
        title: "Figma to React: Complete Workflow",
        description: "Learn how to convert designs into working React components",
        difficulty_level: "Intermediate",
        duration: "2 hours",
        type: "workshop",
        instructor: "Design Systems Team",
        participants_count: 89,
        rating: 4.8,
        genres: ["visual_arts", "tech_development"]
      },
      %{
        id: 2,
        title: "Music Theory for Producers",
        description: "Essential music theory concepts for electronic music production",
        difficulty_level: "Beginner",
        duration: "1.5 hours",
        type: "course",
        instructor: "Producer Collective",
        participants_count: 156,
        rating: 4.6,
        genres: ["music_audio"]
      },
      %{
        id: 3,
        title: "Entrepreneurship Basics",
        description: "Fundamentals of starting and growing a business",
        difficulty_level: "Beginner",
        duration: "3 hours",
        type: "course",
        instructor: "Startup Mentors",
        participants_count: 203,
        rating: 4.7,
        genres: ["business_finance"]
      },
      %{
        id: 4,
        title: "Food Photography Masterclass",
        description: "Professional techniques for shooting and editing food photos",
        difficulty_level: "Intermediate",
        duration: "2.5 hours",
        type: "masterclass",
        instructor: "Culinary Photographers",
        participants_count: 67,
        rating: 4.9,
        genres: ["food_culinary", "visual_arts"]
      },
      %{
        id: 5,
        title: "Spanish Conversation Bootcamp",
        description: "Intensive speaking practice for intermediate learners",
        difficulty_level: "Intermediate",
        duration: "4 weeks",
        type: "bootcamp",
        instructor: "Language Exchange Hub",
        participants_count: 124,
        rating: 4.5,
        genres: ["languages_communication"]
      }
    ]
    |> Enum.take(limit)
  end

  @doc """
  Gets active community challenges for discovery feed.
  """
  def get_active_community_challenges(opts \\ []) do
    limit = Keyword.get(opts, :limit, 3)

    # Mock data - replace with actual challenge system
    [
      %{
        id: 1,
        title: "#30DaysOfCode",
        description: "Code something new every day for 30 days",
        participants_count: 892,
        days_remaining: 12,
        type: "coding_challenge",
        prize: "Featured portfolio spotlight",
        difficulty: "All levels",
        genres: ["tech_development"]
      },
      %{
        id: 2,
        title: "Logo Design Sprint",
        description: "Design 5 logos in 5 days with daily feedback",
        participants_count: 234,
        days_remaining: 3,
        type: "design_challenge",
        prize: "Design mentorship session",
        difficulty: "Intermediate",
        genres: ["visual_arts"]
      },
      %{
        id: 3,
        title: "Recipe Remix Challenge",
        description: "Recreate classic dishes with a modern twist",
        participants_count: 167,
        days_remaining: 8,
        type: "culinary_challenge",
        prize: "Cookbook feature",
        difficulty: "All levels",
        genres: ["food_culinary"]
      },
      %{
        id: 4,
        title: "Micro-Fiction Marathon",
        description: "Write a complete story in under 100 words daily",
        participants_count: 445,
        days_remaining: 15,
        type: "writing_challenge",
        prize: "Writing workshop access",
        difficulty: "All levels",
        genres: ["writing_content"]
      }
    ]
    |> Enum.take(limit)
  end

  @doc """
  Tracks user dismissal of discovery content for better recommendations.
  """
  def track_user_dismissal(user_id, item_id, item_type) do
    # Track user dismissals to improve recommendations
    # This would typically go to an analytics system or database

    dismissal_data = %{
      user_id: user_id,
      item_id: item_id,
      item_type: item_type,
      dismissed_at: DateTime.utc_now(),
      reason: "user_dismissed" # Could be expanded to capture reasons
    }

    # For now, just log it - replace with actual tracking system
    require Logger
    Logger.info("User #{user_id} dismissed #{item_type} #{item_id}")

    # Could store in database table:
    # %UserDismissal{}
    # |> UserDismissal.changeset(dismissal_data)
    # |> Repo.insert()

    :ok
  end

  @doc """
  Gets personalized content based on user's genre interests.
  """
  def get_personalized_discovery_content(user_interests, opts \\ []) do
    if user_interests && user_interests.genres do
      # Filter content by user's selected genres
      %{
        featured_collaborations: filter_by_genres(get_featured_collaborations(), user_interests.genres),
        channel_spotlights: filter_by_genres(get_channel_spotlights(), user_interests.genres),
        platform_news: get_latest_platform_news(opts), # News is universal
        trending_projects: filter_by_genres(get_trending_projects(), user_interests.genres),
        learning_opportunities: filter_by_genres(get_popular_learning_content(), user_interests.genres),
        community_challenges: filter_by_genres(get_active_community_challenges(), user_interests.genres)
      }
    else
      # Default content for users without interests
      %{
        featured_collaborations: get_featured_collaborations(opts),
        channel_spotlights: get_channel_spotlights(opts),
        platform_news: get_latest_platform_news(opts),
        trending_projects: get_trending_projects(opts),
        learning_opportunities: get_popular_learning_content(opts),
        community_challenges: get_active_community_challenges(opts)
      }
    end
  end

  @doc """
  Filters content items by matching genres.
  """
  defp filter_by_genres(content_items, user_genres) do
    content_items
    |> Enum.filter(fn item ->
      item_genres = Map.get(item, :genres, [])
      # Show item if any of its genres match user's interests
      Enum.any?(item_genres, &(&1 in user_genres))
    end)
    |> case do
      [] -> Enum.take(content_items, 2) # If no matches, show some default content
      filtered -> filtered
    end
  end

  @doc """
  Gets discovery content with enhanced metadata for analytics.
  """
  def get_discovery_content_with_analytics(user_id, user_interests \\ nil) do
    content = get_personalized_discovery_content(user_interests)

    # Add analytics metadata
    %{
      content: content,
      analytics: %{
        user_id: user_id,
        generated_at: DateTime.utc_now(),
        personalization_applied: !is_nil(user_interests),
        content_counts: %{
          collaborations: length(content.featured_collaborations),
          channels: length(content.channel_spotlights),
          news: length(content.platform_news),
          projects: length(content.trending_projects),
          learning: length(content.learning_opportunities),
          challenges: length(content.community_challenges)
        }
      }
    }
  end
end
