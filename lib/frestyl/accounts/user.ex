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

    # Add fields for email confirmation token
    field :confirmation_token, :string
    field :confirmation_sent_at, :naive_datetime

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
    |> cast(attrs, [:full_name, :bio, :avatar_url, :website, :social_links])
    |> validate_length(:full_name, max: 255)
    |> validate_length(:bio, max: 2000)
    |> validate_length(:avatar_url, max: 1000)
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
