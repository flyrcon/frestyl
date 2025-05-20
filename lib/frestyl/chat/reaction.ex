defmodule Frestyl.Chat.Reaction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "reactions" do
    field :emoji, :string
    field :reaction_type, :string, default: "emoji"  # "emoji" or "custom"
    field :custom_text, :string  # For custom reactions including hip-hop, slang and other creative reactions

    belongs_to :message, Frestyl.Chat.Message
    belongs_to :user, Frestyl.Accounts.User

    timestamps()
  end

  def changeset(reaction, attrs) do
    reaction
    |> cast(attrs, [:emoji, :reaction_type, :custom_text, :message_id, :user_id])
    |> validate_required([:reaction_type, :message_id, :user_id])
    |> validate_inclusion(:reaction_type, ["emoji", "custom"])
    |> validate_reaction_content()
    |> unique_constraint([:message_id, :user_id, :emoji, :reaction_type],
                        name: :unique_user_emoji_reaction)
  end

  defp validate_reaction_content(changeset) do
    reaction_type = get_field(changeset, :reaction_type)
    emoji = get_field(changeset, :emoji)
    custom_text = get_field(changeset, :custom_text)

    case reaction_type do
      "emoji" ->
        if is_nil(emoji) or emoji == "" do
          add_error(changeset, :emoji, "can't be blank when reaction type is emoji")
        else
          changeset
        end
      "custom" ->
        if is_nil(custom_text) or custom_text == "" do
          add_error(changeset, :custom_text, "can't be blank when reaction type is custom")
        else
          changeset
        end
      _ ->
        changeset
    end
  end
end
