// assets/js/app.js - FIXED VERSION with proper hook registration

import "phoenix_html"
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import topbar from "../vendor/topbar"

import { PublicPortfolioRenderer } from "./hooks/public_portfolio_renderer"
import { DesignSettings } from "./hooks/design_settings"


// Import Video Capture Hook
import VideoCapture from "./hooks/video_capture"
import FileUpload from "./hooks/file_upload"

// Import template hooks
import TemplateHooks from "./hooks/template_hooks"
import PortfolioEditorFixedHooks from "./hooks/portfolio_editor_fixed_hooks"
import PortfolioEditorHooks from "./portfolio_editor_hooks"

import MobileEditorHooks from "./hooks/mobile_editor_hooks"

// Portfolio collaboration
import PortfolioCollaboration from './portfolio_collaboration_hooks'

// Import Sortable Hooks
import SortableHooks from "./hooks/sortable_hooks"

import { SortableSections, PreviewRefresh } from "./hooks/sortable_sections"

// Import Sortable for drag-and-drop
import Sortable from 'sortablejs'


// Add safety checks for potentially undefined imports
const DragDropOutline = window.DragDropOutline || {};
const CharacterRelationships = window.CharacterRelationships || {};
const WorldBibleSearch = window.WorldBibleSearch || {};
const StoryAutoSave = window.StoryAutoSave || {};
const CollaborativeCursors = window.CollaborativeCursors || {};

const PortfolioEditorHooks = {
  // ============================================================================
  // COPY TO CLIPBOARD FUNCTIONALITY
  // ============================================================================
  CopyToClipboard: {
    mounted() {
      this.el.addEventListener('click', () => {
        const textToCopy = this.el.dataset.copy || this.el.previousElementSibling.value;
        
        navigator.clipboard.writeText(textToCopy).then(() => {
          this.showCopySuccess();
        }).catch(() => {
          this.fallbackCopy(textToCopy);
        });
      });
    },

    showCopySuccess() {
      const originalText = this.el.textContent;
      this.el.textContent = 'Copied!';
      this.el.classList.add('bg-green-600');
      
      setTimeout(() => {
        this.el.textContent = originalText;
        this.el.classList.remove('bg-green-600');
      }, 1500);
    },

    fallbackCopy(text) {
      const textArea = document.createElement('textarea');
      textArea.value = text;
      document.body.appendChild(textArea);
      textArea.select();
      document.execCommand('copy');
      document.body.removeChild(textArea);
      this.showCopySuccess();
    }
  }
};

// Video Download Hook
const VideoDownloader = {
  mounted() {
    console.log("🔥 VideoDownloader hook mounted");
    
    this.handleEvent("download_file", (data) => {
      this.downloadFile(data.url, data.filename);
    });
  },

  downloadFile(url, filename) {
    // Create a temporary anchor element to trigger download
    const link = document.createElement('a');
    link.href = url;
    link.download = filename || 'video.mp4';
    link.style.display = 'none';
    
    // Add to DOM, click, and remove
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    
    console.log("🔥 Video download initiated:", filename);
  }
};

// Video Upload Handler Hook
const VideoUploadHandler = {
  mounted() {
    console.log("🔥 VideoUploadHandler hook mounted");
    
    // Handle file input changes
    const fileInput = document.getElementById('video-upload');
    if (fileInput) {
      fileInput.addEventListener('change', (e) => {
        this.handleFileSelection(e);
      });
    }
    
    // Handle drag and drop
    this.setupDragAndDrop();
  },

  handleFileSelection(event) {
    const file = event.target.files[0];
    if (file) {
      this.validateAndPreviewFile(file);
    }
  },

  validateAndPreviewFile(file) {
    // Validate file type
    const validTypes = ['video/mp4', 'video/webm', 'video/mov', 'video/avi'];
    if (!validTypes.includes(file.type)) {
      this.showError('Please select a valid video file (MP4, WebM, MOV, or AVI)');
      return;
    }
    
    // Validate file size (100MB limit)
    const maxSize = 100 * 1024 * 1024; // 100MB in bytes
    if (file.size > maxSize) {
      this.showError('File size must be less than 100MB');
      return;
    }
    
    // Show file preview
    this.showFilePreview(file);
    
    // Trigger upload process
    this.pushEvent("validate_video_upload", {
      filename: file.name,
      size: file.size,
      type: file.type
    });
  },

  showFilePreview(file) {
    const previewArea = document.querySelector('.border-dashed');
    if (previewArea) {
      previewArea.innerHTML = `
        <div class="text-center">
          <div class="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <svg class="w-8 h-8 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
            </svg>
          </div>
          <p class="font-medium text-gray-900">${file.name}</p>
          <p class="text-sm text-gray-600">${this.formatFileSize(file.size)}</p>
        </div>
      `;
      previewArea.classList.remove('border-gray-300');
      previewArea.classList.add('border-green-300', 'bg-green-50');
    }
  },

  showError(message) {
    // You can implement a toast notification system here
    console.error("Video upload error:", message);
    // For now, just alert - you can integrate with your notification system
    alert(message);
  },

  formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  },

  setupDragAndDrop() {
    const dropArea = document.querySelector('.border-dashed');
    if (!dropArea) return;

    ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
      dropArea.addEventListener(eventName, this.preventDefaults, false);
    });

    ['dragenter', 'dragover'].forEach(eventName => {
      dropArea.addEventListener(eventName, () => {
        dropArea.classList.add('border-purple-400', 'bg-purple-50');
      }, false);
    });

    ['dragleave', 'drop'].forEach(eventName => {
      dropArea.addEventListener(eventName, () => {
        dropArea.classList.remove('border-purple-400', 'bg-purple-50');
      }, false);
    });

    dropArea.addEventListener('drop', (e) => {
      const files = e.dataTransfer.files;
      if (files.length > 0) {
        this.validateAndPreviewFile(files[0]);
      }
    }, false);
  },

  preventDefaults(e) {
    e.preventDefault();
    e.stopPropagation();
  }
};

// Video Menu Closer Hook (closes menu when clicking outside)
const VideoMenuCloser = {
  mounted() {
    this.outsideClickHandler = (e) => {
      if (!this.el.contains(e.target)) {
        this.pushEvent("toggle_video_menu");
      }
    };
    
    document.addEventListener("click", this.outsideClickHandler);
  },

  destroyed() {
    document.removeEventListener("click", this.outsideClickHandler);
  }
};

// Add CSS for video upload animations
const videoUploadCSS = `
  .video-upload-progress {
    transition: width 0.3s ease;
  }
  
  .video-upload-success {
    animation: successPulse 0.6s ease-out;
  }
  
  @keyframes successPulse {
    0% { transform: scale(1); }
    50% { transform: scale(1.05); }
    100% { transform: scale(1); }
  }
  
  .drag-over {
    transform: translateY(-2px);
    box-shadow: 0 10px 25px rgba(0,0,0,0.1);
  }
`;

// Inject video upload CSS
if (!document.getElementById("video-upload-css")) {
  const style = document.createElement("style");
  style.id = "video-upload-css";
  style.textContent = videoUploadCSS;
  document.head.appendChild(style);
}

// Update the main hooks export
window.Hooks = window.Hooks || {};
Object.assign(window.Hooks, {
  // ... existing hooks
  VideoDownloader,
  VideoUploadHandler,
  VideoMenuCloser
});

// ============================================================================
// GLOBAL PORTFOLIO EDITOR UTILITIES
// ============================================================================
window.PortfolioEditor = {
  init() {
    this.setupGlobalKeyboardShortcuts();
    this.setupClickOutsideHandlers();
  },

  setupGlobalKeyboardShortcuts() {
    document.addEventListener('keydown', (e) => {
      // Only trigger if not in an input field
      if (e.target.matches('input, textarea, select')) return;
      
      // Ctrl/Cmd + S to save
      if ((e.ctrlKey || e.metaKey) && e.key === 's') {
        e.preventDefault();
        const saveButton = document.querySelector('[phx-click="save_portfolio"]');
        if (saveButton) saveButton.click();
      }
    });
  },

  setupClickOutsideHandlers() {
    // Handle dropdown closing
    document.addEventListener('click', (e) => {
      // Close add section dropdown if clicking outside
      if (!e.target.closest('[phx-click="toggle_add_section_dropdown"]') && 
          !e.target.closest('.absolute.right-0.mt-2')) {
        // Trigger close event if dropdown is open
        const closeButton = document.querySelector('[phx-click="close_add_section_dropdown"]');
        if (closeButton) closeButton.click();
      }
    });
  }
};

