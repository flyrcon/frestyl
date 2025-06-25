defmodule Frestyl.Exports.ExportJob do
  use Ecto.Schema
  import Ecto.Changeset

  schema "export_jobs" do
    belongs_to :portfolio, Frestyl.Portfolios.Portfolio
    belongs_to :user, Frestyl.Accounts.User
    belongs_to :account, Frestyl.Accounts.UserAccount

    field :export_type, :string
    field :format, :string
    field :status, Ecto.Enum, values: [:pending, :processing, :completed, :failed], default: :pending
    field :file_path, :string
    field :file_size, :integer
    field :options, :map, default: %{}
    field :error_message, :string
    field :completed_at, :utc_datetime

    timestamps()
  end

  def changeset(export_job, attrs) do
    export_job
    |> cast(attrs, [:export_type, :format, :status, :file_path, :file_size, :options, :error_message, :completed_at])
    |> validate_required([:export_type, :format])
    |> validate_inclusion(:status, [:pending, :processing, :completed, :failed])
    |> validate_inclusion(:export_type, ["pdf_resume", "portfolio_pdf", "social_story", "ats_resume", "api_export"])
  end
end
