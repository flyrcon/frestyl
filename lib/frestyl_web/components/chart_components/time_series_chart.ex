defmodule FrestylWeb.ChartComponents.TimeSeriesChart do
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
          type: 'line',
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
                }
              },
              y: {
                beginAtZero: true,
                title: {
                  display: true,
                  text: 'Views'
                }
              },
              y1: {
                position: 'right',
                beginAtZero: true,
                title: {
                  display: true,
                  text: 'Engagement Rate (%)'
                },
                grid: {
                  drawOnChartArea: false
                },
                min: 0,
                max: 100
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
                    if (context.dataset.yAxisID === 'y1') {
                      label += context.parsed.y.toFixed(2) + '%';
                    } else {
                      label += context.parsed.y.toLocaleString();
                    }
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
