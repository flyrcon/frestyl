// assets/js/app.js - FIXED VERSION with Portfolio Hooks

import "phoenix_html"
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import topbar from "../vendor/topbar"

// Import Video Capture Hook
import VideoCapture from "./hooks/video_capture"

// Import Sortable for drag-and-drop
import Sortable from 'sortablejs'

// Make Sortable globally available
window.Sortable = Sortable;

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

// FIXED: Portfolio-specific hooks with proper video integration
let Hooks = {
  // FIXED: Video Capture Hook
  VideoCapture: VideoCapture,

  // Auto Focus Hook - for modal inputs
  AutoFocus: {
    mounted() {
      setTimeout(() => {
        this.el.focus();
        this.el.select(); // Also select text if it's an input
      }, 100);
    }
  },

  // FIXED: Copy to Clipboard Hook
  CopyToClipboard: {
    mounted() {
      this.handleEvent('copy_to_clipboard', (payload) => {
        if (navigator.clipboard && navigator.clipboard.writeText) {
          navigator.clipboard.writeText(payload.text).then(() => {
            console.log('✅ Text copied to clipboard:', payload.text);
            
            // Show success feedback
            this.pushEvent('clipboard_success', {});
            
          }).catch(err => {
            console.error('❌ Failed to copy text:', err);
            this.fallbackCopyTextToClipboard(payload.text);
          });
        } else {
          // Fallback for older browsers
          this.fallbackCopyTextToClipboard(payload.text);
        }
      });
    },

    fallbackCopyTextToClipboard(text) {
      const textArea = document.createElement("textarea");
      textArea.value = text;
      
      // Avoid scrolling to bottom
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
  },

  // Section Sortable Hook - for drag-and-drop section reordering
  SectionSortable: {
    mounted() {
      console.log('SectionSortable hook mounted', this.el);
      this.initializeSortable();
    },

    updated() {
      console.log('SectionSortable hook updated');
      this.destroySortable();
      this.initializeSortable();
    },

    destroyed() {
      console.log('SectionSortable hook destroyed');
      this.destroySortable();
    },

    initializeSortable() {
      if (typeof Sortable === 'undefined') {
        console.error('Sortable library not found. Please install SortableJS.');
        return;
      }

      this.destroySortable();

      this.sortable = new Sortable(this.el, {
        animation: 200,
        ghostClass: 'sortable-ghost',
        chosenClass: 'sortable-chosen',
        dragClass: 'sortable-drag',
        handle: '.drag-handle',
        forceFallback: true,
        
        onStart: (evt) => {
          console.log('Drag started');
          evt.item.classList.add('dragging');
          document.body.classList.add('sections-reordering');
        },

        onEnd: (evt) => {
          console.log('Drag ended');
          evt.item.classList.remove('dragging');
          document.body.classList.remove('sections-reordering');
          
          const sectionIds = Array.from(this.el.children)
            .map(child => child.getAttribute('data-section-id'))
            .filter(Boolean);

          console.log('New section order:', sectionIds);
          this.pushEvent('reorder_sections', { sections: sectionIds });
        }
      });

      console.log('SectionSortable initialized successfully');
    },

    destroySortable() {
      if (this.sortable) {
        this.sortable.destroy();
        this.sortable = null;
      }
    }
  },

  // Media Sortable Hook - for drag-and-drop media reordering
  MediaSortable: {
    mounted() {
      console.log('MediaSortable hook mounted', this.el);
      this.initializeSortable();
    },

    updated() {
      this.destroySortable();
      this.initializeSortable();
    },

    destroyed() {
      this.destroySortable();
    },

    initializeSortable() {
      if (typeof Sortable === 'undefined') return;

      this.destroySortable();

      this.sortable = new Sortable(this.el, {
        animation: 150,
        ghostClass: 'sortable-ghost',
        chosenClass: 'sortable-chosen',
        dragClass: 'sortable-drag',
        
        onEnd: (evt) => {
          const sectionId = this.el.getAttribute('data-section-id');
          const mediaIds = Array.from(this.el.children)
            .map(child => child.getAttribute('data-media-id'))
            .filter(Boolean);

          console.log('Media reordered:', mediaIds);
          this.pushEvent('reorder_media', { 
            section_id: sectionId, 
            media_order: mediaIds 
          });
        }
      });
    },

    destroySortable() {
      if (this.sortable) {
        this.sortable.destroy();
        this.sortable = null;
      }
    }
  },

  // File Upload Hook - for enhanced file upload handling
  FileUpload: {
    mounted() {
      console.log('FileUpload hook mounted');
      this.el.addEventListener('change', this.handleFileSelect.bind(this));
    },

    handleFileSelect(event) {
      const files = Array.from(event.target.files);
      console.log('Files selected:', files.length);
      
      const maxSize = 50 * 1024 * 1024; // 50MB
      const validFiles = files.filter(file => file.size <= maxSize);
      
      if (validFiles.length !== files.length) {
        alert(`Some files were too large. Maximum size is 50MB.`);
      }

      // Trigger validation
      this.pushEvent('validate_upload', {
        file_count: validFiles.length,
        total_size: validFiles.reduce((sum, file) => sum + file.size, 0)
      });
    }
  },

  // File Upload Zone Hook - for drag-and-drop file uploads
  FileUploadZone: {
    mounted() {
      console.log('FileUploadZone hook mounted');
      
      this.el.addEventListener('dragover', this.handleDragOver.bind(this));
      this.el.addEventListener('dragleave', this.handleDragLeave.bind(this));
      this.el.addEventListener('drop', this.handleDrop.bind(this));
    },

    handleDragOver(event) {
      event.preventDefault();
      this.el.classList.add('drag-over');
    },

    handleDragLeave(event) {
      event.preventDefault();
      // Only remove class if we're actually leaving the drop zone
      if (!this.el.contains(event.relatedTarget)) {
        this.el.classList.remove('drag-over');
      }
    },

    handleDrop(event) {
      event.preventDefault();
      this.el.classList.remove('drag-over');
      
      const files = Array.from(event.dataTransfer.files);
      console.log('Files dropped:', files.length);
      
      const fileInput = this.el.querySelector('input[type="file"]');
      if (fileInput) {
        // Create a new FileList-like object
        const dt = new DataTransfer();
        files.forEach(file => dt.items.add(file));
        fileInput.files = dt.files;
        
        // Trigger change event
        fileInput.dispatchEvent(new Event('change', { bubbles: true }));
      }
    }
  },

  // Enhanced Modal Management Hook
  ModalManager: {
    mounted() {
      // Close modal on escape key
      this.handleKeyDown = (event) => {
        if (event.key === 'Escape') {
          this.closeModal();
        }
      };

      // Close modal on backdrop click
      this.handleBackdropClick = (event) => {
        if (event.target === this.el) {
          this.closeModal();
        }
      };

      document.addEventListener('keydown', this.handleKeyDown);
      this.el.addEventListener('click', this.handleBackdropClick);
    },

    destroyed() {
      document.removeEventListener('keydown', this.handleKeyDown);
      this.el.removeEventListener('click', this.handleBackdropClick);
    },

    closeModal() {
      // Determine which modal this is and send appropriate event
      if (this.el.querySelector('[phx-click="hide_create_modal"]')) {
        this.pushEvent('hide_create_modal', {});
      } else if (this.el.querySelector('[phx-click="hide_share_modal"]')) {
        this.pushEvent('hide_share_modal', {});
      } else if (this.el.querySelector('[phx-click="hide_video_intro"]')) {
        this.pushEvent('hide_video_intro', {});
      }
    }
  },

  // Form Validation Hook
  FormValidator: {
    mounted() {
      this.form = this.el;
      this.setupValidation();
    },

    setupValidation() {
      const inputs = this.form.querySelectorAll('input[required], textarea[required]');
      
      inputs.forEach(input => {
        input.addEventListener('blur', () => this.validateInput(input));
        input.addEventListener('input', () => this.clearErrors(input));
      });

      this.form.addEventListener('submit', (event) => {
        if (!this.validateForm()) {
          event.preventDefault();
          event.stopPropagation();
        }
      });
    },

    validateInput(input) {
      const value = input.value.trim();
      const errorElement = input.parentNode.querySelector('.error-message');

      if (input.hasAttribute('required') && !value) {
        this.showError(input, 'This field is required');
        return false;
      }

      if (input.type === 'email' && value && !this.isValidEmail(value)) {
        this.showError(input, 'Please enter a valid email address');
        return false;
      }

      this.clearErrors(input);
      return true;
    },

    validateForm() {
      const inputs = this.form.querySelectorAll('input[required], textarea[required]');
      let isValid = true;

      inputs.forEach(input => {
        if (!this.validateInput(input)) {
          isValid = false;
        }
      });

      return isValid;
    },

    showError(input, message) {
      this.clearErrors(input);
      
      const errorElement = document.createElement('div');
      errorElement.className = 'error-message text-red-600 text-sm mt-1';
      errorElement.textContent = message;
      
      input.parentNode.appendChild(errorElement);
      input.classList.add('border-red-500');
    },

    clearErrors(input) {
      const errorElement = input.parentNode.querySelector('.error-message');
      if (errorElement) {
        errorElement.remove();
      }
      input.classList.remove('border-red-500');
    },

    isValidEmail(email) {
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      return emailRegex.test(email);
    }
  },

  // Loading States Hook
  LoadingStates: {
    mounted() {
      this.originalText = this.el.textContent;
      this.isLoading = false;
    },

    updated() {
      // Reset if loading state changed
      if (this.el.hasAttribute('data-loading') && !this.isLoading) {
        this.showLoading();
      } else if (!this.el.hasAttribute('data-loading') && this.isLoading) {
        this.hideLoading();
      }
    },

    showLoading() {
      this.isLoading = true;
      this.el.disabled = true;
      this.el.innerHTML = `
        <svg class="animate-spin -ml-1 mr-3 h-4 w-4 text-white inline" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        Loading...
      `;
    },

    hideLoading() {
      this.isLoading = false;
      this.el.disabled = false;
      this.el.textContent = this.originalText;
    }
  },

  // Smooth Scroll Hook
  SmoothScroll: {
    mounted() {
      this.el.addEventListener('click', (event) => {
        event.preventDefault();
        const targetId = this.el.getAttribute('href');
        const targetElement = document.querySelector(targetId);
        
        if (targetElement) {
          targetElement.scrollIntoView({
            behavior: 'smooth',
            block: 'start'
          });
        }
      });
    }
  },

  // Tooltip Hook
  Tooltip: {
    mounted() {
      this.createTooltip();
      this.bindEvents();
    },

    destroyed() {
      this.removeTooltip();
    },

    createTooltip() {
      this.tooltip = document.createElement('div');
      this.tooltip.className = 'tooltip absolute z-50 px-2 py-1 text-sm text-white bg-gray-900 rounded shadow-lg pointer-events-none opacity-0 transition-opacity duration-200';
      this.tooltip.textContent = this.el.getAttribute('data-tooltip');
      document.body.appendChild(this.tooltip);
    },

    bindEvents() {
      this.el.addEventListener('mouseenter', () => this.showTooltip());
      this.el.addEventListener('mouseleave', () => this.hideTooltip());
      this.el.addEventListener('mousemove', (e) => this.positionTooltip(e));
    },

    showTooltip() {
      this.tooltip.style.opacity = '1';
    },

    hideTooltip() {
      this.tooltip.style.opacity = '0';
    },

    positionTooltip(event) {
      const x = event.clientX + 10;
      const y = event.clientY - 30;
      
      this.tooltip.style.left = `${x}px`;
      this.tooltip.style.top = `${y}px`;
    },

    removeTooltip() {
      if (this.tooltip) {
        this.tooltip.remove();
      }
    }
  },

  // Animate on Scroll Hook
  AnimateOnScroll: {
    mounted() {
      this.observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
          if (entry.isIntersecting) {
            entry.target.classList.add('animate-fade-in-up');
            this.observer.unobserve(entry.target);
          }
        });
      }, {
        threshold: 0.1,
        rootMargin: '0px 0px -50px 0px'
      });

      this.observer.observe(this.el);
    },

    destroyed() {
      if (this.observer) {
        this.observer.disconnect();
      }
    }
  }
};

