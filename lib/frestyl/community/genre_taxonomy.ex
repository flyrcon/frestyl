defmodule Frestyl.Community.GenreTaxonomy do
  @moduledoc """
  Comprehensive genre and interest taxonomy system for Frestyl community channels.
  Built to be stable and extensible without frequent major revisions.
  """

  # Base taxonomy structure - designed for longevity and collaboration
  @genre_taxonomy %{
    # CREATIVE MEDIA & ARTS
    "music_audio" => %{
      name: "Music & Audio",
      description: "Music creation, instrument learning, and audio collaboration",
      sub_genres: [
        # Genre-based music
        "electronic_music", "hip_hop_rap", "rock_alternative", "pop_dance",
        "jazz_blues", "classical_orchestral", "folk_acoustic", "world_music",
        "ambient_experimental", "metal_hardcore", "country_americana",
        "r_b_soul", "reggae_ska", "punk_hardcore", "lo_fi_beats",

        # Instrument learning & performance
        "guitar_learning", "piano_keyboard", "drums_percussion", "vocals_singing",
        "bass_guitar", "violin_strings", "wind_instruments", "electronic_instruments",
        "music_theory", "sight_reading", "ear_training", "improvisation",

        # Collaborative activities
        "songwriting", "co_writing", "music_production", "co_producing",
        "beat_making", "remix_collaboration", "band_formation", "jam_sessions",
        "mixing_mastering", "sound_design", "audio_engineering",

        # Audio content
        "podcast_creation", "voice_over", "audio_drama", "audiobook_narration",
        "field_recording", "foley_art", "radio_production"
      ],
      skill_levels: ["beginner", "learning", "intermediate", "advanced", "professional"],
      collaboration_types: ["learning_together", "teaching", "co_creating", "feedback_exchange", "performance_groups"],
      tools: ["daw", "instruments", "microphones", "audio_interfaces", "synthesizers", "notation_software"]
    },
    # HEALTH & FITNESS
    "health_fitness" => %{
      name: "Health & Fitness",
      description: "Physical fitness, wellness, and health optimization",
      sub_genres: [
        # Fitness activities
        "strength_training", "powerlifting", "bodybuilding", "crossfit", "calisthenics",
        "cardio_fitness", "running", "cycling", "swimming", "triathlon", "marathon_training",
        "yoga", "pilates", "martial_arts", "boxing", "mma", "dance_fitness",
        "rock_climbing", "hiking", "outdoor_fitness", "sports_training",

        # Health & nutrition
        "nutrition_science", "meal_planning", "healthy_cooking", "weight_management",
        "muscle_building", "fat_loss", "specialized_diets", "sports_nutrition",
        "supplement_science", "metabolic_health", "longevity", "biohacking",

        # Mental wellness
        "meditation", "mindfulness", "stress_management", "sleep_optimization",
        "habit_formation", "mental_health", "therapy_support", "addiction_recovery",

        # Collaborative fitness
        "workout_partners", "training_groups", "fitness_challenges", "accountability_partners",
        "running_groups", "cycling_clubs", "hiking_groups", "sports_teams"
      ],
      skill_levels: ["beginner", "developing", "intermediate", "advanced", "expert"],
      collaboration_types: ["workout_partners", "training_groups", "support_circles", "challenge_groups", "accountability_partnerships"],
      tools: ["myfitnesspal", "strava", "fitbit", "garmin", "headspace", "cronometer", "strong_app"]
    },

    # SPORTS & ATHLETICS
    "sports_athletics" => %{
      name: "Sports & Athletics",
      description: "Sports discussion, fandom, analysis, and athletic pursuits",
      sub_genres: [
        # Major sports
        "football_nfl", "basketball_nba", "baseball_mlb", "hockey_nhl", "soccer_football",
        "tennis", "golf", "boxing", "mma_ufc", "wrestling", "track_field", "swimming",
        "gymnastics", "volleyball", "cricket", "rugby", "formula1", "nascar",

        # College & amateur sports
        "college_football", "college_basketball", "high_school_sports", "youth_sports",
        "amateur_athletics", "olympic_sports", "paralympics",

        # Fantasy & analysis
        "fantasy_sports", "sports_betting", "sports_analytics", "draft_analysis",
        "trade_discussions", "salary_cap_analysis", "sports_statistics",

        # Discussion topics
        "goat_debates", "historical_comparisons", "team_rivalries", "player_analysis",
        "coaching_strategies", "sports_culture", "athlete_interviews", "sports_media",

        # Recreational sports
        "pickup_games", "local_leagues", "recreational_sports", "sports_clubs"
      ],
      skill_levels: ["casual_fan", "dedicated_fan", "amateur_player", "serious_athlete", "expert_analyst"],
      collaboration_types: ["fan_discussions", "analysis_groups", "fantasy_leagues", "pickup_organizers", "debate_clubs"],
      tools: ["espn", "fantasy_apps", "stats_websites", "sports_podcasts", "team_apps"]
    },

        # ENTERTAINMENT & MEDIA
    "entertainment_media" => %{
      name: "Entertainment & Media",
      description: "Movies, TV, music, books, and entertainment culture discussion",
      sub_genres: [
        # Film & television
        "movies", "tv_shows", "documentaries", "streaming_content", "film_analysis",
        "movie_reviews", "tv_recaps", "film_theory", "cinematography", "screenwriting_analysis",
        "horror_films", "sci_fi", "fantasy", "comedy", "drama", "action_films",
        "international_cinema", "indie_films", "classic_movies", "film_festivals",

        # Music discussion
        "music_discovery", "album_reviews", "concert_reviews", "music_history",
        "genre_discussions", "artist_analysis", "vinyl_collecting", "live_music",
        "music_theory_discussion", "production_techniques", "music_industry",

        # Literature & books
        "book_discussions", "book_clubs", "literary_analysis", "author_discussions",
        "genre_fiction", "non_fiction", "poetry_discussion", "book_reviews",
        "reading_recommendations", "publishing_industry", "literary_criticism",

        # Gaming culture
        "video_game_discussion", "game_reviews", "gaming_industry", "esports_discussion",
        "retro_gaming", "game_development_discussion", "gaming_culture", "speedrunning",

        # Pop culture
        "celebrity_culture", "awards_shows", "entertainment_news", "fandoms",
        "memes", "internet_culture", "social_media_trends", "influencer_culture"
      ],
      skill_levels: ["casual_consumer", "enthusiast", "serious_fan", "critic", "industry_professional"],
      collaboration_types: ["discussion_groups", "review_circles", "fan_communities", "analysis_groups", "recommendation_networks"],
      tools: ["goodreads", "letterboxd", "spotify", "netflix", "imdb", "podcast_apps"]
    },

    # CURRENT EVENTS & SOCIETY
    "current_events_society" => %{
      name: "Current Events & Society",
      description: "News, social issues, philosophy, and contemporary discourse",
      sub_genres: [
        # News & current events
        "breaking_news", "political_news", "international_news", "local_news",
        "economic_news", "technology_news", "science_news", "health_news",
        "environmental_news", "social_issues", "human_rights", "civil_rights",

        # Philosophy & ideas
        "philosophy", "ethics", "moral_philosophy", "political_philosophy",
        "existentialism", "stoicism", "eastern_philosophy", "religious_studies",
        "theology", "atheism", "agnosticism", "spirituality", "meditation_philosophy",

        # Social commentary
        "social_justice", "inequality", "systemic_issues", "cultural_analysis",
        "generational_differences", "urban_planning", "sociology", "anthropology",
        "psychology_discussion", "behavior_analysis", "social_media_impact",

        # Intellectual discourse
        "debate", "critical_thinking", "logical_reasoning", "fact_checking",
        "media_literacy", "information_analysis", "conspiracy_theories", "misinformation"
      ],
      skill_levels: ["curious_citizen", "informed_participant", "active_discussant", "subject_expert", "thought_leader"],
      collaboration_types: ["discussion_forums", "debate_groups", "study_circles", "book_clubs", "think_tanks"],
      tools: ["news_apps", "fact_checking_sites", "debate_platforms", "philosophy_resources", "academic_journals"]
    },

    # LIFESTYLE & CULTURE
    "lifestyle_culture" => %{
      name: "Lifestyle & Culture",
      description: "Fashion, relationships, parenting, and cultural discussions",
      sub_genres: [
        # Fashion & style
        "fashion_trends", "personal_style", "streetwear", "luxury_fashion", "sustainable_fashion",
        "beauty_trends", "skincare", "makeup", "hair_care", "fashion_history",
        "designer_discussion", "fashion_weeks", "style_advice", "thrift_fashion",

        # Relationships & dating
        "dating_advice", "relationship_discussions", "marriage", "breakups",
        "online_dating", "dating_apps", "relationship_psychology", "communication_skills",
        "love_languages", "attachment_styles", "family_dynamics", "friendship",

        # Parenting & family
        "parenting_advice", "child_development", "pregnancy", "newborn_care",
        "toddler_parenting", "teen_parenting", "single_parenting", "co_parenting",
        "school_discussions", "child_psychology", "family_activities", "work_life_balance",

        # Home & living
        "home_decor", "interior_design", "home_improvement", "gardening", "cleaning_tips",
        "organizing", "minimalism", "home_buying", "renting", "roommate_issues",
        "neighborhood_discussions", "city_living", "suburban_life", "rural_living",

        # Personal development
        "self_improvement", "productivity", "goal_setting", "habit_formation",
        "time_management", "career_advice", "life_coaching", "motivation",
        "personal_finance_discussion", "retirement_planning", "life_transitions"
      ],
      skill_levels: ["exploring", "developing", "experienced", "knowledgeable", "expert_advisor"],
      collaboration_types: ["support_groups", "advice_circles", "discussion_communities", "study_groups", "mentoring_networks"],
      tools: ["pinterest", "instagram", "reddit", "facebook_groups", "lifestyle_apps", "budgeting_apps"]
    },

    # SCIENCE & TECHNOLOGY DISCOURSE
    "science_tech_discourse" => %{
      name: "Science & Technology Discussion",
      description: "Scientific discoveries, tech trends, and future speculation",
      sub_genres: [
        # Science discussion
        "space_exploration", "astronomy", "physics_discussion", "climate_science",
        "biology", "chemistry", "medicine", "neuroscience", "psychology_research",
        "anthropology", "archaeology", "geology", "oceanography", "scientific_breakthroughs",

        # Technology trends
        "artificial_intelligence", "machine_learning_discussion", "automation", "robotics_discussion",
        "quantum_computing", "biotechnology", "nanotechnology", "virtual_reality_discussion",
        "augmented_reality", "blockchain_discussion", "cryptocurrency_discussion",

        # Future speculation
        "futurism", "technological_singularity", "space_colonization", "life_extension",
        "transhumanism", "ethical_ai", "technology_ethics", "privacy_discussion",
        "surveillance", "digital_rights", "tech_policy", "innovation_discussion",

        # Practical tech
        "gadget_reviews", "software_discussion", "app_recommendations", "tech_troubleshooting",
        "cybersecurity_discussion", "digital_privacy", "tech_industry_news"
      ],
      skill_levels: ["curious_learner", "science_enthusiast", "tech_savvy", "domain_expert", "researcher"],
      collaboration_types: ["discussion_groups", "research_circles", "speculation_forums", "review_communities", "expert_panels"],
      tools: ["scientific_journals", "tech_news_sites", "research_platforms", "discussion_forums", "podcast_apps"]
    },

    # HUMOR & CASUAL DISCUSSION
    "humor_casual" => %{
      name: "Humor & Casual Discussion",
      description: "Memes, jokes, random thoughts, and lighthearted conversation",
      sub_genres: [
        # Humor & comedy
        "memes", "internet_humor", "comedy_discussion", "stand_up_comedy", "sketch_comedy",
        "humor_writing", "satirical_content", "funny_videos", "comedy_podcasts",
        "roast_humor", "observational_comedy", "absurd_humor", "dad_jokes",

        # Casual conversation
        "random_thoughts", "shower_thoughts", "unpopular_opinions", "would_you_rather",
        "hypothetical_scenarios", "nostalgic_discussions", "childhood_memories",
        "generational_humor", "cultural_differences", "everyday_observations",

        # Internet culture
        "viral_content", "tiktok_discussions", "youtube_culture", "social_media_fails",
        "internet_drama", "online_communities", "digital_trends", "platform_discussions",

        # Water cooler topics
        "weekend_plans", "vacation_stories", "food_recommendations", "tv_show_chat",
        "weather_discussion", "commute_stories", "work_humor", "life_updates",
        "pet_stories", "family_stories", "embarrassing_moments", "random_questions"
      ],
      skill_levels: ["lurker", "occasional_poster", "regular_contributor", "community_favorite", "meme_creator"],
      collaboration_types: ["casual_chat", "meme_sharing", "story_swapping", "joke_telling", "random_discussions"],
      tools: ["reddit", "twitter", "tiktok", "discord", "meme_generators", "gif_keyboards"]
    },

    "visual_arts" => %{
      name: "Visual Arts & Design",
      description: "Visual creation, design collaboration, and artistic learning",
      sub_genres: [
        # Design disciplines
        "graphic_design", "ui_ux_design", "web_design", "brand_design",
        "typography", "logo_design", "packaging_design", "print_design",
        "motion_graphics", "game_art", "concept_art", "character_design",
        "environment_art", "fashion_design", "interior_design", "industrial_design",

        # Art & illustration
        "digital_illustration", "traditional_art", "portrait_drawing", "landscape_art",
        "comic_book_art", "children_book_illustration", "editorial_illustration",
        "concept_sketching", "life_drawing", "figure_drawing",

        # Photography & imaging
        "portrait_photography", "landscape_photography", "street_photography",
        "product_photography", "event_photography", "photo_editing", "retouching",

        # 3D & animation
        "3d_modeling", "3d_animation", "character_animation", "architectural_visualization",
        "product_visualization", "sculpting", "rigging", "texturing",

        # Collaborative activities
        "design_critique", "portfolio_reviews", "art_challenges", "collaborative_projects",
        "client_work_collaboration", "design_systems", "brand_development"
      ],
      skill_levels: ["beginner", "learning", "intermediate", "advanced", "professional"],
      collaboration_types: ["critique_groups", "co_designing", "mentoring", "client_projects", "art_challenges"],
      tools: ["photoshop", "illustrator", "figma", "sketch", "blender", "cinema4d", "procreate", "indesign"]
    },

    "video_film" => %{
      name: "Video & Film",
      description: "Video production, filmmaking, and motion content",
      sub_genres: [
        "short_films", "documentaries", "music_videos", "commercials",
        "vlogs", "tutorials", "live_streaming", "video_essays",
        "animation", "motion_graphics", "cinematography", "video_editing",
        "color_grading", "vfx", "screenwriting", "directing", "producing",
        "film_collaboration", "video_co_production", "editing_partnerships",
        "sound_design", "film_festivals", "video_critique_groups",
        "collaborative_storytelling", "documentary_teams"
      ],
      skill_levels: ["viewer", "hobbyist", "intermediate", "advanced", "professional"],
      collaboration_types: ["film_crews", "editing_partnerships", "festival_teams", "critique_groups", "co_production"],
      tools: ["premiere", "final_cut", "davinci_resolve", "after_effects", "cameras", "obs_studio", "frame_io", "adobe_audition"]
    },

    # WRITING & CONTENT
    "writing_content" => %{
      name: "Writing & Content Creation",
      description: "Writing, storytelling, and collaborative content development",
      sub_genres: [
        # Creative writing
        "fiction_writing", "short_stories", "novel_writing", "poetry", "screenwriting",
        "playwriting", "creative_nonfiction", "memoir_writing", "children_books",

        # Collaborative writing
        "co_writing", "writing_groups", "beta_reading", "developmental_editing",
        "story_collaboration", "anthology_projects", "writing_challenges",
        "peer_editing", "manuscript_exchange",

        # Professional writing
        "copywriting", "content_marketing", "technical_writing", "grant_writing",
        "academic_writing", "journalism", "blogging", "seo_content",
        "email_marketing", "social_media_content", "press_releases",

        # Content creation
        "newsletter_writing", "course_creation", "ebook_writing", "ghostwriting",
        "translation", "localization", "content_strategy", "editorial_calendar"
      ],
      skill_levels: ["beginner", "developing", "intermediate", "advanced", "professional"],
      collaboration_types: ["writing_partners", "critique_groups", "co_authoring", "editing_exchange", "writing_communities"],
      tools: ["google_docs", "scrivener", "notion", "wordpress", "medium", "grammarly", "hemingway_editor"]
    },

    # TECHNOLOGY & DEVELOPMENT
    "tech_development" => %{
      name: "Technology & Programming",
      description: "Software development, coding collaboration, and tech learning",
      sub_genres: [
        # Programming languages
        "javascript", "python", "react", "nodejs", "typescript", "java", "cpp",
        "swift", "kotlin", "rust", "go", "php", "ruby", "sql",

        # Development areas
        "web_development", "frontend_development", "backend_development", "full_stack",
        "mobile_development", "ios_development", "android_development",
        "game_development", "unity_development", "unreal_development",

        # Specialized tech
        "ai_machine_learning", "data_science", "blockchain", "cybersecurity",
        "cloud_computing", "devops", "api_development", "database_design",
        "system_architecture", "automation", "robotics", "iot", "ar_vr",

        # Collaborative activities
        "pair_programming", "code_review", "open_source", "hackathons",
        "coding_mentorship", "algorithm_practice", "system_design", "debugging_help",
        "project_collaboration", "startup_development", "freelance_projects"
      ],
      skill_levels: ["beginner", "learning", "intermediate", "advanced", "expert"],
      collaboration_types: ["pair_programming", "code_review", "mentoring", "project_teams", "study_groups"],
      tools: ["vs_code", "github", "git", "docker", "aws", "figma", "slack", "jira", "postman"]
    },

    # LANGUAGES & COMMUNICATION
    "languages_communication" => %{
      name: "Languages & Communication",
      description: "Language learning, cultural exchange, and communication skills",
      sub_genres: [
        # Major languages
        "english_learning", "spanish_learning", "french_learning", "german_learning",
        "mandarin_learning", "japanese_learning", "korean_learning", "arabic_learning",
        "portuguese_learning", "italian_learning", "russian_learning", "hindi_learning",
        "dutch_learning", "swedish_learning", "polish_learning", "vietnamese_learning",
        "thai_learning", "hebrew_learning", "greek_learning", "turkish_learning",

        # Sign languages & accessibility
        "american_sign_language", "british_sign_language", "international_sign",
        "deaf_culture", "accessibility_communication", "braille_learning",

        # Language skills
        "conversation_practice", "pronunciation", "grammar_study", "vocabulary_building",
        "reading_comprehension", "writing_practice", "listening_skills", "accent_reduction",

        # Cultural exchange
        "cultural_exchange", "travel_planning", "international_business", "translation_practice",
        "language_exchange", "immersion_groups", "cultural_mentoring",

        # Communication skills
        "public_speaking", "presentation_skills", "debate", "storytelling",
        "interview_preparation", "networking", "cross_cultural_communication"
      ],
      skill_levels: ["absolute_beginner", "beginner", "intermediate", "advanced", "native_fluent"],
      collaboration_types: ["language_exchange", "conversation_partners", "study_groups", "cultural_mentoring", "practice_sessions"],
      tools: ["duolingo", "babbel", "italki", "zoom", "discord", "google_translate", "anki"]
    },

    # BUSINESS & FINANCE
    "business_finance" => %{
      name: "Business & Finance",
      description: "Entrepreneurship, finance, investing, and business development",
      sub_genres: [
        # Entrepreneurship & business
        "startup_development", "small_business", "e_commerce", "saas_business",
        "business_planning", "market_research", "product_development", "business_strategy",
        "supply_chain_management", "operations", "customer_experience", "employee_engagement",
        "leadership_development", "team_building", "organizational_culture", "hr_management",

        # Finance & investing
        "personal_finance", "budgeting", "debt_management", "financial_planning",
        "investing_basics", "stock_market", "real_estate_investing", "retirement_planning",
        "cryptocurrency", "defi", "blockchain_finance", "trading", "forex",
        "credit_cards", "credit_repair", "insurance", "tax_planning",

        # Data & analytics
        "data_analytics", "business_intelligence", "market_analysis", "financial_modeling",
        "excel_mastery", "sql_for_business", "tableau", "power_bi", "google_analytics",
        "a_b_testing", "conversion_optimization", "growth_hacking",

        # Real estate
        "real_estate_basics", "property_investment", "house_flipping", "rental_properties",
        "commercial_real_estate", "real_estate_marketing", "property_management"
      ],
      skill_levels: ["curious", "learning", "practicing", "experienced", "expert"],
      collaboration_types: ["study_groups", "investment_clubs", "business_partnerships", "mentoring", "mastermind_groups"],
      tools: ["excel", "quickbooks", "salesforce", "tableau", "robinhood", "zillow", "linkedin"]
    },

    # LEARNING & SKILL DEVELOPMENT
    "learning_skills" => %{
      name: "Learning & Skill Development",
      description: "Structured learning, teaching, and skill-building collaborations",
      sub_genres: [
        # Academic subjects
        "mathematics", "science", "physics", "chemistry", "biology", "computer_science",
        "history", "literature", "philosophy", "psychology", "economics", "statistics",

        # Professional skills
        "project_management", "leadership", "public_speaking", "negotiation",
        "time_management", "critical_thinking", "problem_solving", "research_methods",

        # Creative skills
        "drawing_fundamentals", "color_theory", "composition", "perspective_drawing",
        "character_development", "world_building", "narrative_structure",

        # Digital literacy
        "computer_basics", "internet_research", "digital_marketing", "social_media_strategy",
        "data_analysis", "spreadsheet_mastery", "presentation_design",

        # Study methods
        "study_groups", "exam_preparation", "note_taking", "research_collaboration",
        "peer_tutoring", "skill_exchanges", "learning_accountability"
      ],
      skill_levels: ["absolute_beginner", "beginner", "intermediate", "advanced", "expert"],
      collaboration_types: ["study_groups", "peer_tutoring", "skill_exchange", "learning_partners", "accountability_groups"],
      tools: ["khan_academy", "coursera", "udemy", "notion", "anki", "zoom", "google_classroom"]
    },

    # LIFESTYLE
    "lifestyle_personal" => %{
      name: "Lifestyle & Personal Development",
      description: "Personal growth, lifestyle design, and self-improvement",
      sub_genres: [
        # Personal development
        "goal_setting", "habit_formation", "productivity", "time_management",
        "life_coaching", "career_development", "personal_branding", "networking",
        "confidence_building", "communication_skills", "emotional_intelligence",

        # Lifestyle areas
        "minimalism", "organization", "home_decor", "fashion_style", "beauty",
        "relationships", "dating", "parenting", "family_life", "work_life_balance",

        # Wellness & spirituality
        "spirituality", "mindfulness_practice", "self_care", "journaling",
        "meditation_practice", "yoga_lifestyle", "holistic_health",

        # Collaborative activities
        "accountability_partnerships", "goal_buddy_groups", "lifestyle_challenges",
        "book_clubs", "support_circles", "mastermind_groups"
      ],
      skill_levels: ["exploring", "developing", "practicing", "advanced", "coaching_others"],
      collaboration_types: ["accountability_partners", "support_groups", "coaching_circles", "challenge_groups", "book_clubs"],
      tools: ["notion", "todoist", "habitica", "zoom", "calendly", "meditation_apps", "journaling_apps"]
    },

    "pets_animals" => %{
      name: "Pets & Animal Care",
      description: "Pet care, animal training, and animal welfare",
      sub_genres: [
          # Pet types
        "dog_training", "cat_care", "bird_keeping", "fish_aquariums", "reptile_care",
        "small_pets", "farm_animals", "horses", "exotic_pets",

        # Care activities
        "pet_nutrition", "grooming", "veterinary_care", "behavioral_training",
        "pet_photography", "pet_sitting", "rescue_volunteering",

        # Collaborative activities
        "training_groups", "breed_communities", "rescue_coordination",
        "pet_playdates", "care_sharing", "emergency_support"
      ],
      skill_levels: ["new_owner", "experienced", "trainer", "professional", "expert"],
      collaboration_types: ["training_groups", "care_communities", "rescue_teams", "breed_groups", "support_networks"],
      tools: ["training_apps", "vet_apps", "pet_cameras", "gps_trackers", "care_scheduling_apps"]
    },

    "spirituality_religion" => %{
      name: "Spirituality & Religion",
      description: "Spiritual practices, religious study, and faith communities",
      sub_genres: [
        # Spiritual practices
        "meditation", "prayer", "mindfulness", "yoga_philosophy", "energy_healing",
        "astrology", "tarot", "crystals", "chakras", "manifestation",

        # Religious traditions
        "christianity", "islam", "judaism", "buddhism", "hinduism", "paganism",
        "indigenous_traditions", "interfaith_dialogue",

        # Study & community
        "scripture_study", "theological_discussion", "spiritual_mentorship",
        "retreat_planning", "ceremony_coordination", "faith_sharing"
      ],
      skill_levels: ["seeker", "practitioner", "student", "teacher", "leader"],
      collaboration_types: ["study_groups", "prayer_circles", "meditation_groups", "interfaith_dialogue", "spiritual_mentorship"],
      tools: ["meditation_apps", "prayer_apps", "scripture_apps", "zoom", "calendar_apps"]
    },

    # CRAFTS & MAKING
    "crafts_making" => %{
      name: "Crafts & Making",
      description: "Hands-on creation, crafting, and maker collaboration",
      sub_genres: [
        # Traditional crafts
        "knitting_crochet", "sewing_tailoring", "embroidery", "quilting", "weaving",
        "pottery_ceramics", "jewelry_making", "woodworking", "metalworking",
        "leatherworking", "bookbinding", "calligraphy", "origami",

        # Modern making
        "3d_printing", "laser_cutting", "electronics", "arduino_projects", "raspberry_pi",
        "cnc_machining", "pcb_design", "soldering", "circuit_design",

        # Collaborative projects
        "maker_challenges", "group_builds", "repair_cafes", "skill_sharing",
        "tool_libraries", "workshop_organization", "project_documentation"
      ],
      skill_levels: ["curious", "beginner", "intermediate", "advanced", "master_craftsperson"],
      collaboration_types: ["maker_groups", "skill_sharing", "project_collaboration", "workshop_teaching", "repair_sessions"],
      tools: ["3d_printer", "sewing_machine", "woodworking_tools", "soldering_iron", "arduino", "fusion360"]
    },

    # FOOD & CULINARY
    "food_culinary" => %{
      name: "Food & Culinary Arts",
      description: "Cooking, baking, food culture, and culinary collaboration",
      sub_genres: [
        # Cooking & techniques
        "home_cooking", "professional_cooking", "baking", "pastry_arts", "bread_making",
        "fermentation", "preserving", "grilling_bbq", "international_cuisine", "plant_based_cooking",
        "meal_prep", "quick_meals", "comfort_food", "fine_dining", "street_food",

        # Beverages
        "coffee_brewing", "espresso_techniques", "coffee_roasting", "tea_culture",
        "cocktail_making", "wine_tasting", "beer_brewing", "kombucha_brewing", "mixology", "whiskey",

        # Food business & culture
        "food_photography", "recipe_development", "food_writing", "restaurant_industry",
        "food_truck_business", "catering", "food_safety", "nutrition_science",
        "sustainable_eating", "local_food_systems", "urban_gardening", "permaculture",

        # Cannabis culinary (where legal)
        "cannabis_cooking", "edibles_creation", "cannabis_culture"
      ],
      skill_levels: ["beginner_cook", "home_chef", "serious_cook", "advanced", "professional"],
      collaboration_types: ["cooking_groups", "recipe_exchange", "meal_planning_groups", "potluck_organizing", "cooking_challenges"],
      tools: ["recipe_apps", "kitchen_scales", "thermometers", "instagram", "youtube", "cookbook_apps"]
    },

    # COMICS & STORYTELLING
    "comics_storytelling" => %{
      name: "Comics & Visual Storytelling",
      description: "Comic creation, graphic novels, and visual narrative",
      sub_genres: [
        # Comic creation
        "comic_writing", "comic_art", "graphic_novels", "webcomics", "manga_creation",
        "character_design", "comic_inking", "comic_coloring", "lettering", "panel_layout",
        "storyboarding", "sequential_art", "comic_scripting",

        # Publishing & community
        "indie_comics", "comic_publishing", "comic_conventions", "comic_collecting",
        "comic_criticism", "comic_history", "zine_making", "anthology_projects",

        # Related storytelling
        "visual_novels", "interactive_fiction", "graphic_design_storytelling",
        "infographic_design", "data_visualization_storytelling"
      ],
      skill_levels: ["fan", "hobbyist", "developing", "advanced", "professional"],
      collaboration_types: ["comic_teams", "anthology_groups", "critique_circles", "convention_groups", "zine_collectives"],
      tools: ["clip_studio", "procreate", "photoshop", "illustrator", "comicraft", "manga_studio"]
    },

    # POLITICS & CIVIC ENGAGEMENT
    "politics_civic" => %{
      name: "Politics & Civic Engagement",
      description: "Political involvement, community organizing, and civic participation",
      sub_genres: [
        # Political engagement
        "local_politics", "national_politics", "international_relations", "political_theory",
        "campaign_volunteering", "candidate_support", "voter_education", "policy_analysis",
        "political_communication", "debate", "advocacy", "lobbying",

        # Community involvement
        "community_organizing", "neighborhood_associations", "volunteer_coordination",
        "nonprofit_management", "fundraising", "grant_writing", "social_justice",
        "environmental_activism", "human_rights", "community_development",

        # Civic skills
        "public_speaking", "meeting_facilitation", "consensus_building", "conflict_resolution",
        "event_planning", "coalition_building", "media_relations", "grassroots_organizing"
      ],
      skill_levels: ["interested_citizen", "active_participant", "organizer", "leader", "expert"],
      collaboration_types: ["organizing_groups", "campaign_teams", "advocacy_coalitions", "study_circles", "action_committees"],
      tools: ["zoom", "facebook", "twitter", "mailchimp", "actionnetwork", "mobilize"]
    },

    # EDUCATION & SPECIAL NEEDS
    "education_specialneeds" => %{
      name: "Education & Special Needs",
      description: "Teaching, learning support, and inclusive education",
      sub_genres: [
        # Early childhood
        "early_childhood_education", "preschool_teaching", "child_development", "play_therapy",
        "montessori_methods", "waldorf_education", "reggio_emilia", "kindergarten_readiness",

        # Special needs & inclusion
        "special_needs_education", "autism_support", "adhd_strategies", "learning_disabilities",
        "sensory_processing", "behavior_support", "iep_planning", "inclusive_education",
        "assistive_technology", "speech_therapy", "occupational_therapy", "social_skills_training",

        # Teaching methods
        "differentiated_instruction", "universal_design", "classroom_management", "curriculum_development",
        "educational_technology", "online_teaching", "homeschooling", "unschooling",

        # Support systems
        "parent_advocacy", "support_groups", "resource_sharing", "therapist_collaboration",
        "teacher_support", "caregiver_education"
      ],
      skill_levels: ["parent_caregiver", "student_teacher", "practicing_educator", "specialist", "expert"],
      collaboration_types: ["parent_groups", "teacher_collaboration", "support_circles", "advocacy_teams", "professional_development"],
      tools: ["zoom", "google_classroom", "specialized_apps", "communication_devices", "learning_platforms"]
    },

    # TRAVEL & EXPLORATION
    "travel_exploration" => %{
      name: "Travel & Cultural Exploration",
      description: "Travel planning, cultural exchange, and global experiences",
      sub_genres: [
        # Travel types
        "budget_travel", "luxury_travel", "solo_travel", "family_travel", "adventure_travel",
        "cultural_immersion", "eco_tourism", "digital_nomad", "backpacking", "road_trips",
        "international_travel", "domestic_exploration", "city_breaks", "nature_travel",

        # Travel planning
        "itinerary_planning", "travel_hacking", "points_miles", "accommodation_finding",
        "transportation", "travel_safety", "travel_photography", "travel_writing",
        "cultural_preparation", "language_prep", "travel_budgeting",

        # Cultural exchange
        "host_families", "cultural_exchange", "volunteer_travel", "work_abroad",
        "study_abroad", "cultural_sensitivity", "cross_cultural_communication"
      ],
      skill_levels: ["new_traveler", "occasional_traveler", "frequent_traveler", "travel_expert", "travel_professional"],
      collaboration_types: ["travel_groups", "planning_partners", "cultural_exchange", "travel_mentoring", "destination_sharing"],
      tools: ["google_maps", "airbnb", "booking_apps", "translation_apps", "currency_converters", "travel_blogs"]
    },

    # SUSTAINABILITY & ENVIRONMENT
    "sustainability_environment" => %{
      name: "Sustainability & Environment",
      description: "Environmental action, sustainable living, and green practices",
      sub_genres: [
        # Environmental action
        "climate_action", "environmental_advocacy", "conservation", "renewable_energy",
        "carbon_footprint", "sustainable_transportation", "green_building", "permaculture",

        # Sustainable living
        "zero_waste", "minimalism", "sustainable_fashion", "eco_friendly_products",
        "plastic_reduction", "composting", "urban_farming", "sustainable_food",
        "green_cleaning", "energy_efficiency", "water_conservation",

        # Community action
        "community_gardens", "environmental_education", "green_initiatives", "cleanup_events",
        "sustainability_consulting", "environmental_policy", "green_business_practices"
      ],
      skill_levels: ["environmentally_curious", "eco_conscious", "sustainability_focused", "environmental_advocate", "sustainability_expert"],
      collaboration_types: ["action_groups", "community_projects", "education_teams", "advocacy_coalitions", "research_collaboration"],
      tools: ["sustainability_apps", "carbon_calculators", "community_platforms", "educational_resources"]
    },

    # GAMING & INTERACTIVE
    "gaming_interactive" => %{
      name: "Gaming & Interactive Media",
      description: "Gaming, game development, and interactive experiences",
      sub_genres: [
        "indie_games", "mobile_games", "pc_gaming", "console_gaming",
        "game_design", "level_design", "game_art", "game_programming",
        "esports", "streaming", "game_review", "retro_gaming",
        "vr_gaming", "ar_experiences", "interactive_fiction", "tabletop_games",
        "game_testing", "mod_development", "game_jams", "speedrunning",
        "guild_coordination", "tournament_organizing", "content_creation"
      ],
      skill_levels: ["player", "enthusiast", "developer", "advanced", "professional"],
      collaboration_types: ["dev_teams", "game_jams", "testing_groups", "streaming_collaborations", "esports_teams"],
      tools: ["unity", "unreal", "godot", "twitch", "obs_studio", "discord", "steam", "github"]
    }
  }

  # Cross-cutting collaboration patterns that apply across genres
  @collaboration_patterns [
    # Learning relationships
    "peer_learning", "mentor_mentee", "study_groups", "skill_exchange", "teaching_practice",

    # Creative partnerships
    "co_creation", "creative_partnerships", "feedback_exchange", "critique_groups", "collaborative_projects",

    # Professional development
    "career_networking", "industry_connections", "freelance_collaboration", "startup_partnerships", "client_work",

    # Community building
    "community_organizing", "event_planning", "workshop_hosting", "challenge_creation", "group_facilitation",

    # Knowledge sharing
    "documentation", "tutorial_creation", "best_practice_sharing", "tool_recommendations", "resource_curation"
  ]

  # Interest intensity levels (how deep someone wants to go)
  @engagement_levels [
    "casual_interest",      # Just curious, light engagement
    "active_learner",       # Dedicated time to learning
    "regular_practitioner", # Consistent practice/creation
    "serious_developer",    # Deep skill development focus
    "professional_level",   # Career/income focused
    "expert_contributor"    # Teaching/leading others
  ]

  def get_full_taxonomy, do: @genre_taxonomy
  def get_collaboration_patterns, do: @collaboration_patterns
  def get_engagement_levels, do: @engagement_levels

  # Enhanced recommendation system that considers collaboration preferences
  def find_collaboration_matches(user_profile, collaboration_type) do
    %{
      genres: user_genres,
      skill_levels: user_skills,
      collaboration_preferences: collab_prefs,
      engagement_level: engagement
    } = user_profile

    case collaboration_type do
      "peer_learning" ->
        find_peers_at_similar_level(user_genres, user_skills, engagement)

      "mentor_mentee" ->
        if engagement in ["serious_developer", "professional_level"] do
          find_mentees_in_genres(user_genres)
        else
          find_mentors_in_genres(user_genres, user_skills)
        end

      "co_creation" ->
        find_complementary_collaborators(user_genres, user_skills, collab_prefs)

      "skill_exchange" ->
        find_skill_exchange_opportunities(user_genres, user_skills)

      _ ->
        find_general_matches(user_genres, collaboration_type)
    end
  end

  # Specific matching functions for different collaboration types
  defp find_peers_at_similar_level(genres, skills, engagement) do
    # Find users with overlapping genres at similar skill levels
    # Implementation would query user database
    %{
      criteria: %{
        genre_overlap: genres,
        skill_similarity: skills,
        engagement_compatibility: engagement
      },
      match_type: "peer_learning"
    }
  end

  defp find_complementary_collaborators(genres, skills, preferences) do
    # Find users with complementary skills in same genres
    # E.g., songwriter + music producer, writer + illustrator
    %{
      criteria: %{
        genre_overlap: genres,
        skill_complementarity: true,
        collaboration_style: preferences
      },
      match_type: "co_creation"
    }
  end

    defp find_complementary_skill_sets(user_skills) do
    # Identify skills that complement user's current skills
    # Mock implementation
    complementary_map = %{
      "songwriting" => ["music_production", "mixing", "vocals"],
      "ui_design" => ["frontend_development", "user_research", "prototyping"],
      "writing" => ["editing", "illustration", "marketing"],
      "frontend_development" => ["backend_development", "ui_design", "devops"],
      "photography" => ["photo_editing", "graphic_design", "marketing"],
      "business_strategy" => ["marketing", "finance", "operations"]
    }

    user_skills
    |> Map.keys()
    |> Enum.flat_map(fn skill -> Map.get(complementary_map, skill, []) end)
    |> Enum.uniq()
  end

  defp find_skill_exchange_opportunities(user_genres, user_skills) do
    # Find opportunities where users can teach their skills and learn others
    # Mock implementation
    strong_skills = user_skills
    |> Enum.filter(fn {_skill, level} -> level in ["advanced", "expert"] end)
    |> Enum.map(fn {skill, _level} -> skill end)

    weak_skills = user_skills
    |> Enum.filter(fn {_skill, level} -> level in ["beginner", "learning"] end)
    |> Enum.map(fn {skill, _level} -> skill end)

    strong_skills
    |> Enum.map(fn strong_skill ->
      %{
        offering: strong_skill,
        seeking: Enum.random(weak_skills),
        potential_exchanges: Enum.random(1..4),
        genre_context: Enum.random(user_genres)
      }
    end)
  end

    defp find_general_matches(user_genres, collaboration_type) do
    # General matching for collaboration types not specifically handled
    # Mock implementation
    %{
      collaboration_type: collaboration_type,
      genres: user_genres,
      general_matches: Enum.random(5..20),
      match_quality: "medium",
      recommendation: "Join genre-specific channels for better matches"
    }
  end

  def get_genre_hierarchy(genre_key) do
    Map.get(@genre_taxonomy, genre_key)
  end

  def get_all_sub_genres do
    @genre_taxonomy
    |> Enum.flat_map(fn {_key, genre} -> genre.sub_genres end)
    |> Enum.uniq()
  end

  def find_genre_by_sub_genre(sub_genre) do
    Enum.find_value(@genre_taxonomy, fn {key, genre} ->
      if sub_genre in genre.sub_genres, do: {key, genre}, else: nil
    end)
  end

  def get_starter_categories do
    # Return 8 most beginner-friendly and popular categories for onboarding
    [
      %{
        key: "music_audio",
        name: "Music & Audio",
        icon: "🎵",
        beginner_friendly: true,
        estimated_members: "15.2k"
      },
      %{
        key: "visual_arts",
        name: "Visual Arts & Design",
        icon: "🎨",
        beginner_friendly: true,
        estimated_members: "22.1k"
      },
      %{
        key: "tech_development",
        name: "Tech & Programming",
        icon: "💻",
        beginner_friendly: false, # More advanced
        estimated_members: "31.5k"
      },
      %{
        key: "writing_content",
        name: "Writing & Content",
        icon: "✍️",
        beginner_friendly: true,
        estimated_members: "18.7k"
      },
      %{
        key: "health_fitness",
        name: "Health & Fitness",
        icon: "💪",
        beginner_friendly: true,
        estimated_members: "9.4k"
      },
      %{
        key: "food_culinary",
        name: "Food & Cooking",
        icon: "🍳",
        beginner_friendly: true,
        estimated_members: "8.9k"
      },
      %{
        key: "business_finance",
        name: "Business & Finance",
        icon: "💼",
        beginner_friendly: false, # Can be complex
        estimated_members: "12.8k"
      },
      %{
        key: "lifestyle_personal",
        name: "Lifestyle & Personal Growth",
        icon: "🌱",
        beginner_friendly: true,
        estimated_members: "7.3k"
      }
    ]
  end

  def get_genres_by_difficulty(difficulty_level) do
    case difficulty_level do
      :beginner_friendly ->
        ["music_audio", "visual_arts", "writing_content", "health_fitness",
        "food_culinary", "lifestyle_personal", "pets_animals", "crafts_making"]

      :intermediate ->
        ["languages_communication", "comics_storytelling", "travel_exploration",
        "sustainability_environment", "education_specialneeds", "learning_skills"]

      :advanced ->
        ["tech_development", "business_finance", "politics_civic", "gaming_interactive"]

      :all ->
        Map.keys(@genre_taxonomy)
    end
  end

  def suggest_onboarding_genres(user_type, max_selections \\ 5) do
    suggestions = case user_type do
      :creative_professional ->
        ["visual_arts", "music_audio", "writing_content", "video_film", "comics_storytelling"]

      :tech_professional ->
        ["tech_development", "business_finance", "learning_skills", "gaming_interactive"]

      :lifestyle_focused ->
        ["health_fitness", "food_culinary", "lifestyle_personal", "travel_exploration", "pets_animals"]

      :student_learner ->
        ["learning_skills", "languages_communication", "tech_development", "writing_content", "music_audio"]

      :entrepreneur ->
        ["business_finance", "tech_development", "visual_arts", "writing_content", "lifestyle_personal"]

      :community_builder ->
        ["politics_civic", "sustainability_environment", "education_specialneeds", "travel_exploration"]

      _ -> # Default balanced selection
        ["music_audio", "visual_arts", "tech_development", "writing_content", "health_fitness"]
    end

    Enum.take(suggestions, max_selections)
  end

  # Recommendation algorithms based on interest overlap
  def calculate_genre_similarity(user_genres, target_genres) do
    intersection = MapSet.intersection(MapSet.new(user_genres), MapSet.new(target_genres))
    union = MapSet.union(MapSet.new(user_genres), MapSet.new(target_genres))

    if MapSet.size(union) == 0, do: 0.0, else: MapSet.size(intersection) / MapSet.size(union)
  end

  def get_related_genres(genre_key, similarity_threshold \\ 0.3) do
    base_genre = get_genre_hierarchy(genre_key)
    if !base_genre, do: []

    @genre_taxonomy
    |> Enum.filter(fn {key, genre} ->
      key != genre_key &&
      calculate_tool_overlap(base_genre.tools, genre.tools) >= similarity_threshold
    end)
    |> Enum.map(fn {key, _genre} -> key end)
  end

  defp calculate_tool_overlap(tools1, tools2) do
    intersection = MapSet.intersection(MapSet.new(tools1), MapSet.new(tools2))
    union = MapSet.union(MapSet.new(tools1), MapSet.new(tools2))

    if MapSet.size(union) == 0, do: 0.0, else: MapSet.size(intersection) / MapSet.size(union)
  end

  # Dynamic expansion capabilities (for future growth)
  def suggest_new_sub_genres(genre_key, user_input_data) do
    # Analyze user-created content and suggest new sub-genres
    # This allows organic growth without major taxonomy overhauls
    existing_genre = get_genre_hierarchy(genre_key)

    # ML/AI could analyze patterns in user behavior here
    # For now, return structure for manual review
    %{
      genre: genre_key,
      suggested_sub_genres: extract_emerging_patterns(user_input_data),
      confidence_score: 0.0,
      review_needed: true
    }
  end

  defp extract_emerging_patterns(user_data) do
    # Placeholder for future ML implementation
    # Could analyze portfolio tags, channel names, collaboration patterns
    []
  end

  # Validation helpers
  def valid_genre?(genre_key), do: Map.has_key?(@genre_taxonomy, genre_key)

  def valid_sub_genre?(sub_genre) do
    sub_genre in get_all_sub_genres()
  end

  def valid_skill_level?(genre_key, skill_level) do
    case get_genre_hierarchy(genre_key) do
      nil -> false
      genre -> skill_level in genre.skill_levels
    end
  end

  # Channel recommendation based on learning goals
  def recommend_learning_channels(user_interests, learning_goals) do
    user_interests
    |> Enum.flat_map(&get_learning_channels_for_genre/1)
    |> filter_by_learning_goals(learning_goals)
    |> rank_by_activity_and_helpfulness()
    |> Enum.take(5)
  end

  defp get_learning_channels_for_genre(genre) do
    # Would query channels tagged with learning-focused activities
    # for the specific genre
    []
  end

    defp filter_by_learning_goals(channels, learning_goals) do
    # Filter channels based on user's learning objectives
    # Mock implementation - in real app, would match channel metadata with goals
    channels
  end

  defp rank_by_activity_and_helpfulness(channels) do
    # Rank channels by activity level and helpfulness ratings
    # Mock implementation - in real app, would use engagement metrics
    channels
  end


  # Skill gap analysis for personalized recommendations
  def analyze_skill_gaps(user_profile, target_goals) do
    current_skills = extract_current_skills(user_profile)
    required_skills = extract_required_skills(target_goals)

    gaps = MapSet.difference(
      MapSet.new(required_skills),
      MapSet.new(current_skills)
    )

    %{
      skill_gaps: MapSet.to_list(gaps),
      learning_path: suggest_learning_sequence(gaps),
      collaboration_opportunities: find_gap_filling_collaborators(gaps)
    }
  end

  defp extract_current_skills(user_profile) do
    # Extract skills from user's current expertise and experience
    user_profile.skill_levels
    |> Enum.filter(fn {_skill, level} -> level in ["intermediate", "advanced", "expert"] end)
    |> Enum.map(fn {skill, _level} -> skill end)
  end

  defp extract_required_skills(target_goals) do
    # Extract skills needed for target goals
    # Mock implementation - in real app, would analyze goal requirements
    target_goals
    |> Enum.flat_map(fn goal ->
      case goal do
        "become_fullstack_developer" -> ["javascript", "react", "nodejs", "databases", "git"]
        "start_music_production" -> ["daw_software", "music_theory", "mixing", "sound_design"]
        "launch_design_business" -> ["graphic_design", "client_communication", "business_planning", "marketing"]
        _ -> []
      end
    end)
  end

    defp suggest_learning_sequence(skill_gaps) do
    # Suggest optimal learning order for skill gaps
    # Mock implementation - in real app, would use dependency graphs
    skill_gaps
    |> MapSet.to_list()
    |> Enum.sort()
    |> Enum.with_index(1)
    |> Enum.map(fn {skill, order} -> %{skill: skill, order: order, estimated_weeks: 2} end)
  end

  defp find_gap_filling_collaborators(skill_gaps) do
    # Find collaborators who can help fill skill gaps
    # Mock implementation - in real app, would query user database
    skill_gaps
    |> MapSet.to_list()
    |> Enum.map(fn skill ->
      %{
        skill: skill,
        available_mentors: Enum.random(1..5),
        skill_exchange_opportunities: Enum.random(0..3)
      }
    end)
  end

  # Enhanced collaboration matching functions
  defp find_peers_at_similar_level(genres, skills, engagement) do
    # Find users with overlapping genres at similar skill levels
    # Mock implementation
    %{
      criteria: %{
        genre_overlap: genres,
        skill_similarity: skills,
        engagement_compatibility: engagement
      },
      match_type: "peer_learning",
      potential_matches: Enum.random(3..15)
    }
  end

  defp find_mentees_in_genres(user_genres) do
    # Find beginners in user's expert genres who need mentoring
    # Mock implementation
    user_genres
    |> Enum.map(fn genre ->
      %{
        genre: genre,
        seeking_mentees: Enum.random(2..8),
        skill_level_needed: "beginner_to_intermediate"
      }
    end)
  end

  defp find_mentors_in_genres(user_genres, user_skills) do
    # Find mentors in genres where user needs help
    # Mock implementation
    user_genres
    |> Enum.filter(fn genre ->
      skill_level = Map.get(user_skills, genre, "beginner")
      skill_level in ["beginner", "learning"]
    end)
    |> Enum.map(fn genre ->
      %{
        genre: genre,
        available_mentors: Enum.random(1..5),
        match_quality: Enum.random(60..95)
      }
    end)
  end

  def search_genres(search_term) do
    search_lower = String.downcase(search_term)

    @genre_taxonomy
    |> Enum.filter(fn {key, genre} ->
      String.contains?(String.downcase(genre.name), search_lower) ||
      String.contains?(String.downcase(genre.description), search_lower) ||
      Enum.any?(genre.sub_genres, &String.contains?(String.downcase(&1), search_lower))
    end)
    |> Enum.map(fn {key, genre} ->
      %{key: key, name: genre.name, description: genre.description}
    end)
  end

  def get_genres_with_sub_genre(sub_genre_search) do
    search_lower = String.downcase(sub_genre_search)

    @genre_taxonomy
    |> Enum.filter(fn {_key, genre} ->
      Enum.any?(genre.sub_genres, &String.contains?(String.downcase(&1), search_lower))
    end)
    |> Enum.map(fn {key, genre} ->
      matching_sub_genres = Enum.filter(genre.sub_genres,
        &String.contains?(String.downcase(&1), search_lower))

      %{key: key, name: genre.name, matching_sub_genres: matching_sub_genres}
    end)
  end

  def get_trending_genres(season \\ nil) do
    base_trending = ["tech_development", "health_fitness", "business_finance", "visual_arts"]

    seasonal_boost = case season do
      :spring -> ["sustainability_environment", "health_fitness", "travel_exploration"]
      :summer -> ["travel_exploration", "food_culinary", "health_fitness"]
      :fall -> ["learning_skills", "writing_content", "crafts_making"]
      :winter -> ["music_audio", "visual_arts", "lifestyle_personal"]
      _ -> base_trending
    end

    (seasonal_boost ++ base_trending)
    |> Enum.uniq()
    |> Enum.take(6)
  end


end
