# Migration 1: Add privacy and social fields to portfolios table
# File: priv/repo/migrations/20241201000001_add_social_privacy_to_portfolios.exs

defmodule Frestyl.Repo.Migrations.AddSocialPrivacyToPortfolios do
  use Ecto.Migration

  def change do
    alter table(:portfolios) do
      add :privacy_settings, :map, default: %{}
      add :social_integration, :map, default: %{}
      add :contact_info, :map, default: %{}
      add :access_request_settings, :map, default: %{}
    end

    execute("""
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'portfolio_visibility') THEN
        BEGIN
          ALTER TYPE portfolio_visibility ADD VALUE IF NOT EXISTS 'request_only';
        EXCEPTION
          WHEN duplicate_object THEN NULL;
        END;
      END IF;
    END;
    $$;
    """, """
    -- Downgrade: no-op, since removing enum values is not straightforward
    """)
  end

end
