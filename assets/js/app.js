// assets/js/app.js - COMPLETE VERSION WITH COLORPICKER
console.log("🔥 Loading app.js with ColorPicker")

import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"
import VideoCapture from "./hooks/video_capture"

console.log("🔥 Imports loaded")

// COMPLETE HOOKS DEFINITION
let Hooks = {

   VideoCapture: VideoCapture
  
};

console.log("🔥 Creating hooks object")

// PreviewFrame Hook
Hooks.PreviewFrame = {
  mounted() {
    console.log("🔥 PreviewFrame hook mounted")
    this.setupPreviewHandling()
  },

  updated() {
    console.log("🔥 PreviewFrame hook updated")
  },

  setupPreviewHandling() {
    this.handleEvent("preview_updated", (data) => {
      console.log("🔥 Preview update received:", data)
      this.refreshPreview()
    })

    this.handleEvent("design_updated", (data) => {
      console.log("🔥 Design updated, refreshing preview")
      this.refreshPreview()
    })

    this.handleEvent("setup_preview_iframe", (data) => {
      console.log("🔥 Setting up preview iframe:", data)
      if (data.preview_url && this.el.src !== data.preview_url) {
        this.el.src = data.preview_url
      }
    })
  },

  refreshPreview() {
    if (this.el && this.el.contentWindow) {
      try {
        this.el.contentWindow.location.reload()
      } catch (error) {
        console.log("🔥 Cross-origin reload")
        const currentSrc = this.el.src
        this.el.src = ''
        setTimeout(() => {
          this.el.src = currentSrc
        }, 100)
      }
    }
  }
};

// ColorPicker Hook - THIS WAS MISSING
Hooks.ColorPicker = {
  mounted() {
    console.log("🎨 ColorPicker hook mounted on element:", this.el.id)
    this.setupColorHandling()
  },

  updated() {
    console.log("🎨 ColorPicker hook updated")
  },

  setupColorHandling() {
    console.log("🎨 Setting up color handling for:", this.el.id)
    
    // Handle input events (while dragging color picker)
    this.el.addEventListener('input', (e) => {
      console.log("🎨 Color input event:", e.target.value)
      this.handleColorChange(e)
    })

    // Handle change events (when color picker is closed)
    this.el.addEventListener('change', (e) => {
      console.log("🎨 Color change event:", e.target.value)
      this.handleColorChange(e)
    })
  },

  handleColorChange(e) {
    const field = e.target.getAttribute('phx-value-field') || e.target.name
    const value = e.target.value
    
    console.log("🎨 Color changed - Field:", field, "Value:", value)
    
    if (field && value) {
      console.log("🎨 Pushing color update to LiveView")
      this.pushEvent('update_single_color', {
        field: field,
        value: value
      })
    } else {
      console.warn("🎨 Missing field or value:", {field, value})
    }
  }
};

Hooks.DesignUpdater = {
  mounted() {
    console.log('DesignUpdater hook mounted')
    
    this.handleEvent("update_portfolio_css", ({css}) => {
      console.log('Received CSS update:', css.substring(0, 100) + '...')
      
      // Update the dynamic CSS in preview
      let styleElement = document.getElementById("dynamic-portfolio-css")
      if (styleElement) {
        styleElement.innerHTML = css
        console.log('✅ CSS updated successfully')
      } else {
        console.log('❌ Could not find #dynamic-portfolio-css element')
        
        // Try to create the style element if it doesn't exist
        let newStyle = document.createElement('style')
        newStyle.id = 'dynamic-portfolio-css'
        newStyle.innerHTML = css
        document.head.appendChild(newStyle)
        console.log('✅ Created new CSS style element')
      }
    })

    this.handleEvent("refresh_preview_iframe", () => {
      let iframe = document.getElementById("portfolio-preview-iframe")
      if (iframe) {
        iframe.src = iframe.src  // Force reload
      }
    })
  }
}

// SortableSections Hook
Hooks.SortableSections = {
  mounted() {
    this.initSortable();
  },
  
  initSortable() {
    if (typeof Sortable !== 'undefined') {
      this.sortable = Sortable.create(this.el, {
        animation: 150,
        ghostClass: 'sortable-ghost',
        onEnd: (evt) => {
          const sectionIds = Array.from(this.el.children).map(item => 
            item.getAttribute('data-section-id')
          );
          
          this.pushEvent("reorder_sections", { sections: sectionIds });
        }
      });
    } else {
      console.warn('Sortable.js not loaded');
    }
  },
  
  destroyed() {
    if (this.sortable) {
      this.sortable.destroy();
    }
  }
};

