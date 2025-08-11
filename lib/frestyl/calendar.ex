# lib/frestyl/calendar.ex (Enhanced)
defmodule Frestyl.Calendar do
  @moduledoc """
  Enhanced Calendar context with content intelligence and portfolio integration.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Frestyl.Repo
  alias Frestyl.Calendar.{
    Event, EventAttendee, Integration, View, ContentSuggestion,
    HealthMetric, IntelligenceEngine, PortfolioHealthAnalyzer
  }
  alias Frestyl.Features.TierManager

  # ============================================================================
  # ENHANCED EVENT MANAGEMENT
  # ============================================================================

  def get_intelligent_calendar_view(user, account, opts \\ []) do
    date_range = %{
      start_date: Keyword.get(opts, :start_date, Date.utc_today()),
      end_date: Keyword.get(opts, :end_date, Date.add(Date.utc_today(), 30))
    }

    IntelligenceEngine.generate_intelligent_calendar(user, account, date_range)
  end

  def get_user_visible_events(user, account, opts \\ []) do
    start_date = Keyword.get(opts, :start_date, Date.utc_today())
    end_date = Keyword.get(opts, :end_date, Date.add(start_date, 30))
    event_types = Keyword.get(opts, :event_types, :all)
    ownership_filter = Keyword.get(opts, :ownership_filter, :all)

    user_tier = TierManager.get_user_tier(user)

    base_query = from e in Event,
      where: e.starts_at >= ^DateTime.new!(start_date, ~T[00:00:00]) and
             e.starts_at <= ^DateTime.new!(end_date, ~T[23:59:59])

    # Apply tier-based filtering
    query = case user_tier do
      "personal" ->
        from e in base_query,
          where: e.creator_id == ^user.id or
                 (e.visibility in ["public", "channel"] and e.ownership_type in ["fyi", "participating"])

      "creator" ->
        from e in base_query,
          where: e.creator_id == ^user.id or
                 e.account_id == ^account.id or
                 (e.visibility in ["public", "channel"] and e.ownership_type in ["fyi", "participating"])

      _ ->
        from e in base_query,
          where: e.creator_id == ^user.id or
                 e.account_id == ^account.id or
                 e.visibility in ["public", "channel", "account"]
    end

    # Apply content type filtering
    query = if event_types != :all do
      from e in query, where: e.content_type in ^event_types
    else
      query
    end

    # Apply ownership filtering
    query = if ownership_filter != :all do
      from e in query, where: e.ownership_type == ^ownership_filter
    else
      query
    end

    query
    |> order_by([e], [asc: e.starts_at, desc: e.priority_level])
    |> Repo.all()
    |> enhance_events_with_context(user, account)
  end

  def create_smart_event(attrs, user, account) do
    # Enhance attributes with intelligent defaults
    enhanced_attrs = enhance_event_attrs(attrs, user, account)

    %Event{}
    |> Event.changeset(enhanced_attrs)
    |> Repo.insert()
    |> case do
      {:ok, event} ->
        # Generate follow-up suggestions
        generate_followup_suggestions(event, user, account)
        {:ok, event}

      error -> error
    end
  end

  def update_event(event, attrs) do
    # Track completion and generate analytics
    changeset = Event.changeset(event, attrs)

    case Repo.update(changeset) do
      {:ok, updated_event} ->
        # Handle completion workflows
        if updated_event.completion_status == "completed" do
          handle_event_completion(updated_event)
        end

        {:ok, updated_event}

      error -> error
    end
  end

  def complete_event(event_id, user_id, completion_notes \\ nil) do
    event = get_event!(event_id)

    if event.creator_id == user_id do
      attrs = %{
        completion_status: "completed",
        metadata: Map.put(event.metadata, "completion_notes", completion_notes)
      }

      update_event(event, attrs)
    else
      {:error, :unauthorized}
    end
  end

  def defer_event(event_id, user_id, new_date, reason \\ nil) do
    event = get_event!(event_id)

    if event.creator_id == user_id do
      attrs = %{
        starts_at: new_date,
        ends_at: DateTime.add(new_date, (event.estimated_time_minutes || 30) * 60, :second),
        completion_status: "deferred",
        metadata: Map.put(event.metadata, "defer_reason", reason)
      }

      update_event(event, attrs)
    else
      {:error, :unauthorized}
    end
  end

  # ============================================================================
  # CONTENT SUGGESTIONS MANAGEMENT
  # ============================================================================

  def create_content_suggestion(attrs) do
    %ContentSuggestion{}
    |> ContentSuggestion.changeset(attrs)
    |> Repo.insert()
  end

  def list_user_suggestions(user_id, opts \\ []) do
    status_filter = Keyword.get(opts, :status, "pending")
    limit = Keyword.get(opts, :limit, 20)

    from(s in ContentSuggestion,
      where: s.user_id == ^user_id,
      where: s.status == ^status_filter,
      order_by: [desc: s.priority_score, desc: s.inserted_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  def accept_suggestion(suggestion_id, user_id) do
    suggestion = get_suggestion!(suggestion_id)

    if suggestion.user_id == user_id do
      # Convert suggestion to calendar event
      event_attrs = convert_suggestion_to_event_attrs(suggestion)

      Multi.new()
      |> Multi.insert(:event, Event.changeset(%Event{}, event_attrs))
      |> Multi.update(:suggestion, ContentSuggestion.changeset(suggestion, %{
        status: "accepted",
        converted_to_event_id: get_in(event_attrs, [:id])
      }))
      |> Repo.transaction()
      |> case do
        {:ok, %{event: event, suggestion: suggestion}} ->
          {:ok, %{event: event, suggestion: suggestion}}

        {:error, _operation, changeset, _changes} ->
          {:error, changeset}
      end
    else
      {:error, :unauthorized}
    end
  end

  def dismiss_suggestion(suggestion_id, user_id) do
    suggestion = get_suggestion!(suggestion_id)

    if suggestion.user_id == user_id do
      attrs = %{status: "dismissed", dismissed_at: DateTime.utc_now()}

      suggestion
      |> ContentSuggestion.changeset(attrs)
      |> Repo.update()
    else
      {:error, :unauthorized}
    end
  end

  def bulk_dismiss_suggestions(suggestion_ids, user_id) do
    from(s in ContentSuggestion,
      where: s.id in ^suggestion_ids and s.user_id == ^user_id
    )
    |> Repo.update_all(set: [
      status: "dismissed",
      dismissed_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    ])
  end

  # ============================================================================
  # PORTFOLIO HEALTH INTEGRATION
  # ============================================================================

  def analyze_user_portfolio_health(user_id) do
    PortfolioHealthAnalyzer.analyze_user_portfolios(user_id)
  end

  def get_portfolio_health_metrics(portfolio_id) do
    from(m in HealthMetric,
      where: m.portfolio_id == ^portfolio_id,
      order_by: [desc: m.last_analyzed_at],
      limit: 1
    )
    |> Repo.one()
  end

  def update_portfolio_health_metrics(portfolio_id, metrics_data) do
    existing_metric = get_portfolio_health_metrics(portfolio_id)

    case existing_metric do
      nil ->
        %HealthMetric{}
        |> HealthMetric.changeset(Map.put(metrics_data, :portfolio_id, portfolio_id))
        |> Repo.insert()

      metric ->
        metric
        |> HealthMetric.changeset(metrics_data)
        |> Repo.update()
    end
  end

  def schedule_portfolio_health_check(user_id) do
    # Schedule automatic health checks for all user portfolios
    user_portfolios = Frestyl.Portfolios.list_user_portfolios(user_id)

    Enum.each(user_portfolios, fn portfolio ->
      # Create health check event if one doesn't exist
      existing_check = from(e in Event,
        where: e.portfolio_id == ^portfolio.id and
               e.content_type == "portfolio_update" and
               e.completion_status in ["pending", "in_progress"] and
               e.starts_at > ^DateTime.utc_now()
      ) |> Repo.one()

      unless existing_check do
        due_date = DateTime.add(DateTime.utc_now(), 7 * 24 * 60 * 60, :second)

        health_check_attrs = %{
          title: "Portfolio Health Check: #{portfolio.title}",
          description: "Review and update portfolio content for freshness",
          starts_at: due_date,
          ends_at: DateTime.add(due_date, 30 * 60, :second),
          content_type: "portfolio_update",
          priority_level: "medium",
          ownership_type: "suggested",
          completion_status: "pending",
          auto_generated: true,
          estimated_time_minutes: 30,
          revenue_impact: "medium",
          workflow_template: "portfolio_health_check",
          creator_id: user_id,
          portfolio_id: portfolio.id
        }

        create_smart_event(health_check_attrs, %{id: user_id}, %{id: portfolio.account_id})
      end
    end)
  end

  # ============================================================================
  # CALENDAR INTELLIGENCE & ANALYTICS
  # ============================================================================

  def get_calendar_insights(user_id, account, timeframe \\ :month) do
    {start_date, end_date} = calculate_timeframe_dates(timeframe)

    events = get_user_visible_events(%{id: user_id}, account,
      start_date: start_date,
      end_date: end_date
    )

    %{
      productivity_score: calculate_productivity_score(events),
      completion_rate: calculate_completion_rate(events),
      priority_distribution: calculate_priority_distribution(events),
      content_type_breakdown: calculate_content_type_breakdown(events),
      revenue_impact_analysis: calculate_revenue_impact_analysis(events),
      time_investment_analysis: calculate_time_investment_analysis(events),
      recommendations: generate_calendar_recommendations(events, user_id, account)
    }
  end

  def get_upcoming_deadlines(user_id, account, days_ahead \\ 7) do
    end_date = Date.add(Date.utc_today(), days_ahead)

    get_user_visible_events(%{id: user_id}, account,
      start_date: Date.utc_today(),
      end_date: end_date
    )
    |> Enum.filter(&(&1.priority_level in ["critical", "high"]))
    |> Enum.filter(&(&1.completion_status in ["pending", "in_progress"]))
    |> Enum.sort_by(&(&1.starts_at))
  end

  def get_overdue_tasks(user_id, account) do
    yesterday = Date.add(Date.utc_today(), -1)

    get_user_visible_events(%{id: user_id}, account,
      start_date: Date.add(Date.utc_today(), -30),
      end_date: yesterday
    )
    |> Enum.filter(&(&1.completion_status in ["pending", "in_progress"]))
    |> Enum.sort_by(&(&1.starts_at))
  end

  def get_calendar_statistics(user_id, account) do
    this_month_events = get_user_visible_events(%{id: user_id}, account)

    %{
      total_events: length(this_month_events),
      completed_events: Enum.count(this_month_events, &(&1.completion_status == "completed")),
      pending_events: Enum.count(this_month_events, &(&1.completion_status == "pending")),
      overdue_events: Enum.count(this_month_events, &is_overdue?/1),
      auto_generated_events: Enum.count(this_month_events, &(&1.auto_generated)),
      high_priority_events: Enum.count(this_month_events, &(&1.priority_level in ["critical", "high"])),
      revenue_events: Enum.count(this_month_events, &(&1.revenue_impact in ["critical", "high", "medium"])),
      avg_completion_time: calculate_avg_completion_time(this_month_events)
    }
  end

  # ============================================================================
  # WORKFLOW MANAGEMENT
  # ============================================================================

  def start_workflow(event_id, user_id) do
    event = get_event!(event_id)

    if event.creator_id == user_id && event.workflow_template do
      # Create workflow execution record
      workflow_attrs = %{
        event_id: event_id,
        template_id: get_workflow_template_id(event.workflow_template),
        user_id: user_id,
        status: "started",
        current_step: 0,
        total_steps: get_workflow_step_count(event.workflow_template),
        started_at: DateTime.utc_now()
      }

      # This would integrate with your workflow system
      {:ok, workflow_attrs}
    else
      {:error, :invalid_workflow}
    end
  end

  def complete_workflow_step(workflow_execution_id, step_data) do
    # Update workflow execution with step completion
    # This would integrate with your workflow execution system
    {:ok, step_data}
  end

  # ============================================================================
  # INTEGRATIONS MANAGEMENT
  # ============================================================================

  def list_calendar_integrations(user_id) do
    from(i in Integration,
      where: i.user_id == ^user_id,
      order_by: [desc: i.is_primary, asc: i.provider]
    )
    |> Repo.all()
  end

  def create_calendar_integration(attrs) do
    %Integration{}
    |> Integration.changeset(attrs)
    |> Repo.insert()
  end

  def update_calendar_integration(integration, attrs) do
    integration
    |> Integration.changeset(attrs)
    |> Repo.update()
  end

  def sync_calendar_integration(integration_id) do
    integration = get_integration!(integration_id)

    case integration.provider do
      "google" -> sync_google_calendar(integration)
      "outlook" -> sync_outlook_calendar(integration)
      _ -> {:error, :unsupported_provider}
    end
  end

  # ============================================================================
  # CALENDAR VIEWS MANAGEMENT
  # ============================================================================

  def list_calendar_views(user_id) do
    from(v in View,
      where: v.user_id == ^user_id,
      order_by: [desc: v.default_view, asc: v.name]
    )
    |> Repo.all()
  end

  def create_calendar_view(attrs) do
    %View{}
    |> View.changeset(attrs)
    |> Repo.insert()
  end

  def update_calendar_view(view, attrs) do
    view
    |> View.changeset(attrs)
    |> Repo.update()
  end

  def set_default_view(view_id, user_id) do
    Multi.new()
    |> Multi.update_all(:clear_defaults,
      from(v in View, where: v.user_id == ^user_id),
      set: [default_view: false, updated_at: DateTime.utc_now()]
    )
    |> Multi.update(:set_default,
      get_view!(view_id) |> View.changeset(%{default_view: true})
    )
    |> Repo.transaction()
  end

  # ============================================================================
  # EVENT ATTENDEES MANAGEMENT
  # ============================================================================

  def add_event_attendee(event_id, attendee_attrs) do
    attendee_attrs = Map.put(attendee_attrs, :event_id, event_id)

    %EventAttendee{}
    |> EventAttendee.changeset(attendee_attrs)
    |> Repo.insert()
  end

  def list_event_attendees(event_id) do
    from(a in EventAttendee,
      where: a.event_id == ^event_id,
      order_by: [asc: a.inserted_at]
    )
    |> Repo.all()
  end

  def update_attendee_status(attendee_id, status) when status in ["accepted", "declined", "tentative"] do
    attendee = get_attendee!(attendee_id)

    attendee
    |> EventAttendee.changeset(%{status: status})
    |> Repo.update()
  end

  def remove_event_attendee(attendee_id) do
    attendee = get_attendee!(attendee_id)
    Repo.delete(attendee)
  end

  # ============================================================================
  # BULK OPERATIONS
  # ============================================================================

  def bulk_update_events(event_ids, attrs, user_id) do
    # Only allow bulk updates for events owned by the user
    query = from(e in Event,
      where: e.id in ^event_ids and e.creator_id == ^user_id
    )

    Repo.update_all(query, set: Map.to_list(attrs))
  end

  def bulk_complete_events(event_ids, user_id) do
    bulk_update_events(event_ids, %{
      completion_status: "completed",
      updated_at: DateTime.utc_now()
    }, user_id)
  end

  def bulk_defer_events(event_ids, days, user_id) do
    # This would need more complex logic to properly update start/end times
    # For now, just mark as deferred
    bulk_update_events(event_ids, %{
      completion_status: "deferred",
      updated_at: DateTime.utc_now()
    }, user_id)
  end

  def bulk_delete_events(event_ids, user_id) do
    query = from(e in Event,
      where: e.id in ^event_ids and e.creator_id == ^user_id
    )

    Repo.delete_all(query)
  end

  # ============================================================================
  # SEARCH AND FILTERING
  # ============================================================================

  def search_events(user_id, search_params) do
    query = build_search_query(user_id, search_params)

    query
    |> limit(100)  # Limit results for performance
    |> Repo.all()
  end

  # ============================================================================
  # CALENDAR EXPORT/IMPORT
  # ============================================================================

  def export_calendar_to_ical(user_id, opts \\ []) do
    start_date = Keyword.get(opts, :start_date, Date.add(Date.utc_today(), -30))
    end_date = Keyword.get(opts, :end_date, Date.add(Date.utc_today(), 365))

    events = from(e in Event,
      where: e.creator_id == ^user_id and
             e.starts_at >= ^DateTime.new!(start_date, ~T[00:00:00]) and
             e.starts_at <= ^DateTime.new!(end_date, ~T[23:59:59]),
      order_by: [asc: e.starts_at]
    )
    |> Repo.all()

    generate_ical_content(events)
  end

  # ============================================================================
  # NOTIFICATIONS AND REMINDERS
  # ============================================================================

  def schedule_event_reminders(event_id) do
    event = get_event!(event_id)

    # Schedule reminders based on the auto_reminder_schedule
    Enum.each(event.auto_reminder_schedule || [], fn reminder_offset ->
      schedule_single_reminder(event, reminder_offset)
    end)
  end

  def send_event_reminder(event_id, reminder_type \\ :email) do
    event = get_event!(event_id)

    case reminder_type do
      :email -> send_email_reminder(event)
      :push -> send_push_reminder(event)
      :sms -> send_sms_reminder(event)
      _ -> {:error, :unsupported_reminder_type}
    end
  end

  # ============================================================================
  # RECURRING EVENTS
  # ============================================================================

  def create_recurring_event(base_event_attrs, recurrence_rule) do
    # Parse recurrence rule and create multiple events
    case parse_recurrence_rule(recurrence_rule) do
      {:ok, rule} ->
        dates = generate_recurring_dates(base_event_attrs[:starts_at], rule)
        create_event_series(base_event_attrs, dates)

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ============================================================================
  # PERFORMANCE AND CACHING
  # ============================================================================

  def preload_event_associations(events) when is_list(events) do
    Repo.preload(events, [:attendees, :child_events])
  end

  def preload_event_associations(event) do
    Repo.preload(event, [:attendees, :child_events])
  end

  def get_cached_user_events(user_id, cache_key \\ nil) do
    # This would integrate with your caching system (Redis, ETS, etc.)
    # For now, just return the events directly
    get_user_visible_events(%{id: user_id}, %{id: nil})
  end

  def invalidate_user_calendar_cache(user_id) do
    # This would invalidate cached calendar data
    # For now, just return success
    :ok
  end

  # ============================================================================
  # METRICS AND TELEMETRY
  # ============================================================================

  def track_calendar_event(event_type, metadata \\ %{}) do
    # This would integrate with your telemetry/analytics system
    # :telemetry.execute([:frestyl, :calendar, event_type], %{count: 1}, metadata)
    :ok
  end

  def get_calendar_usage_metrics(user_id, timeframe \\ :month) do
    {start_date, end_date} = calculate_timeframe_dates(timeframe)

    events = get_user_visible_events(%{id: user_id}, %{id: nil},
      start_date: start_date,
      end_date: end_date
    )

    %{
      events_created: length(events),
      events_completed: Enum.count(events, &(&1.completion_status == "completed")),
      ai_suggestions_accepted: count_accepted_suggestions(user_id, start_date, end_date),
      workflows_started: count_workflow_usage(user_id, start_date, end_date),
      avg_completion_time: calculate_avg_completion_time(events),
      productivity_trend: calculate_productivity_trend(user_id, timeframe)
    }
  end

  # ============================================================================
  # STANDARD CRUD OPERATIONS
  # ============================================================================

  def get_event!(id), do: Repo.get!(Event, id)
  def get_suggestion!(id), do: Repo.get!(ContentSuggestion, id)
  def get_integration!(id), do: Repo.get!(Integration, id)
  def get_view!(id), do: Repo.get!(View, id)
  def get_attendee!(id), do: Repo.get!(EventAttendee, id)

  def list_events(opts \\ []) do
    from(e in Event, order_by: [desc: e.inserted_at])
    |> Repo.all()
  end

  def create_event(attrs) do
    %Event{}
    |> Event.changeset(attrs)
    |> Repo.insert()
  end

  def delete_event(%Event{} = event) do
    Repo.delete(event)
  end

  def delete_suggestion(%ContentSuggestion{} = suggestion) do
    Repo.delete(suggestion)
  end

  # ============================================================================
  # PRIVATE HELPER FUNCTIONS
  # ============================================================================

  defp enhance_events_with_context(events, user, account) do
    Enum.map(events, fn event ->
      event
      |> add_user_permissions(user, account)
      |> add_time_context()
      |> add_priority_context()
    end)
  end

  defp add_user_permissions(event, user, account) do
    permissions = %{
      can_edit: can_edit_event?(event, user, account),
      can_delete: can_delete_event?(event, user, account),
      can_complete: can_complete_event?(event, user),
      can_defer: can_defer_event?(event, user)
    }

    Map.put(event, :permissions, permissions)
  end

  defp add_time_context(event) do
    now = DateTime.utc_now()

    time_context = %{
      is_overdue: is_overdue?(event),
      is_today: is_today?(event),
      is_this_week: is_this_week?(event, now),
      days_until_due: days_until_due(event),
      relative_time: format_relative_time(event.starts_at)
    }

    Map.put(event, :time_context, time_context)
  end

  defp add_priority_context(event) do
    priority_context = %{
      weight: Event.get_priority_weight(event.priority_level),
      color: Event.get_priority_color(event.priority_level),
      icon: get_priority_icon(event.priority_level),
      urgent: event.priority_level in ["critical", "high"] && is_overdue?(event)
    }

    Map.put(event, :priority_context, priority_context)
  end

  defp enhance_event_attrs(attrs, user, account) do
    base_attrs = Map.merge(attrs, %{
      creator_id: user.id,
      account_id: account.id
    })

    # Add intelligent defaults based on content type
    case attrs[:content_type] do
      "portfolio_update" ->
        Map.merge(base_attrs, %{
          estimated_time_minutes: attrs[:estimated_time_minutes] || 30,
          revenue_impact: attrs[:revenue_impact] || "medium",
          workflow_template: "portfolio_update_workflow"
        })

      "skill_showcase" ->
        Map.merge(base_attrs, %{
          estimated_time_minutes: attrs[:estimated_time_minutes] || 45,
          revenue_impact: attrs[:revenue_impact] || "high",
          workflow_template: "skill_development_workflow"
        })

      _ -> base_attrs
    end
  end

  defp generate_followup_suggestions(event, user, account) do
    # Generate intelligent follow-up suggestions based on event type
    case event.content_type do
      "project_addition" ->
        create_content_suggestion(%{
          user_id: user.id,
          account_id: account.id,
          portfolio_id: event.portfolio_id,
          suggestion_type: "testimonial_request",
          title: "Request testimonial for #{event.title}",
          description: "Reach out to the client for a testimonial",
          priority_score: 70,
          estimated_time_minutes: 15,
          suggested_due_date: DateTime.add(DateTime.utc_now(), 3 * 24 * 60 * 60, :second)
        })

      "skill_showcase" ->
        create_content_suggestion(%{
          user_id: user.id,
          account_id: account.id,
          suggestion_type: "service_launch",
          title: "Consider offering services in #{event.title}",
          description: "Create service offerings based on your new skill",
          priority_score: 60,
          estimated_time_minutes: 60,
          suggested_due_date: DateTime.add(DateTime.utc_now(), 7 * 24 * 60 * 60, :second)
        })

      _ -> :ok
    end
  end

  defp handle_event_completion(event) do
    # Track completion analytics
    completion_time = DateTime.diff(DateTime.utc_now(), event.starts_at, :minute)

    # Update metadata with completion info
    updated_metadata = Map.merge(event.metadata, %{
      "actual_completion_time_minutes" => completion_time,
      "completed_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    })

    # This would be used for improving future time estimates
    # and generating completion insights

    :ok
  end

  defp convert_suggestion_to_event_attrs(suggestion) do
    %{
      title: suggestion.title,
      description: suggestion.description,
      starts_at: suggestion.suggested_due_date || DateTime.add(DateTime.utc_now(), 24 * 60 * 60, :second),
      ends_at: DateTime.add(
        suggestion.suggested_due_date || DateTime.utc_now(),
        (suggestion.estimated_time_minutes || 30) * 60,
        :second
      ),
      content_type: suggestion.suggestion_type,
      priority_level: map_suggestion_priority(suggestion.estimated_impact),
      ownership_type: "mine",
      completion_status: "pending",
      estimated_time_minutes: suggestion.estimated_time_minutes,
      revenue_impact: suggestion.estimated_impact,
      creator_id: suggestion.user_id,
      account_id: suggestion.account_id,
      portfolio_id: suggestion.portfolio_id,
      metadata: Map.merge(suggestion.metadata, %{
        "converted_from_suggestion" => suggestion.id,
        "suggestion_rationale" => suggestion.rationale
      })
    }
  end

  # Calendar Analytics Helper Functions
  defp calculate_timeframe_dates(:week) do
    start_date = Date.add(Date.utc_today(), -7)
    end_date = Date.utc_today()
    {start_date, end_date}
  end

  defp calculate_timeframe_dates(:month) do
    start_date = Date.add(Date.utc_today(), -30)
    end_date = Date.utc_today()
    {start_date, end_date}
  end

  defp calculate_timeframe_dates(:quarter) do
    start_date = Date.add(Date.utc_today(), -90)
    end_date = Date.utc_today()
    {start_date, end_date}
  end

  defp calculate_productivity_score(events) do
    if Enum.empty?(events) do
      0
    else
      completed = Enum.count(events, &(&1.completion_status == "completed"))
      total = length(events)

      base_score = (completed / total) * 100

      # Adjust for priority completion
      high_priority_completed = Enum.count(events, fn event ->
        event.completion_status == "completed" && event.priority_level in ["critical", "high"]
      end)

      high_priority_total = Enum.count(events, &(&1.priority_level in ["critical", "high"]))

      priority_bonus = if high_priority_total > 0 do
        (high_priority_completed / high_priority_total) * 20
      else
        0
      end

      min(100, base_score + priority_bonus) |> Float.round(1)
    end
  end

  defp calculate_completion_rate(events) do
    if Enum.empty?(events) do
      0
    else
      completed = Enum.count(events, &(&1.completion_status == "completed"))
      (completed / length(events) * 100) |> Float.round(1)
    end
  end

  defp calculate_priority_distribution(events) do
    total = length(events)

    if total == 0 do
      %{critical: 0, high: 0, medium: 0, low: 0}
    else
      %{
        critical: (Enum.count(events, &(&1.priority_level == "critical")) / total * 100) |> Float.round(1),
        high: (Enum.count(events, &(&1.priority_level == "high")) / total * 100) |> Float.round(1),
        medium: (Enum.count(events, &(&1.priority_level == "medium")) / total * 100) |> Float.round(1),
        low: (Enum.count(events, &(&1.priority_level == "low")) / total * 100) |> Float.round(1)
      }
    end
  end

  defp calculate_content_type_breakdown(events) do
    events
    |> Enum.group_by(& &1.content_type)
    |> Enum.map(fn {type, type_events} ->
      {type, %{
        count: length(type_events),
        completed: Enum.count(type_events, &(&1.completion_status == "completed")),
        avg_time: calculate_avg_time_for_events(type_events)
      }}
    end)
    |> Enum.into(%{})
  end

  defp calculate_revenue_impact_analysis(events) do
    revenue_events = Enum.filter(events, &(&1.revenue_impact in ["critical", "high", "medium"]))

    %{
      total_revenue_events: length(revenue_events),
      completed_revenue_events: Enum.count(revenue_events, &(&1.completion_status == "completed")),
      revenue_completion_rate: if length(revenue_events) > 0 do
        (Enum.count(revenue_events, &(&1.completion_status == "completed")) / length(revenue_events) * 100) |> Float.round(1)
      else
        0
      end,
      high_impact_pending: Enum.count(revenue_events, fn event ->
        event.revenue_impact == "critical" && event.completion_status in ["pending", "in_progress"]
      end)
    }
  end

  defp calculate_time_investment_analysis(events) do
    total_planned_time = Enum.reduce(events, 0, fn event, acc ->
      acc + (event.estimated_time_minutes || 0)
    end)

    completed_events = Enum.filter(events, &(&1.completion_status == "completed"))
    total_actual_time = Enum.reduce(completed_events, 0, fn event, acc ->
      actual_time = get_in(event.metadata, ["actual_completion_time_minutes"]) || event.estimated_time_minutes || 0
      acc + actual_time
    end)

    %{
      total_planned_minutes: total_planned_time,
      total_actual_minutes: total_actual_time,
      time_accuracy: if total_planned_time > 0 do
        (total_actual_time / total_planned_time * 100) |> Float.round(1)
      else
        100
      end,
      avg_task_time: if length(events) > 0 do
        (total_planned_time / length(events)) |> Float.round(1)
      else
        0
      end
    }
  end

  defp generate_calendar_recommendations(events, user_id, account) do
    recommendations = []

    # Check completion rate
    completion_rate = calculate_completion_rate(events)
    recommendations = if completion_rate < 70 do
      [%{
        type: "productivity",
        title: "Improve Task Completion",
        description: "Your completion rate is #{completion_rate}%. Consider breaking large tasks into smaller ones.",
        priority: "medium"
      } | recommendations]
    else
      recommendations
    end

    # Check for overdue tasks
    overdue_count = Enum.count(events, &is_overdue?/1)
    recommendations = if overdue_count > 3 do
      [%{
        type: "time_management",
        title: "Address Overdue Tasks",
        description: "You have #{overdue_count} overdue tasks. Consider rescheduling or delegating.",
        priority: "high"
      } | recommendations]
    else
      recommendations
    end

    # Check revenue focus
    revenue_events = Enum.filter(events, &(&1.revenue_impact in ["critical", "high"]))
    revenue_completion = if length(revenue_events) > 0 do
      Enum.count(revenue_events, &(&1.completion_status == "completed")) / length(revenue_events) * 100
    else
      100
    end

    recommendations = if revenue_completion < 80 do
      [%{
        type: "revenue_focus",
        title: "Prioritize Revenue-Generating Tasks",
        description: "Focus on completing high-revenue-impact tasks first.",
        priority: "high"
      } | recommendations]
    else
      recommendations
    end

    recommendations
  end

  # Search query builder
  defp build_search_query(user_id, params) do
    base_query = from(e in Event, where: e.creator_id == ^user_id)

    Enum.reduce(params, base_query, fn
      {:text, text}, query when is_binary(text) and text != "" ->
        search_term = "%#{text}%"
        from e in query,
          where: ilike(e.title, ^search_term) or ilike(e.description, ^search_term)

      {:content_type, type}, query when is_binary(type) ->
        from e in query, where: e.content_type == ^type

      {:priority_level, level}, query when is_binary(level) ->
        from e in query, where: e.priority_level == ^level

      {:completion_status, status}, query when is_binary(status) ->
        from e in query, where: e.completion_status == ^status

      {:ownership_type, type}, query when is_binary(type) ->
        from e in query, where: e.ownership_type == ^type

      {:date_range, %{start: start_date, end: end_date}}, query ->
        from e in query,
          where: e.starts_at >= ^DateTime.new!(start_date, ~T[00:00:00]) and
                 e.starts_at <= ^DateTime.new!(end_date, ~T[23:59:59])

      {:auto_generated, bool}, query when is_boolean(bool) ->
        from e in query, where: e.auto_generated == ^bool

      {:has_workflow, bool}, query when is_boolean(bool) ->
        if bool do
          from e in query, where: not is_nil(e.workflow_template)
        else
          from e in query, where: is_nil(e.workflow_template)
        end

      _, query -> query
    end)
    |> order_by([e], [desc: e.starts_at])
  end

  # iCal export functions
  defp generate_ical_content(events) do
    header = """
    BEGIN:VCALENDAR
    VERSION:2.0
    PRODID:-//Frestyl//Calendar//EN
    CALSCALE:GREGORIAN
    METHOD:PUBLISH
    """

    events_content = Enum.map_join(events, "\n", &format_event_as_ical/1)

    footer = "END:VCALENDAR"

    header <> events_content <> "\n" <> footer
  end

  defp format_event_as_ical(event) do
    start_time = format_datetime_for_ical(event.starts_at)
    end_time = format_datetime_for_ical(event.ends_at)

    """
    BEGIN:VEVENT
    UID:#{event.id}@frestyl.com
    DTSTART:#{start_time}
    DTEND:#{end_time}
    SUMMARY:#{escape_ical_text(event.title)}
    DESCRIPTION:#{escape_ical_text(event.description || "")}
    STATUS:#{map_status_to_ical(event.completion_status)}
    PRIORITY:#{map_priority_to_ical(event.priority_level)}
    CATEGORIES:#{event.content_type}
    CREATED:#{format_datetime_for_ical(event.inserted_at)}
    LAST-MODIFIED:#{format_datetime_for_ical(event.updated_at)}
    END:VEVENT
    """
  end

  defp format_datetime_for_ical(nil), do: ""
  defp format_datetime_for_ical(datetime) do
    datetime
    |> DateTime.to_naive()
    |> NaiveDateTime.to_iso8601()
    |> String.replace(~r/[-:]/, "")
    |> String.replace("T", "T")
    |> Kernel.<>("Z")
  end

  defp escape_ical_text(text) do
    text
    |> String.replace("\\", "\\\\")
    |> String.replace(",", "\\,")
    |> String.replace(";", "\\;")
    |> String.replace("\n", "\\n")
  end

  defp map_status_to_ical("completed"), do: "COMPLETED"
  defp map_status_to_ical("in_progress"), do: "IN-PROCESS"
  defp map_status_to_ical("cancelled"), do: "CANCELLED"
  defp map_status_to_ical(_), do: "CONFIRMED"

  defp map_priority_to_ical("critical"), do: "1"
  defp map_priority_to_ical("high"), do: "3"
  defp map_priority_to_ical("medium"), do: "5"
  defp map_priority_to_ical("low"), do: "7"
  defp map_priority_to_ical(_), do: "5"

  # Reminder functions
  defp schedule_single_reminder(event, reminder_offset) do
    reminder_time = calculate_reminder_time(event.starts_at, reminder_offset)

    if DateTime.compare(reminder_time, DateTime.utc_now()) == :gt do
      # Schedule the reminder (this would integrate with your job system)
      # For now, we'll just log it
      # Logger.info("Reminder scheduled for event #{event.id} at #{reminder_time}")
      :ok
    else
      :already_passed
    end
  end

  defp calculate_reminder_time(start_time, offset) do
    case offset do
      "7d" -> DateTime.add(start_time, -7 * 24 * 60 * 60, :second)
      "3d" -> DateTime.add(start_time, -3 * 24 * 60 * 60, :second)
      "1d" -> DateTime.add(start_time, -1 * 24 * 60 * 60, :second)
      "4h" -> DateTime.add(start_time, -4 * 60 * 60, :second)
      "2h" -> DateTime.add(start_time, -2 * 60 * 60, :second)
      "30m" -> DateTime.add(start_time, -30 * 60, :second)
      _ -> start_time
    end
  end

  defp send_email_reminder(event) do
    # This would integrate with your email system
    # For now, we'll just return success
    {:ok, "Email reminder sent for event: #{event.title}"}
  end

  defp send_push_reminder(event) do
    # This would integrate with your push notification system
    {:ok, "Push reminder sent for event: #{event.title}"}
  end

  defp send_sms_reminder(event) do
    # This would integrate with your SMS system
    {:ok, "SMS reminder sent for event: #{event.title}"}
  end

  # Recurring event functions
  defp parse_recurrence_rule(rule) when is_binary(rule) do
    # Simple recurrence rule parsing
    # This would be more sophisticated in a real implementation
    case rule do
      "daily" -> {:ok, %{freq: :daily, interval: 1}}
      "weekly" -> {:ok, %{freq: :weekly, interval: 1}}
      "monthly" -> {:ok, %{freq: :monthly, interval: 1}}
      _ -> {:error, :invalid_recurrence_rule}
    end
  end

  defp generate_recurring_dates(start_date, rule, count \\ 10) do
    case rule.freq do
      :daily ->
        for i <- 0..(count-1) do
          DateTime.add(start_date, i * 24 * 60 * 60, :second)
        end

      :weekly ->
        for i <- 0..(count-1) do
          DateTime.add(start_date, i * 7 * 24 * 60 * 60, :second)
        end

      :monthly ->
        for i <- 0..(count-1) do
          # This is simplified - real monthly recurrence is more complex
          DateTime.add(start_date, i * 30 * 24 * 60 * 60, :second)
        end
    end
  end

  defp create_event_series(base_attrs, dates) do
    Multi.new()
    |> create_events_from_dates(base_attrs, dates)
    |> Repo.transaction()
  end

  defp create_events_from_dates(multi, base_attrs, dates) do
    Enum.with_index(dates)
    |> Enum.reduce(multi, fn {date, index}, acc ->
      duration = DateTime.diff(base_attrs[:ends_at], base_attrs[:starts_at], :second)

      event_attrs = base_attrs
      |> Map.put(:starts_at, date)
      |> Map.put(:ends_at, DateTime.add(date, duration, :second))
      |> Map.put(:title, "#{base_attrs[:title]} #{index + 1}")

      Multi.insert(acc, {:event, index}, Event.changeset(%Event{}, event_attrs))
    end)
  end

  # Integration functions
  defp sync_google_calendar(integration) do
    # Google Calendar API integration
    # This would use the Google Calendar API to sync events
    {:ok, "Google calendar synced"}
  end

  defp sync_outlook_calendar(integration) do
    # Microsoft Graph API integration
    # This would use the Microsoft Graph API to sync events
    {:ok, "Outlook calendar synced"}
  end

  # Metrics and usage tracking
  defp count_accepted_suggestions(user_id, start_date, end_date) do
    from(s in ContentSuggestion,
      where: s.user_id == ^user_id and
             s.status == "accepted" and
             s.updated_at >= ^DateTime.new!(start_date, ~T[00:00:00]) and
             s.updated_at <= ^DateTime.new!(end_date, ~T[23:59:59])
    )
    |> Repo.aggregate(:count)
  end

  defp count_workflow_usage(user_id, start_date, end_date) do
    from(e in Event,
      where: e.creator_id == ^user_id and
             not is_nil(e.workflow_template) and
             e.inserted_at >= ^DateTime.new!(start_date, ~T[00:00:00]) and
             e.inserted_at <= ^DateTime.new!(end_date, ~T[23:59:59])
    )
    |> Repo.aggregate(:count)
  end

  defp calculate_productivity_trend(user_id, timeframe) do
    # Calculate productivity trend over time
    # This would compare current period with previous period
    current_metrics = get_calendar_usage_metrics(user_id, timeframe)

    # For now, return a simple trend indicator
    case current_metrics.events_completed do
      n when n > 10 -> :increasing
      n when n > 5 -> :stable
      _ -> :decreasing
    end
  end

  # Utility Functions
  defp is_overdue?(event) do
    case event.starts_at do
      nil -> false
      start_time -> DateTime.compare(DateTime.utc_now(), start_time) == :gt
    end
  end

  defp is_today?(event) do
    case event.starts_at do
      nil -> false
      start_time -> Date.compare(DateTime.to_date(start_time), Date.utc_today()) == :eq
    end
  end

  defp is_this_week?(event, now) do
    case event.starts_at do
      nil -> false
      start_time ->
        days_diff = DateTime.diff(start_time, now, :day)
        days_diff >= 0 && days_diff <= 7
    end
  end

  defp days_until_due(event) do
    case event.starts_at do
      nil -> 999
      start_time -> DateTime.diff(start_time, DateTime.utc_now(), :day)
    end
  end

  defp format_relative_time(nil), do: "No due date"
  defp format_relative_time(datetime) do
    days = DateTime.diff(datetime, DateTime.utc_now(), :day)

    cond do
      days < 0 -> "#{abs(days)} days overdue"
      days == 0 -> "Due today"
      days == 1 -> "Due tomorrow"
      days <= 7 -> "Due in #{days} days"
      true -> "Due #{Date.to_string(DateTime.to_date(datetime))}"
    end
  end

  defp can_edit_event?(event, user, account) do
    event.creator_id == user.id ||
    (event.account_id == account.id && user.role in ["admin", "owner"])
  end

  defp can_delete_event?(event, user, account) do
    event.creator_id == user.id ||
    (event.account_id == account.id && user.role in ["admin", "owner"])
  end

  defp can_complete_event?(event, user) do
    event.creator_id == user.id && event.completion_status in ["pending", "in_progress"]
  end

  defp can_defer_event?(event, user) do
    event.creator_id == user.id && event.completion_status in ["pending", "in_progress"]
  end

  defp get_priority_icon("critical"), do: "🔴"
  defp get_priority_icon("high"), do: "🟠"
  defp get_priority_icon("medium"), do: "🟡"
  defp get_priority_icon("low"), do: "🟢"
  defp get_priority_icon(_), do: "⚪"

  defp map_suggestion_priority("critical"), do: "critical"
  defp map_suggestion_priority("high"), do: "high"
  defp map_suggestion_priority("medium"), do: "medium"
  defp map_suggestion_priority("low"), do: "low"
  defp map_suggestion_priority(_), do: "medium"

  defp calculate_avg_completion_time(events) do
    completed_events = Enum.filter(events, &(&1.completion_status == "completed"))

    if Enum.empty?(completed_events) do
      0
    else
      total_time = Enum.reduce(completed_events, 0, fn event, acc ->
        actual_time = get_in(event.metadata, ["actual_completion_time_minutes"]) ||
                     event.estimated_time_minutes || 0
        acc + actual_time
      end)

      (total_time / length(completed_events)) |> Float.round(1)
    end
  end

  defp calculate_avg_time_for_events(events) do
    if Enum.empty?(events) do
      0
    else
      total_time = Enum.reduce(events, 0, fn event, acc ->
        acc + (event.estimated_time_minutes || 0)
      end)

      (total_time / length(events)) |> Float.round(1)
    end
  end

  defp get_workflow_template_id(_template_name) do
    # This would look up actual workflow template IDs
    Ecto.UUID.generate()
  end

  defp get_workflow_step_count(template_name) do
    case template_name do
      "portfolio_update_workflow" -> 5
      "skill_development_workflow" -> 4
      "portfolio_health_check" -> 6
      _ -> 3
    end
  end
end
