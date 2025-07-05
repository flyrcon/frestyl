// Add to your assets/js/app.js or create a new file: assets/js/live_preview_hooks.js

export const LivePreviewManager = {
  mounted() {
    console.log("🖥️ LivePreviewManager mounted");
    this.setupPreviewRefresh();
    this.setupPreviewCommunication();
    this.setupColorUpdates();
  },

  updated() {
    this.refreshPreviewIfNeeded();
  },

  setupPreviewRefresh() {
    // Listen for preview refresh events
    this.handleEvent("refresh_preview", () => {
      this.refreshPreview();
    });

    this.handleEvent("force_refresh_preview", (data) => {
      this.refreshPreview(true, data.timestamp);
    });

    this.handleEvent("update_preview_color", (data) => {
      this.updatePreviewColor(data.field, data.color);
    });
  },

  setupPreviewCommunication() {
    // Listen for iframe load events
    const iframe = this.el;
    iframe.addEventListener('load', () => {
      console.log("✅ Preview iframe loaded");
      this.hideLoadingOverlay();
      this.injectCustomCSS();
    });

    // Handle iframe communication
    window.addEventListener('message', (event) => {
      if (event.data.type === 'preview_ready') {
        console.log("✅ Preview ready for updates");
        this.hideLoadingOverlay();
      }
    });
  },

  setupColorUpdates() {
    // Real-time color updates without full refresh
    this.handleEvent("update_preview_color", (data) => {
      this.updatePreviewColor(data.field, data.color);
    });
  },

  refreshPreview(force = false, timestamp = null) {
    console.log("🔄 Refreshing preview...", { force, timestamp });
    
    const iframe = this.el;
    if (!iframe) return;

    this.showLoadingOverlay();
    
    // Add timestamp to force refresh
    const url = new URL(iframe.src);
    url.searchParams.set('t', timestamp || Date.now());
    
    if (force) {
      url.searchParams.set('force', '1');
    }
    
    iframe.src = url.toString();
  },

  updatePreviewColor(field, color) {
    console.log(`🎨 Updating preview color: ${field} = ${color}`);
    
    const iframe = this.el;
    if (!iframe || !iframe.contentWindow) return;

    // Try to update CSS custom properties in the iframe
    try {
      const iframeDoc = iframe.contentDocument || iframe.contentWindow.document;
      if (iframeDoc) {
        const root = iframeDoc.documentElement;
        const cssVar = this.fieldToCSSVar(field);
        root.style.setProperty(cssVar, color);
        
        // Update status
        this.updatePreviewStatus("Color updated");
      }
    } catch (error) {
      console.log("🔄 CSS injection failed, will refresh iframe:", error);
      // Fallback to full refresh
      setTimeout(() => this.refreshPreview(), 100);
    }
  },

  injectCustomCSS() {
    const iframe = this.el;
    if (!iframe || !iframe.contentWindow) return;

    try {
      const iframeDoc = iframe.contentDocument || iframe.contentWindow.document;
      if (iframeDoc) {
        // Inject CSS for better preview experience
        const style = iframeDoc.createElement('style');
        style.textContent = `
          /* Preview mode styles */
          body.preview-mode {
            transition: all 0.3s ease;
          }
          
          /* Smooth color transitions */
          .portfolio-section, .portfolio-card {
            transition: background-color 0.3s ease, color 0.3s ease, border-color 0.3s ease;
          }
          
          /* Responsive preview adjustments */
          @media (max-width: 768px) {
            .portfolio-container {
              padding: 1rem !important;
            }
          }
        `;
        
        iframeDoc.head.appendChild(style);
        iframeDoc.body.classList.add('preview-mode');
      }
    } catch (error) {
      console.log("CSS injection failed:", error);
    }
  },

  fieldToCSSVar(field) {
    // Map form fields to CSS custom properties
    const fieldMap = {
      'primary_color': '--primary-color',
      'secondary_color': '--secondary-color', 
      'accent_color': '--accent-color',
      'background_color': '--background-color',
      'text_color': '--text-color'
    };
    
    return fieldMap[field] || `--${field.replace('_', '-')}`;
  },

  showLoadingOverlay() {
    const overlay = document.getElementById('preview-loading');
    if (overlay) {
      overlay.classList.remove('hidden');
    }
    this.updatePreviewStatus("Updating...");
  },

  hideLoadingOverlay() {
    const overlay = document.getElementById('preview-loading');
    if (overlay) {
      overlay.classList.add('hidden');
    }
    this.updatePreviewStatus("Ready");
  },

  updatePreviewStatus(message) {
    const status = document.getElementById('preview-status');
    if (status) {
      status.textContent = message;
      
      // Auto-clear status after delay
      if (message !== "Ready") {
        setTimeout(() => {
          if (status.textContent === message) {
            status.textContent = "Ready";
          }
        }, 2000);
      }
    }
  },

  refreshPreviewIfNeeded() {
    // Check if we need to refresh based on changes
    const lastRefresh = this.el.dataset.lastRefresh;
    const now = Date.now();
    
    if (!lastRefresh || (now - parseInt(lastRefresh)) > 5000) {
      // Only auto-refresh if it's been more than 5 seconds
      this.el.dataset.lastRefresh = now;
    }
  }
};

