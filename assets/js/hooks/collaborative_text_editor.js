// assets/js/hooks/collaborative_text_editor.js
// Real-time collaborative text editing with Operational Transforms for story sections

const CollaborativeTextEditor = {
  mounted() {
    this.sectionId = this.el.dataset.sectionId;
    this.collaborationEnabled = this.el.dataset.collaborationEnabled === "true";
    this.sessionId = this.el.dataset.sessionId;
    this.userId = this.el.dataset.userId;
    
    this.textarea = this.el.querySelector('textarea');
    this.cursorsContainer = this.el.querySelector(`#collaboration-cursors-${this.sectionId}`);
    
    // Operational Transform state
    this.localVersion = 0;
    this.serverVersion = 0;
    this.pendingOperations = [];
    this.inflightOperation = null;
    this.lastContent = this.textarea.value;
    
    // Collaboration state
    this.collaboratorCursors = new Map();
    this.isTyping = false;
    this.typingTimeout = null;
    
    if (this.collaborationEnabled) {
      this.setupCollaborativeFeatures();
    } else {
      this.setupSoloFeatures();
    }
    
    this.setupEventListeners();
  },

  setupCollaborativeFeatures() {
    // Subscribe to real-time operations for this section
    this.handleEvent("apply_remote_operation", (payload) => {
      if (payload.section_id === this.sectionId && payload.user_id !== this.userId) {
        this.applyRemoteOperation(payload.operation);
      }
    });

    // Handle collaborator presence updates
    this.handleEvent("collaborator_cursor_update", (payload) => {
      if (payload.section_id === this.sectionId && payload.user_id !== this.userId) {
        this.updateCollaboratorCursor(payload.user_id, payload.cursor_position, payload.username);
      }
    });

    // Handle operation acknowledgments
    this.handleEvent("operation_acknowledged", (payload) => {
      if (payload.section_id === this.sectionId) {
        this.handleOperationAcknowledged(payload);
      }
    });

    console.log(`Collaborative editing enabled for section ${this.sectionId}`);
  },

  setupSoloFeatures() {
    // Simple auto-save for solo editing
    this.autoSaveInterval = setInterval(() => {
      if (this.hasUnsavedChanges()) {
        this.autoSave();
      }
    }, 2000);
  },

  setupEventListeners() {
    // Text change detection
    this.textarea.addEventListener('input', (e) => {
      this.handleTextChange(e);
    });

    // Cursor position tracking for collaboration
    this.textarea.addEventListener('selectionchange', (e) => {
      if (this.collaborationEnabled) {
        this.handleCursorChange(e);
      }
    });

    // Focus/blur events
    this.textarea.addEventListener('focus', () => {
      if (this.collaborationEnabled) {
        this.broadcastPresence({ focused: true });
      }
    });

    this.textarea.addEventListener('blur', () => {
      if (this.collaborationEnabled) {
        this.broadcastPresence({ focused: false });
      }
    });
  },

  handleTextChange(event) {
    const newContent = this.textarea.value;
    
    if (this.collaborationEnabled) {
      this.handleCollaborativeTextChange(newContent);
    } else {
      this.handleSoloTextChange(newContent);
    }
  },

  handleCollaborativeTextChange(newContent) {
    // Generate operational transform operations
    const operations = this.generateOperations(this.lastContent, newContent);
    
    if (operations.length > 0) {
      // Create operation object
      const operation = {
        id: this.generateOperationId(),
        operations: operations,
        user_id: this.userId,
        version: this.localVersion,
        timestamp: Date.now()
      };

      // Apply locally immediately
      this.lastContent = newContent;
      this.localVersion++;

      // Queue for server sync
      this.sendOperation(operation);
      
      // Track typing status
      this.updateTypingStatus(true);
    }
  },

  handleSoloTextChange(newContent) {
    // Simple debounced auto-save
    this.lastContent = newContent;
    this.markUnsavedChanges();
  },

  generateOperations(oldText, newText) {
    // Simple diff algorithm - in production, use proper OT library
    if (oldText === newText) return [];

    // Find common prefix and suffix
    let prefixLength = 0;
    let suffixLength = 0;

    // Common prefix
    while (prefixLength < oldText.length && 
           prefixLength < newText.length && 
           oldText[prefixLength] === newText[prefixLength]) {
      prefixLength++;
    }

    // Common suffix
    while (suffixLength < (oldText.length - prefixLength) && 
           suffixLength < (newText.length - prefixLength) && 
           oldText[oldText.length - 1 - suffixLength] === newText[newText.length - 1 - suffixLength]) {
      suffixLength++;
    }

    // Extract the differing middle parts
    const deletedText = oldText.slice(prefixLength, oldText.length - suffixLength);
    const insertedText = newText.slice(prefixLength, newText.length - suffixLength);

    const operations = [];

    // Retain prefix
    if (prefixLength > 0) {
      operations.push({ type: 'retain', length: prefixLength });
    }

    // Delete middle
    if (deletedText.length > 0) {
      operations.push({ type: 'delete', length: deletedText.length });
    }

    // Insert new middle
    if (insertedText.length > 0) {
      operations.push({ type: 'insert', text: insertedText });
    }

    // Retain suffix (implicit)

    return operations;
  },

  sendOperation(operation) {
    // Add to pending queue
    this.pendingOperations.push(operation);
    
    // Send to server if no operation in flight
    if (!this.inflightOperation) {
      this.sendNextOperation();
    }
  },

  sendNextOperation() {
    if (this.pendingOperations.length === 0) {
      this.inflightOperation = null;
      return;
    }

    this.inflightOperation = this.pendingOperations.shift();
    
    // Send to Phoenix LiveView
    this.pushEvent("text_operation", {
      section_id: this.sectionId,
      operation: this.inflightOperation
    });
  },

  applyRemoteOperation(operation) {
    // Transform remote operation against pending local operations
    let transformedOp = operation;
    
    // Transform against inflight operation
    if (this.inflightOperation) {
      transformedOp = this.transformOperations(transformedOp, this.inflightOperation, 'right');
    }

    // Transform against pending operations
    for (let pendingOp of this.pendingOperations) {
      transformedOp = this.transformOperations(transformedOp, pendingOp, 'right');
    }

    // Apply the transformed operation to the text
    const currentContent = this.textarea.value;
    const newContent = this.applyOperationToText(currentContent, transformedOp);
    
    // Update textarea
    const cursorPosition = this.textarea.selectionStart;
    this.textarea.value = newContent;
    
    // Restore cursor position (adjusted for operation)
    const adjustedCursor = this.adjustCursorPosition(cursorPosition, transformedOp);
    this.textarea.setSelectionRange(adjustedCursor, adjustedCursor);
    
    this.lastContent = newContent;
    this.serverVersion++;
  },

  transformOperations(op1, op2, priority) {
    // Simplified operational transform - production should use proper OT library
    // This is a basic implementation for demonstration
    
    if (priority === 'left') {
      return op1; // Left wins in conflicts
    } else {
      return op1; // Right wins in conflicts
    }
  },

  applyOperationToText(text, operation) {
    let result = '';
    let textIndex = 0;
    
    for (let op of operation.operations) {
      switch (op.type) {
        case 'retain':
          result += text.slice(textIndex, textIndex + op.length);
          textIndex += op.length;
          break;
        
        case 'insert':
          result += op.text;
          break;
        
        case 'delete':
          textIndex += op.length; // Skip deleted text
          break;
      }
    }
    
    // Add remaining text
    result += text.slice(textIndex);
    
    return result;
  },

  handleOperationAcknowledged(payload) {
    // Server acknowledged our operation
    if (this.inflightOperation && this.inflightOperation.id === payload.operation_id) {
      this.serverVersion = payload.server_version;
      this.sendNextOperation(); // Send next pending operation
    }
  },

  handleCursorChange(event) {
    const cursorPosition = this.textarea.selectionStart;
    
    // Debounce cursor updates
    clearTimeout(this.cursorUpdateTimeout);
    this.cursorUpdateTimeout = setTimeout(() => {
      this.pushEvent("cursor_position_update", {
        section_id: this.sectionId,
        cursor_position: cursorPosition,
        selection_length: this.textarea.selectionEnd - this.textarea.selectionStart
      });
    }, 100);
  },

  updateCollaboratorCursor(userId, position, username) {
    if (!this.cursorsContainer) return;

    // Create or update cursor element
    let cursorElement = this.cursorsContainer.querySelector(`[data-user-id="${userId}"]`);
    
    if (!cursorElement) {
      cursorElement = this.createCursorElement(userId, username);
      this.cursorsContainer.appendChild(cursorElement);
    }

    // Position the cursor
    this.positionCursor(cursorElement, position);
    
    // Store cursor info
    this.collaboratorCursors.set(userId, { position, username, element: cursorElement });
  },

  createCursorElement(userId, username) {
    const cursor = document.createElement('div');
    cursor.setAttribute('data-user-id', userId);
    cursor.className = 'collaboration-cursor';
    cursor.innerHTML = `
      <div class="cursor-line"></div>
      <div class="cursor-label">${username}</div>
    `;
    
    // Add CSS styles
    cursor.style.position = 'absolute';
    cursor.style.pointerEvents = 'none';
    cursor.style.zIndex = '1000';
    
    return cursor;
  },

  positionCursor(cursorElement, textPosition) {
    // Calculate pixel position from text position
    // This is simplified - production should use proper text measurement
    const lineHeight = 24; // Approximate line height
    const charWidth = 8;   // Approximate character width
    
    const lines = this.textarea.value.slice(0, textPosition).split('\n');
    const lineNumber = lines.length - 1;
    const columnNumber = lines[lines.length - 1].length;
    
    const top = lineNumber * lineHeight;
    const left = columnNumber * charWidth;
    
    cursorElement.style.top = `${top}px`;
    cursorElement.style.left = `${left}px`;
  },

  updateTypingStatus(isTyping) {
    if (this.isTyping !== isTyping) {
      this.isTyping = isTyping;
      this.broadcastPresence({ is_typing: isTyping });
    }

    // Clear typing status after delay
    clearTimeout(this.typingTimeout);
    if (isTyping) {
      this.typingTimeout = setTimeout(() => {
        this.updateTypingStatus(false);
      }, 2000);
    }
  },

  broadcastPresence(presence) {
    this.pushEvent("presence_update", {
      section_id: this.sectionId,
      presence: presence
    });
  },

  // Solo editing helpers
  hasUnsavedChanges() {
    return this.textarea.value !== this.lastContent;
  },

  markUnsavedChanges() {
    // Visual indicator of unsaved changes
    this.el.classList.add('has-unsaved-changes');
  },

  autoSave() {
    const content = this.textarea.value;
    this.pushEvent("auto_save_section", {
      section_id: this.sectionId,
      content: content
    });
    
    this.lastContent = content;
    this.el.classList.remove('has-unsaved-changes');
  },

  // Utility functions
  generateOperationId() {
    return `${this.userId}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  },

  adjustCursorPosition(position, operation) {
    // Adjust cursor position based on applied operation
    // Simplified implementation
    let adjustment = 0;
    let opPosition = 0;
    
    for (let op of operation.operations) {
      if (opPosition >= position) break;
      
      switch (op.type) {
        case 'retain':
          opPosition += op.length;
          break;
        case 'insert':
          if (opPosition <= position) {
            adjustment += op.text.length;
          }
          break;
        case 'delete':
          if (opPosition <= position) {
            adjustment -= Math.min(op.length, position - opPosition);
          }
          opPosition += op.length;
          break;
      }
    }
    
    return Math.max(0, position + adjustment);
  },

  destroyed() {
    // Clean up
    if (this.autoSaveInterval) {
      clearInterval(this.autoSaveInterval);
    }
    
    clearTimeout(this.typingTimeout);
    clearTimeout(this.cursorUpdateTimeout);
  }
};

export default CollaborativeTextEditor;