const DevicePreviewSwitcher = {};
const AutoSaveControl = {};
const LayoutPreview = {};

const PortfolioEditorFixedHooks = {
  
  // ============================================================================
  // LIVE PREVIEW MANAGER - Fixed for PortfolioEditorFixed
  // ============================================================================
  LivePreviewManager: {
    mounted() {
      console.log("🖥️ LivePreviewManager hook mounted for PortfolioEditorFixed");
      this.setupPreviewRefresh();
      this.setupPreviewCommunication();
    },

    setupPreviewRefresh() {
      // Listen for the CORRECT event names that PortfolioEditorFixed sends
      this.handleEvent("refresh_portfolio_preview", (data) => {
        console.log("🔄 Refreshing portfolio preview", data);
        this.refreshPreview(data);
      });

      this.handleEvent("update_preview_css", (data) => {
        console.log("🎨 Updating preview CSS", data);
        this.updatePreviewCSS(data.css);
      });

      this.handleEvent("section_added", (data) => {
        console.log("➕ Section added:", data);
        this.showFeedback(`${data.title} section added!`, 'success');
        setTimeout(() => this.refreshPreview(), 100);
      });

      this.handleEvent("section_saved", (data) => {
        console.log("💾 Section saved:", data);
        this.showFeedback("Section saved!", 'success');
        this.refreshPreview();
      });

      this.handleEvent("section_deleted", (data) => {
        console.log("🗑️ Section deleted:", data);
        this.showFeedback("Section deleted", 'info');
        this.refreshPreview();
      });

      this.handleEvent("sections_reordered", (data) => {
        console.log("🔄 Sections reordered:", data);
        this.showFeedback("Sections reordered!", 'success');
        this.refreshPreview();
      });
    },

    setupPreviewCommunication() {
      // Set up communication with the iframe
      window.addEventListener('message', (event) => {
        if (event.data.type === 'preview_loaded') {
          console.log("✅ Preview loaded successfully");
          this.handlePreviewLoaded();
        }
      });
    },

    refreshPreview(data = {}) {
      // Use the CORRECT iframe ID from PortfolioEditorFixed
      const iframe = document.getElementById('portfolio-preview');
      if (!iframe) {
        console.warn("⚠️ Portfolio preview iframe not found");
        return;
      }

      const currentUrl = new URL(iframe.src);
      
      // Add timestamp to force refresh
      currentUrl.searchParams.set('t', data.timestamp || Date.now());
      
      // Add any additional parameters
      if (data.template) {
        currentUrl.searchParams.set('template', data.template);
      }
      
      console.log("🔄 Refreshing iframe:", currentUrl.toString());
      iframe.src = currentUrl.toString();
      
      this.showRefreshAnimation();
    },

    updatePreviewCSS(css) {
      if (!css) return;
      
      // Try to update iframe content if accessible
      try {
        const iframe = document.getElementById('portfolio-preview');
        if (iframe && iframe.contentDocument) {
          // Remove existing preview CSS
          const existingCSS = iframe.contentDocument.getElementById('portfolio-preview-css');
          if (existingCSS) {
            existingCSS.remove();
          }
          
          // Add new CSS
          const style = iframe.contentDocument.createElement('style');
          style.id = 'portfolio-preview-css';
          style.innerHTML = css;
          iframe.contentDocument.head.appendChild(style);
          
          console.log("✅ CSS updated directly in iframe");
        } else {
          throw new Error("Cannot access iframe content");
        }
      } catch (e) {
        // Cross-origin restriction, will refresh instead
        console.log("🔄 Cross-origin CSS update failed, refreshing iframe");
        setTimeout(() => this.refreshPreview(), 300);
      }
    },

    showRefreshAnimation() {
      const iframe = document.getElementById('portfolio-preview');
      if (iframe) {
        iframe.style.opacity = '0.7';
        iframe.style.transform = 'scale(0.98)';
        
        setTimeout(() => {
          iframe.style.opacity = '1';
          iframe.style.transform = 'scale(1)';
        }, 200);
      }
    },

    showFeedback(message, type = 'success') {
      // Remove existing feedback
      const existingFeedback = document.querySelector('.preview-feedback');
      if (existingFeedback) {
        existingFeedback.remove();
      }

      const colors = {
        success: 'bg-green-500 text-white',
        error: 'bg-red-500 text-white',
        info: 'bg-blue-500 text-white',
        warning: 'bg-yellow-500 text-black'
      };

      const feedback = document.createElement('div');
      feedback.className = `preview-feedback fixed top-20 right-4 px-4 py-2 rounded-lg shadow-lg z-50 transition-all ${colors[type]}`;
      feedback.textContent = message;
      document.body.appendChild(feedback);

      setTimeout(() => {
        feedback.style.opacity = '0';
        feedback.style.transform = 'translateX(20px)';
        setTimeout(() => {
          if (feedback.parentNode) {
            feedback.remove();
          }
        }, 300);
      }, 2000);
    },

    handlePreviewLoaded() {
      console.log("📱 Preview loaded, ready for updates");
    }
  },

    MobileNavigation: {
    mounted() {
      console.log("📱 MobileNavigation hook mounted");
    }
  },

  FloatingButtons: {
    mounted() {
      console.log("📱 FloatingButtons hook mounted");
    }
  },

  PreviewDevice: {
    mounted() {
      console.log("📱 PreviewDevice hook mounted");
    }
  },

  LivePreviewManager: {
    mounted() {
      console.log("🖥️ LivePreviewManager hook mounted");
      this.setupPreviewRefresh();
    },

    setupPreviewRefresh() {
      this.handleEvent("refresh_portfolio_preview", (data) => {
        console.log("🔄 Refreshing portfolio preview", data);
        const iframe = document.getElementById('portfolio-preview');
        if (iframe) {
          const url = new URL(iframe.src);
          url.searchParams.set('t', data.timestamp || Date.now());
          iframe.src = url.toString();
          console.log("🔄 Preview refreshed:", url.toString());
        } else {
          console.warn("⚠️ Portfolio preview iframe not found");
        }
      });
    }
  },

  // ============================================================================
  // SORTABLE SECTIONS - Fixed for PortfolioEditorFixed
  // ============================================================================
  SortableSections: {
    mounted() {
      console.log("📝 SortableSections hook mounted for PortfolioEditorFixed");
      this.initializeSortable();
      this.setupEventListeners();
    },

    updated() {
      // Only reinitialize if sections actually changed
      if (this.shouldReinitialize()) {
        console.log("🔄 Reinitializing sortable - sections changed");
        this.initializeSortable();
      }
    },

    shouldReinitialize() {
      const currentItems = this.el.querySelectorAll('[data-section-id]');
      const currentCount = currentItems.length;
      
      if (this.lastItemCount !== currentCount) {
        this.lastItemCount = currentCount;
        return true;
      }
      
      return false;
    },

    initializeSortable() {
      // Destroy existing sortable
      if (this.sortable) {
        this.sortable.destroy();
        this.sortable = null;
      }

      // Find the sections container
      const container = this.el.querySelector('#sections-list') || this.el;
      
      if (!container || typeof Sortable === 'undefined') {
        console.warn("⚠️ Sortable container or SortableJS not found");
        return;
      }

      try {
        this.sortable = Sortable.create(container, {
          handle: '.section-item',
          animation: 200,
          ghostClass: 'sortable-ghost',
          chosenClass: 'sortable-chosen',
          dragClass: 'sortable-drag',
          
          onStart: (evt) => {
            console.log("🎯 Drag started:", evt.oldIndex);
            document.body.classList.add('sorting-active');
          },
          
          onEnd: (evt) => {
            console.log("🎯 Drag ended:", evt.oldIndex, "->", evt.newIndex);
            document.body.classList.remove('sorting-active');
            
            if (evt.oldIndex !== evt.newIndex) {
              this.handleReorder();
            }
          }
        });

        this.lastItemCount = container.querySelectorAll('[data-section-id]').length;
        console.log("✅ SortableSections initialized successfully");
        
      } catch (error) {
        console.error("❌ Failed to initialize SortableJS:", error);
      }
    },

    handleReorder() {
      // Get all section IDs in their new order
      const sectionItems = this.el.querySelectorAll('[data-section-id]');
      const sectionIds = Array.from(sectionItems).map(item => 
        item.getAttribute('data-section-id')
      );

      console.log("🔄 New section order:", sectionIds);

      // Push the reorder event with the correct format
      this.pushEvent("reorder_sections", {
        section_ids: sectionIds
      });
    },

    setupEventListeners() {
      // Listen for section updates from PortfolioEditorFixed
      this.handleEvent("section_added", () => {
        setTimeout(() => this.initializeSortable(), 100);
      });

      this.handleEvent("section_deleted", () => {
        setTimeout(() => this.initializeSortable(), 100);
      });
    },

    destroyed() {
      if (this.sortable) {
        this.sortable.destroy();
      }
      document.body.classList.remove('sorting-active');
    }
  },

  // ============================================================================
  // MOBILE NAVIGATION - From your mobile navigation code
  // ============================================================================
  MobileNavigation: {
    mounted() {
      console.log("📱 MobileNavigation hook mounted");
      this.setupMobileNavigation();
      this.setupSwipeGestures();
    },
    
    setupMobileNavigation() {
      // Handle mobile nav events
      this.handleEvent('mobile_nav_opened', () => {
        document.body.style.overflow = 'hidden';
        document.body.classList.add('mobile-nav-open');
      });
      
      this.handleEvent('mobile_nav_closed', () => {
        document.body.style.overflow = '';
        document.body.classList.remove('mobile-nav-open');
      });
    },
    
    setupSwipeGestures() {
      let startX = 0;
      let isDragging = false;
      
      document.addEventListener('touchstart', (e) => {
        startX = e.touches[0].clientX;
        isDragging = true;
      }, { passive: true });
      
      document.addEventListener('touchmove', (e) => {
        if (!isDragging) return;
        
        const currentX = e.touches[0].clientX;
        const deltaX = currentX - startX;
        
        // Swipe right from left edge to open nav
        if (startX < 30 && deltaX > 80) {
          this.pushEvent('toggle_mobile_nav');
          isDragging = false;
        }
      }, { passive: true });
      
      document.addEventListener('touchend', () => {
        isDragging = false;
      }, { passive: true });
    }
  },

  // ============================================================================
  // PREVIEW DEVICE - For mobile/tablet/desktop switching
  // ============================================================================
  PreviewDevice: {
    mounted() {
      console.log("📱 PreviewDevice hook mounted");
      this.setupDevicePreview();
    },
    
    setupDevicePreview() {
      this.handleEvent('device_changed', ({ device }) => {
        console.log(`📱 Device changed to: ${device}`);
        this.updatePreviewFrame(device);
      });
    },
    
    updatePreviewFrame(device) {
      const iframe = document.getElementById('portfolio-preview');
      if (iframe) {
        const container = iframe.closest('.preview-container');
        if (container) {
          container.className = `preview-container device-${device}`;
        }
      }
    }
  },

  // ============================================================================
  // FLOATING BUTTONS - For mobile floating action buttons
  // ============================================================================
  FloatingButtons: {
    mounted() {
      console.log("📱 FloatingButtons hook mounted");
      this.setupFloatingButtons();
    },
    
    setupFloatingButtons() {
      // Handle unsaved changes indicator
      this.handleEvent('unsaved_changes_updated', ({ has_changes }) => {
        const saveButton = document.querySelector('.floating-save-button, [phx-click="save_portfolio"]');
        if (saveButton) {
          if (has_changes) {
            saveButton.classList.add('has-changes');
            saveButton.style.backgroundColor = '#f59e0b';
          } else {
            saveButton.classList.remove('has-changes');
            saveButton.style.backgroundColor = '';
          }
        }
      });
    }
  }
};

