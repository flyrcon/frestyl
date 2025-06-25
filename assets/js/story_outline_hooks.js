// assets/js/story_outline_hooks.js
// Add this to your existing Phoenix LiveView hooks

export const DragDropOutline = {
  mounted() {
    this.initializeDragDrop();
  },

  updated() {
    this.initializeDragDrop();
  },

  initializeDragDrop() {
    const container = this.el;
    const sections = container.querySelectorAll('[data-section-index]');
    
    sections.forEach(section => {
      // Remove existing listeners to prevent duplicates
      section.removeEventListener('dragstart', this.handleDragStart);
      section.removeEventListener('dragover', this.handleDragOver);
      section.removeEventListener('drop', this.handleDrop);
      section.removeEventListener('dragend', this.handleDragEnd);
      
      // Add drag event listeners
      section.addEventListener('dragstart', this.handleDragStart.bind(this));
      section.addEventListener('dragover', this.handleDragOver.bind(this));
      section.addEventListener('drop', this.handleDrop.bind(this));
      section.addEventListener('dragend', this.handleDragEnd.bind(this));
    });
  },

  handleDragStart(e) {
    const sectionIndex = e.target.getAttribute('data-section-index');
    e.dataTransfer.setData('text/plain', sectionIndex);
    e.target.style.opacity = '0.5';
    
    // Add visual feedback
    e.target.classList.add('dragging');
    
    // Push event to LiveView
    this.pushEvent('section_drag_start', { index: parseInt(sectionIndex) });
  },

  handleDragOver(e) {
    e.preventDefault();
    e.dataTransfer.dropEffect = 'move';
    
    // Add visual feedback for drop zone
    const rect = e.currentTarget.getBoundingClientRect();
    const midpoint = rect.top + rect.height / 2;
    
    if (e.clientY < midpoint) {
      e.currentTarget.classList.add('drop-above');
      e.currentTarget.classList.remove('drop-below');
    } else {
      e.currentTarget.classList.add('drop-below');
      e.currentTarget.classList.remove('drop-above');
    }
  },

  handleDrop(e) {
    e.preventDefault();
    
    const draggedIndex = parseInt(e.dataTransfer.getData('text/plain'));
    const targetIndex = parseInt(e.currentTarget.getAttribute('data-section-index'));
    
    // Calculate drop position (above or below target)
    const rect = e.currentTarget.getBoundingClientRect();
    const midpoint = rect.top + rect.height / 2;
    const dropPosition = e.clientY < midpoint ? 'above' : 'below';
    
    // Clear visual feedback
    e.currentTarget.classList.remove('drop-above', 'drop-below');
    
    // Only proceed if dropping on a different section
    if (draggedIndex !== targetIndex) {
      // Push reorder event to LiveView
      this.pushEvent('reorder_sections', {
        from_index: draggedIndex,
        to_index: targetIndex,
        position: dropPosition
      });
    }
  },

  handleDragEnd(e) {
    // Clean up visual feedback
    e.target.style.opacity = '';
    e.target.classList.remove('dragging');
    
    // Remove drop zone indicators from all sections
    const sections = this.el.querySelectorAll('[data-section-index]');
    sections.forEach(section => {
      section.classList.remove('drop-above', 'drop-below');
    });
    
    // Push event to LiveView
    this.pushEvent('section_drag_end', {});
  }
};

// Character relationship visualization hook
export const CharacterRelationships = {
  mounted() {
    this.initializeRelationshipGraph();
  },

  updated() {
    this.initializeRelationshipGraph();
  },

  initializeRelationshipGraph() {
    const container = this.el.querySelector('#relationship-graph');
    if (!container) return;

    // Simple relationship visualization using basic DOM elements
    // In a production app, you might use D3.js or a similar library
    const characters = JSON.parse(container.dataset.characters || '[]');
    
    this.renderRelationshipGraph(container, characters);
  },

  renderRelationshipGraph(container, characters) {
    container.innerHTML = '';
    
    if (characters.length === 0) {
      container.innerHTML = '<p class="text-gray-500 text-center">No characters to display</p>';
      return;
    }

    // Create simple grid layout for characters
    const grid = document.createElement('div');
    grid.className = 'grid grid-cols-2 md:grid-cols-3 gap-4';
    
    characters.forEach((character, index) => {
      const characterNode = this.createCharacterNode(character, index);
      grid.appendChild(characterNode);
    });
    
    container.appendChild(grid);
  },

  createCharacterNode(character, index) {
    const node = document.createElement('div');
    node.className = 'bg-white border border-gray-200 rounded-lg p-3 cursor-pointer hover:shadow-md transition-shadow';
    node.dataset.characterId = character.id;
    
    node.innerHTML = `
      <div class="flex items-center space-x-2 mb-2">
        <div class="w-8 h-8 rounded-full bg-blue-500 flex items-center justify-center text-white text-sm font-medium">
          ${character.name.charAt(0)}
        </div>
        <div>
          <h4 class="font-medium text-gray-900 text-sm">${character.name}</h4>
          <p class="text-xs text-gray-600">${character.archetype}</p>
        </div>
      </div>
      ${character.relationships && character.relationships.length > 0 ? `
        <div class="text-xs text-gray-500">
          ${character.relationships.length} relationship${character.relationships.length !== 1 ? 's' : ''}
        </div>
      ` : ''}
    `;
    
    // Add click handler for character details
    node.addEventListener('click', () => {
      this.pushEvent('show_character_details', { character_id: character.id });
    });
    
    return node;
  }
};