// Global hooks reference
window.Hooks = Hooks;

// LiveSocket configuration
let liveSocket = new LiveSocket("/live", Socket, {
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
      
      // Preserve input states during updates
      if (from.type === 'range' && from === document.activeElement) {
        to.value = from.value;
      }
      
      return true;
    }
  },

  // Enhanced metadata for better event handling
  metadata: {
    click: (e, el) => {
      return {
        alt: e.altKey,
        shift: e.shiftKey,
        ctrl: e.ctrlKey,
        meta: e.metaKey,
        x: e.clientX,
        y: e.clientY,
        detail: e.detail || 1
      }
    },
    
    keydown: (e, el) => {
      return {
        key: e.key,
        altKey: e.altKey,
        shiftKey: e.shiftKey,
        ctrlKey: e.ctrlKey,
        metaKey: e.metaKey
      }
    }
  }
});

// Enhanced progress bar
topbar.config({ 
  barColors: { 0: "#3b82f6" }, 
  shadowColor: "rgba(0, 0, 0, .3)" 
});

window.addEventListener("phx:page-loading-start", _info => topbar.show(300));
window.addEventListener("phx:page-loading-stop", _info => topbar.hide());

// Portfolio-specific event handlers
window.addEventListener("phx:copy_to_clipboard", (event) => {
  const text = event.detail.text;
  
  if (navigator.clipboard && navigator.clipboard.writeText) {
    navigator.clipboard.writeText(text).then(() => {
      console.log('✅ Text copied to clipboard via event');
      // Show success notification
      showNotification('Link copied to clipboard!', 'success');
    }).catch(err => {
      console.error('❌ Failed to copy text via event:', err);
      fallbackCopyText(text);
    });
  } else {
    fallbackCopyText(text);
  }
});

