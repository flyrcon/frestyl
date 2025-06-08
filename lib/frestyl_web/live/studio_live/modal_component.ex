# lib/frestyl_web/live/studio_live/modal_component.ex
defmodule FrestylWeb.StudioLive.ModalComponent do
  use FrestylWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <!-- End Session Modal -->
      <%= if @show_end_session_modal do %>
        <div class="fixed z-50 inset-0 overflow-y-auto" role="dialog" aria-modal="true">
          <div class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
            <!-- Background overlay -->
            <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity" aria-hidden="true"></div>

            <span class="hidden sm:inline-block sm:align-middle sm:h-screen" aria-hidden="true">&#8203;</span>

            <!-- Modal panel -->
            <div class="inline-block align-bottom bg-white rounded-xl text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full">
              <div class="bg-gradient-to-r from-red-500 to-red-600 px-4 py-4 sm:px-6 flex items-center justify-between">
                <h3 class="text-lg leading-6 font-medium text-white">
                  End Session
                </h3>
                <button
                  type="button"
                  phx-click="cancel_end_session"
                  class="text-white hover:text-gray-200"
                >
                  <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>

              <div class="bg-white px-4 pt-5 pb-4 sm:p-6">
                <p class="text-sm text-gray-500">
                  This will end the session for all participants. Your work will be saved.
                </p>
              </div>

              <div class="bg-gray-50 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse">
                <button
                  type="button"
                  phx-click="end_session_confirmed"
                  class="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-red-600 text-base font-medium text-white hover:bg-red-700 sm:ml-3 sm:w-auto sm:text-sm"
                >
                  End Session
                </button>
                <button
                  type="button"
                  phx-click="cancel_end_session"
                  class="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 sm:mt-0 sm:ml-3 sm:w-auto sm:text-sm"
                >
                  Cancel
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