// Portfolio Hub Hooks
export const PortfolioHub = {
  mounted() {
    this.initializeGridAnimations()
    this.initializeFilterAnimations()
    this.initializeCollaborationFeatures()
  },

  initializeGridAnimations() {
    // Animate portfolio cards on load
    const cards = this.el.querySelectorAll('.portfolio-card')
    cards.forEach((card, index) => {
      card.style.opacity = '0'
      card.style.transform = 'translateY(20px)'
      
      setTimeout(() => {
        card.style.transition = 'all 0.6s ease-out'
        card.style.opacity = '1'
        card.style.transform = 'translateY(0)'
      }, index * 100)
    })
  },

  initializeFilterAnimations() {
    // Add smooth transitions when filtering
    const filterButtons = this.el.querySelectorAll('[phx-click="filter_portfolios"]')
    filterButtons.forEach(button => {
      button.addEventListener('click', () => {
        // Add loading state
        button.classList.add('opacity-50')
        setTimeout(() => {
          button.classList.remove('opacity-50')
        }, 300)
      })
    })
  },

  initializeCollaborationFeatures() {
    // Enhanced collaboration panel interactions
    const collaborationBell = this.el.querySelector('[phx-click="toggle_collaboration_panel"]')
    if (collaborationBell) {
      collaborationBell.addEventListener('click', () => {
        // Add bell animation
        collaborationBell.classList.add('animate-bounce')
        setTimeout(() => {
          collaborationBell.classList.remove('animate-bounce')
        }, 1000)
      })
    }
  },

  updated() {
    // Re-initialize animations after updates
    setTimeout(() => {
      this.initializeGridAnimations()
    }, 100)
  }
}

export const WelcomeCelebration = {
  mounted() {
    this.initializeCelebration()
  },

  initializeCelebration() {
    // Auto-start confetti effect
    setTimeout(() => {
      this.createConfettiEffect()
    }, 500)

    // Auto-dismiss after 30 seconds unless user interacts
    this.dismissTimer = setTimeout(() => {
      this.pushEvent("dismiss_welcome", {})
    }, 30000)
  },

  createConfettiEffect() {
    const colors = ['#fbbf24', '#f59e0b', '#3b82f6', '#8b5cf6', '#ef4444', '#10b981']
    const container = this.el
    
    for (let i = 0; i < 50; i++) {
      setTimeout(() => {
        const confetti = document.createElement('div')
        confetti.style.cssText = `
          position: absolute;
          width: 8px;
          height: 8px;
          background: ${colors[Math.floor(Math.random() * colors.length)]};
          border-radius: 50%;
          pointer-events: none;
          z-index: 1000;
          top: 20%;
          left: ${20 + Math.random() * 60}%;
          animation: confettifall 3s ease-out forwards;
        `
        
        container.appendChild(confetti)
        
        setTimeout(() => confetti.remove(), 3000)
      }, i * 50)
    }
  },

  destroyed() {
    if (this.dismissTimer) {
      clearTimeout(this.dismissTimer)
    }
  }
}

// Make Sortable globally available
window.Sortable = Sortable;

// Chart.js compatibility

if (typeof Chart !== 'undefined' && Chart.adapters) {
  Chart.adapters._adapters = Chart.adapters._adapters || {};
}
window.Chart = window.Chart || {};

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

