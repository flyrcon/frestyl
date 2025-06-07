// assets/js/hooks/text_editor.js - Enhanced Text Editor with Mobile Support

export const TextEditor = {
  mounted() {
    this.initializeEditor();
    this.setupMobileOptimizations();
    this.setupCollaborativeFeatures();
    this.setupVoiceInput();
    this.setupGestureControls();
    this.setupOfflineSync();
  },

  updated() {
    this.handleRemoteUpdates();
  },

  destroyed() {
    this.cleanup();
  },

  initializeEditor() {
    this.editorEl = this.el;
    this.documentId = this.el.dataset.documentId;
    this.isMobile = this.el.dataset.mobileOptimized === "true";
    
    // Initialize state
    this.currentBlock = null;
    this.collaborativeCursors = new Map();
    this.pendingOperations = [];
    this.voiceRecording = false;
    this.offlineQueue = [];

    // Setup event listeners
    this.setupEventListeners();
    this.initializeAutoSave();
    
    console.log("Text Editor initialized", {
      documentId: this.documentId,
      isMobile: this.isMobile
    });
  },

  setupEventListeners() {
    // Block activation and content editing
    this.editorEl.addEventListener('click', (e) => {
      const blockContainer = e.target.closest('.block-container');
      if (blockContainer) {
        this.activateBlock(blockContainer);
      }
    });

    // Auto-resize textareas
    this.editorEl.addEventListener('input', (e) => {
      if (e.target.tagName === 'TEXTAREA') {
        this.autoResizeTextarea(e.target);
      }
    });

    // Enhanced keyboard shortcuts
    this.editorEl.addEventListener('keydown', (e) => {
      this.handleKeyboardShortcuts(e);
    });

    // Content changes with debouncing
    this.editorEl.addEventListener('input', this.debounce((e) => {
      if (e.target.matches('textarea, input[type="text"]')) {
        this.handleContentChange(e.target);
      }
    }, 300));

    // Selection changes for collaborative cursors
    document.addEventListener('selectionchange', () => {
      this.handleSelectionChange();
    });
  },

  setupMobileOptimizations() {
    if (!this.isMobile) return;

    // Touch event handling
    this.setupTouchEvents();
    
    // Virtual keyboard handling
    this.setupVirtualKeyboard();
    
    // Performance optimizations
    this.setupMobilePerformance();

    // Smart toolbar positioning
    this.setupSmartToolbar();
  },

  setupTouchEvents() {
    let touchStartY = 0;
    let touchStartTime = 0;

    this.editorEl.addEventListener('touchstart', (e) => {
      touchStartY = e.touches[0].clientY;
      touchStartTime = Date.now();
    });

    this.editorEl.addEventListener('touchend', (e) => {
      const touchEndY = e.changedTouches[0].clientY;
      const touchDuration = Date.now() - touchStartTime;
      const deltaY = touchStartY - touchEndY;

      // Long press for context menu
      if (touchDuration > 500 && Math.abs(deltaY) < 10) {
        this.showMobileContextMenu(e.changedTouches[0]);
      }

      // Swipe gestures
      if (Math.abs(deltaY) > 50 && touchDuration < 300) {
        if (deltaY > 0) {
          this.pushEvent("mobile_swipe", { direction: "up" });
        } else {
          this.pushEvent("mobile_swipe", { direction: "down" });
        }
      }
    });
  },

  setupVirtualKeyboard() {
    // Handle virtual keyboard showing/hiding
    const viewport = window.visualViewport;
    
    if (viewport) {
      viewport.addEventListener('resize', () => {
        this.adjustForVirtualKeyboard(viewport.height);
      });
    } else {
      // Fallback for older browsers
      window.addEventListener('resize', () => {
        this.adjustForVirtualKeyboard(window.innerHeight);
      });
    }
  },

  adjustForVirtualKeyboard(viewportHeight) {
    const screenHeight = screen.height;
    const isKeyboardVisible = viewportHeight < screenHeight * 0.75;
    
    if (isKeyboardVisible) {
      // Keyboard is visible - adjust UI
      this.editorEl.style.paddingBottom = '120px';
      this.scrollToActiveBlock();
    } else {
      // Keyboard hidden - restore UI
      this.editorEl.style.paddingBottom = '20px';
    }
  },

  setupSmartToolbar() {
    // Auto-hide/show toolbar based on scroll and focus
    let lastScrollY = window.scrollY;
    let scrollDirection = 'up';

    window.addEventListener('scroll', () => {
      const currentScrollY = window.scrollY;
      scrollDirection = currentScrollY > lastScrollY ? 'down' : 'up';
      lastScrollY = currentScrollY;

      const toolbar = this.editorEl.querySelector('.mobile-toolbar');
      if (toolbar) {
        if (scrollDirection === 'down' && !this.isInputFocused()) {
          toolbar.style.transform = 'translateY(100%)';
        } else {
          toolbar.style.transform = 'translateY(0)';
        }
      }
    });
  },

  setupCollaborativeFeatures() {
    // Real-time cursor tracking
    this.cursorUpdateInterval = setInterval(() => {
      this.broadcastCursorPosition();
    }, 1000);

    // Conflict detection and resolution
    this.conflictResolution = new CollaborativeConflictResolver();
    
    // Operation transformation
    this.operationalTransform = new OperationalTransformEngine();
  },

  setupVoiceInput() {
    if (!('webkitSpeechRecognition' in window) && !('SpeechRecognition' in window)) {
      console.log('Speech recognition not supported');
      return;
    }

    this.speechRecognition = new (window.SpeechRecognition || window.webkitSpeechRecognition)();
    this.speechRecognition.continuous = true;
    this.speechRecognition.interimResults = true;
    this.speechRecognition.lang = 'en-US';

    this.speechRecognition.onresult = (event) => {
      this.handleVoiceResult(event);
    };

    this.speechRecognition.onerror = (event) => {
      console.error('Speech recognition error:', event.error);
      this.stopVoiceRecording();
    };
  },

  setupGestureControls() {
    if (!this.isMobile) return;

    // Pinch to zoom text
    let initialDistance = 0;
    let currentScale = 1;

    this.editorEl.addEventListener('touchstart', (e) => {
      if (e.touches.length === 2) {
        initialDistance = this.getTouchDistance(e.touches[0], e.touches[1]);
      }
    });

    this.editorEl.addEventListener('touchmove', (e) => {
      if (e.touches.length === 2) {
        e.preventDefault();
        const currentDistance = this.getTouchDistance(e.touches[0], e.touches[1]);
        const scale = currentDistance / initialDistance;
        
        if (scale > 1.1 || scale < 0.9) {
          this.adjustTextSize(scale);
        }
      }
    });
  },

  setupOfflineSync() {
    // Service worker for offline functionality
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.register('/text-editor-sw.js')
        .then(registration => {
          console.log('Text Editor SW registered:', registration);
          this.serviceWorker = registration;
        })
        .catch(error => {
          console.log('Text Editor SW registration failed:', error);
        });
    }

    // Queue operations when offline
    window.addEventListener('online', () => {
      this.syncOfflineChanges();
    });

    window.addEventListener('offline', () => {
      this.enableOfflineMode();
    });
  },

  // Voice Input Methods
  startVoiceRecording() {
    if (!this.speechRecognition) return;

    this.voiceRecording = true;
    this.speechRecognition.start();
    
    // Show voice recording UI
    this.showVoiceRecordingUI();
    
    // Auto-stop after 30 seconds
    this.voiceTimeout = setTimeout(() => {
      this.stopVoiceRecording();
    }, 30000);
  },

  stopVoiceRecording() {
    if (!this.speechRecognition || !this.voiceRecording) return;

    this.voiceRecording = false;
    this.speechRecognition.stop();
    this.hideVoiceRecordingUI();
    
    if (this.voiceTimeout) {
      clearTimeout(this.voiceTimeout);
    }
  },

  handleVoiceResult(event) {
    let finalTranscript = '';
    let interimTranscript = '';

    for (let i = event.resultIndex; i < event.results.length; i++) {
      const transcript = event.results[i][0].transcript;
      
      if (event.results[i].isFinal) {
        finalTranscript += transcript;
      } else {
        interimTranscript += transcript;
      }
    }

    if (finalTranscript) {
      this.insertVoiceText(finalTranscript);
    }

    // Show interim results
    this.updateVoicePreview(interimTranscript);
  },

  insertVoiceText(text) {
    const activeBlock = this.getActiveBlock();
    if (!activeBlock) return;

    const textarea = activeBlock.querySelector('textarea, input[type="text"]');
    if (textarea) {
      const cursorPos = textarea.selectionStart;
      const currentText = textarea.value;
      const newText = currentText.slice(0, cursorPos) + text + currentText.slice(cursorPos);
      
      textarea.value = newText;
      textarea.selectionStart = textarea.selectionEnd = cursorPos + text.length;
      
      // Trigger content update
      this.handleContentChange(textarea);
      
      // Auto-resize if needed
      this.autoResizeTextarea(textarea);
    }
  },

  // Block Management
  activateBlock(blockContainer) {
    // Remove previous active state
    const previousActive = this.editorEl.querySelector('.block-container.active');
    if (previousActive) {
      previousActive.classList.remove('active');
    }

    // Set new active state
    blockContainer.classList.add('active');
    this.currentBlock = blockContainer;

    // Focus on the input element
    const inputElement = blockContainer.querySelector('textarea, input[type="text"]');
    if (inputElement && this.isMobile) {
      // Delay focus on mobile to prevent keyboard flicker
      setTimeout(() => {
        inputElement.focus();
      }, 100);
    } else if (inputElement) {
      inputElement.focus();
    }

    // Show mobile toolbar if on mobile
    if (this.isMobile) {
      this.showMobileToolbar();
    }

    // Broadcast block activation
    const blockId = blockContainer.id.replace('block-', '');
    this.pushEvent("activate_block", { "block-id": blockId });
  },

  getActiveBlock() {
    return this.editorEl.querySelector('.block-container.active');
  },

  scrollToActiveBlock() {
    const activeBlock = this.getActiveBlock();
    if (activeBlock) {
      activeBlock.scrollIntoView({
        behavior: 'smooth',
        block: 'center'
      });
    }
  },

  // Content Editing
  handleContentChange(element) {
    const blockContainer = element.closest('.block-container');
    if (!blockContainer) return;

    const blockId = blockContainer.id.replace('block-', '');
    const content = element.value;
    const selection = {
      start: element.selectionStart,
      end: element.selectionEnd
    };

    // Check for media attachments
    const mediaAttachments = this.extractMediaAttachments(blockContainer);

    // Create operation for operational transformation
    const operation = {
      type: 'content_update',
      blockId: blockId,
      content: content,
      selection: selection,
      timestamp: Date.now(),
      userId: this.getCurrentUserId()
    };

    // Queue operation if offline
    if (!navigator.onLine) {
      this.queueOfflineOperation(operation);
      return;
    }

    // Send to server with enhanced data
    this.pushEvent("enhanced_text_update", {
      "content": content,
      "selection": selection,
      "block_id": blockId,
      "media_attachments": mediaAttachments,
      "input_method": this.getInputMethod(element)
    });

    // Apply operation locally for immediate feedback
    this.applyOperationLocally(operation);
  },

  autoResizeTextarea(textarea) {
    // Reset height to auto to get the correct scrollHeight
    textarea.style.height = 'auto';
    
    // Set height based on content
    const minHeight = 60; // Minimum height in pixels
    const maxHeight = window.innerHeight * 0.4; // Max 40% of viewport
    const scrollHeight = textarea.scrollHeight;
    
    const newHeight = Math.min(Math.max(scrollHeight, minHeight), maxHeight);
    textarea.style.height = newHeight + 'px';
    
    // Enable scrolling if content exceeds max height
    textarea.style.overflowY = scrollHeight > maxHeight ? 'auto' : 'hidden';
  },

  // Keyboard Shortcuts
  handleKeyboardShortcuts(e) {
    const isMac = navigator.platform.toUpperCase().indexOf('MAC') >= 0;
    const metaKey = isMac ? e.metaKey : e.ctrlKey;

    if (metaKey) {
      switch (e.key) {
        case 'b':
          e.preventDefault();
          this.toggleFormat('bold');
          break;
        case 'i':
          e.preventDefault();
          this.toggleFormat('italic');
          break;
        case 's':
          e.preventDefault();
          this.saveDocument();
          break;
        case 'Enter':
          if (e.shiftKey) {
            e.preventDefault();
            this.addNewBlock();
          }
          break;
        case '/':
          e.preventDefault();
          this.showBlockTypeMenu();
          break;
      }
    }

    // Mobile-specific shortcuts
    if (this.isMobile && e.key === 'Enter' && !e.shiftKey) {
      const target = e.target;
      if (target.tagName === 'INPUT' && target.type === 'text') {
        e.preventDefault();
        this.createNewBlockAfterCurrent();
      }
    }
  },

  toggleFormat(format) {
    const activeBlock = this.getActiveBlock();
    if (!activeBlock) return;

    const input = activeBlock.querySelector('textarea, input[type="text"]');
    if (!input) return;

    // Apply formatting (this would integrate with your rich text system)
    this.pushEvent("toggle_format", { format: format });
  },

  // Media Integration
  extractMediaAttachments(blockContainer) {
    const attachments = [];
    const mediaElements = blockContainer.querySelectorAll('.media-attachment');
    
    mediaElements.forEach(element => {
      const attachmentData = {
        id: element.dataset.attachmentId,
        type: element.dataset.attachmentType,
        position: JSON.parse(element.dataset.position || '{}')
      };
      attachments.push(attachmentData);
    });

    return attachments;
  },

  handleMediaUpload(file, blockId) {
    if (!file) return;

    // Create preview immediately
    const preview = this.createMediaPreview(file, blockId);
    
    // Upload file
    const formData = new FormData();
    formData.append('file', file);
    formData.append('block_id', blockId);

    fetch('/api/media/upload', {
      method: 'POST',
      body: formData,
      headers: {
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      }
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        this.attachMediaToBlock(blockId, data.media_file);
        this.removeMediaPreview(preview);
      } else {
        this.showUploadError(preview, data.error);
      }
    })
    .catch(error => {
      console.error('Upload failed:', error);
      this.showUploadError(preview, 'Upload failed');
    });
  },

  // Camera Integration (Mobile)
  takePlacePhoto(blockId) {
    if (!this.isMobile) return;

    // Use the device camera
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = 'image/*';
    input.capture = 'environment'; // Use rear camera

    input.onchange = (e) => {
      const file = e.target.files[0];
      if (file) {
        this.handleMediaUpload(file, blockId);
      }
    };

    input.click();
  },

  // Collaborative Features
  broadcastCursorPosition() {
    const selection = window.getSelection();
    if (selection.rangeCount === 0) return;

    const range = selection.getRangeAt(0);
    const rect = range.getBoundingClientRect();
    
    if (rect.width === 0 && rect.height === 0) return;

    const cursorData = {
      x: rect.left,
      y: rect.top,
      blockId: this.getCurrentBlockId(),
      userId: this.getCurrentUserId()
    };

    this.pushEvent("cursor_position_update", cursorData);
  },

  handleRemoteUpdates() {
    // Handle updates from other users
    const remoteOperations = this.el.dataset.pendingOperations;
    if (remoteOperations) {
      const operations = JSON.parse(remoteOperations);
      operations.forEach(op => {
        this.applyRemoteOperation(op);
      });
    }
  },

  applyRemoteOperation(operation) {
    // Apply operation from another user with conflict resolution
    const conflictResult = this.operationalTransform.transform(
      operation, 
      this.pendingOperations
    );

    if (conflictResult.hasConflict) {
      this.handleOperationConflict(conflictResult);
    } else {
      this.applyOperationLocally(conflictResult.transformedOperation);
    }
  },

  // Offline Support
  enableOfflineMode() {
    console.log('Switched to offline mode');
    
    // Show offline indicator
    this.showOfflineIndicator();
    
    // Queue all operations
    this.offlineMode = true;
  },

  queueOfflineOperation(operation) {
    operation.offline = true;
    operation.queuedAt = Date.now();
    this.offlineQueue.push(operation);
    
    // Store in localStorage for persistence
    localStorage.setItem('text_editor_offline_queue', JSON.stringify(this.offlineQueue));
  },

  syncOfflineChanges() {
    if (this.offlineQueue.length === 0) return;

    console.log(`Syncing ${this.offlineQueue.length} offline changes`);
    
    // Send queued operations to server
    this.pushEvent("sync_offline_changes", {
      operations: this.offlineQueue
    });

    // Clear queue after successful sync
    this.offlineQueue = [];
    localStorage.removeItem('text_editor_offline_queue');
    
    this.hideOfflineIndicator();
  },

  // Auto-save
  initializeAutoSave() {
    this.autoSaveInterval = setInterval(() => {
      if (this.hasUnsavedChanges()) {
        this.saveDocument();
      }
    }, 30000); // Auto-save every 30 seconds
  },

  saveDocument() {
    this.pushEvent("save_document", {
      document_id: this.documentId,
      create_snapshot: true
    });
  },

  // UI Helpers
  showMobileContextMenu(touch) {
    const menu = document.createElement('div');
    menu.className = 'mobile-context-menu';
    menu.style.position = 'absolute';
    menu.style.left = touch.clientX + 'px';
    menu.style.top = touch.clientY + 'px';
    
    menu.innerHTML = `
      <button onclick="this.parentElement.remove()">📷 Add Image</button>
      <button onclick="this.parentElement.remove()">🎙️ Voice Note</button>
      <button onclick="this.parentElement.remove()">📝 New Block</button>
      <button onclick="this.parentElement.remove()">❌ Cancel</button>
    `;

    document.body.appendChild(menu);

    // Remove menu after 3 seconds
    setTimeout(() => {
      if (menu.parentElement) {
        menu.remove();
      }
    }, 3000);
  },

  showVoiceRecordingUI() {
    const existingUI = document.querySelector('.voice-recording-ui');
    if (existingUI) return;

    const voiceUI = document.createElement('div');
    voiceUI.className = 'voice-recording-ui';
    voiceUI.innerHTML = `
      <div class="voice-recording-indicator">
        <div class="pulse-dot"></div>
        <span>Listening...</span>
        <button onclick="window.textEditor.stopVoiceRecording()">Stop</button>
      </div>
      <div class="voice-preview"></div>
    `;

    document.body.appendChild(voiceUI);
  },

  hideVoiceRecordingUI() {
    const voiceUI = document.querySelector('.voice-recording-ui');
    if (voiceUI) {
      voiceUI.remove();
    }
  },

  updateVoicePreview(text) {
    const preview = document.querySelector('.voice-preview');
    if (preview) {
      preview.textContent = text;
    }
  },

  showOfflineIndicator() {
    const indicator = document.createElement('div');
    indicator.className = 'offline-indicator';
    indicator.innerHTML = '📡 Working offline - changes will sync when connected';
    document.body.appendChild(indicator);
  },

  hideOfflineIndicator() {
    const indicator = document.querySelector('.offline-indicator');
    if (indicator) {
      indicator.remove();
    }
  },

  // Utility Methods
  getTouchDistance(touch1, touch2) {
    const dx = touch1.clientX - touch2.clientX;
    const dy = touch1.clientY - touch2.clientY;
    return Math.sqrt(dx * dx + dy * dy);
  },

  adjustTextSize(scale) {
    const activeBlock = this.getActiveBlock();
    if (!activeBlock) return;

    const textElement = activeBlock.querySelector('textarea, input');
    if (textElement) {
      const currentSize = parseFloat(getComputedStyle(textElement).fontSize);
      const newSize = Math.min(Math.max(currentSize * scale, 12), 24);
      textElement.style.fontSize = newSize + 'px';
    }
  },

  isInputFocused() {
    const activeElement = document.activeElement;
    return activeElement && (
      activeElement.tagName === 'TEXTAREA' || 
      activeElement.tagName === 'INPUT'
    );
  },

  getCurrentBlockId() {
    const activeBlock = this.getActiveBlock();
    return activeBlock ? activeBlock.id.replace('block-', '') : null;
  },

  getCurrentUserId() {
    return this.el.dataset.userId || 'anonymous';
  },

  getInputMethod(element) {
    // Detect input method for analytics
    if (this.voiceRecording) return 'voice';
    if (this.isMobile) return 'touch';
    return 'keyboard';
  },

  hasUnsavedChanges() {
    return this.pendingOperations.length > 0 || this.offlineQueue.length > 0;
  },

  debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
      const later = () => {
        clearTimeout(timeout);
        func(...args);
      };
      clearTimeout(timeout);
      timeout = setTimeout(later, wait);
    };
  },

  cleanup() {
    if (this.cursorUpdateInterval) {
      clearInterval(this.cursorUpdateInterval);
    }
    
    if (this.autoSaveInterval) {
      clearInterval(this.autoSaveInterval);
    }

    if (this.voiceTimeout) {
      clearTimeout(this.voiceTimeout);
    }

    if (this.speechRecognition) {
      this.speechRecognition.stop();
    }
  }
};

// Operational Transform Engine for Conflict Resolution
class OperationalTransformEngine {
  transform(remoteOp, localOps) {
    // Simplified OT implementation
    // In production, you'd use a more sophisticated OT library
    
    let hasConflict = false;
    let transformedOperation = { ...remoteOp };

    for (const localOp of localOps) {
      if (this.detectConflict(remoteOp, localOp)) {
        hasConflict = true;
        transformedOperation = this.resolveConflict(remoteOp, localOp);
      }
    }

    return {
      hasConflict,
      transformedOperation
    };
  }

  detectConflict(op1, op2) {
    return op1.blockId === op2.blockId && 
           Math.abs(op1.timestamp - op2.timestamp) < 1000;
  }

  resolveConflict(remoteOp, localOp) {
    // Simple last-writer-wins strategy
    // In production, implement more sophisticated resolution
    return remoteOp.timestamp > localOp.timestamp ? remoteOp : localOp;
  }
}

// Export for use in Phoenix hooks
window.TextEditor = TextEditor;