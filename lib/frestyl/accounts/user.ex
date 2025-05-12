defmodule Frestyl.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset
  # Ensure hash_generate is imported for password hashing
  import Bcrypt, only: [verify_pass: 2, hash_generate: 1]


  schema "users" do
    field :name, :string
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :password_hash, :string
    field :confirmed_at, :naive_datetime # <-- Add this field for email confirmation
    field :status, :string, default: "offline"
    field :username, :string

    # New fields
    field :role, :string, default: "user"
    field :subscription_tier, :string, default: "free"
    field :full_name, :string
    field :bio, :string
    field :avatar_url, :string
    field :website, :string
    field :social_links, :map, default: %{}
    field :last_active_at, :utc_datetime

    # Update media-related fields
    field :profile_video_url, :string
    field :profile_audio_url, :string

    # Add virtual fields for file uploads
    field :avatar_upload, :any, virtual: true
    field :video_upload, :any, virtual: true
    field :audio_upload, :any, virtual: true

    # Add fields for email confirmation token
    field :confirmation_token, :string
    field :confirmation_sent_at, :naive_datetime

    field :totp_secret, :binary
    field :totp_enabled, :boolean, default: false
    field :backup_codes, {:array, :string}

    field :totp_code, :string, virtual: true

    # Privacy
    field :privacy_settings, :map, default: %{
      "profile_visibility" => "public",
      "media_visibility" => "public",
      "metrics_visibility" => "private"
    }

    timestamps()
  end

  # You may have a general changeset for admin use etc.
  # Ensure this one handles password hashing correctly if password is changed.
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password, :name]) # Added name based on required validation
    |> validate_required([:name, :email]) # Password required handled in registration_changeset
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> unique_constraint(:email)
    # Apply password hashing only if password is provided
    |> put_password_hash()
  end

  # Add to lib/frestyl/accounts/user.ex
  def privacy_changeset(user, attrs) do
    user
    |> cast(attrs, [:privacy_settings])
    |> validate_privacy_settings()
  end

  defp validate_privacy_settings(changeset) do
    validate_change(changeset, :privacy_settings, fn _, privacy_settings ->
      valid_visibilities = ["public", "friends", "private"]

      required_settings = [
        "profile_visibility",
        "media_visibility",
        "metrics_visibility"
      ]

      errors = []

      # Validate that all required settings are present
      errors = Enum.reduce(required_settings, errors, fn setting, acc ->
        if !Map.has_key?(privacy_settings, setting) do
          [{:privacy_settings, "missing required setting: #{setting}"} | acc]
        else
          acc
        end
      end)

      # Validate that all present settings have valid values
      errors = Enum.reduce(privacy_settings, errors, fn {setting, value}, acc ->
        if value not in valid_visibilities do
          [{:privacy_settings, "invalid visibility value for #{setting}: must be one of #{Enum.join(valid_visibilities, ", ")}"} | acc]
        else
          acc
        end
      end)

      errors
    end)
  end

  # Corrected password hashing function
  defp put_password_hash(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true, changes: %{password: password}} when is_binary(password) and byte_size(password) > 0 ->
        # Use Bcrypt.hash_generate to securely hash the password
        put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))
      _ ->
        changeset # No password change, return changeset as is
    end
  end

  # Corrected valid_password? function to reference password_hash
  def valid_password?(%Frestyl.Accounts.User{password_hash: password_hash}, password)
      when is_binary(password) and is_binary(password_hash) do
    # Use Bcrypt.verify_pass to compare the provided password with the stored hash
    Bcrypt.verify_pass(password, password_hash)
  end

  # Keep the helper for timing attack resistance on failed attempts
  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  # Add this function to lib/frestyl/accounts/user.ex
  def two_factor_auth_changeset(user, attrs) do
    user
    |> cast(attrs, [:totp_secret, :totp_enabled, :backup_codes])
    |> validate_required([:totp_enabled])
  end

  # Add this function for verifying TOTP codes during login
  def totp_verification_changeset(user, attrs) do
    user
    |> cast(attrs, [:totp_code])
    |> validate_required([:totp_code])
    |> validate_length(:totp_code, is: 6)
    |> validate_format(:totp_code, ~r/^[0-9]+$/, message: "must contain only numbers")
  end

  # This changeset is specifically for registration
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email, :password, :username, :confirmed_at, :confirmation_token, :confirmation_sent_at]) # Include confirmation fields
    |> validate_required([:name, :email, :password, :username])
    # Ensure required fields are present *before* unique constraints
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:password, min: 6)
    # Validate username format if needed (e.g., no spaces, certain characters)
    |> unique_constraint(:users_username_index, name: :users_username_index) # Use name: option
    |> unique_constraint(:email, name: :users_email_index) # Use name: option or just field name if index matches
    # Ensure index names match your database indices if using atom names
    # Alternatively, use field names if your index names match:
    # |> unique_constraint(:username)
    # |> unique_constraint(:email)
    |> put_password_hash()
  end

  # Add a changeset specifically for confirming the user
  def confirm_changeset(user, attrs \\ %{}) do
    user
    |> cast(attrs, [:confirmed_at, :confirmation_token])
    |> put_change(:confirmation_token, nil) # Clear the token upon confirmation
    |> put_change(:confirmed_at, DateTime.utc_now()) # Set confirmed_at to current time
    |> validate_required([:confirmed_at])
  end

  def login_changeset(user, attrs) do
    user
    |> Ecto.Changeset.cast(attrs, [:email, :password])
    |> Ecto.Changeset.validate_required([:email, :password])
  end

  def role_changeset(user, attrs) do
    user
    |> cast(attrs, [:role])
    |> validate_inclusion(:role, ["user", "creator", "host", "channel_owner", "admin"])
  end

  def subscription_changeset(user, attrs) do
    user
    |> cast(attrs, [:subscription_tier])
    |> validate_inclusion(:subscription_tier, ["free", "basic", "premium", "pro"])
  end

  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :full_name, :bio, :avatar_url, :website, :social_links, :profile_video_url, :profile_audio_url])
    |> validate_required([:username])
    |> validate_length(:username, min: 3, max: 30)
    |> validate_format(:username, ~r/^[a-zA-Z0-9_-]+$/,
       message: "only letters, numbers, underscores, and hyphens are allowed")
    |> unique_constraint(:username)
    |> validate_length(:full_name, max: 255)
    |> validate_length(:bio, max: 2000)
    |> validate_length(:avatar_url, max: 1000)
    |> validate_length(:profile_video_url, max: 1000)
    |> validate_length(:profile_audio_url, max: 1000)
    |> validate_length(:website, max: 255)
    |> validate_website_format(:website)
  end

  def activity_changeset(user, attrs) do
    user
    |> cast(attrs, [:last_active_at])
  end

  def status_changeset(user, attrs) do
    user
    |> cast(attrs, [:status])
    |> validate_inclusion(:status, ["online", "away", "busy", "offline"])
  end

  defp validate_website_format(changeset, field) do
    validate_change(changeset, field, fn _, website ->
      if is_nil(website) do
        []
      else
        uri = URI.parse(website)
        # Check for scheme, host, and at least one dot in the host
        if uri.scheme in ["http", "https"] && uri.host && String.contains?(uri.host, ".") do
          []
        else
          [{field, "must be a valid URL (e.g., https://example.com)"}]
        end
      end
    end)
  end
end
