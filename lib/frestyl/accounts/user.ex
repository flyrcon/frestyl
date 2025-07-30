# lib/frestyl/accounts/user.ex
defmodule Frestyl.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  # JSON encoding with fields that actually exist in your database
  @derive {Jason.Encoder, only: [:id, :name, :email, :username, :display_name, :bio, :avatar_url, :role, :verified, :full_name, :website, :status, :inserted_at, :updated_at]}

  schema "users" do
    # Core fields that exist in your database
    field :name, :string
    field :email, :string
    field :password_hash, :string, redact: true  # Your DB has password_hash, not hashed_password
    field :username, :string
    field :display_name, :string
    field :bio, :string
    field :avatar_url, :string
    field :role, :string
    field :verified, :boolean, default: false
    field :confirmed_at, :utc_datetime
    field :full_name, :string
    field :confirmation_token, :string
    field :confirmation_sent_at, :utc_datetime
    field :profile_video_url, :string
    field :profile_audio_url, :string
    field :totp_secret, :string, redact: true
    field :totp_enabled, :boolean, default: false
    field :backup_codes, {:array, :string}, redact: true
    field :privacy_settings, :map, default: %{}
    field :timezone, :string
    field :preferences, :map, default: %{}
    field :website, :string
    field :social_links, :map, default: %{}
    field :last_active_at, :utc_datetime
    field :status, :string, default: "active"
    field :primary_account_type, Ecto.Enum, values: [:personal, :professional, :enterprise]
    field :subscription_tier, Ecto.Enum, values: [:personal, :creator, :professional, :enterprise]
    field :onboarding_completed, :boolean, default: false


    # Virtual field for forms
    field :password, :string, virtual: true, redact: true

    # Relationships
    has_many :media_files, Frestyl.Media.MediaFile, on_delete: :delete_all, foreign_key: :user_id
    has_many :reactions, Frestyl.Media.MediaReaction, on_delete: :delete_all, foreign_key: :user_id
    has_many :view_histories, Frestyl.Media.ViewHistory, on_delete: :delete_all, foreign_key: :user_id
    has_many :theme_preferences, Frestyl.Media.UserThemePreferences, on_delete: :delete_all, foreign_key: :user_id
    has_many :saved_filters, Frestyl.Media.SavedFilter, on_delete: :delete_all, foreign_key: :user_id
    has_many :discussions, Frestyl.Media.MediaDiscussion, on_delete: :delete_all, foreign_key: :user_id
    has_many :discussion_messages, Frestyl.Media.DiscussionMessage, on_delete: :delete_all, foreign_key: :user_id
    has_many :user_accounts, Frestyl.Accounts.UserAccount
    has_many :portfolios, Frestyl.Portfolios.Portfolio

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email, :primary_account_type, :username, :display_name, :bio, :avatar_url, :full_name, :website, :social_links, :timezone, :preferences, :privacy_settings, :onboarding_completed, :subscription_tier, :primary_account_type])
    |> validate_required([:email, :primary_account_type])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> validate_inclusion(:primary_account_type, [:personal, :professional, :enterprise])
    |> unique_constraint(:email)
    |> validate_username()
  end

  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:name, :email, :password, :username, :display_name, :bio, :full_name])
    |> validate_required([:email])
    |> validate_email(opts)
    |> validate_password(opts)
    |> validate_username()
  end

  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :username, :display_name, :avatar_url, :bio, :full_name, :website, :social_links, :timezone, :preferences, :privacy_settings])
    |> validate_username()
    |> validate_length(:display_name, max: 100)
    |> validate_length(:bio, max: 500)
    |> validate_url(:avatar_url)
    |> validate_url(:website)
    |> validate_url(:profile_video_url)
    |> validate_url(:profile_audio_url)
  end

  defp validate_email(changeset, opts) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> maybe_validate_unique_email(opts)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 8, max: 72)
    |> maybe_hash_password(opts)
  end

  defp validate_username(changeset) do
    case get_field(changeset, :username) do
      nil -> changeset
      "" -> changeset
      _ ->
        changeset
        |> validate_length(:username, min: 3, max: 30)
        |> validate_format(:username, ~r/^[a-zA-Z0-9_]+$/, message: "only letters, numbers, and underscores allowed")
        |> unique_constraint(:username)
    end
  end

  defp validate_url(changeset, field) do
    case get_field(changeset, field) do
      nil -> changeset
      "" -> changeset
      _ -> validate_format(changeset, field, ~r/^https?:\/\/.+/, message: "must be a valid URL")
    end
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      |> put_change(:password_hash, hash_password(password))  # Use password_hash not hashed_password
      |> delete_change(:password)
    else
      changeset
    end
  end

  defp maybe_validate_unique_email(changeset, opts) do
    if Keyword.get(opts, :validate_email, true) do
      changeset
      |> unsafe_validate_unique(:email, Frestyl.Repo)
      |> unique_constraint(:email)
    else
      changeset
    end
  end

  # Use bcrypt if available
  defp hash_password(password) do
    if Code.ensure_loaded?(Bcrypt) do
      Bcrypt.hash_pwd_salt(password)
    else
      password
    end
  end

  @doc """
  Verifies the password.
  """
  def valid_password?(%__MODULE__{password_hash: password_hash}, password)
      when is_binary(password_hash) and byte_size(password) > 0 do
    if Code.ensure_loaded?(Bcrypt) do
      Bcrypt.verify_pass(password, password_hash)
    else
      password_hash == password
    end
  end

  def valid_password?(_, _) do
    if Code.ensure_loaded?(Bcrypt) do
      Bcrypt.no_user_verify()
    end
    false
  end

  @doc """
  Validates the current password otherwise adds an error to the changeset.
  """
  def validate_current_password(changeset, password) do
    if valid_password?(changeset.data, password) do
      changeset
    else
      add_error(changeset, :current_password, "is not valid")
    end
  end

  # Helper functions for display and JSON
  def display_name(%__MODULE__{display_name: display_name, full_name: full_name, name: name, username: username, email: email}) do
    display_name || full_name || name || username || email || "Anonymous"
  end

  def initials(%__MODULE__{} = user) do
    display_name(user)
    |> String.split()
    |> Enum.take(2)
    |> Enum.map(&String.first/1)
    |> Enum.join()
    |> String.upcase()
  end

  def avatar_url(%__MODULE__{avatar_url: nil} = user) do
    initials = initials(user)
    "https://ui-avatars.com/api/?name=#{URI.encode(initials)}&background=6366f1&color=fff"
  end

  def avatar_url(%__MODULE__{avatar_url: url}), do: url

  # Preferences helper functions
  def preferences(%__MODULE__{preferences: prefs}) when is_map(prefs), do: prefs
  def preferences(_user), do: %{}

  def get_preference(user, key, default \\ nil) do
    user
    |> preferences()
    |> Map.get(to_string(key), default)
  end

  def set_preference(user, key, value) do
    new_prefs =
      user
      |> preferences()
      |> Map.put(to_string(key), value)

    {:ok, %{user | preferences: new_prefs}}
  end

  def subscription_changeset(user, attrs) do
    user
    |> cast(attrs, [:subscription_tier])
    |> validate_inclusion(:subscription_tier, [:personal, :creator, :professional, :enterprise])
  end

  # Role and permission helpers
  def admin?(%__MODULE__{role: "admin"}), do: true
  def admin?(_), do: false

  def verified?(%__MODULE__{verified: true}), do: true
  def verified?(_), do: false

  def active?(%__MODULE__{status: "active"}), do: true
  def active?(_), do: false

  # Social links helper
  def get_social_link(user, platform) do
    user
    |> Map.get(:social_links, %{})
    |> Map.get(to_string(platform))
  end

  # Two-factor authentication helpers
  def totp_enabled?(%__MODULE__{totp_enabled: true}), do: true
  def totp_enabled?(_), do: false

  def has_backup_codes?(%__MODULE__{backup_codes: codes}) when is_list(codes) and length(codes) > 0, do: true
  def has_backup_codes?(_), do: false

end
