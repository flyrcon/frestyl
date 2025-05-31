// assets/js/app.js
import "phoenix_html"
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import topbar from "../vendor/topbar"

// Import hooks
import { CipherCanvas } from "./cipher_canvas_hook"

import { AutoScrollComments } from "./hooks/comments_hooks"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

import { SupremeDiscoveryInterface } from "./supreme_discovery_hook"
import RevolutionaryDiscoveryInterface from "./components/revolutionary_discovery_interface.jsx"
window.RevolutionaryDiscoveryInterface = RevolutionaryDiscoveryInterface;


// Also ensure React is available
if (typeof window.React === 'undefined') {
  import('react').then(React => {
    window.React = React;
  });
}

if (typeof window.ReactDOM === 'undefined') {
  import('react-dom').then(ReactDOM => {
    window.ReactDOM = ReactDOM;
  });
}


// Define all hooks
let Hooks = {
    AutoScrollComments,
    SupremeDiscoveryInterface: SupremeDiscoveryInterface,
    CipherCanvas: CipherCanvas,
  
  // Analytics Dashboard Hook for smooth animations
  AnalyticsDashboard: {
    mounted() {
      this.initializeAnimations();
      this.bindEvents();
    },

    updated() {
      this.initializeAnimations();
    },

    initializeAnimations() {
      // Animate counters
      this.animateCounters();
      
      // Animate progress bars
      this.animateProgressBars();
      
      // Animate charts
      this.animateCharts();
    },

    animateCounters() {
      this.el.querySelectorAll('[data-counter]').forEach(counter => {
        const target = parseInt(counter.dataset.counter);
        const duration = 2000;
        const increment = target / (duration / 16);
        let current = 0;

        const updateCounter = () => {
          current += increment;
          if (current < target) {
            counter.textContent = Math.floor(current);
            requestAnimationFrame(updateCounter);
          } else {
            counter.textContent = target;
          }
        };

        updateCounter();
      });
    },

    animateProgressBars() {
      this.el.querySelectorAll('.progress-bar').forEach(bar => {
        const fill = bar.querySelector('.progress-fill');
        if (fill) {
          const percentage = fill.dataset.percentage || 0;
          setTimeout(() => {
            fill.style.width = percentage + '%';
          }, 100);
        }
      });
    },

    animateCharts() {
      // Animate mini charts with CSS animations
      this.el.querySelectorAll('.mini-chart').forEach(chart => {
        chart.style.opacity = '0';
        chart.style.transform = 'translateY(20px)';
        
        setTimeout(() => {
          chart.style.transition = 'all 0.6s ease';
          chart.style.opacity = '1';
          chart.style.transform = 'translateY(0)';
        }, 200);
      });
    },

    bindEvents() {
      // Toggle detailed analytics
      const toggleBtn = this.el.querySelector('#toggleAnalytics');
      const detailsPanel = this.el.querySelector('#analyticsDetails');
      
      if (toggleBtn && detailsPanel) {
        toggleBtn.addEventListener('click', () => {
          const isExpanded = detailsPanel.style.maxHeight !== '0px';
          
          if (isExpanded) {
            detailsPanel.style.maxHeight = '0px';
            detailsPanel.style.opacity = '0';
            toggleBtn.textContent = 'Show Details ▼';
          } else {
            detailsPanel.style.maxHeight = detailsPanel.scrollHeight + 'px';
            detailsPanel.style.opacity = '1';
            toggleBtn.textContent = 'Hide Details ▲';
          }
        });
      }
    }
  },

  // File Upload Hook for enhanced drag and drop
  FileUpload: {
    mounted() {
      this.uploadArea = this.el.querySelector('.upload-area');
      this.fileInput = this.el.querySelector('input[type="file"]');
      
      if (this.uploadArea && this.fileInput) {
        this.bindDragEvents();
        this.bindClickEvents();
      }
    },

    bindDragEvents() {
      ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
        this.uploadArea.addEventListener(eventName, this.preventDefaults, false);
      });

      ['dragenter', 'dragover'].forEach(eventName => {
        this.uploadArea.addEventListener(eventName, () => {
          this.uploadArea.classList.add('drag-over');
        }, false);
      });

      ['dragleave', 'drop'].forEach(eventName => {
        this.uploadArea.addEventListener(eventName, () => {
          this.uploadArea.classList.remove('drag-over');
        }, false);
      });

      this.uploadArea.addEventListener('drop', (e) => {
        const files = e.dataTransfer.files;
        this.handleFiles(files);
      }, false);
    },

    bindClickEvents() {
      this.uploadArea.addEventListener('click', () => {
        this.fileInput.click();
      });

      this.fileInput.addEventListener('change', (e) => {
        this.handleFiles(e.target.files);
      });
    },

    preventDefaults(e) {
      e.preventDefault();
      e.stopPropagation();
    },

    handleFiles(files) {
      // Add visual feedback for file selection
      const fileList = Array.from(files);
      const preview = this.el.querySelector('.file-preview');
      
      if (preview) {
        preview.innerHTML = '';
        fileList.forEach(file => {
          const fileItem = document.createElement('div');
          fileItem.className = 'file-item';
          fileItem.innerHTML = `
            <span class="file-name">${file.name}</span>
            <span class="file-size">${this.formatFileSize(file.size)}</span>
          `;
          preview.appendChild(fileItem);
        });
      }
    },

    formatFileSize(bytes) {
      if (bytes === 0) return '0 Bytes';
      const k = 1024;
      const sizes = ['Bytes', 'KB', 'MB', 'GB'];
      const i = Math.floor(Math.log(bytes) / Math.log(k));
      return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
    }
  },

  // View Mode Switcher Hook
  ViewModeSwitcher: {
    mounted() {
      this.updateToggleIndicator();
      this.addKeyboardShortcuts();
    },

    updated() {
      this.updateToggleIndicator();
    },

    updateToggleIndicator() {
      const toggle = document.querySelector('.view-toggle');
      const activeBtn = document.querySelector('.view-btn.active');
      
      if (toggle && activeBtn) {
        const mode = activeBtn.getAttribute('phx-value-mode');
        toggle.setAttribute('data-active', mode);
      }
    },

    addKeyboardShortcuts() {
      document.addEventListener('keydown', (e) => {
        // Only trigger if not in an input field
        if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') return;
        
        switch(e.key) {
          case '1':
            e.preventDefault();
            this.switchView('cipher_canvas');
            break;
          case '2':
            e.preventDefault();
            this.switchView('grid');
            break;
          case '3':
            e.preventDefault();
            this.switchView('list');
            break;
          case '4':
            e.preventDefault();
            this.switchView('analytics');
            break;
        }
      });
    },

    switchView(mode) {
      const btn = document.querySelector(`[phx-value-mode="${mode}"]`);
      if (btn) {
        btn.click();
      }
    }
  },
    mounted() {
      this.card = this.el;
      this.bindHoverEffects();
    },

    bindHoverEffects() {
      this.card.addEventListener('mouseenter', () => {
        this.card.style.transform = 'translateY(-10px) scale(1.02)';
        this.card.style.boxShadow = '0 20px 40px rgba(0,0,0,0.2)';
      });

      this.card.addEventListener('mouseleave', () => {
        this.card.style.transform = 'translateY(0) scale(1)';
        this.card.style.boxShadow = '0 4px 6px rgba(0,0,0,0.1)';
      });

      // Add ripple effect on click
      this.card.addEventListener('click', (e) => {
        const ripple = document.createElement('div');
        const rect = this.card.getBoundingClientRect();
        const size = Math.max(rect.width, rect.height);
        const x = e.clientX - rect.left - size / 2;
        const y = e.clientY - rect.top - size / 2;

        ripple.style.cssText = `
          position: absolute;
          width: ${size}px;
          height: ${size}px;
          left: ${x}px;
          top: ${y}px;
          background: rgba(255,255,255,0.3);
          border-radius: 50%;
          transform: scale(0);
          animation: ripple 0.6s ease-out;
          pointer-events: none;
        `;

        this.card.style.position = 'relative';
        this.card.style.overflow = 'hidden';
        this.card.appendChild(ripple);

        setTimeout(() => ripple.remove(), 600);
      });
    }
  },

  // Search Enhancement Hook
  SearchEnhancement: {
    mounted() {
      this.searchInput = this.el.querySelector('input[type="text"]');
      this.searchResults = this.el.querySelector('.search-results');
      
      if (this.searchInput) {
        this.bindSearchEvents();
      }
    },

    bindSearchEvents() {
      let searchTimeout;
      
      this.searchInput.addEventListener('input', (e) => {
        clearTimeout(searchTimeout);
        
        // Add loading state
        this.searchInput.classList.add('searching');
        
        searchTimeout = setTimeout(() => {
          this.searchInput.classList.remove('searching');
          // Trigger search after 300ms delay
          this.pushEvent('search', { query: e.target.value });
        }, 300);
      });

      // Enhanced focus states
      this.searchInput.addEventListener('focus', () => {
        this.searchInput.parentElement.classList.add('focused');
      });

      this.searchInput.addEventListener('blur', () => {
        this.searchInput.parentElement.classList.remove('focused');
      });
    }
  },

  // Notification System
  NotificationSystem: {
    mounted() {
      this.showNotification();
    },

    updated() {
      this.showNotification();
    },

    showNotification() {
      const notification = this.el;
      
      // Slide in animation
      setTimeout(() => {
        notification.classList.add('show');
      }, 100);

      // Auto-hide after 5 seconds
      setTimeout(() => {
        notification.classList.add('hide');
        setTimeout(() => {
          notification.remove();
        }, 300);
      }, 5000);
    }
  }
}