// Enhanced Color Picker Hook
export const ColorPickerLive = {
  mounted() {
    console.log("🎨 ColorPickerLive mounted");
    this.setupColorPicker();
  },

  setupColorPicker() {
    const colorInput = this.el.querySelector('input[type="color"]');
    const textInput = this.el.querySelector('input[type="text"]');
    
    if (colorInput && textInput) {
      // Sync color picker with text input
      colorInput.addEventListener('input', (e) => {
        textInput.value = e.target.value;
        this.pushEvent("update_color_live", {
          field: colorInput.dataset.field || this.el.dataset.field,
          value: e.target.value
        });
      });

      // Sync text input with color picker
      textInput.addEventListener('input', (e) => {
        const color = e.target.value;
        if (this.isValidColor(color)) {
          colorInput.value = color;
          this.pushEvent("update_color_live", {
            field: textInput.dataset.field || this.el.dataset.field,
            value: color
          });
        }
      });
    }
  },

  isValidColor(color) {
    // Simple hex color validation
    return /^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$/.test(color);
  }
};

// Device Preview Switcher
export const DevicePreviewSwitcher = {
  mounted() {
    console.log("📱 DevicePreviewSwitcher mounted");
    this.updatePreviewSize();
  },

  updated() {
    this.updatePreviewSize();
  },

  updatePreviewSize() {
    const device = this.el.dataset.device || 'desktop';
    const previewContainer = document.querySelector('.preview-container');
    const iframe = document.getElementById('portfolio-preview-iframe');
    
    if (previewContainer && iframe) {
      // Remove existing device classes
      previewContainer.classList.remove('preview-mobile', 'preview-tablet', 'preview-desktop');
      
      // Add appropriate class
      previewContainer.classList.add(`preview-${device}`);
      
      // Update iframe dimensions
      switch (device) {
        case 'mobile':
          iframe.style.width = '375px';
          iframe.style.maxWidth = '100%';
          break;
        case 'tablet':
          iframe.style.width = '768px';
          iframe.style.maxWidth = '100%';
          break;
        default:
          iframe.style.width = '100%';
          iframe.style.maxWidth = 'none';
      }
      
      // Trigger refresh to ensure layout updates
      setTimeout(() => {
        if (iframe.contentWindow) {
          iframe.contentWindow.dispatchEvent(new Event('resize'));
        }
      }, 100);
    }
  }
};

// Auto-save for typography and spacing
export const AutoSaveControl = {
  mounted() {
    this.setupAutoSave();
  },

  setupAutoSave() {
    const input = this.el;
    let timeout;

    // Debounced auto-save
    input.addEventListener('input', (e) => {
      clearTimeout(timeout);
      
      timeout = setTimeout(() => {
        const field = input.dataset.field;
        const value = input.value;
        
        if (field && value) {
          this.pushEvent("auto_save_setting", {
            field: field,
            value: value
          });
          
          // Visual feedback
          input.classList.add('border-green-300');
          setTimeout(() => {
            input.classList.remove('border-green-300');
          }, 1000);
        }
      }, 500);
    });
  }
};

// Layout Preview Hook
export const LayoutPreview = {
  mounted() {
    console.log("📐 LayoutPreview mounted");
    this.animateLayoutChange();
  },

  updated() {
    this.animateLayoutChange();
  },

  animateLayoutChange() {
    // Add a subtle animation when layout changes
    this.el.style.transform = 'scale(0.95)';
    this.el.style.transition = 'transform 0.2s ease';
    
    setTimeout(() => {
      this.el.style.transform = 'scale(1)';
    }, 100);
    
    setTimeout(() => {
      this.el.style.transition = '';
    }, 300);
  }
};

