// assets/js/hooks/rich_text_editor.js
export const RichTextEditor = {
  mounted() {
    this.editor = this.el;
    this.sectionId = this.editor.dataset.sectionId;
    this.format = this.editor.dataset.format;
    this.collaborators = new Map();
    this.lastContent = this.editor.innerHTML;
    this.saveTimeout = null;
    this.isComposing = false;
    
    // Initialize editor features
    this.setupEditor();
    this.setupCollaboration();
    this.setupFormatSpecificFeatures();
    this.setupKeyboardShortcuts();
    
    // Handle external content updates
    this.handleEvent("external_content_update", ({section_id, content}) => {
      if (section_id === this.sectionId && content !== this.editor.innerHTML) {
        this.updateContentWithoutTrigger(content);
      }
    });
    
    // Handle collaborator cursors
    this.handleEvent("collaborator_cursor", ({user_id, position, user_name}) => {
      this.updateCollaboratorCursor(user_id, position, user_name);
    });
  },

  setupEditor() {
    // Content change detection
    this.editor.addEventListener('input', (e) => {
      if (this.isComposing) return;
      
      const content = this.editor.innerHTML;
      if (content !== this.lastContent) {
        this.lastContent = content;
        this.debounceContentChange(content);
        this.broadcastCursorPosition();
      }
    });

    // Composition events for IME input (Chinese, Japanese, etc.)
    this.editor.addEventListener('compositionstart', () => {
      this.isComposing = true;
    });

    this.editor.addEventListener('compositionend', (e) => {
      this.isComposing = false;
      this.debounceContentChange(this.editor.innerHTML);
    });

    // Selection/cursor changes
    this.editor.addEventListener('selectionchange', () => {
      this.broadcastCursorPosition();
    });

    // Paste handling
    this.editor.addEventListener('paste', (e) => {
      e.preventDefault();
      const text = e.clipboardData.getData('text/plain');
      this.insertTextAtCursor(text);
    });

    // Format-specific paste handling
    if (this.format === 'screenplay') {
      this.setupScreenplayPasting();
    }
  },

  setupCollaboration() {
    // Create cursor container
    this.cursorContainer = document.getElementById('collaborator-cursors') || 
      this.createCursorContainer();
    
    // Broadcast cursor position every 2 seconds when active
    this.cursorInterval = setInterval(() => {
      if (document.activeElement === this.editor) {
        this.broadcastCursorPosition();
      }
    }, 2000);
  },

  setupFormatSpecificFeatures() {
    switch(this.format) {
      case 'screenplay':
        this.setupScreenplayFormatting();
        break;
      case 'novel':
        this.setupNovelFormatting();
        break;
      case 'case_study':
        this.setupBusinessFormatting();
        break;
      case 'live_story':
        this.setupLiveStoryFormatting();
        break;
    }
  },

  setupScreenplayFormatting() {
    // Auto-format screenplay elements
    this.editor.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') {
        const currentLine = this.getCurrentLine();
        const lineType = this.detectScreenplayElement(currentLine);
        
        setTimeout(() => {
          this.applyScreenplayFormatting(lineType);
        }, 10);
      }
      
      // Tab for dialogue indentation
      if (e.key === 'Tab') {
        e.preventDefault();
        this.cycleScreenplayElements();
      }
    });
  },

  setupNovelFormatting() {
    // Smart quotes and em-dashes
    this.editor.addEventListener('keydown', (e) => {
      if (e.key === '"') {
        e.preventDefault();
        this.insertSmartQuote();
      }
      
      if (e.key === '-' && e.ctrlKey) {
        e.preventDefault();
        this.insertEmDash();
      }
    });
  },

  setupBusinessFormatting() {
    // Auto-numbering and bullet points
    this.editor.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') {
        const currentLine = this.getCurrentLine();
        if (this.isNumberedList(currentLine)) {
          setTimeout(() => {
            this.continueNumberedList(currentLine);
          }, 10);
        }
      }
    });
  },

  setupLiveStoryFormatting() {
    // Choice point creation
    this.editor.addEventListener('keydown', (e) => {
      if (e.key === '[' && e.ctrlKey) {
        e.preventDefault();
        this.insertChoicePoint();
      }
    });
  },

  setupKeyboardShortcuts() {
    this.editor.addEventListener('keydown', (e) => {
      // Bold
      if (e.key === 'b' && (e.ctrlKey || e.metaKey)) {
        e.preventDefault();
        this.toggleFormat('bold');
      }
      
      // Italic
      if (e.key === 'i' && (e.ctrlKey || e.metaKey)) {
        e.preventDefault();
        this.toggleFormat('italic');
      }
      
      // AI suggestions
      if (e.key === '/' && (e.ctrlKey || e.metaKey)) {
        e.preventDefault();
        this.pushEvent('toggle_ai_panel', {});
      }
      
      // Manual save
      if (e.key === 's' && (e.ctrlKey || e.metaKey)) {
        e.preventDefault();
        this.pushEvent('manual_save', {});
      }
      
      // Voice input
      if (e.key === 'v' && e.ctrlKey && e.shiftKey) {
        e.preventDefault();
        this.pushEvent('voice_input_start', {});
      }
    });
  },

  debounceContentChange(content) {
    clearTimeout(this.saveTimeout);
    this.saveTimeout = setTimeout(() => {
      this.pushEvent('content_changed', {
        content: content,
        section_id: this.sectionId
      });
    }, 1000);
  },

  broadcastCursorPosition() {
    const selection = window.getSelection();
    if (selection.rangeCount > 0) {
      const range = selection.getRangeAt(0);
      const rect = range.getBoundingClientRect();
      const editorRect = this.editor.getBoundingClientRect();
      
      const position = {
        x: rect.left - editorRect.left,
        y: rect.top - editorRect.top,
        offset: this.getTextOffset(range.startContainer, range.startOffset)
      };
      
      this.pushEvent('cursor_position_changed', {
        section_id: this.sectionId,
        position: position
      });
    }
  },

  updateCollaboratorCursor(userId, position, userName) {
    let cursor = this.collaborators.get(userId);
    
    if (!cursor) {
      cursor = this.createCursor(userId, userName);
      this.collaborators.set(userId, cursor);
      this.cursorContainer.appendChild(cursor);
    }
    
    // Update cursor position
    cursor.style.left = position.x + 'px';
    cursor.style.top = position.y + 'px';
    cursor.dataset.user = userName;
    
    // Auto-hide after 10 seconds of inactivity
    clearTimeout(cursor.hideTimeout);
    cursor.style.opacity = '1';
    cursor.hideTimeout = setTimeout(() => {
      cursor.style.opacity = '0.3';
    }, 10000);
  },

  createCursor(userId, userName) {
    const cursor = document.createElement('div');
    cursor.className = 'collaborator-cursor';
    cursor.dataset.userId = userId;
    cursor.dataset.user = userName;
    
    // Random color for each user
    const colors = ['#3B82F6', '#10B981', '#F59E0B', '#EF4444', '#8B5CF6', '#06B6D4'];
    const color = colors[userId.charCodeAt(0) % colors.length];
    cursor.style.setProperty('--cursor-color', color);
    
    return cursor;
  },

  createCursorContainer() {
    const container = document.createElement('div');
    container.id = 'collaborator-cursors';
    container.style.position = 'absolute';
    container.style.top = '0';
    container.style.left = '0';
    container.style.pointerEvents = 'none';
    this.editor.parentNode.style.position = 'relative';
    this.editor.parentNode.appendChild(container);
    return container;
  },

  updateContentWithoutTrigger(content) {
    // Save current cursor position
    const selection = window.getSelection();
    let cursorPosition = 0;
    
    if (selection.rangeCount > 0) {
      const range = selection.getRangeAt(0);
      cursorPosition = this.getTextOffset(range.startContainer, range.startOffset);
    }
    
    // Update content
    this.editor.innerHTML = content;
    this.lastContent = content;
    
    // Restore cursor position
    this.setCursorPosition(cursorPosition);
  },

  getTextOffset(node, offset) {
    let textOffset = 0;
    const walker = document.createTreeWalker(
      this.editor,
      NodeFilter.SHOW_TEXT,
      null,
      false
    );
    
    let currentNode;
    while (currentNode = walker.nextNode()) {
      if (currentNode === node) {
        return textOffset + offset;
      }
      textOffset += currentNode.textContent.length;
    }
    
    return textOffset;
  },

  setCursorPosition(offset) {
    const walker = document.createTreeWalker(
      this.editor,
      NodeFilter.SHOW_TEXT,
      null,
      false
    );
    
    let currentOffset = 0;
    let targetNode = null;
    let targetOffset = 0;
    
    let node;
    while (node = walker.nextNode()) {
      const nodeLength = node.textContent.length;
      
      if (currentOffset + nodeLength >= offset) {
        targetNode = node;
        targetOffset = offset - currentOffset;
        break;
      }
      
      currentOffset += nodeLength;
    }
    
    if (targetNode) {
      const range = document.createRange();
      range.setStart(targetNode, targetOffset);
      range.collapse(true);
      
      const selection = window.getSelection();
      selection.removeAllRanges();
      selection.addRange(range);
    }
  },

  // Format-specific helper methods
  getCurrentLine() {
    const selection = window.getSelection();
    if (selection.rangeCount === 0) return '';
    
    const range = selection.getRangeAt(0);
    let container = range.startContainer;
    
    while (container && container.nodeType === Node.TEXT_NODE) {
      container = container.parentNode;
    }
    
    return container ? container.textContent.trim() : '';
  },

  detectScreenplayElement(line) {
    if (line.match(/^[A-Z\s]+$/)) return 'character';
    if (line.match(/^\(/)) return 'parenthetical';
    if (line.match(/^(INT\.|EXT\.|FADE IN:|FADE OUT:)/i)) return 'scene_heading';
    if (line.match(/^(CUT TO:|DISSOLVE TO:)/i)) return 'transition';
    return 'dialogue';
  },

  applyScreenplayFormatting(elementType) {
    const selection = window.getSelection();
    if (selection.rangeCount === 0) return;
    
    const range = selection.getRangeAt(0);
    let container = range.startContainer;
    
    while (container && container.nodeType === Node.TEXT_NODE) {
      container = container.parentNode;
    }
    
    if (container) {
      // Apply format-specific styling
      container.className = `screenplay-${elementType}`;
    }
  },

  cycleScreenplayElements() {
    const currentLine = this.getCurrentLine();
    const currentType = this.detectScreenplayElement(currentLine);
    
    const cycle = ['scene_heading', 'character', 'dialogue', 'parenthetical', 'transition'];
    const currentIndex = cycle.indexOf(currentType);
    const nextType = cycle[(currentIndex + 1) % cycle.length];
    
    this.applyScreenplayFormatting(nextType);
  },

  insertSmartQuote() {
    const selection = window.getSelection();
    const range = selection.getRangeAt(0);
    
    // Determine if opening or closing quote based on context
    const beforeText = range.startContainer.textContent.substring(0, range.startOffset);
    const isOpening = !beforeText.match(/\w$/) || beforeText.match(/^\s*$/);
    
    const quote = isOpening ? '"' : '"';
    this.insertTextAtCursor(quote);
  },

  insertEmDash() {
    this.insertTextAtCursor('—');
  },

  insertChoicePoint() {
    const choiceHTML = `
      <div class="choice-point" contenteditable="false">
        <div class="choice-prompt" contenteditable="true">What should happen next?</div>
        <div class="choice-options">
          <div class="choice-option" contenteditable="true">Option A</div>
          <div class="choice-option" contenteditable="true">Option B</div>
        </div>
      </div>
      <p><br></p>
    `;
    
    this.insertHTMLAtCursor(choiceHTML);
  },

  isNumberedList(line) {
    return line.match(/^\d+\.\s/);
  },

  continueNumberedList(currentLine) {
    const match = currentLine.match(/^(\d+)\.\s/);
    if (match) {
      const nextNumber = parseInt(match[1]) + 1;
      this.insertTextAtCursor(`${nextNumber}. `);
    }
  },

  toggleFormat(format) {
    document.execCommand(format, false, null);
  },

  insertTextAtCursor(text) {
    const selection = window.getSelection();
    if (selection.rangeCount === 0) return;
    
    const range = selection.getRangeAt(0);
    range.deleteContents();
    
    const textNode = document.createTextNode(text);
    range.insertNode(textNode);
    
    // Move cursor after inserted text
    range.setStartAfter(textNode);
    range.setEndAfter(textNode);
    selection.removeAllRanges();
    selection.addRange(range);
  },

  insertHTMLAtCursor(html) {
    const selection = window.getSelection();
    if (selection.rangeCount === 0) return;
    
    const range = selection.getRangeAt(0);
    range.deleteContents();
    
    const fragment = range.createContextualFragment(html);
    range.insertNode(fragment);
    
    // Move cursor after inserted content
    range.setStartAfter(fragment);
    range.setEndAfter(fragment);
    selection.removeAllRanges();
    selection.addRange(range);
  },

  destroyed() {
    if (this.saveTimeout) {
      clearTimeout(this.saveTimeout);
    }
    
    if (this.cursorInterval) {
      clearInterval(this.cursorInterval);
    }
    
    // Clean up collaborator cursors
    this.collaborators.forEach(cursor => {
      if (cursor.hideTimeout) {
        clearTimeout(cursor.hideTimeout);
      }
    });
    
    if (this.cursorContainer) {
      this.cursorContainer.remove();
    }
  }
};

// Export for Phoenix LiveView hooks
export default { RichTextEditor };