// Include phoenix_html to handle method=PUT/DELETE in forms and buttons
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

// Import our analytics module
import "./analytics"
require("phoenix_html")

// Import Chart.js for visualization components
import Chart from 'chart.js/auto'
import 'chartjs-adapter-date-fns' // For time-series charts

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

let Hooks = {
  MessagesContainer: {
    mounted() {
      this.scrollToBottom();
      this.handleEvent("chat-message-sent", () => {
        this.scrollToBottom();
      });
    },
    updated() {
      this.scrollToBottom();
    },
    scrollToBottom() {
      this.el.scrollTop = this.el.scrollHeight;
    }
  },
  
  TypingIndicator: {
    mounted() {
      let timeout;
      const pushTyping = (isTyping) => {
        this.pushEvent("typing", { typing: isTyping.toString() });
      };

      this.el.addEventListener("input", (e) => {
        clearTimeout(timeout);
        
        if (this.el.value.trim().length > 0) {
          pushTyping(true);
          
          // Set timeout to stop typing indicator after 3 seconds of inactivity
          timeout = setTimeout(() => {
            pushTyping(false);
          }, 3000);
        } else {
          pushTyping(false);
        }
      });

      // Clear typing indicator when user leaves the page
      window.addEventListener("beforeunload", () => {
        pushTyping(false);
      });
    }
  },
  
  AutoResizeTextarea: {
    mounted() {
      this.resize();
      this.el.addEventListener("input", () => {
        this.resize();
      });
    },
    resize() {
      this.el.style.height = "auto";
      this.el.style.height = (this.el.scrollHeight) + "px";
    }
  },
  
  // Keep your existing chart hooks
  TimeSeriesChart: {
    mounted() {
      const chartData = JSON.parse(this.el.dataset.chartData);
      this.chart = new Chart(this.el.getContext('2d'), {
        type: 'line',
        data: chartData,
        options: {
          responsive: true,
          maintainAspectRatio: false,
          scales: {
            x: {
              type: 'time',
              time: {
                unit: chartData.time_unit || 'day'
              }
            }
          }
        }
      });
    },
    updated() {
      const chartData = JSON.parse(this.el.dataset.chartData);
      this.chart.data = chartData;
      this.chart.options.scales.x.time.unit = chartData.time_unit || 'day';
      this.chart.update();
    },
    destroyed() {
      this.chart.destroy();
    }
  },
  
  StackedBarChart: {
    mounted() {
      const chartData = JSON.parse(this.el.dataset.chartData);
      this.chart = new Chart(this.el.getContext('2d'), {
        type: 'bar',
        data: chartData,
        options: {
          responsive: true,
          maintainAspectRatio: false,
          scales: {
            x: {
              stacked: true,
              type: 'time',
              time: {
                unit: chartData.time_unit || 'day'
              }
            },
            y: {
              stacked: true
            }
          }
        }
      });
    },
    updated() {
      const chartData = JSON.parse(this.el.dataset.chartData);
      this.chart.data = chartData;
      this.chart.options.scales.x.time.unit = chartData.time_unit || 'day';
      this.chart.update();
    },
    destroyed() {
      this.chart.destroy();
    }
  },
  
  PieChart: {
    mounted() {
      const chartData = JSON.parse(this.el.dataset.chartData);
      this.chart = new Chart(this.el.getContext('2d'), {
        type: 'pie',
        data: chartData,
        options: {
          responsive: true,
          maintainAspectRatio: false
        }
      });
    },
    updated() {
      const chartData = JSON.parse(this.el.dataset.chartData);
      this.chart.data = chartData;
      this.chart.update();
    },
    destroyed() {
      this.chart.destroy();
    }
  }
}

let liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", info => topbar.show())
window.addEventListener("phx:page-loading-stop", info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket