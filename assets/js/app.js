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
import FabricCanvas from "./hooks/fabric"
import {RatingCanvas} from "./hooks/rating_canvas_hook"
import PodcastStudio from "./hooks/podcast_hooks"
import { PodcastTimelineEditor} from "./hooks/podcast_hooks"


console.log("🔥 Imports loaded")

// COMPLETE HOOKS DEFINITION
let Hooks = {
  VideoCapture: VideoCapture,  // Use new clean hook
  RichTextEditor: RichTextEditor,
  CollaborativeTextEditor,
  VoiceRecorder,

  // Podcast hooks
  PodcastStudio,
  PodcastTimelineEditor,
  
  // New storyboard hooks
  StoryboardManager,
  FabricCanvas,

  // Peer review
  RatingCanvas,

  VibeRatingWidget: {
    mounted() {
      this.canvas = this.el.querySelector('canvas') || this.createCanvas();
      this.ctx = this.canvas.getContext('2d');
      this.isActive = false;
      this.currentRating = { x: 50, y: 50 }; // Default center position
      this.sessionStartTime = Date.now();
      
      this.setupCanvas();
      this.setupEventListeners();
      this.drawInterface();
    },

    createCanvas() {
      const canvas = document.createElement('canvas');
      canvas.className = 'w-full h-48 border border-gray-300 rounded-lg cursor-crosshair';
      canvas.style.touchAction = 'none'; // Prevent scrolling on touch
      this.el.appendChild(canvas);
      return canvas;
    },

    setupCanvas() {
      // Set canvas size based on container
      const rect = this.canvas.parentElement.getBoundingClientRect();
      const width = Math.max(300, rect.width);
      const height = 200;
      
      this.canvas.width = width;
      this.canvas.height = height;
      this.canvas.style.width = width + 'px';
      this.canvas.style.height = height + 'px';
    },

    setupEventListeners() {
      // Mouse events
      this.canvas.addEventListener('mousedown', (e) => this.startRating(e));
      this.canvas.addEventListener('mousemove', (e) => this.updateRating(e));
      this.canvas.addEventListener('mouseup', (e) => this.endRating(e));
      this.canvas.addEventListener('mouseleave', (e) => this.endRating(e));

      // Touch events for mobile
      this.canvas.addEventListener('touchstart', (e) => {
        e.preventDefault();
        const touch = e.touches[0];
        this.startRating(this.getTouchMouseEvent(touch, 'mousedown'));
      });

      this.canvas.addEventListener('touchmove', (e) => {
        e.preventDefault();
        const touch = e.touches[0];
        this.updateRating(this.getTouchMouseEvent(touch, 'mousemove'));
      });

      this.canvas.addEventListener('touchend', (e) => {
        e.preventDefault();
        this.endRating();
      });

      // Window resize
      window.addEventListener('resize', () => {
        this.setupCanvas();
        this.drawInterface();
      });
    },

    getTouchMouseEvent(touch, type) {
      return {
        type: type,
        clientX: touch.clientX,
        clientY: touch.clientY,
        preventDefault: () => {}
      };
    },

    startRating(e) {
      this.isActive = true;
      this.updateRatingPosition(e);
    },

    updateRating(e) {
      if (!this.isActive) return;
      this.updateRatingPosition(e);
    },

    endRating(e) {
      if (!this.isActive) return;
      this.isActive = false;
      
      const sessionDuration = Date.now() - this.sessionStartTime;
      
      // Send rating to LiveView
      this.pushEvent("rating_updated", {
        primary_score: this.currentRating.x,
        secondary_score: this.currentRating.y,
        rating_coordinates: {
          x: this.currentRating.x,
          y: this.currentRating.y
        },
        rating_session_duration: sessionDuration
      });
    },

    updateRatingPosition(e) {
      const rect = this.canvas.getBoundingClientRect();
      const x = ((e.clientX - rect.left) / rect.width) * 100;
      const y = 100 - ((e.clientY - rect.top) / rect.height) * 100; // Invert Y axis
      
      // Clamp values between 0 and 100
      this.currentRating.x = Math.max(0, Math.min(100, x));
      this.currentRating.y = Math.max(0, Math.min(100, y));
      
      this.drawInterface();
    },

    drawInterface() {
      const ctx = this.ctx;
      const width = this.canvas.width;
      const height = this.canvas.height;
      
      // Clear canvas
      ctx.clearRect(0, 0, width, height);
      
      // Draw gradient background
      this.drawGradientBackground(ctx, width, height);
      
      // Draw current rating position
      this.drawRatingIndicator(ctx, width, height);
      
      // Draw axis labels
      this.drawAxisLabels(ctx, width, height);
    },

    drawGradientBackground(ctx, width, height) {
      // Create horizontal gradient (red to green for quality)
      const horizontalGradient = ctx.createLinearGradient(0, 0, width, 0);
      horizontalGradient.addColorStop(0, '#ef4444'); // Red (poor)
      horizontalGradient.addColorStop(0.5, '#eab308'); // Yellow (okay)
      horizontalGradient.addColorStop(1, '#22c55e'); // Green (excellent)
      
      // Fill with horizontal gradient
      ctx.fillStyle = horizontalGradient;
      ctx.fillRect(0, 0, width, height);
      
      // Create vertical gradient overlay for secondary dimension
      const verticalGradient = ctx.createLinearGradient(0, height, 0, 0);
      verticalGradient.addColorStop(0, 'rgba(139, 92, 246, 0.3)'); // Purple (low collaboration)
      verticalGradient.addColorStop(1, 'rgba(6, 182, 212, 0.3)'); // Cyan (high collaboration)
      
      // Overlay vertical gradient
      ctx.fillStyle = verticalGradient;
      ctx.fillRect(0, 0, width, height);
    },

    drawRatingIndicator(ctx, width, height) {
      const x = (this.currentRating.x / 100) * width;
      const y = height - (this.currentRating.y / 100) * height; // Invert Y for canvas
      
      // Draw white circle with black border
      ctx.beginPath();
      ctx.arc(x, y, 12, 0, 2 * Math.PI);
      ctx.fillStyle = 'white';
      ctx.fill();
      ctx.strokeStyle = 'black';
      ctx.lineWidth = 3;
      ctx.stroke();
      
      // Draw inner dot
      ctx.beginPath();
      ctx.arc(x, y, 4, 0, 2 * Math.PI);
      ctx.fillStyle = 'black';
      ctx.fill();
      
      // Draw crosshairs
      ctx.beginPath();
      ctx.moveTo(x - 20, y);
      ctx.lineTo(x + 20, y);
      ctx.moveTo(x, y - 20);
      ctx.lineTo(x, y + 20);
      ctx.strokeStyle = 'rgba(0, 0, 0, 0.5)';
      ctx.lineWidth = 1;
      ctx.stroke();
    },

    drawAxisLabels(ctx, width, height) {
      ctx.fillStyle = 'rgba(255, 255, 255, 0.9)';
      ctx.font = '14px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif';
      ctx.textAlign = 'center';
      ctx.strokeStyle = 'rgba(0, 0, 0, 0.8)';
      ctx.lineWidth = 3;
      
      // Bottom labels (Quality axis)
      const bottomY = height - 10;
      ctx.strokeText('Poor Quality', 60, bottomY);
      ctx.fillText('Poor Quality', 60, bottomY);
      
      ctx.strokeText('High Quality', width - 60, bottomY);
      ctx.fillText('High Quality', width - 60, bottomY);
      
      // Side labels (Secondary dimension)
      ctx.save();
      ctx.translate(15, height - 30);
      ctx.rotate(-Math.PI / 2);
      ctx.strokeText('Low Collaboration', 0, 0);
      ctx.fillText('Low Collaboration', 0, 0);
      ctx.restore();
      
      ctx.save();
      ctx.translate(15, 40);
      ctx.rotate(-Math.PI / 2);
      ctx.strokeText('High Collaboration', 0, 0);
      ctx.fillText('High Collaboration', 0, 0);
      ctx.restore();
    },

    updated() {
      // Redraw if component updates
      this.drawInterface();
    }
  },

  // Fabric Canvas Hook (for storyboards)
  FabricCanvas: {
    mounted() {
      console.log("FabricCanvas mounted");
      // Add your fabric.js initialization here if needed
    }
  }
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