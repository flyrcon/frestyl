// assets/js/app.js - Updated to use new VideoCapture hook
console.log("🔥 Loading app.js with new VideoCapture")

import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"
import VideoCapture from "./hooks/video_capture_v2"  // Import new hook
import { RichTextEditor } from "./hooks/rich_text_editor"
import CollaborativeTextEditor from "./hooks/collaborative_text_editor"
import VoiceRecorder from "./hooks/voice_recorder"
import StoryboardManager from "./hooks/storyboard_manager"
import FabricCanvas from "./hooks/fabric_canvas"


console.log("🔥 Imports loaded")

// COMPLETE HOOKS DEFINITION
let Hooks = {
  VideoCapture: VideoCapture,  // Use new clean hook
  RichTextEditor: RichTextEditor,
  CollaborativeTextEditor,
  VoiceRecorder,
  
  // New storyboard hooks
  StoryboardManager,
  FabricCanvas

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

// ColorPicker Hook
Hooks.ColorPicker = {
  mounted() {
    console.log("🎨 ColorPicker hook mounted")
    this.initColorPicker()
  },

  updated() {
    console.log("🎨 ColorPicker hook updated")
    this.initColorPicker()
  },

  initColorPicker() {
    const input = this.el.querySelector('input[type="color"]')
    if (input && !input.dataset.initialized) {
      input.dataset.initialized = 'true'
      
      input.addEventListener('input', (e) => {
        console.log("🎨 Color changed:", e.target.value)
        this.pushEvent("color_changed", { value: e.target.value })
      })
      
      console.log("🎨 ColorPicker initialized")
    }
  }
};

// FileUploader Hook for drag and drop functionality
Hooks.FileUploader = {
  mounted() {
    console.log("📁 FileUploader hook mounted")
    this.setupDragAndDrop()
  },

  setupDragAndDrop() {
    const dropZone = this.el
    
    dropZone.addEventListener('dragover', (e) => {
      e.preventDefault()
      e.stopPropagation()
      this.highlight(dropZone)
    })
    
    dropZone.addEventListener('dragleave', (e) => {
      e.preventDefault()
      e.stopPropagation()
      if (!dropZone.contains(e.relatedTarget)) {
        this.unhighlight(dropZone)
      }
    })
    
    dropZone.addEventListener('drop', (e) => {
      e.preventDefault()
      e.stopPropagation()
      this.unhighlight(dropZone)
      
      const files = Array.from(e.dataTransfer.files)
      if (files.length > 0) {
        this.handleFiles(files, dropZone)
      }
    })
  },

  highlight(element) {
    element.classList.add('drag-over')
    element.style.backgroundColor = '#f0f9ff'
    element.style.borderColor = '#3b82f6'
    element.style.borderStyle = 'dashed'
  },

  unhighlight(element) {
    element.classList.remove('drag-over')
    element.style.backgroundColor = ''
    element.style.borderColor = ''
    element.style.borderStyle = ''
  },

  handleFiles(files, dropZone) {
    console.log("📁 Files dropped:", files.length)
    
    // Find the file input within the drop zone
    const fileInput = dropZone.querySelector('input[type="file"]')
    if (fileInput) {
      // Create a new FileList-like object
      const dt = new DataTransfer()
      files.forEach(file => dt.items.add(file))
      fileInput.files = dt.files
      
      // Trigger change event
      fileInput.dispatchEvent(new Event('change', { bubbles: true }))
      console.log("📁 Files assigned to input")
    }
  }
};

// Get CSRF token
let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
if (!csrfToken) {
  console.error("🔥 CSRF token not found")
}

// Create LiveSocket
let liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

console.log("🔥 LiveSocket created with hooks:", Object.keys(Hooks))

// Portfolio design application
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

console.log("🔥 App.js fully loaded with new VideoCapture hook")
console.log("🔥 Available hooks:", Object.keys(window.Hooks))