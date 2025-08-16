# lib/frestyl/content_editing/project.ex
defmodule Frestyl.ContentEditing.Project do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "editing_projects" do
    field :name, :string
    field :description, :string
    field :project_type, :string # video, audio, podcast, text, mixed
    field :status, :string, default: "draft" # draft, active, rendering, completed, archived
    field :settings, :map, default: %{}
    field :metadata, :map, default: %{}
    field :duration, :integer, default: 0 # in milliseconds
    field :render_settings, :map, default: %{}
    field :collaboration_enabled, :boolean, default: true
    field :auto_save_enabled, :boolean, default: true
    field :version, :integer, default: 1

    belongs_to :creator, Frestyl.Accounts.User
    belongs_to :channel, Frestyl.Channels.Channel
    belongs_to :session, Frestyl.Sessions.Session # Associated editing session

    has_many :tracks, Frestyl.ContentEditing.Track
    has_many :clips, Frestyl.ContentEditing.Clip
    has_many :effects, Frestyl.ContentEditing.Effect
    has_many :timeline_entries, Frestyl.ContentEditing.Timeline
    has_many :render_jobs, Frestyl.ContentEditing.RenderJob
    has_many :collaborators, Frestyl.ContentEditing.Collaborator

    timestamps()
  end

  def changeset(project, attrs) do
    project
    |> cast(attrs, [:name, :description, :project_type, :status, :settings, :metadata,
                    :duration, :render_settings, :collaboration_enabled, :auto_save_enabled,
                    :version, :creator_id, :channel_id, :session_id])
    |> validate_required([:name, :project_type, :creator_id])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_length(:description, max: 2000)
    |> validate_inclusion(:project_type, ~w(video audio podcast text mixed))
    |> validate_inclusion(:status, ~w(draft active rendering completed archived))
    |> validate_number(:duration, greater_than_or_equal_to: 0)
    |> validate_number(:version, greater_than: 0)
  end
end
