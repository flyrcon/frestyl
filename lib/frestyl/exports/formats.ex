defmodule Frestyl.Exports.Formats do
  def available_formats(:basic) do
    %{
      pdf_resume: %{
        name: "PDF Resume",
        description: "Standard PDF format",
        max_quality: :standard,
        watermark: true
      }
    }
  end

  def available_formats(:creator) do
    Map.merge(available_formats(:basic), %{
      social_story: %{
        name: "Social Media Story",
        description: "Optimized for social platforms",
        formats: [:instagram_story, :linkedin_post, :twitter_card],
        max_quality: :high
      },
      portfolio_pdf: %{
        name: "Portfolio PDF",
        description: "Complete portfolio as PDF",
        max_quality: :high,
        watermark: false
      }
    })
  end

  def available_formats(:professional) do
    Map.merge(available_formats(:creator), %{
      ats_resume: %{
        name: "ATS-Optimized Resume",
        description: "Applicant Tracking System optimized",
        ats_score: true,
        custom_branding: true
      },
      branded_exports: %{
        name: "Branded Portfolio",
        description: "Custom branded exports",
        custom_templates: true,
        batch_processing: true
      }
    })
  end

  def available_formats(:enterprise) do
    Map.merge(available_formats(:professional), %{
      api_export: %{
        name: "API Export",
        description: "Programmatic access to portfolio data",
        formats: [:json, :xml, :csv],
        bulk_operations: true
      },
      white_label: %{
        name: "White-label Export",
        description: "Completely unbranded exports",
        custom_domains: true,
        unlimited_batch: true
      }
    })
  end
end
