# lib/frestyl/content_editing/render_job.ex
defmodule Frestyl.ContentEditing.RenderJob do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "editing_render_jobs" do
    field :status, :string, default: "queued" # queued, processing, completed, failed, cancelled
    field :progress, :float, default: 0.0
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :failed_at, :utc_datetime
    field :error_message, :string
    field :render_settings, :map, default: %{}
    field :output_file_url, :string
    field :output_file_size, :integer
    field :processing_time, :integer # seconds
    field :estimated_completion, :utc_datetime
    field :priority, :integer, default: 0
    field :metadata, :map, default: %{}

    belongs_to :project, Frestyl.ContentEditing.Project
    belongs_to :user, Frestyl.Accounts.User

    timestamps()
  end

  def changeset(render_job, attrs) do
    render_job
    |> cast(attrs, [:status, :progress, :started_at, :completed_at, :failed_at, :error_message,
                    :render_settings, :output_file_url, :output_file_size, :processing_time,
                    :estimated_completion, :priority, :metadata, :project_id, :user_id])
    |> validate_required([:project_id, :user_id])
    |> validate_inclusion(:status, ~w(queued processing completed failed cancelled))
    |> validate_number(:progress, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:priority, greater_than_or_equal_to: 0)
    |> validate_number(:output_file_size, greater_than_or_equal_to: 0)
    |> validate_number(:processing_time, greater_than_or_equal_to: 0)
  end
end
