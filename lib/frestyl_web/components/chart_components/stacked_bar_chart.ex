defmodule FrestylWeb.ChartComponents.StackedBarChart do
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
          type: 'bar',
          data: <%= raw(Jason.encode!(@chart_data)) %>,
          options: {
            responsive: true,
            maintainAspectRatio: false,
            scales: {
              x: {
                type: 'time',
                time: {
                  unit: '<%= @chart_data[:time_unit] || "day" %>'
                },
                title: {
                  display: true,
                  text: 'Date'
                },
                stacked: true
              },
              y: {
                beginAtZero: true,
                title: {
                  display: true,
                  text: 'Revenue'
                },
                stacked: true
              }
            },
            interaction: {
              mode: 'index',
              intersect: false
            },
            plugins: {
              tooltip: {
                callbacks: {
                  label: function(context) {
                    let label = context.dataset.label || '';
                    if (label) {
                      label += ': ';
                    }
                    label += new Intl.NumberFormat('en-US', {
                      style: 'currency',
                      currency: 'USD'
                    }).format(context.parsed.y);
                    return label;
                  },
                  footer: function(tooltipItems) {
                    let sum = 0;
                    tooltipItems.forEach(tooltipItem => {
                      sum += tooltipItem.parsed.y;
                    });
                    return 'Total: ' + new Intl.NumberFormat('en-US', {
                      style: 'currency',
                      currency: 'USD'
                    }).format(sum);
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