// FIXED: Clean hooks object with no conflicts
let Hooks = {
  // Video Recording
  VideoPlayer,
  VideoCapture,
 ...PortfolioEditorFixedHooks,
  FileUpload,

  PublicPortfolioRenderer,
  DesignSettings,

   ...MobileEditorHooks,

  MobileNavigation: {
    mounted() {
      console.log("📱 MobileNavigation hook mounted");
    }
  },

  FloatingButtons: {
    mounted() {
      console.log("📱 FloatingButtons hook mounted");
    }
  },

  PreviewDevice: {
    mounted() {
      console.log("📱 PreviewDevice hook mounted");
    }
  },

  LivePreviewManager: {
    mounted() {
      console.log("🖥️ LivePreviewManager hook mounted");
      this.setupPreviewRefresh();
    },

    setupPreviewRefresh() {
      this.handleEvent("refresh_portfolio_preview", (data) => {
        console.log("🔄 Refreshing portfolio preview", data);
        const iframe = document.getElementById('portfolio-preview');
        if (iframe) {
          const url = new URL(iframe.src);
          url.searchParams.set('t', data.timestamp || Date.now());
          iframe.src = url.toString();
          console.log("🔄 Preview refreshed:", url.toString());
        } else {
          console.warn("⚠️ Portfolio preview iframe not found");
        }
      });
    }
  },
  
  SortableSections: {
    mounted() {
      console.log("📝 SortableSections hook mounted");
      // Basic sortable functionality will be added later
    },
    
    updated() {
      console.log("📝 SortableSections updated");
    }
  },
  

  // Portfolio Collaboration
  PortfolioCollaboration,

  // Drag & Drop Hooks - FIXED: No duplicates
  SortableMedia: SortableHooks.MediaSortable,
  SortableSkills: SortableHooks.SkillsSortable,
  SortableExperience: SortableHooks.ExperienceSortable,
  SortableEducation: SortableHooks.EducationSortable,
    // FIXED: Enhanced Sortable Sections Hook
  SortableSections: OptimizedSortableHooks.SortableSections,
  SortableSections: SortableHooks.SectionSortable, 
  PreviewRefresh: PreviewRefresh,

    // Other existing hooks...
    PreviewFrame: {
      mounted() {
        console.log("📱 PreviewFrame hook mounted");
        
        this.handleEvent("refresh_preview", () => {
          const iframe = this.el.querySelector('iframe');
          if (iframe) {
            iframe.src = iframe.src;
          }
        });
      }
    }
  };

