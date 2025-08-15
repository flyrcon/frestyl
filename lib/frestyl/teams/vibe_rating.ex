defmodule Frestyl.Teams.VibeRating do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "vibe_ratings" do
    field :primary_score, :float # 0-100 color gradient position
    field :secondary_score, :float # 0-100 vertical axis position
    field :rating_coordinates, :map # {x: 73, y: 45}
    field :rating_type, :string, default: "peer_review"
    field :dimension_context, :string
    field :rating_session_duration, :integer
    field :is_self_rating, :boolean, default: false
    field :translated_scores, :map
    field :rating_prompt, :string
    field :milestone_checkpoint, :string
    field :session_id, :string

    belongs_to :team, Frestyl.Teams.ChannelTeam
    belongs_to :reviewer, Frestyl.Accounts.User
    belongs_to :reviewee, Frestyl.Accounts.User

    timestamps()
  end

  def changeset(rating, attrs) do
    rating
    |> cast(attrs, [:primary_score, :secondary_score, :rating_coordinates, :rating_type,
                    :dimension_context, :rating_session_duration, :is_self_rating,
                    :translated_scores, :rating_prompt, :milestone_checkpoint, :session_id])
    |> validate_required([:team_id, :reviewer_id, :reviewee_id, :primary_score])
    |> validate_number(:primary_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:secondary_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_inclusion(:rating_type, ["peer_review", "milestone", "pulse_check", "self_assessment"])
    |> validate_inclusion(:milestone_checkpoint, ["25%", "50%", "75%", "final", nil])
    |> foreign_key_constraint(:team_id)
    |> foreign_key_constraint(:reviewer_id)
    |> foreign_key_constraint(:reviewee_id)
    |> put_translated_scores()
  end

  defp put_translated_scores(changeset) do
    case get_change(changeset, :primary_score) do
      nil -> changeset
      primary_score ->
        secondary_score = get_change(changeset, :secondary_score) || 50.0

        translated = %{
          "quality" => translate_color_to_score(primary_score),
          "collaboration" => translate_vertical_to_score(secondary_score)
        }

        put_change(changeset, :translated_scores, translated)
    end
  end

  # Convert color position (0-100) to quality score (1-5)
  defp translate_color_to_score(color_position) do
    cond do
      color_position <= 20 -> 1.0
      color_position <= 40 -> 2.0
      color_position <= 60 -> 3.0
      color_position <= 80 -> 4.0
      true -> 5.0
    end
  end

  # Convert vertical position to collaboration score
  defp translate_vertical_to_score(vertical_position) do
    # Linear scale: 0-100 maps to 1-5
    1.0 + (vertical_position / 100.0) * 4.0
  end
end
