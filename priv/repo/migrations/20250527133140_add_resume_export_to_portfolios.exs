defmodule Frestyl.Repo.Migrations.AddResumeExportToPortfolios do
  use Ecto.Migration

  def change do
    alter table(:portfolios) do
      add :allow_resume_export, :boolean, default: false
      add :resume_template, :string, default: "ats_friendly"
      add :resume_config, :map, default: %{}
    end

    create index(:portfolios, [:allow_resume_export])
  end
end