// Add sortable CSS if not already present
if (!document.getElementById('sortable-styles')) {
  const style = document.createElement('style');
  style.id = 'sortable-styles';
  style.textContent = `
    .sortable-ghost {
      opacity: 0.4;
      transform: scale(0.95);
      background: #f3f4f6;
    }
    
    .sortable-chosen {
      transform: scale(1.02);
      box-shadow: 0 8px 25px rgba(0, 0, 0, 0.15);
      z-index: 1000;
    }
    
    .sortable-drag {
      transform: rotate(2deg);
      opacity: 0.8;
    }
    
    .sorting-active .section-card:not(.sortable-chosen) {
      opacity: 0.7;
    }
    
    .drag-in-progress {
      cursor: grabbing !important;
    }
    
    .drag-handle, .section-drag-handle, .block-drag-handle {
      cursor: grab;
      transition: all 0.2s ease;
    }
    
    .drag-handle:hover, .section-drag-handle:hover, .block-drag-handle:hover {
      color: #4f46e5;
      transform: scale(1.1);
    }
    
    .drag-handle:active, .section-drag-handle:active, .block-drag-handle:active {
      cursor: grabbing;
    }
    
    .drag-placeholder {
      border: 2px dashed #cbd5e1;
      background: #f8fafc;
    }
  `;
  document.head.appendChild(style);
};


  // Portfolio Hub Hook
  PortfolioHub: PortfolioHub,

  // Mobile Hooks
  window.MobilePortfolioHooks?.MobileGestures;
  window.MobilePortfolioHooks?.MobilePullRefresh;

  // Auto Focus Hook
  AutoFocus = {
    mounted() {
      setTimeout(() => {
        this.el.focus();
        this.el.select();
      }, 100);
    }
  },

  DragDropOutline,
  CharacterRelationships,
  WorldBibleSearch,
  StoryAutoSave,
  CollaborativeCursors,  

  DragBlock = {
    mounted() {
      const element = this.el;
      const blockId = element.dataset.blockId;
      
      element.addEventListener('dragstart', (e) => {
        console.log('Drag started for block:', blockId);
        e.dataTransfer.setData('text/plain', blockId);
        e.dataTransfer.effectAllowed = 'move';
        
        // Add visual feedback
        element.style.opacity = '0.5';
        element.style.transform = 'rotate(2deg) scale(1.02)';
        
        // Notify LiveView
        this.pushEvent('start_drag', { block_id: blockId });
      });
      
      element.addEventListener('dragend', (e) => {
        console.log('Drag ended for block:', blockId);
        
        // Remove visual feedback
        element.style.opacity = '1';
        element.style.transform = 'none';
        
        // Notify LiveView
        this.pushEvent('drag_end', {});
      });
    }
  },  

  Hooks.DropZone = {
    mounted() {
      const element = this.el;
      const zoneName = element.dataset.zone;
      
      element.addEventListener('dragover', (e) => {
        e.preventDefault();
        e.dataTransfer.dropEffect = 'move';
        
        // Add visual feedback
        element.classList.add('border-green-400', 'bg-green-50');
        element.classList.remove('border-purple-200', 'bg-purple-50');
        
        // Notify LiveView
        this.pushEvent('drag_over', { zone: zoneName });
      });
      
      element.addEventListener('dragleave', (e) => {
        // Only trigger if we're actually leaving the zone (not just moving between child elements)
        if (!element.contains(e.relatedTarget)) {
          // Remove visual feedback
          element.classList.remove('border-green-400', 'bg-green-50');
          element.classList.add('border-purple-200', 'bg-purple-50');
          
          // Notify LiveView
          this.pushEvent('drag_leave', {});
        }
      });
      
      element.addEventListener('drop', (e) => {
        e.preventDefault();
        
        const blockId = e.dataTransfer.getData('text/plain');
        
        // Calculate drop position based on where in the zone we dropped
        const blocks = element.querySelectorAll('[data-block-id]');
        let position = blocks.length; // Default to end
        
        const mouseY = e.clientY;
        for (let i = 0; i < blocks.length; i++) {
          const blockRect = blocks[i].getBoundingClientRect();
          if (mouseY < blockRect.top + blockRect.height / 2) {
            position = i;
            break;
          }
        }
        
        console.log('Dropped block', blockId, 'in zone', zoneName, 'at position', position);
        
        // Remove visual feedback
        element.classList.remove('border-green-400', 'bg-green-50');
        element.classList.add('border-purple-200', 'bg-purple-50');
        
        // Notify LiveView
        this.pushEvent('drop', { 
          zone: zoneName, 
          position: position.toString(),
          block_id: blockId 
        });
      });
    }
  },

  PdfDownload = {
    mounted() {
      console.log('🎯 PdfDownload hook mounted successfully on element:', this.el.id)
      
      this.handleEvent("download_pdf", (data) => {
        console.log('🎯 Received download_pdf event with data:', data)
        
        if (!data.data) {
          console.error('❌ No PDF data received!')
          this.showToast('No PDF data received. Please try again.', 'error')
          return
        }
        
        try {
          this.showPdfPreviewModal(data)
        } catch (error) {
          console.error('❌ Error showing PDF preview:', error)
          this.showToast(`Error showing PDF preview: ${error.message}`, 'error')
        }
      })
    },

    showPdfPreviewModal(data) {
      try {
        const byteCharacters = atob(data.data)
        const byteNumbers = new Array(byteCharacters.length)
        
        for (let i = 0; i < byteCharacters.length; i++) {
          byteNumbers[i] = byteCharacters.charCodeAt(i)
        }
        
        const byteArray = new Uint8Array(byteNumbers)
        const blob = new Blob([byteArray], { type: 'application/pdf' })
        const pdfUrl = window.URL.createObjectURL(blob)
        
        this.createStyledModal(pdfUrl, data.filename, data, () => {
          window.URL.revokeObjectURL(pdfUrl)
        })
        
      } catch (error) {
        console.error('❌ Error in showPdfPreviewModal:', error)
        this.showToast(`Failed to preview PDF: ${error.message}`, 'error')
      }
    },

    createStyledModal(pdfUrl, filename, originalData, onClose) {
      const existingModal = document.getElementById('pdf-preview-modal')
      if (existingModal) {
        existingModal.remove()
      }

      const modal = document.createElement('div')
      modal.id = 'pdf-preview-modal'
      modal.className = 'fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50'
      modal.style.backdropFilter = 'blur(4px)'
      
      modal.innerHTML = `
        <div class="bg-white rounded-2xl shadow-2xl w-11/12 max-w-4xl h-5/6 max-h-[90vh] flex flex-col overflow-hidden">
          <div class="bg-gradient-to-r from-blue-600 to-purple-600 px-6 py-4 rounded-t-2xl">
            <div class="flex items-center justify-between">
              <div class="flex items-center space-x-3">
                <div class="w-10 h-10 bg-white bg-opacity-20 rounded-lg flex items-center justify-center backdrop-blur">
                  <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                  </svg>
                </div>
                <div>
                  <h3 class="text-xl font-bold text-white">Portfolio PDF Preview</h3>
                  <p class="text-blue-100 text-sm">Review your portfolio before printing or saving</p>
                </div>
              </div>
              
              <div class="flex items-center space-x-2">
                <button id="pdf-print-btn" class="bg-blue-700 hover:bg-blue-800 text-white px-3 py-2 rounded-lg text-sm font-medium transition-all duration-200 flex items-center space-x-2 border border-blue-500">
                  <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z"/>
                  </svg>
                  <span class="text-white">Print</span>
                </button>
                
                <button id="pdf-download-btn" class="bg-green-600 hover:bg-green-700 text-white px-3 py-2 rounded-lg text-sm font-medium transition-all duration-200 flex items-center space-x-2 border border-green-500">
                  <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                  </svg>
                  <span class="text-white">Save</span>
                </button>
                
                <button id="pdf-close-btn" class="bg-gray-600 hover:bg-gray-700 text-white p-2 rounded-lg transition-colors border border-gray-500">
                  <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                  </svg>
                </button>
              </div>
            </div>
          </div>

          <div class="bg-gray-50 px-6 py-2 border-b border-gray-200">
            <div class="flex items-center justify-between text-xs">
              <div class="flex items-center space-x-3 text-gray-600">
                <span class="font-medium text-gray-900">${filename}</span>
                <span>•</span>
                <span>${this.formatFileSize(originalData.size)}</span>
                <span>•</span>
                <span class="text-green-600 font-medium">ATS-optimized</span>
              </div>
              <div class="text-gray-500">
                <span class="text-xs">ESC to close</span>
              </div>
            </div>
          </div>
          
          <div class="flex-1 p-4 bg-gray-100 min-h-0 overflow-hidden">
            <div class="h-full bg-white rounded-lg shadow-inner overflow-hidden border border-gray-300">
              <iframe 
                src="${pdfUrl}#toolbar=1&navpanes=0&scrollbar=1&view=FitH" 
                class="w-full h-full border-0"
                type="application/pdf"
                title="Portfolio PDF Preview">
              </iframe>
            </div>
          </div>

          <div class="bg-white px-6 py-3 border-t border-gray-200 rounded-b-2xl">
            <div class="flex items-center justify-between text-xs text-gray-600">
              <div class="flex items-center space-x-4">
                <span class="flex items-center space-x-1">
                  <svg class="w-3 h-3 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
                  </svg>
                  <span>ATS-compatible</span>
                </span>
                <span class="flex items-center space-x-1">
                  <svg class="w-3 h-3 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
                  </svg>
                  <span>Print-ready</span>
                </span>
              </div>
              <div class="text-gray-500">
                Click outside modal to close
              </div>
            </div>
          </div>
        </div>
      `

      document.body.appendChild(modal)
      
      modal.style.opacity = '0'
      modal.style.transform = 'scale(0.96)'
      modal.style.transition = 'all 0.25s ease-out'
      
      requestAnimationFrame(() => {
        modal.style.opacity = '1'
        modal.style.transform = 'scale(1)'
      })

      this.setupModalEventListeners(modal, pdfUrl, filename, originalData, onClose)
    },

    setupModalEventListeners(modal, pdfUrl, filename, originalData, onClose) {
      const printBtn = modal.querySelector('#pdf-print-btn')
      const downloadBtn = modal.querySelector('#pdf-download-btn')
      const closeBtn = modal.querySelector('#pdf-close-btn')

      if (printBtn) {
        printBtn.addEventListener('click', () => {
          this.handlePrint(modal.querySelector('iframe'), pdfUrl)
        })
      }

      if (downloadBtn) {
        downloadBtn.addEventListener('click', () => {
          this.handleDownload(originalData)
        })
      }

      const closeModal = () => {
        modal.style.opacity = '0'
        modal.style.transform = 'scale(0.95)'
        setTimeout(() => {
          modal.remove()
          onClose()
        }, 200)
      }

      if (closeBtn) {
        closeBtn.addEventListener('click', closeModal)
      }
      
      modal.addEventListener('click', (e) => {
        if (e.target === modal) {
          closeModal()
        }
      })

      const handleEscape = (e) => {
        if (e.key === 'Escape') {
          closeModal()
          document.removeEventListener('keydown', handleEscape)
        }
      }
      document.addEventListener('keydown', handleEscape)
    },

    handlePrint(iframe, pdfUrl) {
      try {
        if (iframe && iframe.contentWindow) {
          iframe.contentWindow.print()
        } else {
          throw new Error('Cannot access iframe content')
        }
      } catch (error) {
        const printWindow = window.open(pdfUrl, '_blank', 'width=800,height=600,toolbar=yes,scrollbars=yes,resizable=yes')
        if (printWindow) {
          printWindow.addEventListener('load', () => {
            setTimeout(() => printWindow.print(), 500)
          })
        } else {
          this.showToast('Please allow popups to print, or use Save to download the PDF.', 'error')
        }
      }
    },

    async handleDownload(data) {
      try {
        if ('showSaveFilePicker' in window) {
          await this.modernDownload(data)
        } else {
          this.traditionalDownload(data)
        }
      } catch (error) {
        if (error.name === 'AbortError') {
          this.showToast('Save cancelled', 'info')
        } else {
          this.showToast('Download failed. Please try again.', 'error')
        }
      }
    },

    async modernDownload(data) {
      const fileHandle = await window.showSaveFilePicker({
        suggestedName: data.filename,
        types: [{
          description: 'PDF files',
          accept: { 'application/pdf': ['.pdf'] }
        }]
      })

      const binaryString = atob(data.data)
      const bytes = new Uint8Array(binaryString.length)
      
      for (let i = 0; i < binaryString.length; i++) {
        bytes[i] = binaryString.charCodeAt(i)
      }

      const writable = await fileHandle.createWritable()
      await writable.write(bytes)
      await writable.close()

      this.showToast('PDF saved successfully!', 'success')
    },

    traditionalDownload(data) {
      const binaryString = atob(data.data)
      const bytes = new Uint8Array(binaryString.length)
      
      for (let i = 0; i < binaryString.length; i++) {
        bytes[i] = binaryString.charCodeAt(i)
      }

      const blob = new Blob([bytes], { type: data.content_type })
      const url = window.URL.createObjectURL(blob)
      
      const link = document.createElement('a')
      link.href = url
      link.download = data.filename
      link.style.display = 'none'
      
      document.body.appendChild(link)
      link.click()
      document.body.removeChild(link)
      
      window.URL.revokeObjectURL(url)
      
      this.showToast(`"${data.filename}" downloaded successfully!`, 'success')
    },

    formatFileSize(bytes) {
      if (!bytes) return 'Unknown size'
      
      const sizes = ['Bytes', 'KB', 'MB', 'GB']
      if (bytes === 0) return '0 Bytes'
      
      const i = Math.floor(Math.log(bytes) / Math.log(1024))
      return Math.round(bytes / Math.pow(1024, i) * 100) / 100 + ' ' + sizes[i]
    },

    showToast(message, type = 'info') {
      const toast = document.createElement('div')
      toast.className = `fixed top-4 right-4 z-50 px-6 py-4 rounded-lg shadow-lg text-white max-w-sm transition-all duration-300 transform translate-x-full`
      
      const colors = {
        success: 'bg-green-500',
        error: 'bg-red-500',
        info: 'bg-blue-500'
      }
      toast.classList.add(colors[type] || colors.info)
      
      const icons = {
        success: '✅',
        error: '❌',
        info: 'ℹ️'
      }
      
      toast.innerHTML = `
        <div class="flex items-center space-x-3">
          <div class="flex-shrink-0 text-lg">
            ${icons[type] || icons.info}
          </div>
          <div class="flex-1">
            <p class="text-sm font-medium">${message}</p>
          </div>
          <button class="flex-shrink-0 text-white hover:text-gray-200 ml-2" onclick="this.parentElement.parentElement.remove()">
            ✕
          </button>
        </div>
      `
      
      document.body.appendChild(toast)
      
      setTimeout(() => {
        toast.classList.remove('translate-x-full')
      }, 100)
      
      setTimeout(() => {
        if (toast.parentElement) {
          toast.classList.add('translate-x-full')
          setTimeout(() => toast.remove(), 300)
        }
      }, 5000)
    }
  },

  TemplateHooks,
  
  // Preview refresh hook
  PreviewRefresh = {
    mounted() {
      this.handleEvent("refresh_portfolio_preview", ({timestamp}) => {
        console.log("🔄 Refreshing portfolio preview");
        this.refreshPreview();
      });
      
      this.handleEvent("schedule_preview_refresh", ({delay, timestamp}) => {
        clearTimeout(this.refreshTimeout);
        this.refreshTimeout = setTimeout(() => {
          this.refreshPreview();
        }, delay);
      });
    },
    
    refreshPreview() {
      const iframe = document.querySelector('iframe[src*="/p/"]');
      if (iframe) {
        iframe.src = iframe.src.split('?')[0] + '?preview=true&t=' + Date.now();
      }
    }
  },

    // Clipboard Hook
  Clipboard ={
    mounted() {
      this.el.addEventListener('click', async () => {
        const textToCopy = this.el.dataset.clipboard || this.el.textContent;
        
        try {
          await navigator.clipboard.writeText(textToCopy);
          console.log('✅ Text copied to clipboard');
          this.pushEvent('clipboard_success', {});
        } catch (err) {
          console.error('❌ Failed to copy text:', err);
          this.fallbackCopy(textToCopy);
        }
      });
    },

    fallbackCopy(text) {
      const textArea = document.createElement('textarea');
      textArea.value = text;
      textArea.style.position = 'fixed';
      textArea.style.opacity = '0';
      
      document.body.appendChild(textArea);
      textArea.focus();
      textArea.select();

      try {
        const successful = document.execCommand('copy');
        if (successful) {
          console.log('✅ Fallback: Text copied to clipboard');
          this.pushEvent('clipboard_success', {});
        } else {
          console.error('❌ Fallback: Failed to copy text');
        }
      } catch (err) {
        console.error('❌ Fallback: Copy command failed:', err);
      }

      document.body.removeChild(textArea);
    }
  },

  // Template selection hook
  TemplateSelector = {
    mounted() {
      console.log("🎨 Template Selector mounted");
      this.el.addEventListener('click', (e) => {
        const templateCard = e.target.closest('.template-preview-card');
        if (templateCard) {
          // Add loading state
          const loading = templateCard.querySelector('.template-loading');
          if (loading) {
            loading.classList.remove('hidden');
            loading.classList.add('flex');
          }
          
          // Update selection immediately for better UX
          this.updateTemplateSelection(templateCard);
        }
      });
    },
    
    updateTemplateSelection(selectedCard) {
      // Remove selection from all cards
      const allCards = document.querySelectorAll('.template-preview-card');
      allCards.forEach(card => {
        card.classList.remove('border-blue-500', 'shadow-lg', 'ring-2', 'ring-blue-200', 'bg-blue-50');
        card.classList.add('border-gray-200', 'bg-white');
        
        // Hide selection indicator
        const indicator = card.querySelector('.absolute.top-2.right-2');
        if (indicator) {
          indicator.style.display = 'none';
        }
      });
      
      // Add selection to clicked card
      selectedCard.classList.remove('border-gray-200', 'bg-white');
      selectedCard.classList.add('border-blue-500', 'shadow-lg', 'ring-2', 'ring-blue-200', 'bg-blue-50');
      
      // Show selection indicator
      const indicator = selectedCard.querySelector('.absolute.top-2.right-2');
      if (indicator) {
        indicator.style.display = 'flex';
      }
    }
  },

  // Color picker enhancements
  ColorPickerLive = {
    mounted() {
      console.log("🎨 Live Color Picker mounted");
      this.setupColorPicker();
    },
    
    setupColorPicker() {
      const colorInputs = this.el.querySelectorAll('input[type="color"], input[type="text"]');
      
      colorInputs.forEach(input => {
        // Sync color and text inputs
        input.addEventListener('input', (e) => {
          const value = e.target.value;
          const name = e.target.name;
          
          // Update paired input
          const pairedInput = this.el.querySelector(`input[name="${name}"]:not([type="${e.target.type}"])`);
          if (pairedInput && pairedInput.value !== value) {
            pairedInput.value = value;
          }
          
          // Update preview immediately
          this.updateColorPreview(name, value);
        });
        
        // Validate hex input
        if (input.type === 'text') {
          input.addEventListener('blur', (e) => {
            const value = e.target.value;
            if (value && !this.isValidHex(value)) {
              e.target.style.borderColor = '#ef4444';
              setTimeout(() => {
                e.target.style.borderColor = '';
              }, 2000);
            }
          });
        }
      });
    },
    
    updateColorPreview(colorField, value) {
      if (this.isValidHex(value)) {
        // Update CSS variable
        const varName = `--portfolio-${colorField.replace('_', '-')}`;
        document.documentElement.style.setProperty(varName, value);
        
        // Update swatches
        const swatchClass = `.color-swatch-${colorField.replace('_color', '')}`;
        const swatches = document.querySelectorAll(swatchClass);
        swatches.forEach(swatch => {
          swatch.style.backgroundColor = value;
          // Add animation
          swatch.style.transform = 'scale(1.05)';
          setTimeout(() => {
            swatch.style.transform = 'scale(1)';
          }, 150);
        });
        
        // Update template overlays
        this.updateTemplateOverlays();
      }
    },
    
    updateTemplateOverlays() {
      const primaryColor = getComputedStyle(document.documentElement)
        .getPropertyValue('--portfolio-primary-color').trim();
      const secondaryColor = getComputedStyle(document.documentElement)
        .getPropertyValue('--portfolio-secondary-color').trim();
      
      if (primaryColor && secondaryColor) {
        const overlays = document.querySelectorAll('.template-preview-card [style*="linear-gradient"]');
        overlays.forEach(overlay => {
          overlay.style.background = `linear-gradient(135deg, ${primaryColor}, ${secondaryColor})`;
        });
      }
    },
    
    isValidHex(hex) {
      return /^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$/.test(hex);
    }
  },

  // Font preview hook
  FontPreview = {
    mounted() {
      console.log("🎨 Font Preview mounted");
      this.setupFontPreview();
    },
    
    setupFontPreview() {
      const fontButtons = this.el.querySelectorAll('button[phx-click="update_typography"]');
      
      fontButtons.forEach(button => {
        button.addEventListener('mouseenter', (e) => {
          const fontFamily = e.target.getAttribute('phx-value-font');
          this.previewFont(fontFamily, true);
        });
        
        button.addEventListener('mouseleave', (e) => {
          this.resetFontPreview();
        });
        
        button.addEventListener('click', (e) => {
          const fontFamily = e.target.getAttribute('phx-value-font');
          this.selectFont(fontFamily);
        });
      });
    },
    
    previewFont(fontFamily, isHover = false) {
      const fontCSS = this.getFontCSS(fontFamily);
      const preview = document.querySelector('.portfolio-preview');
      
      if (preview) {
        preview.style.fontFamily = fontCSS;
        if (isHover) {
          preview.style.opacity = '0.8';
        }
      }
    },
    
    resetFontPreview() {
      const preview = document.querySelector('.portfolio-preview');
      if (preview) {
        preview.style.opacity = '1';
        // Reset to current font
        const currentFont = document.documentElement.style.getPropertyValue('--portfolio-font-family');
        if (currentFont) {
          preview.style.fontFamily = currentFont;
        }
      }
    },
    
    selectFont(fontFamily) {
      // Update all buttons
      const buttons = this.el.querySelectorAll('button[phx-click="update_typography"]');
      buttons.forEach(btn => {
        btn.classList.remove('border-blue-500', 'bg-blue-50');
        btn.classList.add('border-gray-200');
      });
      
      // Highlight selected
      const selectedButton = this.el.querySelector(`button[phx-value-font="${fontFamily}"]`);
      if (selectedButton) {
        selectedButton.classList.remove('border-gray-200');
        selectedButton.classList.add('border-blue-500', 'bg-blue-50');
      }
      
      // Update CSS
      const fontCSS = this.getFontCSS(fontFamily);
      document.documentElement.style.setProperty('--portfolio-font-family', fontCSS);
    },
    
    getFontCSS(fontFamily) {
      const fontMap = {
        'Inter': "'Inter', system-ui, sans-serif",
        'Merriweather': "'Merriweather', Georgia, serif",
        'JetBrains Mono': "'JetBrains Mono', 'Fira Code', monospace",
        'Playfair Display': "'Playfair Display', Georgia, serif"
      };
      return fontMap[fontFamily] || "system-ui, sans-serif";
    }
  },

  // Template Upload Hook
  TemplateUpload = {
    mounted() {
      console.log('🎨 TemplateUpload hook mounted');
      
      this.dropZone = this.el;
      this.fileInput = this.el.querySelector('#template-file-input');
      this.filePreview = this.el.querySelector('#file-preview');
      this.fileName = this.el.querySelector('#file-name');
      this.removeBtn = this.el.querySelector('#remove-file');
      this.templateDataInput = document.querySelector('#template-data-input');
      this.importButton = document.querySelector('#import-button');
      
      this.setupEventListeners();
    },

    setupEventListeners() {
      if (this.fileInput) {
        this.fileInput.addEventListener('change', (e) => {
          if (e.target.files[0]) {
            this.handleFileSelect(e.target.files[0]);
          }
        });
      }

      if (this.removeBtn) {
        this.removeBtn.addEventListener('click', () => {
          this.clearFile();
        });
      }

      this.dropZone.addEventListener('dragover', (e) => {
        e.preventDefault();
        e.stopPropagation();
        this.dropZone.classList.add('border-indigo-400', 'bg-indigo-50');
      });

      this.dropZone.addEventListener('dragleave', (e) => {
        e.preventDefault();
        e.stopPropagation();
        this.dropZone.classList.remove('border-indigo-400', 'bg-indigo-50');
      });

      this.dropZone.addEventListener('drop', (e) => {
        e.preventDefault();
        e.stopPropagation();
        this.dropZone.classList.remove('border-indigo-400', 'bg-indigo-50');
        
        const files = e.dataTransfer.files;
        if (files.length > 0) {
          this.handleFileSelect(files[0]);
        }
      });
    },

    handleFileSelect(file) {
      console.log('📁 File selected:', file.name);
      
      if (!file.name.toLowerCase().endsWith('.json')) {
        this.showError('Please select a JSON file');
        return;
      }

      if (file.size > 1024 * 1024) {
        this.showError('File too large. Maximum size is 1MB');
        return;
      }

      const reader = new FileReader();
      
      reader.onload = (e) => {
        try {
          const content = e.target.result;
          const templateData = JSON.parse(content);
          
          if (!templateData.template_name && !templateData.customization) {
            throw new Error('Invalid template format - missing required fields');
          }

          this.showFilePreview(file.name);
          
          if (this.templateDataInput) {
            this.templateDataInput.value = content;
          }
          
          if (this.importButton) {
            this.importButton.disabled = false;
          }
          
          console.log('✅ Template file loaded successfully');
          
        } catch (error) {
          console.error('❌ Template file error:', error);
          this.showError('Invalid template file: ' + error.message);
        }
      };

      reader.onerror = () => {
        this.showError('Failed to read file');
      };

      reader.readAsText(file);
    },

    showFilePreview(filename) {
      if (this.fileName) {
        this.fileName.textContent = filename;
      }
      if (this.filePreview) {
        this.filePreview.classList.remove('hidden');
      }
    },

    clearFile() {
      if (this.fileInput) {
        this.fileInput.value = '';
      }
      
      if (this.filePreview) {
        this.filePreview.classList.add('hidden');
      }
      
      if (this.templateDataInput) {
        this.templateDataInput.value = '';
      }
      
      if (this.importButton) {
        this.importButton.disabled = true;
      }
      
      console.log('🗑️ File cleared');
    },

    showError(message) {
      const existingError = this.el.querySelector('.upload-error');
      if (existingError) {
        existingError.remove();
      }
      
      const errorDiv = document.createElement('div');
      errorDiv.className = 'upload-error mt-2 p-2 bg-red-50 border border-red-200 rounded text-sm text-red-600';
      errorDiv.textContent = message;
      this.dropZone.appendChild(errorDiv);
      
      setTimeout(() => {
        if (errorDiv && errorDiv.parentNode) {
          errorDiv.remove();
        }
      }, 5000);
    },

    destroyed() {
      console.log('🎨 TemplateUpload hook destroyed');
    }
  },

  // Template Export Hook
  TemplateExport = {
    mounted() {
      this.handleEvent("download_template", (data) => {
        console.log('📥 Downloading template:', data.filename);
        
        try {
          const blob = new Blob([data.data], { type: data.mime_type || 'application/json' });
          const url = window.URL.createObjectURL(blob);
          
          const link = document.createElement('a');
          link.href = url;
          link.download = data.filename;
          link.style.display = 'none';
          
          document.body.appendChild(link);
          link.click();
          document.body.removeChild(link);
          
          window.URL.revokeObjectURL(url);
          
          console.log('✅ Template downloaded successfully');
          
        } catch (error) {
          console.error('❌ Download failed:', error);
        }
      });
    }
  },

  // Copy to Clipboard Hook
  CopyToClipboard = {
    mounted() {
      this.handleEvent('copy_to_clipboard', (payload) => {
        if (navigator.clipboard && navigator.clipboard.writeText) {
          navigator.clipboard.writeText(payload.text).then(() => {
            console.log('✅ Text copied to clipboard:', payload.text);
            this.pushEvent('clipboard_success', {});
          }).catch(err => {
            console.error('❌ Failed to copy text:', err);
            this.fallbackCopyTextToClipboard(payload.text);
          });
        } else {
          this.fallbackCopyTextToClipboard(payload.text);
        }
      });
    },

    fallbackCopyTextToClipboard(text) {
      const textArea = document.createElement("textarea");
      textArea.value = text;
      textArea.style.top = "0";
      textArea.style.left = "0";
      textArea.style.position = "fixed";

      document.body.appendChild(textArea);
      textArea.focus();
      textArea.select();

      try {
        const successful = document.execCommand('copy');
        if (successful) {
          console.log('✅ Fallback: Text copied to clipboard');
          this.pushEvent('clipboard_success', {});
        } else {
          console.error('❌ Fallback: Failed to copy text');
        }
      } catch (err) {
        console.error('❌ Fallback: Copy command failed:', err);
      }

      document.body.removeChild(textArea);
    }
  };


