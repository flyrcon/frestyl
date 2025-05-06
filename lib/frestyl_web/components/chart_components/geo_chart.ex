defmodule FrestylWeb.ChartComponents.GeoChart do
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
      <!-- This component uses a simple choropleth approach. For a more advanced geographic visualization,
           you might want to use a dedicated mapping library like Leaflet or MapBox -->
      <div id={@id} class="w-full h-full"></div>
    </div>
    <script>
      (() => {
        // Get the container element
        const container = document.getElementById('<%= @id %>');

        // Clear existing content
        container.innerHTML = '';

        // If no data, show a message
        if (!<%= raw(Jason.encode!(@chart_data[:data])) %> || <%= raw(Jason.encode!(@chart_data[:data])) %>.length === 0) {
          container.innerHTML = '<div class="flex items-center justify-center h-full text-gray-500">No geographic data available</div>';
          return;
        }

        // Create a simple bar chart for the geographic distribution
        // In a real application, you might want to use a proper choropleth map
        const data = <%= raw(Jason.encode!(@chart_data[:data])) %>;

        // Sort by count descending
        data.sort((a, b) => b.count - a.count);

        // Create a table for the geographic data
        const table = document.createElement('table');
        table.className = 'min-w-full divide-y divide-gray-200';

        // Create table header
        const thead = document.createElement('thead');
        thead.className = 'bg-gray-50';
        thead.innerHTML = `
          <tr>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Country</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Viewers</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Percentage</th>
          </tr>
        `;
        table.appendChild(thead);

        // Create table body
        const tbody = document.createElement('tbody');
        tbody.className = 'bg-white divide-y divide-gray-200';

        // Add rows for each country
        data.forEach((item, index) => {
          const row = document.createElement('tr');
          row.className = index % 2 === 0 ? 'bg-white' : 'bg-gray-50';

          // Country cell
          const countryCell = document.createElement('td');
          countryCell.className = 'px-6 py-4 whitespace-nowrap text-sm text-gray-900';
          countryCell.textContent = item.country;

          // Count cell
          const countCell = document.createElement('td');
          countCell.className = 'px-6 py-4 whitespace-nowrap text-sm text-gray-500';
          countCell.textContent = item.count.toLocaleString();

          // Percentage cell
          const percentageCell = document.createElement('td');
          percentageCell.className = 'px-6 py-4 whitespace-nowrap text-sm text-gray-500';

          // Create a progress bar for the percentage
          const percentageValue = Math.round(item.percentage * 10) / 10;
          const progressBar = document.createElement('div');
          progressBar.className = 'flex items-center';
          progressBar.innerHTML = `
            <div class="w-full bg-gray-200 rounded-full h-2.5">
              <div class="bg-blue-600 h-2.5 rounded-full" style="width: ${percentageValue}%"></div>
            </div>
            <span class="ml-2">${percentageValue}%</span>
          `;

          percentageCell.appendChild(progressBar);

          // Add cells to row
          row.appendChild(countryCell);
          row.appendChild(countCell);
          row.appendChild(percentageCell);

          // Add row to table body
          tbody.appendChild(row);
        });

        table.appendChild(tbody);
        container.appendChild(table);
      })();
    </script>
    """
  end
end