// Notification system
function showNotification(message, type = 'info') {
  const notification = document.createElement('div');
  notification.className = `fixed top-4 right-4 z-50 p-4 rounded-lg text-white transform translate-x-full transition-transform duration-300 ${
    type === 'success' ? 'bg-green-500' : 
    type === 'error' ? 'bg-red-500' : 
    'bg-blue-500'
  }`;
  notification.textContent = message;
  
  document.body.appendChild(notification);
  
  // Animate in
  setTimeout(() => {
    notification.style.transform = 'translateX(0)';
  }, 100);
  
  // Remove after 3 seconds
  setTimeout(() => {
    notification.style.transform = 'translateX(full)';
    setTimeout(() => {
      notification.remove();
    }, 300);
  }, 3000);
}

// Fallback copy function
function fallbackCopyText(text) {
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
      console.log('✅ Fallback: Text copied');
      showNotification('Link copied to clipboard!', 'success');
    } else {
      showNotification('Failed to copy link', 'error');
    }
  } catch (err) {
    console.error('❌ Fallback: Copy failed:', err);
    showNotification('Failed to copy link', 'error');
  }

  document.body.removeChild(textArea);
}

// Enhanced CSS animations
const additionalStyles = `
  @keyframes fade-in-up {
    from {
      opacity: 0;
      transform: translateY(30px);
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  .animate-fade-in-up {
    animation: fade-in-up 0.6s ease-out;
  }

  .sortable-ghost {
    opacity: 0.5;
    background: #f3f4f6;
    transform: scale(1.05);
  }

  .sortable-chosen {
    box-shadow: 0 8px 25px rgba(0, 0, 0, 0.15);
  }

  .sortable-drag {
    transform: rotate(5deg);
  }

  .drag-over {
    transform: scale(1.02);
    border-color: #3b82f6 !important;
    background-color: rgba(59, 130, 246, 0.1) !important;
  }

  .sections-reordering .section-item:not(.sortable-chosen) {
    opacity: 0.7;
  }

  /* Modal animations */
  .modal-enter {
    animation: modal-fade-in 0.3s ease-out;
  }

  .modal-leave {
    animation: modal-fade-out 0.3s ease-out;
  }

  @keyframes modal-fade-in {
    from {
      opacity: 0;
      transform: scale(0.9);
    }
    to {
      opacity: 1;
      transform: scale(1);
    }
  }

  @keyframes modal-fade-out {
    from {
      opacity: 1;
      transform: scale(1);
    }
    to {
      opacity: 0;
      transform: scale(0.9);
    }
  }

  /* Loading spinner */
  .spinner {
    border: 2px solid #f3f3f3;
    border-top: 2px solid #3b82f6;
    border-radius: 50%;
    width: 20px;
    height: 20px;
    animation: spin 1s linear infinite;
  }

  @keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }

  /* Tooltip styles */
  .tooltip {
    z-index: 9999;
    white-space: nowrap;
  }

  /* Video preview enhancements */
  #camera-preview, #playback-video {
    border-radius: 8px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  }

  .video-overlay {
    background: linear-gradient(45deg, rgba(0,0,0,0.7), rgba(0,0,0,0.3));
  }

  /* Enhanced focus styles */
  .focus\\:ring-portfolio:focus {
    ring-color: #8b5cf6;
    ring-width: 2px;
  }

  /* Smooth transitions for all interactive elements */
  button, .btn, .card, input, textarea, select {
    transition: all 0.2s cubic-bezier(0.4, 0.0, 0.2, 1);
  }

  /* Enhanced hover effects */
  .hover-lift:hover {
    transform: translateY(-2px);
    box-shadow: 0 8px 25px rgba(0, 0, 0, 0.15);
  }
`;

// Inject additional styles
const styleSheet = document.createElement('style');
styleSheet.textContent = additionalStyles;
document.head.appendChild(styleSheet);

// Connect LiveSocket
liveSocket.connect();

// Expose for debugging
window.liveSocket = liveSocket;

console.log('✅ Frestyl Portfolio app.js loaded with enhanced hooks');