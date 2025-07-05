defmodule Frestyl.Portfolios.CustomFieldDefinition do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Frestyl.Repo
  alias __MODULE__

  schema "custom_field_definitions" do
    field :field_name, :string
    field :field_type, :string
    field :field_label, :string
    field :field_description, :string
    field :validation_rules, :map
    field :display_options, :map
    field :position, :integer, default: 0
    field :is_required, :boolean, default: false
    field :is_public, :boolean, default: true

    belongs_to :portfolio, Frestyl.Portfolios.Portfolio
    has_many :custom_field_values, Frestyl.Portfolios.CustomFieldValue

    timestamps()
  end

  @field_types ~w(text rich_text number date url email list object boolean)

  def changeset(definition, attrs) do
    definition
    |> cast(attrs, [
      :field_name, :field_type, :field_label, :field_description,
      :validation_rules, :display_options, :position, :is_required, :is_public, :portfolio_id
    ])
    |> validate_required([:field_name, :field_type, :field_label, :portfolio_id])
    |> validate_inclusion(:field_type, @field_types)
    |> validate_format(:field_name, ~r/^[a-z][a-z0-9_]*$/, message: "must start with letter and contain only lowercase letters, numbers, and underscores")
    |> validate_length(:field_name, min: 2, max: 50)
    |> validate_length(:field_label, min: 1, max: 100)
    |> validate_validation_rules()
    |> unique_constraint([:portfolio_id, :field_name])
  end

  # Context functions
  def create(attrs) do
    %CustomFieldDefinition{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  def update(%CustomFieldDefinition{} = definition, attrs) do
    definition
    |> changeset(attrs)
    |> Repo.update()
  end

  def delete(%CustomFieldDefinition{} = definition) do
    Repo.delete(definition)
  end

  def list_for_portfolio(portfolio_id) do
    CustomFieldDefinition
    |> where([cfd], cfd.portfolio_id == ^portfolio_id)
    |> order_by([cfd], cfd.position)
    |> Repo.all()
  end

  def get!(id) do
    Repo.get!(CustomFieldDefinition, id)
  end

  def apply_template(portfolio_id, template_name) do
    case common_templates()[template_name] do
      nil -> {:error, "Template not found"}
      template_fields ->
        results = Enum.map(template_fields, fn field_attrs ->
          attrs = Map.put(field_attrs, :portfolio_id, portfolio_id)
          create(attrs)
        end)

        {:ok, results}
    end
  end

  # Private validation functions
  defp validate_validation_rules(changeset) do
    case get_change(changeset, :validation_rules) do
      nil -> changeset
      rules when is_map(rules) ->
        field_type = get_change(changeset, :field_type) || get_field(changeset, :field_type)
        validate_rules_for_type(changeset, field_type, rules)
      _ ->
        add_error(changeset, :validation_rules, "must be a valid map")
    end
  end

  defp validate_rules_for_type(changeset, "text", rules) do
    allowed_keys = ~w(min_length max_length pattern required)
    validate_rule_keys(changeset, rules, allowed_keys)
  end

  defp validate_rules_for_type(changeset, "number", rules) do
    allowed_keys = ~w(min_value max_value integer_only required)
    validate_rule_keys(changeset, rules, allowed_keys)
  end

  defp validate_rules_for_type(changeset, "list", rules) do
    allowed_keys = ~w(min_items max_items allowed_values required)
    validate_rule_keys(changeset, rules, allowed_keys)
  end

  defp validate_rules_for_type(changeset, _type, _rules), do: changeset

  defp validate_rule_keys(changeset, rules, allowed_keys) do
    invalid_keys = Map.keys(rules) -- allowed_keys
    if Enum.empty?(invalid_keys) do
      changeset
    else
      add_error(changeset, :validation_rules, "contains invalid keys: #{Enum.join(invalid_keys, ", ")}")
    end
  end

  # Predefined field templates for common use cases
  def common_templates do
    %{
      "social_metrics" => [
        %{field_name: "followers_count", field_type: "number", field_label: "Followers", validation_rules: %{"min_value" => 0}},
        %{field_name: "engagement_rate", field_type: "number", field_label: "Engagement Rate (%)", validation_rules: %{"min_value" => 0, "max_value" => 100}},
        %{field_name: "platform", field_type: "list", field_label: "Platform", validation_rules: %{"allowed_values" => ["Instagram", "Twitter", "LinkedIn", "TikTok"]}}
      ],
      "certifications" => [
        %{field_name: "certification_name", field_type: "text", field_label: "Certification Name", is_required: true},
        %{field_name: "issuing_organization", field_type: "text", field_label: "Issuing Organization", is_required: true},
        %{field_name: "issue_date", field_type: "date", field_label: "Issue Date"},
        %{field_name: "expiry_date", field_type: "date", field_label: "Expiry Date"},
        %{field_name: "credential_url", field_type: "url", field_label: "Credential URL"}
      ],
      "languages" => [
        %{field_name: "language", field_type: "text", field_label: "Language", is_required: true},
        %{field_name: "proficiency", field_type: "list", field_label: "Proficiency Level", validation_rules: %{"allowed_values" => ["Beginner", "Intermediate", "Advanced", "Fluent", "Native"]}}
      ],
      "awards" => [
        %{field_name: "award_title", field_type: "text", field_label: "Award Title", is_required: true},
        %{field_name: "awarding_organization", field_type: "text", field_label: "Awarding Organization"},
        %{field_name: "award_date", field_type: "date", field_label: "Award Date"},
        %{field_name: "description", field_type: "rich_text", field_label: "Description"}
      ]
    }
  end
end
