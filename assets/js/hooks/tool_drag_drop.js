// Desktop Tool Drag & Drop Hook
const ToolDragDrop = {
  mounted() {
    this.draggedElement = null;
    this.placeholder = null;
    this.isDragging = false;
    
    // Initialize drag handlers for all tool panels
    this.initializeDragHandlers();
    
    // Initialize drop zones
    this.initializeDropZones();
  },

  initializeDragHandlers() {
    const dragHandles = this.el.querySelectorAll('[data-drag-handle]');
    
    dragHandles.forEach(handle => {
      const toolPanel = handle.closest('[data-tool-id]');
      if (toolPanel) {
        toolPanel.draggable = true;
        toolPanel.addEventListener('dragstart', this.handleDragStart.bind(this));
        toolPanel.addEventListener('dragend', this.handleDragEnd.bind(this));
      }
    });
  },

  initializeDropZones() {
    const dropZones = [
      { selector: '#left-dock', area: 'left_dock' },
      { selector: '#right-dock', area: 'right_dock' },
      { selector: '#bottom-dock', area: 'bottom_dock' },
      { selector: '#main-content', area: 'floating' }
    ];

    dropZones.forEach(zone => {
      const element = document.querySelector(zone.selector);
      if (element) {
        element.addEventListener('dragover', this.handleDragOver.bind(this));
        element.addEventListener('drop', (e) => this.handleDrop(e, zone.area));
        element.addEventListener('dragenter', this.handleDragEnter.bind(this));
        element.addEventListener('dragleave', this.handleDragLeave.bind(this));
      }
    });
  },

  handleDragStart(e) {
    this.draggedElement = e.target;
    this.isDragging = true;
    
    const toolId = e.target.dataset.toolId;
    e.dataTransfer.setData('text/plain', toolId);
    e.dataTransfer.effectAllowed = 'move';
    
    // Add dragging class
    e.target.classList.add('dragging');
    
    // Create placeholder
    this.createPlaceholder();
    
    // Highlight valid drop zones
    this.highlightDropZones(true);
  },

  handleDragEnd(e) {
    this.isDragging = false;
    
    // Remove dragging class
    e.target.classList.remove('dragging');
    
    // Remove placeholder
    if (this.placeholder) {
      this.placeholder.remove();
      this.placeholder = null;
    }
    
    // Remove drop zone highlights
    this.highlightDropZones(false);
    
    this.draggedElement = null;
  },

  handleDragOver(e) {
    e.preventDefault();
    e.dataTransfer.dropEffect = 'move';
  },

  handleDragEnter(e) {
    e.preventDefault();
    e.target.classList.add('drag-over');
  },

  handleDragLeave(e) {
    e.target.classList.remove('drag-over');
  },

  handleDrop(e, dockArea) {
    e.preventDefault();
    e.target.classList.remove('drag-over');
    
    const toolId = e.dataTransfer.getData('text/plain');
    
    if (toolId && this.draggedElement) {
      // Send move event to LiveView
      this.pushEvent("move_tool_to_dock", {
        tool_id: toolId,
        dock_area: dockArea
      });
      
      // Visual feedback
      this.showDropSuccess(e.target);
    }
  },

  createPlaceholder() {
    this.placeholder = document.createElement('div');
    this.placeholder.className = 'tool-placeholder bg-gray-600 border-2 border-dashed border-gray-500 rounded-lg opacity-50';
    this.placeholder.style.height = this.draggedElement.offsetHeight + 'px';
    this.placeholder.textContent = 'Drop tool here';
    
    // Insert placeholder after dragged element
    this.draggedElement.parentNode.insertBefore(this.placeholder, this.draggedElement.nextSibling);
  },

  highlightDropZones(highlight) {
    const dropZones = document.querySelectorAll('#left-dock, #right-dock, #bottom-dock, #main-content');
    
    dropZones.forEach(zone => {
      if (highlight) {
        zone.classList.add('drop-zone-active');
      } else {
        zone.classList.remove('drop-zone-active', 'drag-over');
      }
    });
  },

  showDropSuccess(dropZone) {
    dropZone.classList.add('drop-success');
    setTimeout(() => {
      dropZone.classList.remove('drop-success');
    }, 300);
  },

  destroyed() {
    // Clean up event listeners
    const dragHandles = this.el.querySelectorAll('[data-drag-handle]');
    dragHandles.forEach(handle => {
      const toolPanel = handle.closest('[data-tool-id]');
      if (toolPanel) {
        toolPanel.removeEventListener('dragstart', this.handleDragStart);
        toolPanel.removeEventListener('dragend', this.handleDragEnd);
      }
    });
  }
};

export default ToolDragDrop;