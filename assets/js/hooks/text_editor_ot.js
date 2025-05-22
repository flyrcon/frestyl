// assets/js/hooks/text_editor_ot.js
export const TextEditorOT = {
  mounted() {
    this.editor = this.el;
    this.lastContent = this.editor.value;
    this.lastSelection = { start: 0, end: 0 };
    this.pendingOperations = [];
    this.isComposing = false;
    this.typingTimer = null;

    // Debounced change handler
    this.debouncedChange = this.debounce(this.handleContentChange.bind(this), 300);
    
    // Set up event listeners
    this.setupEventListeners();
    
    // Focus the editor
    this.editor.focus();
  },

  setupEventListeners() {
    // Content change events
    this.editor.addEventListener('input', (e) => {
      if (!this.isComposing) {
        this.handleInput(e);
      }
    });

    // Selection change events
    this.editor.addEventListener('selectionchange', () => {
      this.handleSelectionChange();
    });

    // Composition events (for IME support)
    this.editor.addEventListener('compositionstart', () => {
      this.isComposing = true;
    });

    this.editor.addEventListener('compositionend', (e) => {
      this.isComposing = false;
      this.handleInput(e);
    });

    // Typing indicators
    this.editor.addEventListener('focus', () => {
      this.pushEvent('typing_start', {});
    });

    this.editor.addEventListener('blur', () => {
      this.pushEvent('typing_stop', {});
      this.clearTypingTimer();
    });

    // Keyboard shortcuts
    this.editor.addEventListener('keydown', (e) => {
      this.handleKeydown(e);
    });
  },

  handleInput(e) {
    const currentContent = this.editor.value;
    const currentSelection = this.getCurrentSelection();

    // Check if content actually changed
    if (currentContent !== this.lastContent) {
      // Generate operations
      const operations = this.generateOperations(this.lastContent, currentContent);
      
      if (operations.length > 0) {
        // Send to server
        this.pushEvent('text_update', {
          content: currentContent,
          selection: currentSelection,
          operations: operations
        });
      }

      this.lastContent = currentContent;
    }

    this.lastSelection = currentSelection;
    this.handleTypingIndicator();
  },

  handleSelectionChange() {
    const currentSelection = this.getCurrentSelection();
    
    // Only send selection updates if significantly different
    if (Math.abs(currentSelection.start - this.lastSelection.start) > 0 ||
        Math.abs(currentSelection.end - this.lastSelection.end) > 0) {
      
      this.pushEvent('cursor_update', {
        selection: currentSelection
      });
      
      this.lastSelection = currentSelection;
    }
  },

  handleKeydown(e) {
    // Handle special key combinations
    if (e.ctrlKey || e.metaKey) {
      switch (e.key) {
        case 'z':
          if (e.shiftKey) {
            // Redo
            e.preventDefault();
            this.pushEvent('redo', {});
          } else {
            // Undo
            e.preventDefault();
            this.pushEvent('undo', {});
          }
          break;
        case 's':
          // Save
          e.preventDefault();
          this.pushEvent('save', {});
          break;
      }
    }
  },

  handleTypingIndicator() {
    // Clear existing timer
    this.clearTypingTimer();
    
    // Send typing start
    this.pushEvent('typing_start', {});
    
    // Set timer to send typing stop
    this.typingTimer = setTimeout(() => {
      this.pushEvent('typing_stop', {});
    }, 1000);
  },

  clearTypingTimer() {
    if (this.typingTimer) {
      clearTimeout(this.typingTimer);
      this.typingTimer = null;
    }
  },

  getCurrentSelection() {
    return {
      start: this.editor.selectionStart,
      end: this.editor.selectionEnd,
      line: this.getLineNumber(this.editor.selectionStart),
      column: this.getColumnNumber(this.editor.selectionStart)
    };
  },

  getLineNumber(position) {
    const textUpToPosition = this.editor.value.substring(0, position);
    return textUpToPosition.split('\n').length - 1;
  },

  getColumnNumber(position) {
    const textUpToPosition = this.editor.value.substring(0, position);
    const lines = textUpToPosition.split('\n');
    return lines[lines.length - 1].length;
  },

  // Generate text operations (simple diff algorithm)
  generateOperations(oldText, newText) {
    const operations = [];
    
    if (oldText === newText) {
      return operations;
    }

    // Find common prefix
    let prefixLength = 0;
    while (prefixLength < oldText.length && 
           prefixLength < newText.length && 
           oldText[prefixLength] === newText[prefixLength]) {
      prefixLength++;
    }

    // Find common suffix
    let suffixLength = 0;
    while (suffixLength < (oldText.length - prefixLength) && 
           suffixLength < (newText.length - prefixLength) && 
           oldText[oldText.length - 1 - suffixLength] === newText[newText.length - 1 - suffixLength]) {
      suffixLength++;
    }

    // Calculate the changed portion
    const oldMiddle = oldText.substring(prefixLength, oldText.length - suffixLength);
    const newMiddle = newText.substring(prefixLength, newText.length - suffixLength);

    // Build operations
    if (prefixLength > 0) {
      operations.push({ type: 'retain', count: prefixLength });
    }

    if (oldMiddle.length > 0) {
      operations.push({ type: 'delete', count: oldMiddle.length });
    }

    if (newMiddle.length > 0) {
      operations.push({ type: 'insert', text: newMiddle });
    }

    if (suffixLength > 0) {
      operations.push({ type: 'retain', count: suffixLength });
    }

    return operations;
  },

  // Apply remote operations to local text
  applyRemoteOperations(operations) {
    let text = this.editor.value;
    let position = 0;
    const selection = this.getCurrentSelection();

    for (const op of operations) {
      switch (op.type) {
        case 'retain':
          position += op.count;
          break;
          
        case 'insert':
          text = text.substring(0, position) + op.text + text.substring(position);
          position += op.text.length;
          break;
          
        case 'delete':
          text = text.substring(0, position) + text.substring(position + op.count);
          break;
      }
    }

    // Update editor content
    this.editor.value = text;
    this.lastContent = text;

    // Restore cursor position (approximate)
    this.editor.setSelectionRange(selection.start, selection.end);
  },

  // Handle incoming server events
  handleEvent(event, payload) {
    switch (event) {
      case 'remote_operations':
        this.applyRemoteOperations(payload.operations);
        break;
        
      case 'cursor_update':
        this.showRemoteCursor(payload.user_id, payload.selection);
        break;
        
      case 'content_update':
        // Full content update (fallback)
        if (payload.content !== this.editor.value) {
          const selection = this.getCurrentSelection();
          this.editor.value = payload.content;
          this.lastContent = payload.content;
          this.editor.setSelectionRange(selection.start, selection.end);
        }
        break;
    }
  },

  showRemoteCursor(userId, selection) {
    // This would show other users' cursors
    // Implementation depends on your UI design
    console.log(`User ${userId} cursor at:`, selection);
  },

  // Utility function for debouncing
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

  handleContentChange() {
    // This is called after debounce delay
    const currentContent = this.editor.value;
    const currentSelection = this.getCurrentSelection();

    if (currentContent !== this.lastContent) {
      this.pushEvent('text_update', {
        content: currentContent,
        selection: currentSelection
      });

      this.lastContent = currentContent;
    }
  },

  destroyed() {
    this.clearTypingTimer();
  }
};

// Auto-resize textarea hook
export const AutoResize = {
  mounted() {
    this.resize();
    this.el.addEventListener('input', () => this.resize());
  },

  resize() {
    this.el.style.height = 'auto';
    this.el.style.height = this.el.scrollHeight + 'px';
  }
};

// Message form hook for chat
export const MessageForm = {
  mounted() {
    this.el.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        this.el.dispatchEvent(new Event('submit', { bubbles: true }));
      }
    });
  },

  updated() {
    // Auto-focus the textarea after form reset
    const textarea = this.el.querySelector('textarea');
    if (textarea && textarea.value === '') {
      textarea.focus();
    }
  }
};

// Drag and drop file upload hook
export const DragAndDrop = {
  mounted() {
    this.overlay = this.el;
    
    // Prevent default drag behaviors
    ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
      this.overlay.addEventListener(eventName, this.preventDefaults, false);
      document.body.addEventListener(eventName, this.preventDefaults, false);
    });

    // Highlight drop area when dragging over it
    ['dragenter', 'dragover'].forEach(eventName => {
      this.overlay.addEventListener(eventName, () => this.highlight(), false);
    });

    ['dragleave', 'drop'].forEach(eventName => {
      this.overlay.addEventListener(eventName, () => this.unhighlight(), false);
    });

    // Handle dropped files
    this.overlay.addEventListener('drop', (e) => this.handleDrop(e), false);
  },

  preventDefaults(e) {
    e.preventDefault();
    e.stopPropagation();
  },

  highlight() {
    this.overlay.classList.remove('hidden');
  },

  unhighlight() {
    this.overlay.classList.add('hidden');
  },

  handleDrop(e) {
    const dt = e.dataTransfer;
    const files = dt.files;

    this.handleFiles(files);
  },

  handleFiles(files) {
    // Trigger file input change
    const fileInput = document.querySelector('[data-phx-upload-ref]');
    if (fileInput && files.length > 0) {
      // This is a bit tricky - we need to simulate file selection
      // In practice, you might need to handle this differently
      console.log('Files dropped:', files);
      
      // For now, just hide the overlay
      this.unhighlight();
    }
  }
};