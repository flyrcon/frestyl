# File: lib/frestyl_web/live/portfolio_hub_live/contract_signing_modal.ex

defmodule FrestylWeb.PortfolioHubLive.ContractSigningModal do
  use Phoenix.Component
  import FrestylWeb.CoreComponents

  @doc """
  Contract signing modal with terms display and digital signature.
  """
  def contract_signing_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
      <div class="relative top-10 mx-auto p-6 border w-11/12 md:w-4/5 lg:w-3/4 xl:w-2/3 shadow-lg rounded-md bg-white max-h-screen overflow-y-auto">
        <!-- Modal Header -->
        <div class="flex items-center justify-between mb-6 pb-4 border-b">
          <div>
            <h3 class="text-xl font-bold text-gray-900">Campaign Contract</h3>
            <p class="text-gray-600"><%= @contract.campaign_title %></p>
          </div>
          <button phx-click="close_contract_modal" class="text-gray-400 hover:text-gray-600">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>

        <!-- Contract Summary -->
        <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
          <h4 class="font-semibold text-blue-900 mb-2">Contract Summary</h4>
          <div class="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
            <div>
              <span class="text-blue-700 font-medium">Revenue Share:</span>
              <div class="font-bold text-blue-900"><%= Float.round(@contract.revenue_percentage, 1) %>%</div>
            </div>
            <div>
              <span class="text-blue-700 font-medium">Content Type:</span>
              <div class="font-bold text-blue-900"><%= format_content_type(@contract.content_type) %></div>
            </div>
            <div>
              <span class="text-blue-700 font-medium">Deadline:</span>
              <div class="font-bold text-blue-900"><%= format_date(@contract.deadline) %></div>
            </div>
            <div>
              <span class="text-blue-700 font-medium">Projected Earnings:</span>
              <div class="font-bold text-blue-900">$<%= format_currency(@contract.projected_earnings) %></div>
            </div>
          </div>
        </div>

        <!-- Contract Terms -->
        <div class="space-y-6 mb-8">
          <!-- Contribution Requirements -->
          <div>
            <h4 class="font-semibold text-gray-900 mb-3">Contribution Requirements</h4>
            <div class="bg-gray-50 rounded-lg p-4">
              <ul class="space-y-2 text-sm text-gray-700">
                <%= for requirement <- @contract.contribution_requirements do %>
                  <li class="flex items-start space-x-2">
                    <svg class="w-4 h-4 text-green-500 mt-0.5 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
                    </svg>
                    <span><%= requirement %></span>
                  </li>
                <% end %>
              </ul>
            </div>
          </div>

          <!-- Quality Standards -->
          <div>
            <h4 class="font-semibold text-gray-900 mb-3">Quality Standards</h4>
            <div class="bg-gray-50 rounded-lg p-4">
              <div class="space-y-3 text-sm text-gray-700">
                <%= for {standard, threshold} <- @contract.quality_standards do %>
                  <div class="flex justify-between items-center">
                    <span><%= humanize_standard(standard) %></span>
                    <span class="font-medium text-purple-600"><%= format_threshold(threshold) %></span>
                  </div>
                <% end %>
              </div>
            </div>
          </div>

          <!-- Revenue Distribution -->
          <div>
            <h4 class="font-semibold text-gray-900 mb-3">Revenue Distribution</h4>
            <div class="bg-gray-50 rounded-lg p-4">
              <div class="space-y-2 text-sm">
                <div class="flex justify-between">
                  <span class="text-gray-700">Your Share:</span>
                  <span class="font-bold text-green-600"><%= Float.round(@contract.revenue_percentage, 1) %>%</span>
                </div>
                <div class="flex justify-between">
                  <span class="text-gray-700">Platform Fee:</span>
                  <span class="font-medium text-gray-600">30%</span>
                </div>
                <div class="flex justify-between">
                  <span class="text-gray-700">Payment Processing:</span>
                  <span class="font-medium text-gray-600">2.9% + $0.30</span>
                </div>
                <div class="pt-2 border-t border-gray-300 flex justify-between">
                  <span class="font-semibold text-gray-900">Estimated Net Earnings:</span>
                  <span class="font-bold text-green-600">$<%= format_currency(@contract.estimated_net_earnings) %></span>
                </div>
              </div>
            </div>
          </div>

          <!-- Legal Terms -->
          <div>
            <h4 class="font-semibold text-gray-900 mb-3">Legal Terms</h4>
            <div class="bg-gray-50 rounded-lg p-4 max-h-40 overflow-y-auto">
              <div class="text-sm text-gray-700 whitespace-pre-line">
                <%= @contract.legal_terms %>
              </div>
            </div>
          </div>
        </div>

        <!-- Agreement Checkboxes -->
        <div class="space-y-3 mb-6">
          <label class="flex items-start space-x-3">
            <input
              type="checkbox"
              name="agree_terms"
              required
              class="mt-1 rounded text-purple-600 focus:ring-purple-500" />
            <span class="text-sm text-gray-700">
              I have read and agree to the contract terms and conditions outlined above.
            </span>
          </label>

          <label class="flex items-start space-x-3">
            <input
              type="checkbox"
              name="agree_quality"
              required
              class="mt-1 rounded text-purple-600 focus:ring-purple-500" />
            <span class="text-sm text-gray-700">
              I understand the quality requirements and commit to meeting them within the specified timeline.
            </span>
          </label>

          <label class="flex items-start space-x-3">
            <input
              type="checkbox"
              name="agree_revenue"
              required
              class="mt-1 rounded text-purple-600 focus:ring-purple-500" />
            <span class="text-sm text-gray-700">
              I understand that revenue distribution is based on dynamic contribution tracking and may change based on my actual contributions.
            </span>
          </label>
        </div>

        <!-- Digital Signature -->
        <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mb-6">
          <h4 class="font-semibold text-yellow-800 mb-3">Digital Signature</h4>
          <div class="space-y-3">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Full Legal Name</label>
              <input
                type="text"
                name="legal_name"
                required
                placeholder="Enter your full legal name"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-purple-500 focus:border-purple-500" />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Digital Signature</label>
              <input
                type="text"
                name="digital_signature"
                required
                placeholder="Type your name as digital signature"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-purple-500 focus:border-purple-500" />
            </div>
            <p class="text-xs text-gray-600">
              By typing your name above, you are creating a legally binding digital signature equivalent to a handwritten signature.
            </p>
          </div>
        </div>

        <!-- Form Actions -->
        <div class="flex justify-end space-x-3 pt-4 border-t">
          <button
            type="button"
            phx-click="close_contract_modal"
            class="px-6 py-2 border border-gray-300 text-gray-700 rounded-md hover:bg-gray-50">
            Cancel
          </button>
          <button
            type="submit"
            phx-click="sign_contract_submit"
            phx-value-contract_id={@contract.id}
            class="px-6 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 font-medium">
            Sign Contract
          </button>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions
  defp format_content_type(:data_story), do: "Data Story"
  defp format_content_type(:book), do: "Book"
  defp format_content_type(:podcast), do: "Podcast"
  defp format_content_type(:music_track), do: "Music Track"
  defp format_content_type(:blog_post), do: "Blog Post"
  defp format_content_type(_), do: "Content"

  defp format_date(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%B %d, %Y")
  end
  defp format_date(_), do: "TBD"

  defp format_currency(amount) when is_number(amount) do
    :erlang.float_to_binary(amount, [{:decimals, 2}])
  end
  defp format_currency(%Decimal{} = amount) do
    Decimal.to_string(amount, :normal)
  end
  defp format_currency(_), do: "0.00"

  defp humanize_standard("minimum_word_count"), do: "Minimum Word Count"
  defp humanize_standard("peer_review_score"), do: "Peer Review Score"
  defp humanize_standard("audio_quality_threshold"), do: "Audio Quality"
  defp humanize_standard("minimum_audio_minutes"), do: "Minimum Audio Duration"
  defp humanize_standard(standard), do: String.replace(standard, "_", " ") |> String.capitalize()

  defp format_threshold(threshold) when is_number(threshold) do
    if threshold > 1, do: "#{threshold}", else: "#{Float.round(threshold * 100)}%"
  end
  defp format_threshold(threshold), do: "#{threshold}"
end
