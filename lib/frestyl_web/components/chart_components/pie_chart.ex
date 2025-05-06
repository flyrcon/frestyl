defmodule FrestylWeb.ChartComponents.PieChart do
  use FrestylWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-container"} phx-update="ignore" class="w-full h-full">
      <canvas id={@id}></canvas>
    </div>
    <script>
      (() => {
        const ctx = document.getElementById('<%= @id %>').getContext('2d');

        // Destroy existing chart if it exists
        if (window.charts && window.charts['<%= @id %>']) {
          window.charts['<%= @id %>'].destroy();
        }

        // Create or ensure the charts object exists
        window.charts = window.charts || {};

        // Create the new chart
        window.charts['<%= @id %>'] = new Chart(ctx, {
          type: 'pie',
          data: <%= raw(Jason.encode!(@chart_data)) %>,
          options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
              legend: {
                position: 'right',
                labels: {
                  boxWidth: 15
                }
              },
              tooltip: {
                callbacks: {
                  label: function(context) {
                    let label = context.label || '';
                    if (label) {
                      label += ': ';
                    }
                    let value = context.parsed;
                    let sum = context.dataset.data.reduce((a, b) => a + b, 0);
                    let percentage = Math.round((value * 100) / sum);
                    label += `${value} (${percentage}%)`;
                    return label;
                  }
                }
              }
            }
          }
        });
      })();
    </script>
    """
  end
end