// World bible search and navigation
export const WorldBibleSearch = {
  mounted() {
    this.initializeSearch();
  },

  initializeSearch() {
    const searchInput = this.el.querySelector('input[type="text"]');
    if (!searchInput) return;

    // Debounced search
    let searchTimeout;
    searchInput.addEventListener('input', (e) => {
      clearTimeout(searchTimeout);
      searchTimeout = setTimeout(() => {
        this.pushEvent('search_world_bible', { query: e.target.value });
      }, 300);
    });

    // Search shortcuts
    searchInput.addEventListener('keydown', (e) => {
      // Escape to clear search
      if (e.key === 'Escape') {
        e.target.value = '';
        this.pushEvent('clear_search', {});
      }
      
      // Enter to focus first result
      if (e.key === 'Enter') {
        e.preventDefault();
        const firstResult = this.el.querySelector('.world-entry');
        if (firstResult) {
          firstResult.focus();
        }
      }
    });
  }
};

// Auto-save functionality for story components
export const StoryAutoSave = {
  mounted() {
    this.initializeAutoSave();
  },

  initializeAutoSave() {
    // Auto-save on form changes
    const forms = this.el.querySelectorAll('form, input, textarea');
    
    forms.forEach(element => {
      element.addEventListener('input', this.debounceAutoSave.bind(this));
      element.addEventListener('change', this.debounceAutoSave.bind(this));
    });
  },

  debounceAutoSave(e) {
    clearTimeout(this.autoSaveTimeout);
    
    this.autoSaveTimeout = setTimeout(() => {
      // Show saving indicator
      this.showSavingIndicator();
      
      // Push auto-save event
      this.pushEvent('auto_save_story', {
        field: e.target.name,
        value: e.target.value,
        timestamp: Date.now()
      });
      
      // Hide saving indicator after delay
      setTimeout(() => {
        this.hideSavingIndicator();
      }, 1000);
    }, 2000); // Auto-save after 2 seconds of inactivity
  },

  showSavingIndicator() {
    const indicator = document.createElement('div');
    indicator.id = 'auto-save-indicator';
    indicator.className = 'fixed top-4 right-4 bg-blue-500 text-white px-3 py-1 rounded-lg text-sm z-50';
    indicator.textContent = 'Saving...';
    
    // Remove existing indicator
    const existing = document.getElementById('auto-save-indicator');
    if (existing) existing.remove();
    
    document.body.appendChild(indicator);
  },

  hideSavingIndicator() {
    const indicator = document.getElementById('auto-save-indicator');
    if (indicator) {
      indicator.textContent = 'Saved';
      indicator.className = 'fixed top-4 right-4 bg-green-500 text-white px-3 py-1 rounded-lg text-sm z-50';
      
      setTimeout(() => {
        indicator.remove();
      }, 2000);
    }
  }
};

// Collaborative cursors for story editing
export const CollaborativeCursors = {
  mounted() {
    this.initializeCursorTracking();
  },

  initializeCursorTracking() {
    const textareas = this.el.querySelectorAll('textarea, input[type="text"]');
    
    textareas.forEach(textarea => {
      textarea.addEventListener('selectionchange', this.handleSelectionChange.bind(this));
      textarea.addEventListener('input', this.handleTextChange.bind(this));
    });
  },

  handleSelectionChange(e) {
    const element = e.target;
    const start = element.selectionStart;
    const end = element.selectionEnd;
    
    // Convert cursor position to line/column for display
    const lines = element.value.substring(0, start).split('\n');
    const line = lines.length - 1;
    const column = lines[lines.length - 1].length;
    
    // Push cursor position to other collaborators
    this.pushEvent('update_cursor_position', {
      field: element.name || element.id,
      line: line,
      column: column,
      selection_start: start,
      selection_end: end
    });
  },

  handleTextChange(e) {
    // Handle text changes for operational transforms
    const element = e.target;
    
    this.pushEvent('text_content_changed', {
      field: element.name || element.id,
      content: element.value,
      cursor_position: element.selectionStart
    });
  }
};

// Export all hooks for use in app.js
export default {
  DragDropOutline,
  CharacterRelationships,
  WorldBibleSearch,
  StoryAutoSave,
  CollaborativeCursors
};