// assets/js/hooks/media_management.js - PHASE 4 FIXED VERSION
/**
 * Phase 4: Enhanced media management hooks with drag-and-drop functionality,
 * upload progress tracking, and seamless section-media integration.
 */

export const MediaManagement = {
  /**
   * Enhanced sortable media hook with improved drag feedback and error handling
   */
  SortableMedia: {
    mounted() {
      this.initializeSortable();
      this.setupEventListeners();
    },

    updated() {
      this.destroySortable();
      this.initializeSortable();
    },

    destroyed() {
      this.destroySortable();
    },

    initializeSortable() {
      if (typeof Sortable === 'undefined') {
        console.warn('Sortable.js not loaded, skipping media sorting functionality');
        return;
      }

      const element = this.el;
      const sectionId = element.dataset.sectionId;

      if (!sectionId) {
        console.error('Section ID not found for sortable media');
        return;
      }

      this.sortable = Sortable.create(element, {
        group: `section-media-${sectionId}`,
        animation: 200,
        ghostClass: 'media-ghost',
        chosenClass: 'media-chosen',
        dragClass: 'media-drag',
        forceFallback: true,
        fallbackClass: 'media-sorting-active',
        fallbackOnBody: true,
        swapThreshold: 0.65,
        
        onStart: (evt) => {
          element.classList.add('sorting-active');
          this.showReorderFeedback();
        },

        onEnd: (evt) => {
          element.classList.remove('sorting-active');
          this.hideReorderFeedback();
          
          if (evt.oldIndex !== evt.newIndex) {
            this.updateMediaOrder(evt);
          }
        },

        onMove: (evt) => {
          // Add visual feedback during drag
          const related = evt.related;
          if (related) {
            related.classList.add('drop-zone-active');
            setTimeout(() => related.classList.remove('drop-zone-active'), 100);
          }
        }
      });
    },

    destroySortable() {
      if (this.sortable) {
        this.sortable.destroy();
        this.sortable = null;
      }
    },

    updateMediaOrder(evt) {
      const mediaItems = Array.from(this.el.querySelectorAll('[data-media-id]'));
      const orderedIds = mediaItems.map(item => item.dataset.mediaId);
      const sectionId = this.el.dataset.sectionId;

      // Send reorder event to LiveView
      this.pushEvent('reorder_media', {
        section_id: sectionId,
        media_ids: orderedIds,
        old_index: evt.oldIndex,
        new_index: evt.newIndex
      });

      // Show completion feedback
      this.showCompletionFeedback();
    },

    showReorderFeedback() {
      const feedback = document.createElement('div');
      feedback.className = 'media-reorder-feedback';
      feedback.innerHTML = `
        <div class="bg-blue-500 text-white px-4 py-2 rounded-lg shadow-lg">
          <div class="flex items-center space-x-2">
            <svg class="w-4 h-4 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 8h16M4 16h16"/>
            </svg>
            <span>Reordering media...</span>
          </div>
        </div>
      `;
      document.body.appendChild(feedback);
      
      setTimeout(() => {
        feedback.style.opacity = '1';
        feedback.style.transform = 'translateY(0)';
      }, 10);
      
      this.feedbackElement = feedback;
    },

    hideReorderFeedback() {
      if (this.feedbackElement) {
        this.feedbackElement.style.opacity = '0';
        this.feedbackElement.style.transform = 'translateY(-20px)';
        setTimeout(() => {
          if (this.feedbackElement) {
            this.feedbackElement.remove();
            this.feedbackElement = null;
          }
        }, 300);
      }
    },

    showCompletionFeedback() {
      const sectionId = this.el.dataset.sectionId;
      
      // Dispatch custom event for completion
      window.dispatchEvent(new CustomEvent('phx:media-reorder-complete', {
        detail: { section_id: sectionId }
      }));
    },

    setupEventListeners() {
      // Handle upload progress updates
      this.handleEvent('upload-progress', (data) => {
        this.updateUploadProgress(data);
      });

      // Handle upload completion
      this.handleEvent('upload-complete', (data) => {
        this.showUploadComplete(data);
      });

      // Handle upload errors
      this.handleEvent('upload-error', (data) => {
        this.showUploadError(data);
      });
    },

    updateUploadProgress(data) {
      const { ref, progress } = data;
      const progressBar = document.querySelector(`[data-upload-ref="${ref}"] .upload-progress-bar`);
      const progressText = document.querySelector(`[data-upload-ref="${ref}"] .upload-progress-text`);
      
      if (progressBar) {
        progressBar.style.width = `${progress}%`;
      }
      
      if (progressText) {
        progressText.textContent = `${progress}%`;
      }
    },

    showUploadComplete(data) {
      const { ref, media } = data;
      const uploadItem = document.querySelector(`[data-upload-ref="${ref}"]`);
      
      if (uploadItem) {
        uploadItem.classList.add('upload-complete');
        setTimeout(() => uploadItem.remove(), 2000);
      }

      // Refresh media grid
      this.pushEvent('refresh_section_media', {});
    },

    showUploadError(data) {
      const { ref, error } = data;
      const uploadItem = document.querySelector(`[data-upload-ref="${ref}"]`);
      
      if (uploadItem) {
        uploadItem.classList.add('upload-error');
        const errorMsg = uploadItem.querySelector('.upload-error-message');
        if (errorMsg) {
          errorMsg.textContent = error;
          errorMsg.style.display = 'block';
        }
      }
    }
  },

  /**
   * Enhanced drag-and-drop file upload with better visual feedback
   */
  FileDropZone: {
    mounted() {
      this.setupDropZone();
      this.setupFileInput();
    },

    destroyed() {
      this.cleanupDropZone();
    },

    setupDropZone() {
      const dropZone = this.el;
      
      // Prevent default drag behaviors
      ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
        dropZone.addEventListener(eventName, this.preventDefaults.bind(this), false);
        document.body.addEventListener(eventName, this.preventDefaults.bind(this), false);
      });

      // Highlight drop zone when dragging over it
      ['dragenter', 'dragover'].forEach(eventName => {
        dropZone.addEventListener(eventName, this.highlight.bind(this), false);
      });

      ['dragleave', 'drop'].forEach(eventName => {
        dropZone.addEventListener(eventName, this.unhighlight.bind(this), false);
      });

      // Handle dropped files
      dropZone.addEventListener('drop', this.handleDrop.bind(this), false);
    },

    cleanupDropZone() {
      const dropZone = this.el;
      
      ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
        dropZone.removeEventListener(eventName, this.preventDefaults);
        document.body.removeEventListener(eventName, this.preventDefaults);
      });

      ['dragenter', 'dragover'].forEach(eventName => {
        dropZone.removeEventListener(eventName, this.highlight);
      });

      ['dragleave', 'drop'].forEach(eventName => {
        dropZone.removeEventListener(eventName, this.unhighlight);
      });

      dropZone.removeEventListener('drop', this.handleDrop);
    },

    setupFileInput() {
      const fileInput = this.el.querySelector('input[type="file"]');
      if (fileInput) {
        fileInput.addEventListener('change', this.handleFileSelect.bind(this));
      }
    },

    preventDefaults(e) {
      e.preventDefault();
      e.stopPropagation();
    },

    highlight() {
      this.el.classList.add('drag-over');
    },

    unhighlight() {
      this.el.classList.remove('drag-over');
    },

    handleDrop(e) {
      const dt = e.dataTransfer;
      const files = dt.files;
      this.handleFiles(files);
    },

    handleFileSelect(e) {
      const files = e.target.files;
      this.handleFiles(files);
    },

    handleFiles(files) {
      if (files.length === 0) return;

      // Validate files before processing
      const validFiles = Array.from(files).filter(file => this.validateFile(file));
      
      if (validFiles.length === 0) {
        this.showError('No valid files selected');
        return;
      }

      if (validFiles.length !== files.length) {
        this.showWarning(`${files.length - validFiles.length} file(s) were rejected`);
      }

      // Start upload process
      this.startUpload(validFiles);
    },

    validateFile(file) {
      const maxSize = 50 * 1024 * 1024; // 50MB
      const allowedTypes = [
        'image/jpeg', 'image/png', 'image/gif', 'image/webp',
        'video/mp4', 'video/webm', 'video/mov',
        'audio/mp3', 'audio/wav', 'audio/ogg',
        'application/pdf', 'text/plain',
        'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      ];

      if (file.size > maxSize) {
        this.showError(`File "${file.name}" is too large (max 50MB)`);
        return false;
      }

      if (!allowedTypes.includes(file.type)) {
        this.showError(`File type "${file.type}" is not supported`);
        return false;
      }

      return true;
    },

    startUpload(files) {
      // Notify LiveView about upload start
      this.pushEvent('start_upload', {
        files: Array.from(files).map(file => ({
          name: file.name,
          size: file.size,
          type: file.type,
          lastModified: file.lastModified
        }))
      });

      // Show upload progress UI
      this.showUploadProgress(files);
    },

    showUploadProgress(files) {
      // Create upload progress container if it doesn't exist
      let progressContainer = document.getElementById('upload-progress-container');
      if (!progressContainer) {
        progressContainer = document.createElement('div');
        progressContainer.id = 'upload-progress-container';
        progressContainer.className = 'fixed top-4 right-4 z-50 space-y-2 max-w-sm';
        document.body.appendChild(progressContainer);
      }

      // Add progress item for each file
      files.forEach((file, index) => {
        const progressItem = this.createProgressItem(file, index);
        progressContainer.appendChild(progressItem);
      });
    },

    createProgressItem(file, index) {
      const item = document.createElement('div');
      item.className = 'bg-white border border-gray-200 rounded-lg p-4 shadow-lg transform translate-x-full transition-transform duration-300';
      item.dataset.uploadIndex = index;
      
      item.innerHTML = `
        <div class="flex items-center space-x-3">
          <div class="flex-shrink-0">
            <div class="w-8 h-8 bg-blue-100 rounded-lg flex items-center justify-center">
              <svg class="w-4 h-4 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
              </svg>
            </div>
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-sm font-medium text-gray-900 truncate">${file.name}</p>
            <p class="text-xs text-gray-500">${this.formatFileSize(file.size)}</p>
            <div class="mt-2">
              <div class="bg-gray-200 rounded-full h-2">
                <div class="upload-progress-bar bg-blue-600 h-2 rounded-full transition-all duration-300" style="width: 0%"></div>
              </div>
              <div class="mt-1 flex justify-between text-xs text-gray-500">
                <span class="upload-progress-text">0%</span>
                <span class="upload-status">Uploading...</span>
              </div>
            </div>
          </div>
          <button class="upload-cancel-btn flex-shrink-0 p-1 text-gray-400 hover:text-red-500 transition-colors">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>
        <div class="upload-error-message mt-2 text-sm text-red-600 hidden"></div>
      `;

      // Add cancel functionality
      const cancelBtn = item.querySelector('.upload-cancel-btn');
      cancelBtn.addEventListener('click', () => {
        this.cancelUpload(index);
        item.remove();
      });

      // Animate in
      setTimeout(() => {
        item.classList.remove('translate-x-full');
      }, 10);

      return item;
    },

    cancelUpload(index) {
      this.pushEvent('cancel_upload', { index });
    },

    formatFileSize(bytes) {
      if (bytes === 0) return '0 Bytes';
      const k = 1024;
      const sizes = ['Bytes', 'KB', 'MB', 'GB'];
      const i = Math.floor(Math.log(bytes) / Math.log(k));
      return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
    },

    showError(message) {
      this.showNotification(message, 'error');
    },

    showWarning(message) {
      this.showNotification(message, 'warning');
    },

    showNotification(message, type = 'info') {
      const notification = document.createElement('div');
      notification.className = `toast-notification fixed top-4 right-4 z-50 max-w-sm opacity-0 transform translate-x-full transition-all duration-300`;
      
      const bgColor = {
        'info': 'bg-blue-500',
        'warning': 'bg-yellow-500',
        'error': 'bg-red-500',
        'success': 'bg-green-500'
      }[type] || 'bg-gray-500';

      notification.innerHTML = `
        <div class="${bgColor} text-white px-4 py-3 rounded-lg shadow-lg">
          <div class="flex items-center space-x-3">
            <svg class="w-5 h-5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              ${type === 'error' ? 
                '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.732-.833-2.5 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z"/>' :
                '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>'
              }
            </svg>
            <span class="flex-1">${message}</span>
            <button class="flex-shrink-0 ml-2 p-1 hover:bg-white hover:bg-opacity-20 rounded transition-colors" onclick="this.closest('.toast-notification').remove()">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>
        </div>
      `;

      document.body.appendChild(notification);

      // Animate in
      setTimeout(() => {
        notification.classList.remove('opacity-0', 'translate-x-full');
      }, 10);

      // Auto remove after delay
      setTimeout(() => {
        notification.classList.add('opacity-0', 'translate-x-full');
        setTimeout(() => notification.remove(), 300);
      }, type === 'error' ? 7000 : 4000);
    }
  },

  /**
   * Enhanced media modal with keyboard navigation and preview controls
   */
  MediaModal: {
    mounted() {
      this.setupKeyboardNavigation();
      this.setupModalInteractions();
      this.preventBodyScroll();
    },

    destroyed() {
      this.restoreBodyScroll();
      this.removeKeyboardNavigation();
    },

    setupKeyboardNavigation() {
      this.keyboardHandler = (e) => {
        switch (e.key) {
          case 'Escape':
            this.closeModal();
            break;
          case 'ArrowLeft':
            this.navigateMedia('previous');
            break;
          case 'ArrowRight':
            this.navigateMedia('next');
            break;
          case 'Delete':
          case 'Backspace':
            if (e.target.tagName !== 'INPUT' && e.target.tagName !== 'TEXTAREA') {
              this.deleteCurrentMedia();
            }
            break;
        }
      };

      document.addEventListener('keydown', this.keyboardHandler);
    },

    removeKeyboardNavigation() {
      if (this.keyboardHandler) {
        document.removeEventListener('keydown', this.keyboardHandler);
        this.keyboardHandler = null;
      }
    },

    setupModalInteractions() {
      // Setup modal backdrop click
      this.el.addEventListener('click', (e) => {
        if (e.target === this.el) {
          this.closeModal();
        }
      });

      // Setup media selection
      this.setupMediaSelection();
    },

    setupMediaSelection() {
      const mediaItems = this.el.querySelectorAll('[data-media-id]');
      mediaItems.forEach(item => {
        item.addEventListener('click', (e) => {
          if (!e.target.closest('button')) {
            this.toggleMediaSelection(item.dataset.mediaId);
          }
        });
      });
    },

    toggleMediaSelection(mediaId) {
      this.pushEvent('toggle_media_selection', { media_id: mediaId });
    },

    navigateMedia(direction) {
      this.pushEvent('navigate_media', { direction });
    },

    deleteCurrentMedia() {
      this.pushEvent('delete_current_media', {});
    },

    closeModal() {
      this.pushEvent('hide_media_modal', {});
    },

    preventBodyScroll() {
      document.body.style.overflow = 'hidden';
    },

    restoreBodyScroll() {
      document.body.style.overflow = '';
    }
  },

  /**
   * Enhanced media preview with zoom and pan capabilities
   */
  MediaPreview: {
    mounted() {
      this.setupPreviewControls();
      this.setupKeyboardShortcuts();
      this.initializeImageZoom();
    },

    destroyed() {
      this.cleanupPreviewControls();
    },

    setupPreviewControls() {
      const previewElement = this.el.querySelector('.media-preview-content');
      if (previewElement && previewElement.tagName === 'IMG') {
        this.setupImageControls(previewElement);
      }
    },

    setupImageControls(img) {
      let scale = 1;
      let translateX = 0;
      let translateY = 0;
      let isDragging = false;
      let lastX = 0;
      let lastY = 0;

      // Zoom with mouse wheel
      this.el.addEventListener('wheel', (e) => {
        e.preventDefault();
        const delta = e.deltaY > 0 ? 0.9 : 1.1;
        scale = Math.max(0.5, Math.min(5, scale * delta));
        this.updateTransform(img, scale, translateX, translateY);
      });

      // Pan with mouse drag
      img.addEventListener('mousedown', (e) => {
        if (scale > 1) {
          isDragging = true;
          lastX = e.clientX;
          lastY = e.clientY;
          img.style.cursor = 'grabbing';
        }
      });

      document.addEventListener('mousemove', (e) => {
        if (isDragging) {
          const deltaX = e.clientX - lastX;
          const deltaY = e.clientY - lastY;
          translateX += deltaX;
          translateY += deltaY;
          lastX = e.clientX;
          lastY = e.clientY;
          this.updateTransform(img, scale, translateX, translateY);
        }
      });

      document.addEventListener('mouseup', () => {
        isDragging = false;
        img.style.cursor = scale > 1 ? 'grab' : 'default';
      });

      // Double-click to reset
      img.addEventListener('dblclick', () => {
        scale = 1;
        translateX = 0;
        translateY = 0;
        this.updateTransform(img, scale, translateX, translateY);
      });

      // Store references for cleanup
      this.zoomControls = { scale, translateX, translateY, isDragging };
    },

    updateTransform(img, scale, translateX, translateY) {
      img.style.transform = `scale(${scale}) translate(${translateX}px, ${translateY}px)`;
      img.style.cursor = scale > 1 ? 'grab' : 'default';
    },

    setupKeyboardShortcuts() {
      this.previewKeyHandler = (e) => {
        switch (e.key) {
          case 'Escape':
            this.closePreview();
            break;
          case '=':
          case '+':
            this.zoomIn();
            break;
          case '-':
            this.zoomOut();
            break;
          case '0':
            this.resetZoom();
            break;
        }
      };

      document.addEventListener('keydown', this.previewKeyHandler);
    },

    cleanupPreviewControls() {
      if (this.previewKeyHandler) {
        document.removeEventListener('keydown', this.previewKeyHandler);
        this.previewKeyHandler = null;
      }
    },

    initializeImageZoom() {
      const img = this.el.querySelector('img');
      if (img) {
        img.style.transition = 'transform 0.3s ease';
        img.style.cursor = 'default';
      }
    },

    zoomIn() {
      if (this.zoomControls) {
        this.zoomControls.scale = Math.min(5, this.zoomControls.scale * 1.2);
        const img = this.el.querySelector('img');
        if (img) {
          this.updateTransform(img, this.zoomControls.scale, this.zoomControls.translateX, this.zoomControls.translateY);
        }
      }
    },

    zoomOut() {
      if (this.zoomControls) {
        this.zoomControls.scale = Math.max(0.5, this.zoomControls.scale * 0.8);
        const img = this.el.querySelector('img');
        if (img) {
          this.updateTransform(img, this.zoomControls.scale, this.zoomControls.translateX, this.zoomControls.translateY);
        }
      }
    },

    resetZoom() {
      if (this.zoomControls) {
        this.zoomControls.scale = 1;
        this.zoomControls.translateX = 0;
        this.zoomControls.translateY = 0;
        const img = this.el.querySelector('img');
        if (img) {
          this.updateTransform(img, 1, 0, 0);
        }
      }
    },

    closePreview() {
      this.pushEvent('hide_media_preview', {});
    }
  }
};

// Export individual hooks for Phoenix LiveView
export const SortableMedia = MediaManagement.SortableMedia;
export const FileDropZone = MediaManagement.FileDropZone;
export const MediaModal = MediaManagement.MediaModal;
export const MediaPreview = MediaManagement.MediaPreview;