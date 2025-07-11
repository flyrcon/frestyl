// assets/js/portfolio_editor_hooks.js - ENHANCED VERSION

const PortfolioEditorHooks = {
  // ============================================================================
  // SORTABLE SECTIONS - DRAG & DROP FUNCTIONALITY
  // ============================================================================
  SortableSections: {
    mounted() {
      console.log("📝 SortableSections hook mounted");
      this.initializeSortable();
      this.setupEventListeners();
    },

    updated() {
      // Reinitialize sortable when sections are added/removed
      this.initializeSortable();
    },

    initializeSortable() {
      // Destroy existing sortable instance if it exists
      if (this.sortable) {
        this.sortable.destroy();
      }

      // Initialize drag and drop with SortableJS if available
      if (typeof Sortable !== 'undefined') {
        this.sortable = Sortable.create(this.el, {
          handle: '.drag-handle',
          animation: 150,
          ghostClass: 'sortable-ghost',
          chosenClass: 'sortable-chosen',
          dragClass: 'sortable-drag',
          onStart: (evt) => {
            console.log("🎯 Drag started:", evt.oldIndex);
            this.addSortingStyles();
          },
          onEnd: (evt) => {
            console.log("🎯 Drag ended:", evt.oldIndex, "->", evt.newIndex);
            this.removeSortingStyles();
            
            if (evt.oldIndex !== evt.newIndex) {
              this.pushEvent("reorder_sections", {
                old_index: evt.oldIndex,
                new_index: evt.newIndex
              });
            }
          }
        });
      } else {
        // Fallback: Basic drag and drop with HTML5 API
        this.initializeFallbackDragDrop();
      }
    },

    initializeFallbackDragDrop() {
      const sections = this.el.querySelectorAll('.section-card');
      
      sections.forEach((section, index) => {
        const dragHandle = section.querySelector('.drag-handle');
        if (dragHandle) {
          section.draggable = true;
          section.dataset.index = index;
          
          section.addEventListener('dragstart', this.handleDragStart.bind(this));
          section.addEventListener('dragover', this.handleDragOver.bind(this));
          section.addEventListener('drop', this.handleDrop.bind(this));
          section.addEventListener('dragend', this.handleDragEnd.bind(this));
        }
      });
    },

    handleDragStart(e) {
      this.draggedElement = e.target;
      this.draggedIndex = parseInt(e.target.dataset.index);
      e.target.style.opacity = '0.5';
      this.addSortingStyles();
    },

    handleDragOver(e) {
      e.preventDefault();
      e.dataTransfer.dropEffect = 'move';
    },

    handleDrop(e) {
      e.preventDefault();
      const dropTarget = e.target.closest('.section-card');
      const dropIndex = parseInt(dropTarget.dataset.index);
      
      if (this.draggedIndex !== dropIndex) {
        this.pushEvent("reorder_sections", {
          old_index: this.draggedIndex,
          new_index: dropIndex
        });
      }
    },

    handleDragEnd(e) {
      e.target.style.opacity = '';
      this.removeSortingStyles();
      this.draggedElement = null;
      this.draggedIndex = null;
    },

    addSortingStyles() {
      this.el.classList.add('sorting-active');
      document.body.classList.add('drag-in-progress');
    },

    removeSortingStyles() {
      this.el.classList.remove('sorting-active');
      document.body.classList.remove('drag-in-progress');
    },

    setupEventListeners() {
      // Listen for section updates
      this.handleEvent("section_added", (data) => {
        console.log("➕ Section added:", data);
        this.showFeedback(`${data.title} section added successfully!`, 'success');
        setTimeout(() => this.initializeSortable(), 100);
      });

      this.handleEvent("section_deleted", (data) => {
        console.log("🗑️ Section deleted:", data);
        this.showFeedback(`Section deleted`, 'info');
        setTimeout(() => this.initializeSortable(), 100);
      });

      this.handleEvent("sections_reordered", (data) => {
        console.log("🔄 Sections reordered:", data);
        this.showFeedback(`Sections reordered successfully!`, 'success');
      });
    },

    showFeedback(message, type = 'success') {
      const colors = {
        success: 'bg-green-500 text-white',
        error: 'bg-red-500 text-white',
        info: 'bg-blue-500 text-white',
        warning: 'bg-yellow-500 text-black'
      };

      const feedback = document.createElement('div');
      feedback.className = `fixed top-4 right-4 px-4 py-2 rounded-lg shadow-lg z-50 transition-all ${colors[type]}`;
      feedback.textContent = message;
      document.body.appendChild(feedback);

      setTimeout(() => {
        feedback.style.opacity = '0';
        feedback.style.transform = 'translateY(-20px)';
        setTimeout(() => feedback.remove(), 300);
      }, 3000);
    },

    destroyed() {
      if (this.sortable) {
        this.sortable.destroy();
      }
    }
  },

  // ============================================================================
  // LIVE PREVIEW IFRAME MANAGER
  // ============================================================================
  LivePreviewManager: {
    mounted() {
      console.log("🖥️ LivePreviewManager hook mounted");
      this.setupPreviewRefresh();
      this.setupPreviewCommunication();
    },

    setupPreviewRefresh() {
      // Listen for various events that should trigger preview refresh
      this.handleEvent("template_changed", (data) => {
        console.log("🎨 Template changed:", data.template);
        this.refreshPreview({ template: data.template });
        this.showTemplateChangeAnimation(data.template);
      });

      this.handleEvent("customization_changed", (data) => {
        console.log("🎨 Design updated:", data);
        this.refreshPreview({ customization: data.customization });
      });

      this.handleEvent("section_updated", (data) => {
        console.log("📝 Section updated:", data);
        this.refreshPreview();
      });

      this.handleEvent("portfolio_saved", (data) => {
        console.log("💾 Portfolio saved:", data);
        this.showSaveAnimation();
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

    refreshPreview(params = {}) {
      const iframe = document.getElementById('live-preview-iframe');
      if (!iframe) return;

      const url = new URL(iframe.src);
      
      // Add timestamp to force refresh
      url.searchParams.set('t', Date.now());
      
      // Add any additional parameters
      Object.entries(params).forEach(([key, value]) => {
        if (value !== undefined && value !== null) {
          url.searchParams.set(key, typeof value === 'object' ? JSON.stringify(value) : value);
        }
      });

      iframe.src = url.toString();
      this.showRefreshAnimation();
    },

    showRefreshAnimation() {
      const iframe = document.getElementById('live-preview-iframe');
      if (iframe) {
        iframe.style.opacity = '0.7';
        iframe.style.transform = 'scale(0.98)';
        
        setTimeout(() => {
          iframe.style.opacity = '1';
          iframe.style.transform = 'scale(1)';
        }, 200);
      }
    },

    showTemplateChangeAnimation(template) {
      const previewContainer = document.querySelector('.preview-container');
      if (previewContainer) {
        previewContainer.classList.add('template-changing');
        
        setTimeout(() => {
          previewContainer.classList.remove('template-changing');
        }, 500);
      }
    },

    showSaveAnimation() {
      // Create a save success indicator
      const saveIndicator = document.createElement('div');
      saveIndicator.className = 'fixed top-20 right-4 bg-green-500 text-white px-4 py-2 rounded-lg shadow-lg z-50 flex items-center space-x-2';
      saveIndicator.innerHTML = `
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
        </svg>
        <span>Portfolio Saved!</span>
      `;
      
      document.body.appendChild(saveIndicator);
      
      setTimeout(() => {
        saveIndicator.style.opacity = '0';
        saveIndicator.style.transform = 'translateX(20px)';
        setTimeout(() => saveIndicator.remove(), 300);
      }, 2000);
    },

    handlePreviewLoaded() {
      // Add any post-load actions here
      const iframe = document.getElementById('live-preview-iframe');
      if (iframe) {
        iframe.style.opacity = '1';
      }
    }
  },

  // ============================================================================
  // SECTION EDITOR ENHANCEMENTS
  // ============================================================================
  SectionEditor: {
    mounted() {
      console.log("✏️ SectionEditor hook mounted");
      this.setupAutoSave();
      this.setupKeyboardShortcuts();
      this.setupContentValidation();
    },

    setupAutoSave() {
      let autoSaveTimeout;
      
      // Auto-save content after user stops typing
      this.el.addEventListener('input', (e) => {
        if (e.target.matches('input, textarea, select')) {
          clearTimeout(autoSaveTimeout);
          
          // Mark as having unsaved changes
          this.markUnsavedChanges();
          
          autoSaveTimeout = setTimeout(() => {
            this.autoSaveContent(e.target);
          }, 2000); // Auto-save after 2 seconds of inactivity
        }
      });
    },

    setupKeyboardShortcuts() {
      this.el.addEventListener('keydown', (e) => {
        // Ctrl/Cmd + S to save section
        if ((e.ctrlKey || e.metaKey) && e.key === 's') {
          e.preventDefault();
          this.pushEvent("save_section");
          this.showSaveIndicator();
        }
        
        // Ctrl/Cmd + Enter to save and close
        if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
          e.preventDefault();
          this.pushEvent("save_and_close_section");
        }
        
        // Escape to close without saving
        if (e.key === 'Escape') {
          this.pushEvent("close_section_editor");
        }
      });
    },

    setupContentValidation() {
      // Real-time content validation
      this.el.addEventListener('blur', (e) => {
        if (e.target.matches('input[type="text"], textarea')) {
          this.validateField(e.target);
        }
      }, true);
    },

    autoSaveContent(field) {
      const sectionId = field.getAttribute('phx-value-section-id');
      const fieldName = field.getAttribute('phx-value-field');
      
      if (sectionId && fieldName) {
        console.log(`💾 Auto-saving ${fieldName} for section ${sectionId}`);
        
        // Trigger the save event
        field.dispatchEvent(new Event('blur', { bubbles: true }));
        
        this.showAutoSaveIndicator();
      }
    },

    validateField(field) {
      const value = field.value.trim();
      const fieldType = field.getAttribute('phx-value-field');
      
      // Remove existing validation messages
      this.removeValidationMessage(field);
      
      // Basic validation rules
      if (fieldType === 'title' && value.length === 0) {
        this.showValidationMessage(field, 'Section title is required', 'error');
        return false;
      }
      
      if (fieldType === 'title' && value.length > 100) {
        this.showValidationMessage(field, 'Title is too long (max 100 characters)', 'warning');
      }
      
      return true;
    },

    showValidationMessage(field, message, type) {
      const messageEl = document.createElement('div');
      messageEl.className = `validation-message text-xs mt-1 ${
        type === 'error' ? 'text-red-600' : 'text-yellow-600'
      }`;
      messageEl.textContent = message;
      
      field.parentNode.appendChild(messageEl);
    },

    removeValidationMessage(field) {
      const existingMessage = field.parentNode.querySelector('.validation-message');
      if (existingMessage) {
        existingMessage.remove();
      }
    },

    markUnsavedChanges() {
      // Add visual indicator for unsaved changes
      document.body.classList.add('has-unsaved-changes');
      
      // Update save button if it exists
      const saveButton = document.querySelector('[phx-click="save_portfolio"]');
      if (saveButton) {
        saveButton.classList.add('has-changes');
      }
    },

    showAutoSaveIndicator() {
      const indicator = document.createElement('div');
      indicator.className = 'fixed bottom-4 right-4 bg-gray-800 text-white px-3 py-2 rounded-lg text-sm z-50';
      indicator.textContent = 'Auto-saved';
      
      document.body.appendChild(indicator);
      
      setTimeout(() => {
        indicator.style.opacity = '0';
        setTimeout(() => indicator.remove(), 300);
      }, 1500);
    },

    showSaveIndicator() {
      const indicator = document.createElement('div');
      indicator.className = 'fixed bottom-4 right-4 bg-green-600 text-white px-3 py-2 rounded-lg text-sm z-50 flex items-center space-x-2';
      indicator.innerHTML = `
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
        </svg>
        <span>Section Saved!</span>
      `;
      
      document.body.appendChild(indicator);
      
      setTimeout(() => {
        indicator.style.opacity = '0';
        setTimeout(() => indicator.remove(), 300);
      }, 2000);
    }
  },

  // ============================================================================
  // COPY TO CLIPBOARD FUNCTIONALITY
  // ============================================================================
  CopyToClipboard: {
    mounted() {
      this.el.addEventListener('click', () => {
        const textToCopy = this.el.dataset.copy || this.el.textContent;
        
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
  },

  // ============================================================================
  // MEDIA UPLOAD HANDLER
  // ============================================================================
  MediaUpload: {
    mounted() {
      console.log("📸 MediaUpload hook mounted");
      this.setupDropZone();
      this.setupFileInput();
    },

    setupDropZone() {
      this.el.addEventListener('dragover', (e) => {
        e.preventDefault();
        this.el.classList.add('drag-over');
      });

      this.el.addEventListener('dragleave', (e) => {
        e.preventDefault();
        this.el.classList.remove('drag-over');
      });

      this.el.addEventListener('drop', (e) => {
        e.preventDefault();
        this.el.classList.remove('drag-over');
        
        const files = Array.from(e.dataTransfer.files);
        this.handleFiles(files);
      });
    },

    setupFileInput() {
      const fileInput = this.el.querySelector('input[type="file"]');
      if (fileInput) {
        fileInput.addEventListener('change', (e) => {
          const files = Array.from(e.target.files);
          this.handleFiles(files);
        });
      }
    },

    handleFiles(files) {
      const validFiles = files.filter(file => {
        const isValidType = file.type.startsWith('image/') || 
                           file.type.startsWith('video/') || 
                           file.type === 'application/pdf';
        const isValidSize = file.size <= 10 * 1024 * 1024; // 10MB limit
        
        if (!isValidType) {
          this.showError(`${file.name} is not a supported file type`);
          return false;
        }
        
        if (!isValidSize) {
          this.showError(`${file.name} is too large (max 10MB)`);
          return false;
        }
        
        return true;
      });

      if (validFiles.length > 0) {
        this.pushEvent("files_selected", { 
          file_count: validFiles.length,
          files: validFiles.map(f => ({ name: f.name, size: f.size, type: f.type }))
        });
      }
    },

    showError(message) {
      const error = document.createElement('div');
      error.className = 'fixed top-4 right-4 bg-red-500 text-white px-4 py-2 rounded-lg shadow-lg z-50';
      error.textContent = message;
      document.body.appendChild(error);

      setTimeout(() => {
        error.style.opacity = '0';
        setTimeout(() => error.remove(), 300);
      }, 4000);
    }
  },
  
    const VideoPlayer = {
    mounted() {
      console.log("🎥 VideoPlayer hook mounted");
      this.setupVideoPlayers();
      this.setupVideoEvents();
    },

    updated() {
      this.setupVideoPlayers();
    },

    setupVideoPlayers() {
      // Setup click handlers for video thumbnails
      const videoThumbnails = this.el.querySelectorAll('.video-thumbnail');
      
      videoThumbnails.forEach(thumbnail => {
        thumbnail.addEventListener('click', (e) => {
          e.preventDefault();
          this.playVideo(thumbnail);
        });
      });
    },

    setupVideoEvents() {
      // Listen for video events from the server
      this.handleEvent("play_video", ({ block_id, video_url }) => {
        this.playVideoById(block_id, video_url);
      });

      this.handleEvent("pause_video", ({ block_id }) => {
        this.pauseVideoById(block_id);
      });
    },

    playVideo(thumbnailElement) {
      const videoUrl = thumbnailElement.dataset.videoUrl;
      const embedUrl = thumbnailElement.dataset.embedUrl;
      const blockId = thumbnailElement.closest('[data-block-id]')?.dataset.blockId;

      if (!blockId) return;

      if (embedUrl) {
        // External video (YouTube/Vimeo)
        this.replaceWithIframe(thumbnailElement, embedUrl, blockId);
      } else if (videoUrl) {
        // Uploaded video
        this.replaceWithVideoElement(thumbnailElement, videoUrl, blockId);
      }
    },

    playVideoById(blockId, videoUrl) {
      const blockElement = this.el.querySelector(`[data-block-id="${blockId}"]`);
      if (!blockElement) return;

      const thumbnail = blockElement.querySelector('.video-thumbnail');
      if (thumbnail) {
        this.playVideo(thumbnail);
      }
    },

    pauseVideoById(blockId) {
      const blockElement = this.el.querySelector(`[data-block-id="${blockId}"]`);
      if (!blockElement) return;

      // Find and pause any active video
      const video = blockElement.querySelector('video');
      const iframe = blockElement.querySelector('iframe');

      if (video) {
        video.pause();
      } else if (iframe) {
        // For external videos, we need to reload to stop
        const thumbnailHtml = this.createThumbnailFromIframe(iframe);
        iframe.parentNode.innerHTML = thumbnailHtml;
        this.setupVideoPlayers(); // Re-setup click handlers
      }
    },

    replaceWithIframe(thumbnailElement, embedUrl, blockId) {
      const container = thumbnailElement.parentNode;
      
      // Create iframe
      const iframe = document.createElement('iframe');
      iframe.id = `video-player-${blockId}`;
      iframe.src = embedUrl;
      iframe.className = 'w-full h-full';
      iframe.setAttribute('frameborder', '0');
      iframe.setAttribute('allow', 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture');
      iframe.setAttribute('allowfullscreen', '');

      // Replace thumbnail with iframe
      container.innerHTML = '';
      container.appendChild(iframe);

      // Add close button
      this.addCloseButton(container, blockId);
    },

    replaceWithVideoElement(thumbnailElement, videoUrl, blockId) {
      const container = thumbnailElement.parentNode;
      
      // Create video element
      const video = document.createElement('video');
      video.id = `video-player-${blockId}`;
      video.className = 'w-full h-full object-cover';
      video.controls = true;
      video.autoplay = true;
      video.src = videoUrl;

      // Replace thumbnail with video
      container.innerHTML = '';
      container.appendChild(video);

      // Add close button
      this.addCloseButton(container, blockId);

      // Auto-play
      video.play().catch(e => {
        console.log("Auto-play prevented:", e);
      });
    },

    addCloseButton(container, blockId) {
      const closeButton = document.createElement('button');
      closeButton.className = 'absolute top-4 right-4 z-10 bg-black bg-opacity-75 text-white p-2 rounded-full hover:bg-opacity-100 transition-opacity';
      closeButton.innerHTML = `
        <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
        </svg>
      `;
      
      closeButton.addEventListener('click', (e) => {
        e.stopPropagation();
        this.closeVideo(container, blockId);
      });

      container.style.position = 'relative';
      container.appendChild(closeButton);
    },

    closeVideo(container, blockId) {
      // Send pause event to LiveView
      this.pushEvent("pause_video", { block_id: blockId });
    },

    createThumbnailFromIframe(iframe) {
      // This would recreate the thumbnail HTML
      // For now, just reload the page section
      return `
        <div class="video-thumbnail relative w-full h-full cursor-pointer bg-gray-900 flex items-center justify-center">
          <div class="text-center text-white">
            <svg class="w-16 h-16 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
            </svg>
            <p>Click to play video</p>
          </div>
        </div>
      `;
    }
  }
};

// ============================================================================
// GLOBAL PORTFOLIO EDITOR UTILITIES
// ============================================================================
window.PortfolioEditor = {
  // Initialize all editor functionality
  init() {
    this.setupGlobalKeyboardShortcuts();
    this.setupBeforeUnloadWarning();
    this.setupGlobalEventListeners();
  },

  setupGlobalKeyboardShortcuts() {
    document.addEventListener('keydown', (e) => {
      // Only trigger if not in an input field
      if (e.target.matches('input, textarea, select')) return;
      
      // Global shortcuts
      if ((e.ctrlKey || e.metaKey) && e.key === 's') {
        e.preventDefault();
        this.triggerSave();
      }
      
      if ((e.ctrlKey || e.metaKey) && e.key === 'p') {
        e.preventDefault();
        this.togglePreview();
      }
      
      if ((e.ctrlKey || e.metaKey) && e.shiftKey && e.key === 'S') {
        e.preventDefault();
        this.triggerShare();
      }
    });
  },

  setupBeforeUnloadWarning() {
    window.addEventListener('beforeunload', (e) => {
      if (document.body.classList.contains('has-unsaved-changes')) {
        e.preventDefault();
        e.returnValue = 'You have unsaved changes. Are you sure you want to leave?';
        return e.returnValue;
      }
    });
  },

  setupGlobalEventListeners() {
    // Listen for Phoenix events
    window.addEventListener('phx:portfolio_saved', () => {
      document.body.classList.remove('has-unsaved-changes');
      this.showGlobalFeedback('Portfolio saved successfully!', 'success');
    });

    window.addEventListener('phx:section_added', (e) => {
      this.showGlobalFeedback(`${e.detail.title} section added!`, 'success');
    });

    window.addEventListener('phx:template_changed', (e) => {
      this.showGlobalFeedback(`Template changed to ${e.detail.template}`, 'info');
    });
  },

  triggerSave() {
    const saveButton = document.querySelector('[phx-click="save_portfolio"]');
    if (saveButton) {
      saveButton.click();
    }
  },

  togglePreview() {
    const previewButton = document.querySelector('[phx-click="toggle_preview"]');
    if (previewButton) {
      previewButton.click();
    }
  },

  triggerShare() {
    const shareButton = document.querySelector('[phx-click="share_portfolio"]');
    if (shareButton) {
      shareButton.click();
    }
  },

  showGlobalFeedback(message, type = 'info') {
    const colors = {
      success: 'bg-green-500 text-white',
      error: 'bg-red-500 text-white', 
      info: 'bg-blue-500 text-white',
      warning: 'bg-yellow-500 text-black'
    };

    const feedback = document.createElement('div');
    feedback.className = `fixed top-4 left-1/2 transform -translate-x-1/2 px-6 py-3 rounded-lg shadow-lg z-50 transition-all font-medium ${colors[type]}`;
    feedback.textContent = message;
    
    document.body.appendChild(feedback);

    // Animate in
    setTimeout(() => {
      feedback.style.opacity = '1';
      feedback.style.transform = 'translate(-50%, 0)';
    }, 10);

    // Animate out
    setTimeout(() => {
      feedback.style.opacity = '0';
      feedback.style.transform = 'translate(-50%, -20px)';
      setTimeout(() => feedback.remove(), 300);
    }, 3000);
  },

  // Utility functions for section management
  scrollToSection(sectionId) {
    const section = document.getElementById(`section-${sectionId}`);
    if (section) {
      section.scrollIntoView({ behavior: 'smooth', block: 'center' });
      section.classList.add('highlight-section');
      setTimeout(() => section.classList.remove('highlight-section'), 2000);
    }
  },

  focusSection(sectionId) {
    const editButton = document.querySelector(`[phx-value-section-id="${sectionId}"][phx-click="edit_section"]`);
    if (editButton) {
      editButton.click();
    }
  },

  // Animation utilities
  animateElement(element, animation) {
    return new Promise((resolve) => {
      element.classList.add(animation);
      element.addEventListener('animationend', () => {
        element.classList.remove(animation);
        resolve();
      }, { once: true });
    });
  }
};

// ============================================================================
// CUSTOM CSS ANIMATIONS (inject into head)
// ============================================================================
const portfolioEditorStyles = `
<style id="portfolio-editor-styles">
  /* Sortable animations */
  .sortable-ghost {
    opacity: 0.4;
    transform: scale(0.95);
  }
  
  .sortable-chosen {
    transform: scale(1.02);
    box-shadow: 0 8px 25px rgba(0, 0, 0, 0.15);
  }
  
  .sortable-drag {
    transform: rotate(2deg);
  }
  
  .sorting-active .section-card:not(.sortable-chosen) {
    opacity: 0.7;
  }
  
  .drag-in-progress {
    cursor: grabbing !important;
  }
  
  .drag-handle {
    cursor: grab;
    transition: all 0.2s ease;
  }
  
  .drag-handle:hover {
    color: #4f46e5;
    transform: scale(1.1);
  }
  
  .drag-handle:active {
    cursor: grabbing;
  }
  
  /* Section animations */
  .section-card {
    transition: all 0.3s ease;
  }
  
  .section-card:hover {
    transform: translateY(-2px);
  }
  
  .highlight-section {
    animation: highlightPulse 2s ease-in-out;
  }
  
  @keyframes highlightPulse {
    0%, 100% { 
      border-color: #e5e7eb; 
      box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
    }
    50% { 
      border-color: #3b82f6; 
      box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
    }
  }
  
  /* Preview animations */
  .template-changing {
    animation: templateChange 0.5s ease-in-out;
  }
  
  @keyframes templateChange {
    0% { transform: scale(1); }
    50% { transform: scale(0.95); opacity: 0.8; }
    100% { transform: scale(1); }
  }
  
  /* Button feedback animations */
  .has-changes {
    animation: pulseGreen 2s infinite;
  }
  
  @keyframes pulseGreen {
    0%, 100% { box-shadow: 0 0 0 0 rgba(34, 197, 94, 0.4); }
    50% { box-shadow: 0 0 0 8px rgba(34, 197, 94, 0); }
  }
  
  /* Unsaved changes indicator */
  .has-unsaved-changes::before {
    content: '';
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    height: 3px;
    background: linear-gradient(90deg, #f59e0b, #ef4444);
    z-index: 9999;
    animation: unsavedPulse 3s infinite;
  }
  
  @keyframes unsavedPulse {
    0%, 100% { opacity: 0.6; }
    50% { opacity: 1; }
  }
  
  /* Media upload animations */
  .drag-over {
    border-color: #3b82f6 !important;
    background-color: #eff6ff !important;
    transform: scale(1.02);
  }
  
  /* Loading states */
  .loading-overlay {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(255, 255, 255, 0.8);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 10;
  }
  
  .loading-spinner {
    width: 40px;
    height: 40px;
    border: 4px solid #e5e7eb;
    border-top: 4px solid #3b82f6;
    border-radius: 50%;
    animation: spin 1s linear infinite;
  }
  
  @keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }
  
  /* Responsive improvements */
  @media (max-width: 768px) {
    .section-card {
      margin-bottom: 1rem;
    }
    
    .drag-handle {
      padding: 0.75rem;
    }
    
    .section-header {
      flex-direction: column;
      align-items: flex-start;
      gap: 1rem;
    }
    
    .section-actions {
      flex-wrap: wrap;
      gap: 0.5rem;
    }
  }
  
  /* Accessibility improvements */
  .drag-handle:focus {
    outline: 2px solid #3b82f6;
    outline-offset: 2px;
  }
  
  .section-card:focus-within {
    ring: 2px;
    ring-color: #3b82f6;
    ring-opacity: 0.5;
  }
  
  /* Dark mode support (if implemented) */
  @media (prefers-color-scheme: dark) {
    .section-card {
      background-color: #1f2937;
      border-color: #374151;
      color: #f9fafb;
    }
    
    .loading-overlay {
      background: rgba(17, 24, 39, 0.8);
    }
  }
</style>
`;

// ============================================================================
// INITIALIZATION
// ============================================================================
document.addEventListener('DOMContentLoaded', function() {
  // Inject custom styles
  if (!document.getElementById('portfolio-editor-styles')) {
    document.head.insertAdjacentHTML('beforeend', portfolioEditorStyles);
  }
  
  // Initialize global portfolio editor
  window.PortfolioEditor.init();
  
  console.log('🚀 Portfolio Editor initialized successfully');
});

// ============================================================================
// CUSTOM FIELDS DYNAMIC MANAGEMENT
// ============================================================================

const CustomFieldsManager = {
  init() {
    this.setupFieldTypeHandlers();
    this.setupValidationRules();
    this.setupDynamicFields();
  },

  setupFieldTypeHandlers() {
    document.addEventListener('change', (e) => {
      if (e.target.matches('select[name="field_type"]')) {
        this.handleFieldTypeChange(e.target);
      }
    });
  },

  handleFieldTypeChange(selectElement) {
    const fieldType = selectElement.value;
    const form = selectElement.closest('form');
    const validationSection = form.querySelector('.validation-rules-section');
    
    if (validationSection) {
      this.updateValidationRulesSection(validationSection, fieldType);
    }
  },

  updateValidationRulesSection(section, fieldType) {
    // Clear existing validation rules
    section.innerHTML = '';
    
    const validationHTML = this.getValidationRulesHTML(fieldType);
    section.innerHTML = validationHTML;
  },

  getValidationRulesHTML(fieldType) {
    switch (fieldType) {
      case 'text':
        return `
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Minimum Length</label>
              <input type="number" name="validation_rules[min_length]" min="0" 
                     class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Maximum Length</label>
              <input type="number" name="validation_rules[max_length]" min="1" 
                     class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
            </div>
          </div>
          <div class="mt-4">
            <label class="block text-sm font-medium text-gray-700 mb-2">Pattern (Regex)</label>
            <input type="text" name="validation_rules[pattern]" placeholder="e.g., ^[A-Z].*" 
                   class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
            <p class="mt-1 text-xs text-gray-500">Regular expression pattern (optional)</p>
          </div>
        `;
      
      case 'number':
        return `
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Minimum Value</label>
              <input type="number" name="validation_rules[min_value]" step="any" 
                     class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Maximum Value</label>
              <input type="number" name="validation_rules[max_value]" step="any" 
                     class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
            </div>
          </div>
          <div class="mt-4 flex items-center">
            <input type="checkbox" name="validation_rules[integer_only]" 
                   class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded" />
            <label class="ml-2 text-sm text-gray-700">Integer values only</label>
          </div>
        `;
      
      case 'list':
        return `
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Minimum Items</label>
              <input type="number" name="validation_rules[min_items]" min="0" 
                     class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Maximum Items</label>
              <input type="number" name="validation_rules[max_items]" min="1" 
                     class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
            </div>
          </div>
          <div class="mt-4">
            <label class="block text-sm font-medium text-gray-700 mb-2">Allowed Values</label>
            <textarea name="validation_rules[allowed_values]" rows="3" placeholder="One value per line" 
                      class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"></textarea>
            <p class="mt-1 text-xs text-gray-500">Enter one allowed value per line (optional)</p>
          </div>
        `;
      
      default:
        return '<p class="text-sm text-gray-500">No additional validation options for this field type.</p>';
    }
  },

  setupValidationRules() {
    document.addEventListener('input', (e) => {
      if (e.target.matches('input[name*="validation_rules"], textarea[name*="validation_rules"]')) {
        this.validateRuleInput(e.target);
      }
    });
  },

  validateRuleInput(input) {
    const ruleName = input.name.match(/validation_rules\[([^\]]+)\]/);
    if (!ruleName) return;

    const rule = ruleName[1];
    const value = input.value;

    // Remove previous validation messages
    const existingMessage = input.parentNode.querySelector('.validation-message');
    if (existingMessage) {
      existingMessage.remove();
    }

    let isValid = true;
    let message = '';

    switch (rule) {
      case 'min_length':
      case 'max_length':
      case 'min_items':
      case 'max_items':
        if (value && !Number.isInteger(Number(value))) {
          isValid = false;
          message = 'Must be a whole number';
        }
        break;
      
      case 'min_value':
      case 'max_value':
        if (value && isNaN(Number(value))) {
          isValid = false;
          message = 'Must be a valid number';
        }
        break;
      
      case 'pattern':
        if (value) {
          try {
            new RegExp(value);
          } catch (e) {
            isValid = false;
            message = 'Invalid regular expression';
          }
        }
        break;
    }

    if (!isValid) {
      const messageEl = document.createElement('p');
      messageEl.className = 'validation-message text-xs text-red-600 mt-1';
      messageEl.textContent = message;
      input.parentNode.appendChild(messageEl);
      input.classList.add('border-red-300');
    } else {
      input.classList.remove('border-red-300');
    }
  },

  setupDynamicFields() {
    // Handle dynamic addition/removal of field values
    document.addEventListener('click', (e) => {
      if (e.target.matches('[data-action="add-field-value"]')) {
        this.addFieldValue(e.target);
      } else if (e.target.matches('[data-action="remove-field-value"]')) {
        this.removeFieldValue(e.target);
      }
    });
  },

  addFieldValue(button) {
    const container = button.closest('.field-values-container');
    const template = container.querySelector('.field-value-template');
    if (template) {
      const clone = template.cloneNode(true);
      clone.classList.remove('field-value-template', 'hidden');
      clone.classList.add('field-value-item');
      
      // Update field names with unique indices
      const index = container.querySelectorAll('.field-value-item').length;
      const inputs = clone.querySelectorAll('input, textarea, select');
      inputs.forEach(input => {
        const oldName = input.getAttribute('name');
        if (oldName) {
          input.setAttribute('name', oldName.replace(/\[\d*\]/, `[${index}]`));
        }
      });
      
      button.parentNode.insertBefore(clone, button);
    }
  },

  removeFieldValue(button) {
    const item = button.closest('.field-value-item');
    if (item) {
      item.remove();
    }
  }
};

// Add to the main PortfolioEditor initialization
const originalInit = window.PortfolioEditor.init;
window.PortfolioEditor.init = function() {
  originalInit.call(this);
  CustomFieldsManager.init();
  console.log('🎯 Custom Fields Manager initialized');
};

// Export CustomFieldsManager for external use
window.CustomFieldsManager = CustomFieldsManager;

// Export hooks for Phoenix LiveView
export default PortfolioEditorHooks;