defmodule Frestyl.Portfolios.CustomFieldValue do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Frestyl.Repo
  alias __MODULE__

  schema "custom_field_values" do
    field :field_name, :string
    field :value, :map
    field :value_text, :string

    belongs_to :portfolio, Frestyl.Portfolios.Portfolio
    belongs_to :section, Frestyl.Portfolios.PortfolioSection
    belongs_to :field_definition, Frestyl.Portfolios.CustomFieldDefinition

    timestamps()
  end

  def changeset(value, attrs) do
    value
    |> cast(attrs, [:field_name, :value, :value_text, :portfolio_id, :section_id, :field_definition_id])
    |> validate_required([:field_name, :value, :portfolio_id, :field_definition_id])
    |> validate_value_against_definition()
    |> generate_searchable_text()
  end

  # Context functions
  def create(attrs) do
    %CustomFieldValue{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  def update(%CustomFieldValue{} = value, attrs) do
    value
    |> changeset(attrs)
    |> Repo.update()
  end

  def delete(%CustomFieldValue{} = value) do
    Repo.delete(value)
  end

  def list_for_portfolio(portfolio_id, section_id \\ nil) do
    query = CustomFieldValue
    |> where([cfv], cfv.portfolio_id == ^portfolio_id)
    |> preload(:field_definition)

    query = if section_id do
      where(query, [cfv], cfv.section_id == ^section_id)
    else
      query
    end

    Repo.all(query)
  end

  def get!(id) do
    Repo.get!(CustomFieldValue, id)
  end

  def validate_against_definition(value, %Frestyl.Portfolios.CustomFieldDefinition{} = definition) do
    # Validate value against field definition rules
    rules = definition.validation_rules || %{}

    case definition.field_type do
      "text" -> validate_text_field(value, rules)
      "number" -> validate_number_field(value, rules)
      "list" -> validate_list_field(value, rules)
      "date" -> validate_date_field(value, rules)
      "url" -> validate_url_field(value, rules)
      "email" -> validate_email_field(value, rules)
      _ -> {:ok, value}
    end
  end

  # Private validation functions
  defp validate_value_against_definition(changeset) do
    case get_change(changeset, :field_definition_id) do
      nil -> changeset
      definition_id ->
        # This would validate against the field definition's rules
        # For now, basic validation
        changeset
    end
  end

  defp generate_searchable_text(changeset) do
    case get_change(changeset, :value) do
      nil -> changeset
      value ->
        text = extract_searchable_text(value)
        put_change(changeset, :value_text, text)
    end
  end

  defp extract_searchable_text(value) when is_map(value) do
    value
    |> Map.values()
    |> Enum.filter(&is_binary/1)
    |> Enum.join(" ")
  end

  defp extract_searchable_text(value) when is_list(value) do
    value
    |> Enum.filter(&is_binary/1)
    |> Enum.join(" ")
  end

  defp extract_searchable_text(value) when is_binary(value), do: value
  defp extract_searchable_text(_), do: ""

  defp validate_text_field(value, rules) when is_binary(value) do
    cond do
      Map.get(rules, "min_length") && String.length(value) < rules["min_length"] ->
        {:error, "Text too short (minimum #{rules["min_length"]} characters)"}

      Map.get(rules, "max_length") && String.length(value) > rules["max_length"] ->
        {:error, "Text too long (maximum #{rules["max_length"]} characters)"}

      Map.get(rules, "pattern") && !Regex.match?(~r/#{rules["pattern"]}/, value) ->
        {:error, "Text does not match required pattern"}

      true -> {:ok, value}
    end
  end

  defp validate_number_field(value, rules) when is_number(value) do
    cond do
      Map.get(rules, "min_value") && value < rules["min_value"] ->
        {:error, "Value too small (minimum #{rules["min_value"]})"}

      Map.get(rules, "max_value") && value > rules["max_value"] ->
        {:error, "Value too large (maximum #{rules["max_value"]})"}

      Map.get(rules, "integer_only", false) && !is_integer(value) ->
        {:error, "Value must be an integer"}

      true -> {:ok, value}
    end
  end

  defp validate_list_field(value, rules) when is_list(value) do
    cond do
      Map.get(rules, "min_items") && length(value) < rules["min_items"] ->
        {:error, "Too few items (minimum #{rules["min_items"]})"}

      Map.get(rules, "max_items") && length(value) > rules["max_items"] ->
        {:error, "Too many items (maximum #{rules["max_items"]})"}

      Map.get(rules, "allowed_values") && !Enum.all?(value, &(&1 in rules["allowed_values"])) ->
        {:error, "Contains invalid values"}

      true -> {:ok, value}
    end
  end

  defp validate_date_field(value, _rules) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, _date} -> {:ok, value}
      {:error, _} -> {:error, "Invalid date format"}
    end
  end

  defp validate_url_field(value, _rules) when is_binary(value) do
    if String.match?(value, ~r/^https?:\/\/.+/) do
      {:ok, value}
    else
      {:error, "Invalid URL format"}
    end
  end

  defp validate_email_field(value, _rules) when is_binary(value) do
    if String.match?(value, ~r/^[^\s]+@[^\s]+\.[^\s]+$/) do
      {:ok, value}
    else
      {:error, "Invalid email format"}
    end
  end

  # Fallback for validation errors
  defp validate_text_field(_, _), do: {:error, "Invalid text value"}
  defp validate_number_field(_, _), do: {:error, "Invalid number value"}
  defp validate_list_field(_, _), do: {:error, "Invalid list value"}
end
