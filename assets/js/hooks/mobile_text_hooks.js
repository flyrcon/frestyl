// Mobile Text Editor Hooks
export const MobileTextEditor = {
  mounted() {
    this.textarea = this.el;
    this.lastContent = this.textarea.value;
    this.lastCursor = { line: 0, column: 0 };
    this.isComposing = false;
    this.undoStack = [this.textarea.value];
    this.redoStack = [];
    this.maxUndoStackSize = 50;

    this.setupEventListeners();
    this.setupVirtualKeyboard();
    this.initializeCollaborativeCursor();
  },

  setupEventListeners() {
    // Handle input changes
    this.textarea.addEventListener('input', this.handleInput.bind(this));
    this.textarea.addEventListener('selectionchange', this.handleSelectionChange.bind(this));
    
    // Handle composition events (for international keyboards)
    this.textarea.addEventListener('compositionstart', () => {
      this.isComposing = true;
    });
    
    this.textarea.addEventListener('compositionend', () => {
      this.isComposing = false;
      this.handleInput();
    });

    // Handle focus events for toolbar
    this.textarea.addEventListener('focus', () => {
      this.pushEvent("show_keyboard_toolbar", {});
    });

    this.textarea.addEventListener('blur', () => {
      // Small delay to prevent hiding toolbar when tapping buttons
      setTimeout(() => {
        this.pushEvent("hide_keyboard_toolbar", {});
      }, 200);
    });

    // Handle keyboard shortcuts
    this.textarea.addEventListener('keydown', this.handleKeyDown.bind(this));
  },

  setupVirtualKeyboard() {
    // Handle virtual keyboard on mobile
    if ('visualViewport' in window) {
      const viewport = window.visualViewport;
      
      const handleViewportChange = () => {
        const keyboardHeight = window.innerHeight - viewport.height;
        
        if (keyboardHeight > 150) { // Keyboard is open
          this.el.style.paddingBottom = `${keyboardHeight + 100}px`;
          // Scroll to cursor position
          this.scrollToCursor();
        } else {
          this.el.style.paddingBottom = '0px';
        }
      };

      viewport.addEventListener('resize', handleViewportChange);
      viewport.addEventListener('scroll', handleViewportChange);
    }
  },

  initializeCollaborativeCursor() {
    // Set up mutation observer for remote cursor updates
    this.cursorObserver = new MutationObserver(() => {
      this.updateCursorPositions();
    });

    this.cursorObserver.observe(this.el.parentElement, {
      childList: true,
      subtree: true
    });
  },

  handleInput() {
    if (this.isComposing) return;

    const content = this.textarea.value;
    const cursor = this.getCursorPosition();
    const selection = this.getSelection();

    // Add to undo stack if content changed significantly
    if (this.shouldAddToUndoStack(content)) {
      this.addToUndoStack(this.lastContent);
    }

    this.lastContent = content;
    this.lastCursor = cursor;

    // Send update with debouncing
    this.debounceTextUpdate(content, cursor, selection);
  },

  handleSelectionChange() {
    const cursor = this.getCursorPosition();
    const selection = this.getSelection();
    
    // Only send cursor updates, not full content
    this.debounceCursorUpdate(cursor, selection);
  },

  handleKeyDown(e) {
    // Handle keyboard shortcuts
    if (e.metaKey || e.ctrlKey) {
      switch (e.key) {
        case 'z':
          if (e.shiftKey) {
            e.preventDefault();
            this.redo();
          } else {
            e.preventDefault();
            this.undo();
          }
          break;
        case 'y':
          e.preventDefault();
          this.redo();
          break;
        case 'b':
          e.preventDefault();
          this.formatBold();
          break;
        case 'i':
          e.preventDefault();
          this.formatItalic();
          break;
      }
    }
  },

  getCursorPosition() {
    const selectionStart = this.textarea.selectionStart;
    const textBeforeCursor = this.textarea.value.substring(0, selectionStart);
    const lines = textBeforeCursor.split('\n');
    
    return {
      line: lines.length - 1,
      column: lines[lines.length - 1].length,
      offset: selectionStart
    };
  },

  getSelection() {
    const start = this.textarea.selectionStart;
    const end = this.textarea.selectionEnd;
    
    if (start === end) return null;
    
    return {
      start: start,
      end: end,
      text: this.textarea.value.substring(start, end)
    };
  },

  scrollToCursor() {
    const cursor = this.getCursorPosition();
    const lineHeight = parseInt(window.getComputedStyle(this.textarea).lineHeight);
    const scrollTop = cursor.line * lineHeight;
    
    this.textarea.scrollTop = Math.max(0, scrollTop - this.textarea.clientHeight / 2);
  },

  shouldAddToUndoStack(newContent) {
    const contentDiff = Math.abs(newContent.length - this.lastContent.length);
    return contentDiff > 10 || newContent.includes('\n') !== this.lastContent.includes('\n');
  },

  addToUndoStack(content) {
    this.undoStack.push(content);
    if (this.undoStack.length > this.maxUndoStackSize) {
      this.undoStack.shift();
    }
    this.redoStack = []; // Clear redo stack when new change is made
  },

  undo() {
    if (this.undoStack.length > 1) {
      const current = this.undoStack.pop();
      this.redoStack.push(current);
      const previous = this.undoStack[this.undoStack.length - 1];
      
      this.textarea.value = previous;
      this.lastContent = previous;
      this.triggerUpdate();
    }
  },

  redo() {
    if (this.redoStack.length > 0) {
      const content = this.redoStack.pop();
      this.undoStack.push(content);
      
      this.textarea.value = content;
      this.lastContent = content;
      this.triggerUpdate();
    }
  },

  formatBold() {
    this.wrapSelection('**', '**');
  },

  formatItalic() {
    this.wrapSelection('*', '*');
  },

  formatHeading() {
    this.insertAtLineStart('# ');
  },

  formatBullet() {
    this.insertAtLineStart('- ');
  },

  wrapSelection(prefix, suffix) {
    const start = this.textarea.selectionStart;
    const end = this.textarea.selectionEnd;
    const selectedText = this.textarea.value.substring(start, end);
    const replacement = prefix + selectedText + suffix;
    
    this.textarea.setRangeText(replacement, start, end, 'select');
    this.triggerUpdate();
  },

  insertAtLineStart(prefix) {
    const start = this.textarea.selectionStart;
    const value = this.textarea.value;
    const lineStart = value.lastIndexOf('\n', start - 1) + 1;
    
    this.textarea.setRangeText(prefix, lineStart, lineStart, 'end');
    this.triggerUpdate();
  },

  insertText(text) {
    const start = this.textarea.selectionStart;
    const end = this.textarea.selectionEnd;
    
    this.textarea.setRangeText(text, start, end, 'end');
    this.triggerUpdate();
  },

  triggerUpdate() {
    const content = this.textarea.value;
    const cursor = this.getCursorPosition();
    const selection = this.getSelection();
    
    this.pushEvent("text_update", {
      content: content,
      cursor: cursor,
      selection: selection
    });
  },

  updateCursorPositions() {
    // Update visual positions of collaborative cursors
    const cursors = this.el.parentElement.querySelectorAll('[data-user-id]');
    cursors.forEach(cursor => {
      const userId = cursor.dataset.userId;
      // Position cursor based on text metrics
      // This would need cursor position data from the server
    });
  },

  // Debounced functions to prevent excessive updates
  debounceTextUpdate: (() => {
    let timeout;
    return function(content, cursor, selection) {
      clearTimeout(timeout);
      timeout = setTimeout(() => {
        this.pushEvent("text_update", {
          content: content,
          cursor: cursor,
          selection: selection
        });
      }, 300);
    };
  })(),

  debounceCursorUpdate: (() => {
    let timeout;
    return function(cursor, selection) {
      clearTimeout(timeout);
      timeout = setTimeout(() => {
        this.pushEvent("cursor_update", {
          cursor: cursor,
          selection: selection
        });
      }, 100);
    };
  })(),

  // Handle events from LiveView
  handleEvent("mobile_insert_text", ({ text }) => {
    this.insertText(text);
  }),

  handleEvent("mobile_format_bold", () => {
    this.formatBold();
  }),

  handleEvent("mobile_format_italic", () => {
    this.formatItalic();
  }),

  handleEvent("mobile_format_heading", () => {
    this.formatHeading();
  }),

  handleEvent("mobile_format_bullet", () => {
    this.formatBullet();
  }),

  destroyed() {
    if (this.cursorObserver) {
      this.cursorObserver.disconnect();
    }
  }
};

export const CollaboratorCursor = {
  mounted() {
    this.userId = this.el.dataset.userId;
    this.animateIn();
  },

  updated() {
    this.animateUpdate();
  },

  animateIn() {
    this.el.style.opacity = '0';
    this.el.style.transform += ' scale(0.8)';
    
    requestAnimationFrame(() => {
      this.el.style.transition = 'all 0.2s ease-out';
      this.el.style.opacity = '1';
      this.el.style.transform = this.el.style.transform.replace('scale(0.8)', 'scale(1)');
    });
  },

  animateUpdate() {
    this.el.style.transition = 'transform 0.15s ease-out';
  },

  destroyed() {
    this.el.style.transition = 'all 0.2s ease-in';
    this.el.style.opacity = '0';
    this.el.style.transform += ' scale(0.8)';
  }
};