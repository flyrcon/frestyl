defmodule Frestyl.Portfolios.LayoutSystem do
  @moduledoc """
  Simplified layout system focusing on the 4 core layouts:
  - Sidebar
  - Single
  - Workspace
  - Grid
  """

  def available_layouts do
    [
      %{
        key: "single",
        name: "Single Column",
        description: "Clean single-column layout with floating navigation",
        icon: "📄",
        preview_class: "flex flex-col gap-1 h-8 bg-gray-100 rounded p-1",
        preview_content: "<div class='bg-blue-200 rounded h-2'></div><div class='bg-gray-200 rounded flex-1'></div>",
        mobile_optimized: true,
        best_for: ["Personal portfolios", "Clean presentations"]
      },
      %{
        key: "sidebar",
        name: "Sidebar",
        description: "Navigation on the left, content on the right",
        icon: "📐",
        preview_class: "grid grid-cols-4 gap-1 h-8 bg-gray-100 rounded p-1",
        preview_content: "<div class='bg-blue-200 rounded'></div><div class='bg-gray-200 rounded col-span-3'></div>",
        mobile_optimized: true,
        best_for: ["Professional portfolios", "Content-heavy sites"]
      },
      %{
        key: "workspace",
        name: "Workspace",
        description: "Dashboard-style layout with organized sections",
        icon: "🗂️",
        preview_class: "grid grid-cols-3 grid-rows-2 gap-1 h-8 bg-gray-100 rounded p-1",
        preview_content: "<div class='bg-blue-200 rounded col-span-2'></div><div class='bg-gray-200 rounded'></div><div class='bg-gray-200 rounded'></div><div class='bg-gray-200 rounded'></div>",
        mobile_optimized: true,
        best_for: ["Business portfolios", "Executive profiles"]
      },
      %{
        key: "grid",
        name: "Uniform Grid",
        description: "Uniform card grid layout for all sections",
        icon: "⊞",
        preview_class: "grid grid-cols-2 grid-rows-2 gap-1 h-8 bg-gray-100 rounded p-1",
        preview_content: "<div class='bg-blue-200 rounded'></div><div class='bg-gray-200 rounded'></div><div class='bg-gray-200 rounded'></div><div class='bg-gray-200 rounded'></div>",
        mobile_optimized: true,
        best_for: ["Creative portfolios", "Visual showcases"]
      },
      %{
        key: "time_machine",
        name: "Cards",
        description: "Immersive card-stack navigation experience",
        icon: "🎭",
        preview_class: "relative h-8 bg-gray-100 rounded p-1 overflow-hidden",
        preview_content: "<div class='absolute inset-1 bg-white rounded shadow-sm border border-gray-200 z-20'></div><div class='absolute inset-1 bg-gray-50 rounded shadow-sm border border-gray-200 transform translate-x-1 translate-y-0.5 z-10'></div><div class='absolute inset-1 bg-gray-100 rounded shadow-sm border border-gray-200 transform translate-x-2 translate-y-1'></div>",
        badge: "New",
        experimental: true,
        mobile_optimized: true,
        immersive: true,
        best_for: ["Creative portfolios", "Storytelling", "Interactive presentations"],
        requirements: ["Works best with video intro", "Minimum 3 sections recommended"]
      }
    ]
  end

  def get_layout_config(layout_key) do
    case layout_key do
      "single" -> %{
        type: "single",
        supports_navigation: true,
        mobile_optimized: true,
        best_for: ["Personal portfolios", "Clean presentations"]
      }

      "sidebar" -> %{
        type: "sidebar",
        supports_navigation: true,
        mobile_optimized: true,
        best_for: ["Professional portfolios", "Content-heavy sites"]
      }

      "workspace" -> %{
        type: "workspace",
        supports_navigation: true,
        mobile_optimized: true,
        best_for: ["Business portfolios", "Executive profiles"]
      }

      "grid" -> %{
        type: "grid",
        supports_navigation: true,
        mobile_optimized: true,
        best_for: ["Creative portfolios", "Visual showcases"]
      }

      "time_machine" -> %{
        type: "time_machine",
        supports_navigation: true,
        mobile_optimized: true,
        immersive: true,
        best_for: ["Creative portfolios", "Storytelling", "Interactive presentations"],
        requirements: ["Works best with video intro", "Minimum 3 sections recommended"]
      }

      _ -> %{
        type: "single",
        supports_navigation: true,
        mobile_optimized: true,
        best_for: ["Default portfolios"]
      }
    end
  end

  def is_layout_available?(layout_key, user_tier \\ :free) do
    case layout_key do
      "time_machine" ->
        # Time Machine available for all users, but show as "New" feature
        true
      _ ->
        true
    end
  end
end
