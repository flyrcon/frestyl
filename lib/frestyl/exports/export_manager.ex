defmodule Frestyl.Exports.ExportManager do
  alias Frestyl.Exports.ExportJob
  alias Frestyl.{Accounts, Repo}

  def export_portfolio(portfolio, user, export_options) do
    subscription_tier = get_user_subscription_tier(user)

    case validate_export_permissions(subscription_tier, export_options) do
      {:ok, validated_options} ->
        process_export(portfolio, user, validated_options, subscription_tier)
      {:error, reason} ->
        {:error, {:subscription_required, reason}}
    end
  end

  defp validate_export_permissions(tier, options) do
    case tier do
      :basic -> validate_basic_export(options)
      :creator -> validate_creator_export(options)
      :professional -> validate_professional_export(options)
      :enterprise -> validate_enterprise_export(options)
    end
  end

  defp process_export(portfolio, user, options, tier) do
    export_job_attrs = %{
      portfolio_id: portfolio.id,
      user_id: user.id,
      account_id: get_user_account_id(user),
      export_type: options.export_type,
      format: options.format,
      options: %{
        quality: get_quality_for_tier(tier),
        branding: get_branding_for_tier(tier),
        ats_optimization: tier in [:professional, :enterprise],
        watermark: tier == :basic
      }
    }

    case create_export_job(export_job_attrs) do
      {:ok, export_job} ->
        Oban.insert(Frestyl.Workers.ExportWorker.new(%{export_job_id: export_job.id}))
        {:ok, export_job}
      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp create_export_job(attrs) do
    %ExportJob{}
    |> ExportJob.changeset(attrs)
    |> Repo.insert()
  end

  defp get_user_subscription_tier(user) do
    case user.subscription_tier do
      "free" -> :basic
      "creator" -> :creator
      "professional" -> :professional
      "enterprise" -> :enterprise
      _ -> :basic
    end
  end

  defp get_user_account_id(user) do
    # Get the primary account for the user
    case Accounts.get_primary_user_account(user.id) do
      nil -> nil
      account -> account.id
    end
  end

  defp validate_basic_export(options) do
    case options.export_type do
      "pdf_resume" -> {:ok, options}
      _ -> {:error, "Only PDF resume export available for basic tier"}
    end
  end

  defp validate_creator_export(options) do
    allowed_types = ["pdf_resume", "portfolio_pdf", "social_story"]
    if options.export_type in allowed_types do
      {:ok, options}
    else
      {:error, "Export type not available for creator tier"}
    end
  end

  defp validate_professional_export(options) do
    allowed_types = ["pdf_resume", "portfolio_pdf", "social_story", "ats_resume", "branded_exports"]
    if options.export_type in allowed_types do
      {:ok, options}
    else
      {:error, "Export type not available for professional tier"}
    end
  end

  defp validate_enterprise_export(options) do
    # Enterprise has access to all export types
    {:ok, options}
  end

  defp get_quality_for_tier(:basic), do: "standard"
  defp get_quality_for_tier(:creator), do: "high"
  defp get_quality_for_tier(:professional), do: "ultra_high"
  defp get_quality_for_tier(:enterprise), do: "raw"

  defp get_branding_for_tier(:basic), do: %{watermark: true, custom_branding: false}
  defp get_branding_for_tier(:creator), do: %{watermark: false, custom_branding: false}
  defp get_branding_for_tier(:professional), do: %{watermark: false, custom_branding: true}
  defp get_branding_for_tier(:enterprise), do: %{watermark: false, custom_branding: true, white_label: true}
end