// CopyToClipboard Hook
Hooks.CopyToClipboard = {
  mounted() {
    this.el.addEventListener('click', () => {
      const textToCopy = this.el.dataset.copy || this.el.previousElementSibling?.value || this.el.textContent
      
      navigator.clipboard.writeText(textToCopy).then(() => {
        this.showCopySuccess()
      }).catch(() => {
        this.fallbackCopy(textToCopy)
      })
    })
  },

  showCopySuccess() {
    const originalText = this.el.textContent
    this.el.textContent = 'Copied!'
    this.el.classList.add('bg-green-600')
    
    setTimeout(() => {
      this.el.textContent = originalText
      this.el.classList.remove('bg-green-600')
    }, 1500)
  },

  fallbackCopy(text) {
    const textArea = document.createElement('textarea')
    textArea.value = text
    document.body.appendChild(textArea)
    textArea.select()
    document.execCommand('copy')
    document.body.removeChild(textArea)
    this.showCopySuccess()
  }
};

Hooks.LayoutPicker = {
  mounted() {
    console.log('🏗️ LayoutPicker hook mounted on element:', this.el.id);
    this.setupLayoutHandling();
  },
  
  setupLayoutHandling() {
    // Handle layout button clicks
    this.el.addEventListener('click', (e) => {
      const layout = this.el.dataset.layout;
      if (layout) {
        console.log('🏗️ Layout selected:', layout);
        this.pushEvent("update_portfolio_layout", { layout: layout });
      }
    });
  },
  
  updated() {
    console.log('🏗️ LayoutPicker hook updated');
  }
};

Hooks.FontPicker = {
  mounted() {
    console.log('🔤 FontPicker hook mounted');
    this.el.addEventListener('click', (e) => {
      const font = this.el.dataset.font;
      console.log('🔤 Font selected:', font);
      this.pushEvent("update_font_family", { font: font });
    });
  }
};

Hooks.ThemePicker = {
  mounted() {
    console.log('🎨 ThemePicker hook mounted');
    this.el.addEventListener('click', (e) => {
      const theme = this.el.dataset.theme;
      console.log('🎨 Theme selected:', theme);
      this.pushEvent("update_theme", { theme: theme });
    });
  }
};
/*
Hooks.VideoCapture = {
  mounted() {
    // Get the actual component ID from the data attribute
    this.componentId = this.el.dataset.componentId;
    console.log('VideoCapture hook mounted with component ID:', this.componentId);
    
    // Wait for LiveView to be fully connected
    setTimeout(() => {
      this.initializeCamera();
    }, 200);
  },
  
  async initializeCamera() {
    try {
      console.log('Initializing camera for component:', this.componentId);
      
      const video = this.el;
      const stream = await navigator.mediaDevices.getUserMedia({ 
        video: { 
          width: { ideal: 1280 }, 
          height: { ideal: 720 },
          facingMode: 'user'
        }, 
        audio: true 
      });
      
      video.srcObject = stream;
      this.stream = stream;
      
      console.log('Camera stream attached, pushing camera_ready event');
      
      // Send the actual component ID with the event
      this.pushEvent("camera_ready", {
        componentId: this.componentId,
        portfolioId: this.el.dataset.portfolioId
      });
      
    } catch (error) {
      console.error("Camera initialization failed:", error);
      
      this.pushEvent("camera_error", { 
        error: error.message,
        componentId: this.componentId,
        portfolioId: this.el.dataset.portfolioId
      });
    }
  },
  
  destroyed() {
    console.log('VideoCapture hook destroyed for component:', this.componentId);
    if (this.stream) {
      this.stream.getTracks().forEach(track => track.stop());
    }
  }
};*/

console.log("🔥 All hooks defined:", Object.keys(Hooks))

export default Hooks

// Make sure Hooks object exists
window.Hooks = window.Hooks || {};

