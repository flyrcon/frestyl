defmodule Frestyl.ServicesTest do
  use Frestyl.DataCase
  alias Frestyl.Services
  alias Frestyl.Services.{Service, ServiceBooking}

  describe "services" do
    test "create_service/2 creates service with valid attributes" do
      user = user_fixture()
      account = account_fixture(%{user_id: user.id, subscription_tier: :creator})

      attrs = %{
        title: "Strategy Consultation",
        description: "60-minute business strategy session",
        service_type: :consultation,
        duration_minutes: 60,
        price_cents: 15000
      }

      assert {:ok, %Service{} = service} = Services.create_service(user, attrs)
      assert service.title == "Strategy Consultation"
      assert service.price_cents == 15000
    end

    test "create_service/2 respects subscription limits" do
      user = user_fixture()
      account = account_fixture(%{user_id: user.id, subscription_tier: :personal})

      attrs = %{
        title: "Test Service",
        service_type: :consultation,
        duration_minutes: 30,
        price_cents: 5000
      }

      assert {:error, :limit_reached} = Services.create_service(user, attrs)
    end
  end

  describe "bookings" do
    test "create_booking/3 calculates platform fees correctly" do
      provider = user_fixture()
      account = account_fixture(%{user_id: provider.id, subscription_tier: :creator})
      service = service_fixture(%{user_id: provider.id, price_cents: 10000})

      client_attrs = %{
        client_name: "John Doe",
        client_email: "john@example.com",
        scheduled_at: DateTime.add(DateTime.utc_now(), 3600)
      }

      assert {:ok, %ServiceBooking{} = booking} =
        Services.create_booking(service, client_attrs, provider)

      # Creator tier has 5% platform fee
      assert booking.platform_fee_cents == 500  # 5% of 10000
      assert booking.provider_amount_cents == 9500  # 10000 - 500
    end
  end
end
