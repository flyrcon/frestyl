# Create this file: priv/repo/seeds/subscription_plans.exs

alias Frestyl.Payments.SubscriptionPlan
alias Frestyl.Repo

# Clear existing plans in development
if Mix.env() == :dev do
  Repo.delete_all(SubscriptionPlan)
end

# Personal Plan (Free)
personal_plan = %SubscriptionPlan{
  name: "Personal",
  description: "Perfect for individuals starting their portfolio journey",
  price_monthly_cents: 0,
  price_yearly_cents: 0,
  platform_fee_percentage: Decimal.new("0.00"),
  features: [
    "3 portfolios", "1GB storage", "2 collaborators",
    "Basic templates", "Link sharing"
  ],
  max_events_per_month: 0,
  is_active: true
}

case Repo.get_by(SubscriptionPlan, name: "Personal") do
  nil -> Repo.insert!(personal_plan)
  existing -> Repo.update!(SubscriptionPlan.changeset(existing, Map.from_struct(personal_plan)))
end

# Creator Plan
creator_plan = %SubscriptionPlan{
  name: "Creator",
  description: "For creative professionals ready to monetize their skills",
  price_monthly_cents: 1900, # $19.00
  price_yearly_cents: 19000, # $190.00 (2 months free)
  platform_fee_percentage: Decimal.new("5.0"),
  features: [
    "25 portfolios", "10GB storage", "10 collaborators",
    "Real-time collaboration", "Service booking", "Calendar integration",
    "Basic analytics", "Custom domains", "Priority support"
  ],
  max_events_per_month: 10,
  is_active: true
}

case Repo.get_by(SubscriptionPlan, name: "Creator") do
  nil -> Repo.insert!(creator_plan)
  existing -> Repo.update!(SubscriptionPlan.changeset(existing, Map.from_struct(creator_plan)))
end

# Professional Plan
professional_plan = %SubscriptionPlan{
  name: "Professional",
  description: "Advanced features for growing businesses and teams",
  price_monthly_cents: 4900, # $49.00
  price_yearly_cents: 49000, # $490.00 (2 months free)
  platform_fee_percentage: Decimal.new("3.0"),
  features: [
    "Unlimited portfolios", "100GB storage", "Unlimited collaborators",
    "Advanced analytics", "White-label options", "API access",
    "Unlimited services", "Advanced booking features", "Team management"
  ],
  max_events_per_month: -1, # Unlimited
  is_active: true
}

case Repo.get_by(SubscriptionPlan, name: "Professional") do
  nil -> Repo.insert!(professional_plan)
  existing -> Repo.update!(SubscriptionPlan.changeset(existing, Map.from_struct(professional_plan)))
end

# Enterprise Plan
enterprise_plan = %SubscriptionPlan{
  name: "Enterprise",
  description: "Custom solutions for large organizations",
  price_monthly_cents: 9900, # $99.00 starting price
  price_yearly_cents: 99000, # $990.00 starting price
  platform_fee_percentage: Decimal.new("1.5"),
  features: [
    "Everything in Professional", "SSO integration", "Dedicated support",
    "Custom integrations", "Advanced security", "White-label platform",
    "Custom platform fee rates", "Dedicated account manager"
  ],
  max_events_per_month: -1, # Unlimited
  is_active: true
}

case Repo.get_by(SubscriptionPlan, name: "Enterprise") do
  nil -> Repo.insert!(enterprise_plan)
  existing -> Repo.update!(SubscriptionPlan.changeset(existing, Map.from_struct(enterprise_plan)))
end

IO.puts("✅ Subscription plans seeded successfully!")
IO.puts("📊 Created #{Repo.aggregate(SubscriptionPlan, :count, :id)} subscription plans")