// Fix the DesignUpdater hook
window.Hooks.DesignUpdater = {
  mounted() {
    console.log("DesignUpdater hook mounted successfully");
    
    this.handleEvent("design_updated", (data) => {
      console.log("🎨 Design updated:", data);
      this.updatePortfolioStyles(data.customization);
    });
    
    // Listen for direct CSS injection
    this.handleEvent("inject_design_css", (data) => {
      console.log("🎨 CSS injection received:", data.css.substring(0, 100) + "...");
      this.injectCSS(data.css);
    });
  },
  
  injectCSS(css) {
    // Remove old portfolio CSS
    const oldCSS = document.getElementById('dynamic-portfolio-css');
    if (oldCSS) {
      oldCSS.remove();
    }
    
    // Inject new CSS
    const style = document.createElement('style');
    style.id = 'dynamic-portfolio-css';
    style.innerHTML = css;
    document.head.appendChild(style);
    
    console.log("✅ CSS injected successfully");
    
    // Force layout recalculation
    const containers = document.querySelectorAll('.portfolio-display, .portfolio-preview-container');
    containers.forEach(container => {
      container.style.display = 'none';
      container.offsetHeight; // Trigger reflow
      container.style.display = '';
      console.log("🔄 Container attributes:", {
        'data-portfolio-layout': container.getAttribute('data-portfolio-layout'),
        'data-professional-type': container.getAttribute('data-professional-type'),
        classes: container.className
      });
    });
  },
  
  updatePortfolioStyles(customization) {
    console.log("🔄 Updating portfolio styles:", customization);
    
    // Update data attributes
    const containers = document.querySelectorAll('.portfolio-display, .portfolio-preview-container');
    containers.forEach(container => {
      if (customization.portfolio_layout) {
        container.setAttribute('data-portfolio-layout', customization.portfolio_layout);
        console.log("📝 Set data-portfolio-layout to:", customization.portfolio_layout);
      }
      if (customization.professional_type) {
        container.setAttribute('data-professional-type', customization.professional_type);
        console.log("📝 Set data-professional-type to:", customization.professional_type);
      }
    });
    
    // Update CSS custom properties
    const root = document.documentElement;
    if (customization.primary_color) {
      root.style.setProperty('--primary-color', customization.primary_color);
    }
    if (customization.portfolio_layout) {
      root.style.setProperty('--portfolio-layout', customization.portfolio_layout);
    }
  }
};

// Get CSRF token
let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
console.log("🔥 CSRF token found:", !!csrfToken)

// Create LiveSocket
let liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

console.log("🔥 LiveSocket created with hooks:", Object.keys(Hooks))

window.addEventListener("phx:apply_portfolio_design", (e) => {
  console.log("🎨 JS: Applying portfolio design:", e.detail);
  
  const { layout, color_scheme, customization } = e.detail;
  
  // Update CSS variables
  const root = document.documentElement;
  if (customization) {
    if (customization.primary_color) {
      root.style.setProperty('--primary-color', customization.primary_color);
    }
    if (customization.secondary_color) {
      root.style.setProperty('--secondary-color', customization.secondary_color);
    }
    if (customization.accent_color) {
      root.style.setProperty('--accent-color', customization.accent_color);
    }
    if (customization.typography) {
      const fontFamily = getTypographyCSS(customization.typography);
      root.style.setProperty('--font-family', fontFamily);
    }
  }
  
  // Update layout attributes
  const portfolioView = document.querySelector('.portfolio-enhanced-view, .portfolio-show');
  if (portfolioView) {
    if (layout) {
      portfolioView.setAttribute('data-portfolio-layout', layout);
    }
    if (color_scheme) {
      portfolioView.setAttribute('data-color-scheme', color_scheme);
    }
  }
  
  console.log("✅ Portfolio design applied successfully");
});

function getTypographyCSS(typography) {
  switch(typography) {
    case 'sans': return '-apple-system, BlinkMacSystemFont, "Inter", sans-serif';
    case 'serif': return '"Crimson Text", "Times New Roman", serif';
    case 'mono': return '"JetBrains Mono", "Fira Code", monospace';
    default: return '-apple-system, BlinkMacSystemFont, "Inter", sans-serif';
  }
}

// Progress bar
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", info => topbar.show())
window.addEventListener("phx:page-loading-stop", info => topbar.hide())

// Connect
liveSocket.connect()
console.log("🔥 LiveSocket connected")

// Expose for debugging
window.liveSocket = liveSocket
window.Hooks = Hooks

console.log("🔥 App.js fully loaded with ColorPicker hook")
console.log("🔥 Available hooks:", Object.keys(window.Hooks))

// Verify hooks are properly registered
setTimeout(() => {
  console.log("🔥 Final verification - LiveSocket hooks:", window.liveSocket.getHooks ? Object.keys(window.liveSocket.getHooks()) : 'getHooks not available')
}, 1000)