// Global hooks reference
window.Hooks = Hooks;

// Add this to your existing hooks
const LivePreviewManager = {
  mounted() {
    console.log("🔥 LivePreviewManager hook mounted");
    this.iframe = this.el;
    this.setupPreviewCommunication();
  },

  init: () => console.log('LivePreviewManager initialized'),
  updatePreview: () => {},
  toggleMobile: () => {},

  updated() {
    console.log("🔥 LivePreviewManager hook updated");
    this.refreshPreview();
  },

  setupPreviewCommunication() {
    // Listen for messages from the preview iframe
    window.addEventListener('message', (event) => {
      if (event.source === this.iframe.contentWindow) {
        console.log("🔥 Preview message received:", event.data);
        // Handle preview events if needed
      }
    });
  },

  refreshPreview() {
    if (this.iframe && this.iframe.contentWindow) {
      try {
        this.iframe.contentWindow.location.reload();
      } catch (e) {
        console.log("Preview refresh blocked by same-origin policy");
      }
    }
  }
};

// Add to your existing hooks object
window.Hooks = window.Hooks || {};
window.Hooks.LivePreviewManager = LivePreviewManager;

// LiveSocket configuration
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: Hooks,
  
  // Enhanced DOM configuration
  dom: {
    onBeforeElUpdated(from, to) {
      // Preserve focus state
      if (from === document.activeElement) {
        to.focus();
      }
      
      // Preserve video states
      if (from.tagName === 'VIDEO' && to.tagName === 'VIDEO') {
        to.currentTime = from.currentTime;
        to.muted = from.muted;
        to.volume = from.volume;
        
        if (!from.paused && from.srcObject) {
          to.srcObject = from.srcObject;
        }
      }
      
      return true;
    }
  }
});

