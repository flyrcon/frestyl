# lib/frestyl/accounts/user.ex
defmodule Frestyl.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :password_hash, :string
    field :password, :string, virtual: true
    field :password_confirmation, :string, virtual: true
    field :username, :string
    field :display_name, :string
    field :bio, :string
    field :avatar_url, :string
    field :role, Ecto.Enum, values: [:admin, :creator, :host, :attendee, :channel_owner]
    field :verified, :boolean, default: false

    has_many :owned_channels, Frestyl.Channels.Channel, foreign_key: :owner_id
    has_many :created_sessions, Frestyl.Sessions.Session, foreign_key: :creator_id
    has_many :hosted_events, Frestyl.Events.Event, foreign_key: :host_id
    has_many :media_uploads, Frestyl.Media.MediaItem, foreign_key: :uploader_id

    many_to_many :attended_events, Frestyl.Events.Event, join_through: "event_attendees"
    many_to_many :subscribed_channels, Frestyl.Channels.Channel, join_through: "channel_subscribers"
    many_to_many :joined_sessions, Frestyl.Sessions.Session, join_through: "session_participants"

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password, :password_confirmation, :username, :display_name, :bio, :avatar_url, :role])
    |> validate_required([:email, :password, :username, :role])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/)
    |> validate_length(:password, min: 8)
    |> validate_confirmation(:password)
    |> unique_constraint(:email)
    |> unique_constraint(:username)
    |> put_password_hash()
  end

  defp put_password_hash(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true, changes: %{password: password}} ->
        put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))
      _ ->
        changeset
    end
  end
end

# lib/frestyl/channels/channel.ex
defmodule Frestyl.Channels.Channel do
  use Ecto.Schema
  import Ecto.Changeset

  schema "channels" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :logo_url, :string
    field :banner_url, :string
    field :theme_color, :string
    field :is_public, :boolean, default: true
    field :is_verified, :boolean, default: false

    belongs_to :owner, Frestyl.Accounts.User

    has_many :sessions, Frestyl.Sessions.Session
    has_many :events, Frestyl.Events.Event
    has_many :media_items, Frestyl.Media.MediaItem

    many_to_many :subscribers, Frestyl.Accounts.User, join_through: "channel_subscribers"

    timestamps()
  end

  def changeset(channel, attrs) do
    channel
    |> cast(attrs, [:name, :slug, :description, :logo_url, :banner_url, :theme_color, :is_public, :owner_id])
    |> validate_required([:name, :owner_id])
    |> validate_length(:name, min: 2, max: 100)
    |> validate_length(:description, max: 1000)
    |> validate_format(:slug, ~r/^[a-z0-9\-_]+$/)
    |> generate_slug_if_needed()
    |> unique_constraint(:slug)
  end

  defp generate_slug_if_needed(changeset) do
    case get_field(changeset, :slug) do
      nil ->
        case get_field(changeset, :name) do
          nil -> changeset
          name ->
            slug = name
                   |> String.downcase()
                   |> String.replace(~r/[^a-z0-9\-_]/, "-")
                   |> String.replace(~r/-+/, "-")
                   |> String.trim("-")
            put_change(changeset, :slug, slug)
        end
      _ -> changeset
    end
  end
end

# lib/frestyl/sessions/session.ex
defmodule Frestyl.Sessions.Session do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sessions" do
    field :title, :string
    field :description, :string
    field :status, Ecto.Enum, values: [:draft, :active, :completed, :archived], default: :draft
    field :scheduled_start, :utc_datetime
    field :scheduled_end, :utc_datetime
    field :actual_start, :utc_datetime
    field :actual_end, :utc_datetime
    field :max_participants, :integer
    field :is_private, :boolean, default: false
    field :access_code, :string
    field :session_type, Ecto.Enum, values: [:collaboration, :rehearsal, :recording, :other]

    belongs_to :creator, Frestyl.Accounts.User
    belongs_to :channel, Frestyl.Channels.Channel

    has_many :events, Frestyl.Events.Event
    has_many :media_items, Frestyl.Media.MediaItem

    many_to_many :participants, Frestyl.Accounts.User, join_through: "session_participants"

    timestamps()
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [:title, :description, :status, :scheduled_start, :scheduled_end,
                   :max_participants, :is_private, :access_code, :session_type,
                   :creator_id, :channel_id])
    |> validate_required([:title, :creator_id, :channel_id])
    |> validate_length(:title, min: 3, max: 255)
    |> validate_length(:description, max: 2000)
    |> validate_number(:max_participants, greater_than: 0)
    |> validate_scheduled_dates()
    |> maybe_generate_access_code()
  end

  defp validate_scheduled_dates(changeset) do
    scheduled_start = get_field(changeset, :scheduled_start)
    scheduled_end = get_field(changeset, :scheduled_end)

    if scheduled_start && scheduled_end && DateTime.compare(scheduled_end, scheduled_start) == :lt do
      add_error(changeset, :scheduled_end, "must be after scheduled start")
    else
      changeset
    end
  end

  defp maybe_generate_access_code(changeset) do
    is_private = get_field(changeset, :is_private)
    access_code = get_field(changeset, :access_code)

    if is_private && !access_code do
      put_change(changeset, :access_code, generate_random_code())
    else
      changeset
    end
  end

  defp generate_random_code do
    :crypto.strong_rand_bytes(6)
    |> Base.url_encode64
    |> binary_part(0, 8)
  end
