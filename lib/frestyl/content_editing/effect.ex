# lib/frestyl/content_editing/effect.ex
defmodule Frestyl.ContentEditing.Effect do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "editing_effects" do
    field :name, :string
    field :effect_type, :string # color_grading, noise_reduction, eq, reverb, etc.
    field :target_type, :string # clip, track, project
    field :target_id, :binary_id # ID of target (clip_id, track_id, etc.)
    field :enabled, :boolean, default: true
    field :order, :integer # order in effects chain
    field :parameters, :map, default: %{}
    field :preset_name, :string
    field :processing_status, :string, default: "pending" # pending, processing, completed, failed
    field :processing_progress, :float, default: 0.0
    field :result_url, :string # URL to processed result
    field :metadata, :map, default: %{}

    belongs_to :project, Frestyl.ContentEditing.Project
    belongs_to :creator, Frestyl.Accounts.User

    timestamps()
  end

  def changeset(effect, attrs) do
    effect
    |> cast(attrs, [:name, :effect_type, :target_type, :target_id, :enabled, :order,
                    :parameters, :preset_name, :processing_status, :processing_progress,
                    :result_url, :metadata, :project_id, :creator_id])
    |> validate_required([:effect_type, :target_type, :target_id, :project_id, :creator_id])
    |> validate_length(:name, max: 255)
    |> validate_inclusion(:effect_type, valid_effect_types())
    |> validate_inclusion(:target_type, ~w(clip track project))
    |> validate_inclusion(:processing_status, ~w(pending processing completed failed))
    |> validate_number(:order, greater_than_or_equal_to: 0)
    |> validate_number(:processing_progress, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> generate_name_if_needed()
  end

  defp valid_effect_types do
    ~w(
      color_grading brightness contrast saturation hue_shift
      noise_reduction eq compression reverb delay chorus flanger
      stabilization motion_blur gaussian_blur sharpen
      crop resize rotate flip
      fade_in fade_out crossfade
      speed_change pitch_shift
      text_overlay image_overlay
      chroma_key masking
      ai_enhancement auto_enhance
    )
  end

  defp generate_name_if_needed(changeset) do
    case get_change(changeset, :name) do
      nil ->
        effect_type = get_change(changeset, :effect_type)
        if effect_type do
          name = effect_type
          |> String.replace("_", " ")
          |> String.split()
          |> Enum.map(&String.capitalize/1)
          |> Enum.join(" ")

          put_change(changeset, :name, name)
        else
          changeset
        end
      _ -> changeset
    end
  end
end