export { PortfolioEditorHooks };

// Enhanced progress bar
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"});

window.addEventListener("phx:page-loading-start", _info => topbar.show(300));
window.addEventListener("phx:page-loading-stop", _info => topbar.hide());
window.PortfolioEditorFixedHooks = PortfolioEditorFixedHooks;

// Connect LiveSocket
liveSocket.connect();

// Expose for debugging
window.liveSocket = liveSocket;

// Enhanced LiveView event listeners for better UX
window.addEventListener('phx:section-added', (e) => {
  console.log('📝 Section added:', e.detail);
  const newSection = document.querySelector(`[data-section-id="${e.detail.section_id}"]`);
  if (newSection) {
    newSection.classList.add('bg-green-50', 'border-green-300');
    newSection.scrollIntoView({ behavior: 'smooth', block: 'center' });
    
    // Remove highlight after 3 seconds
    setTimeout(() => {
      newSection.classList.remove('bg-green-50', 'border-green-300');
    }, 3000);
  }
});

window.addEventListener('phx:section-saved', (e) => {
  console.log('💾 Section saved:', e.detail);
  const section = document.querySelector(`[data-section-id="${e.detail.section_id}"]`);
  if (section) {
    section.classList.add('bg-green-50', 'border-green-300');
    setTimeout(() => {
      section.classList.remove('bg-green-50', 'border-green-300');
    }, 2000);
  }
});