// Initialize LiveSocket
let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: Hooks,
  dom: {
    onBeforeElUpdated(from, to) {
      if (from._x_dataStack) {
        window.Alpine.clone(from, to)
      }
    }
  }
})

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// Connect if there are any LiveViews on the page
liveSocket.connect()

// Expose liveSocket on window for web console debug logs and latency simulation
window.liveSocket = liveSocket

// Add global styles for enhanced UI effects
const globalStyles = `
  @keyframes ripple {
    to {
      transform: scale(4);
      opacity: 0;
    }
  }

  @keyframes fadeInUp {
    from {
      opacity: 0;
      transform: translateY(30px);
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  @keyframes slideInRight {
    from {
      opacity: 0;
      transform: translateX(30px);
    }
    to {
      opacity: 1;
      transform: translateX(0);
    }
  }

  @keyframes pulse {
    0%, 100% {
      opacity: 1;
    }
    50% {
      opacity: 0.5;
    }
  }

  .searching {
    animation: pulse 1.5s ease-in-out infinite;
  }

  .drag-over {
    transform: scale(1.02);
    border-color: #3b82f6 !important;
    background-color: rgba(59, 130, 246, 0.1) !important;
  }

  .notification.show {
    animation: slideInRight 0.3s ease-out;
  }

  .notification.hide {
    animation: slideInRight 0.3s ease-out reverse;
  }

  .fade-in {
    animation: fadeInUp 0.6s ease-out;
  }

  .search-results {
    max-height: 0;
    overflow: hidden;
    transition: max-height 0.3s ease-out;
  }

  .search-results.show {
    max-height: 400px;
  }

  .focused {
    box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
  }

  /* Custom scrollbar */
  ::-webkit-scrollbar {
    width: 8px;
  }

  ::-webkit-scrollbar-track {
    background: rgba(255, 255, 255, 0.1);
    border-radius: 4px;
  }

  ::-webkit-scrollbar-thumb {
    background: rgba(255, 255, 255, 0.3);
    border-radius: 4px;
  }

  ::-webkit-scrollbar-thumb:hover {
    background: rgba(255, 255, 255, 0.5);
  }

  /* Smooth transitions for all interactive elements */
  button, .btn, .card, .media-node {
    transition: all 0.3s cubic-bezier(0.4, 0.0, 0.2, 1);
  }

  /* Enhanced focus states for accessibility */
  button:focus-visible,
  input:focus-visible,
  select:focus-visible {
    outline: 2px solid #3b82f6;
    outline-offset: 2px;
  }
`;

// Inject global styles
const styleSheet = document.createElement('style');
styleSheet.textContent = globalStyles;
document.head.appendChild(styleSheet);