end

# lib/frestyl/events/event.ex
defmodule Frestyl.Events.Event do
  use Ecto.Schema
  import Ecto.Changeset

  schema "events" do
    field :title, :string
    field :description, :string
    field :status, Ecto.Enum, values: [:scheduled, :live, :ended, :cancelled], default: :scheduled
    field :scheduled_start, :utc_datetime
    field :scheduled_end, :utc_datetime
    field :actual_start, :utc_datetime
    field :actual_end, :utc_datetime
    field :visibility, Ecto.Enum, values: [:public, :private, :unlisted], default: :public
    field :access_code, :string
    field :max_attendees, :integer
    field :thumbnail_url, :string
    field :recording_available, :boolean, default: false

    belongs_to :host, Frestyl.Accounts.User
    belongs_to :channel, Frestyl.Channels.Channel
    belongs_to :session, Frestyl.Sessions.Session

    has_many :media_items, Frestyl.Media.MediaItem

    many_to_many :attendees, Frestyl.Accounts.User, join_through: "event_attendees"

    timestamps()
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:title, :description, :status, :scheduled_start, :scheduled_end,
                   :visibility, :access_code, :max_attendees, :thumbnail_url,
                   :host_id, :channel_id, :session_id])
    |> validate_required([:title, :scheduled_start, :host_id, :channel_id])
    |> validate_length(:title, min: 3, max: 255)
    |> validate_length(:description, max: 5000)
    |> validate_number(:max_attendees, greater_than: 0)
    |> validate_scheduled_dates()
    |> maybe_generate_access_code()
  end

  defp validate_scheduled_dates(changeset) do
    scheduled_start = get_field(changeset, :scheduled_start)
    scheduled_end = get_field(changeset, :scheduled_end)

    if scheduled_start && scheduled_end && DateTime.compare(scheduled_end, scheduled_start) == :lt do
      add_error(changeset, :scheduled_end, "must be after scheduled start")
    else
      changeset
    end
  end

  defp maybe_generate_access_code(changeset) do
    visibility = get_field(changeset, :visibility)
    access_code = get_field(changeset, :access_code)

    if visibility == :private && !access_code do
      put_change(changeset, :access_code, generate_random_code())
    else
      changeset
    end
  end

  defp generate_random_code do
    :crypto.strong_rand_bytes(6)
    |> Base.url_encode64
    |> binary_part(0, 8)
  end
end

# lib/frestyl/media/media_item.ex
defmodule Frestyl.Media.MediaItem do
  use Ecto.Schema
  import Ecto.Changeset

  schema "media_items" do
    field :title, :string
    field :description, :string
    field :file_path, :string
    field :file_size, :integer
    field :file_type, :string
    field :mime_type, :string
    field :duration, :integer
    field :width, :integer
    field :height, :integer
    field :thumbnail_url, :string
    field :is_public, :boolean, default: false
    field :status, Ecto.Enum, values: [:processing, :ready, :error], default: :processing
    field :media_type, Ecto.Enum, values: [:audio, :video, :image, :document, :other]
    field :metadata, :map

    belongs_to :uploader, Frestyl.Accounts.User
    belongs_to :channel, Frestyl.Channels.Channel
    belongs_to :session, Frestyl.Sessions.Session
    belongs_to :event, Frestyl.Events.Event

    timestamps()
  end

  def changeset(media_item, attrs) do
    media_item
    |> cast(attrs, [:title, :description, :file_path, :file_size, :file_type, :mime_type,
                   :duration, :width, :height, :thumbnail_url, :is_public, :status,
                   :media_type, :metadata, :uploader_id, :channel_id, :session_id, :event_id])
    |> validate_required([:title, :file_path, :file_type, :mime_type, :media_type, :uploader_id])
    |> validate_length(:title, min: 2, max: 255)
    |> validate_length(:description, max: 2000)
    |> validate_number(:file_size, greater_than: 0)
    |> validate_required_associations()
  end

  defp validate_required_associations(changeset) do
    channel_id = get_field(changeset, :channel_id)
    session_id = get_field(changeset, :session_id)
    event_id = get_field(changeset, :event_id)

    if !channel_id && !session_id && !event_id do
      add_error(changeset, :base, "Media must be associated with at least one of: channel, session, or event")
    else
      changeset
    end
  end
end