window.addEventListener('phx:section-edit-started', (e) => {
  console.log('✏️ Section edit started:', e.detail);
  const section = document.querySelector(`[data-section-id="${e.detail.section_id}"]`);
  if (section) {
    section.classList.add('ring-2', 'ring-blue-300', 'bg-blue-50');
  }
});

window.addEventListener('phx:section-edit-cancelled', (e) => {
  console.log('❌ Section edit cancelled');
  document.querySelectorAll('.section-item').forEach(section => {
    section.classList.remove('ring-2', 'ring-blue-300', 'bg-blue-50');
  });
});

// Prevent any residual form submission issues
window.addEventListener('beforeunload', function(e) {
  // Don't show confirmation for LiveView navigation
  return undefined;
});

// Global template utilities
window.PortfolioTemplates = {
  // Refresh all previews
  refreshPreviews() {
    window.TemplateUtils?.updateAllColors();
    window.TemplateUtils?.refreshPreview();
  },
  
  // Apply template immediately (for testing)
  applyTemplate(templateName) {
    console.log(`🎨 Applying template: ${templateName}`);
    // This would trigger the LiveView event
    liveSocket.execJS(document.body, `
      window.liveSocket.pushEvent('select_template', {template: '${templateName}'});
    `);
  },
  
  // Update colors immediately (for testing)
  updateColors(colors) {
    Object.entries(colors).forEach(([key, value]) => {
      document.documentElement.style.setProperty(`--portfolio-${key.replace('_', '-')}`, value);
    });
    window.TemplateUtils?.updateAllColors();
  }
};

console.log('✅ Frestyl Portfolio app.js loaded with FIXED drag & drop hooks');

document.addEventListener('DOMContentLoaded', function() {
  // Enhanced form handling to prevent page refresh
  document.addEventListener('DOMContentLoaded', function() {
    console.log('🚀 Form handling initialized');

    // Prevent ALL form submissions that don't have phx-submit
    document.addEventListener('submit', function(e) {
      const form = e.target;
      
      // Allow LiveView forms with phx-submit to be handled by LiveView
      if (form && form.hasAttribute('phx-submit')) {
        console.log('✅ LiveView form submission allowed');
        return; // Let LiveView handle it
      }
      
      // Allow forms with data-allow-submit to submit normally
      if (form && form.hasAttribute('data-allow-submit')) {
        console.log('✅ Form with data-allow-submit allowed');
        return;
      }
      
      // Prevent all other form submissions
      console.log('❌ Preventing form submission to avoid page refresh');
      e.preventDefault();
      e.stopPropagation();
      
      // Try to find a submit button and trigger a LiveView event instead
      const submitBtn = form.querySelector('button[type="submit"]');
      if (submitBtn && submitBtn.hasAttribute('phx-click')) {
        console.log('🔄 Triggering LiveView event instead');
        submitBtn.click();
      }
      
      return false;
    });

    // Enhanced button click handling for section actions
    document.addEventListener('click', function(e) {
      const button = e.target.closest('button');
      
      if (button) {
        // Handle add section buttons
        if (button.hasAttribute('phx-click') && button.getAttribute('phx-click').includes('add_section')) {
          console.log('🔧 Add section button clicked');
          e.preventDefault();
          // Let LiveView handle the phx-click
          return;
        }
        
        // Handle edit section buttons
        if (button.hasAttribute('phx-click') && button.getAttribute('phx-click').includes('edit_section')) {
          console.log('🔧 Edit section button clicked');
          e.preventDefault();
          // Let LiveView handle the phx-click
          return;
        }
        
        // Handle save section buttons
        if (button.hasAttribute('phx-click') && button.getAttribute('phx-click').includes('save_section')) {
          console.log('🔧 Save section button clicked');
          e.preventDefault();
          // Let LiveView handle the phx-click
          return;
        }
      }
    });

    // Auto-close dropdowns when clicking outside
    document.addEventListener('click', function(e) {
      const dropdowns = document.querySelectorAll('[phx-click="toggle_add_section_dropdown"]');
      
      dropdowns.forEach(dropdown => {
        const dropdownMenu = dropdown.nextElementSibling;
        
        if (dropdownMenu && 
            !dropdown.contains(e.target) && 
            !dropdownMenu.contains(e.target) &&
            !dropdownMenu.classList.contains('hidden')) {
          
          // Trigger close event
          const closeEvent = new CustomEvent('phx:close-dropdown');
          dropdown.dispatchEvent(closeEvent);
        }
      });
    });
  });

  window.PortfolioEditor.init();
  console.log('🚀 Portfolio Editor initialized successfully');
  
  // Auto-save indicators
  let saveTimeout;
  document.addEventListener('input', function(e) {
    if (e.target.matches('[phx-change], [phx-blur]')) {
      clearTimeout(saveTimeout);
      showSavingIndicator();
      
      saveTimeout = setTimeout(() => {
        hideSavingIndicator();
      }, 1000);
    }
  });
});

function showSavingIndicator() {
  let indicator = document.getElementById('saving-indicator');
  if (!indicator) {
    indicator = document.createElement('div');
    indicator.id = 'saving-indicator';
    indicator.className = 'fixed top-4 left-1/2 transform -translate-x-1/2 bg-blue-500 text-white px-4 py-2 rounded-lg shadow-lg z-50 transition-all';
    indicator.innerHTML = '💾 Saving...';
    document.body.appendChild(indicator);
  }
  indicator.style.opacity = '1';
  indicator.style.transform = 'translate(-50%, 0)';
}

function hideSavingIndicator() {
  const indicator = document.getElementById('saving-indicator');
  if (indicator) {
    indicator.style.opacity = '0';
    indicator.style.transform = 'translate(-50%, -20px)';
    setTimeout(() => {
      if (indicator.parentNode) {
        indicator.parentNode.removeChild(indicator);
      }
    }, 300);
  }
}