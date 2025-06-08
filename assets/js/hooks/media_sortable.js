// assets/js/hooks/media_sortable.js

const MediaSortable = {
  mounted() {
    this.initSortable();
  },

  updated() {
    this.initSortable();
  },

  initSortable() {
    // Only initialize if we have items to sort
    const items = this.el.querySelectorAll('[data-media-id]');
    if (items.length === 0) return;

    // Simple drag and drop implementation
    this.setupDragAndDrop();
  },

  setupDragAndDrop() {
    const container = this.el;
    let draggedElement = null;
    let draggedOver = null;

    // Add drag listeners to all media items
    container.addEventListener('dragstart', (e) => {
      if (e.target.closest('[data-media-id]')) {
        draggedElement = e.target.closest('[data-media-id]');
        draggedElement.style.opacity = '0.5';
        e.dataTransfer.effectAllowed = 'move';
      }
    });

    container.addEventListener('dragend', (e) => {
      if (draggedElement) {
        draggedElement.style.opacity = '';
        draggedElement = null;
        draggedOver = null;
      }
    });

    container.addEventListener('dragover', (e) => {
      e.preventDefault();
      e.dataTransfer.dropEffect = 'move';
      
      const target = e.target.closest('[data-media-id]');
      if (target && target !== draggedElement) {
        draggedOver = target;
        target.style.borderTop = '3px solid #3b82f6';
      }
    });

    container.addEventListener('dragleave', (e) => {
      const target = e.target.closest('[data-media-id]');
      if (target) {
        target.style.borderTop = '';
      }
    });

    container.addEventListener('drop', (e) => {
      e.preventDefault();
      
      if (draggedElement && draggedOver && draggedElement !== draggedOver) {
        // Clear visual indicators
        draggedOver.style.borderTop = '';
        
        // Reorder elements in DOM
        const container = draggedElement.parentNode;
        const allItems = Array.from(container.querySelectorAll('[data-media-id]'));
        const draggedIndex = allItems.indexOf(draggedElement);
        const targetIndex = allItems.indexOf(draggedOver);
        
        if (draggedIndex < targetIndex) {
          container.insertBefore(draggedElement, draggedOver.nextSibling);
        } else {
          container.insertBefore(draggedElement, draggedOver);
        }
        
        // Send new order to server
        this.updateMediaOrder();
      }
    });

    // Make items draggable
    container.querySelectorAll('[data-media-id]').forEach(item => {
      item.draggable = true;
      item.style.cursor = 'move';
    });
  },

  updateMediaOrder() {
    const sectionId = this.el.dataset.sectionId;
    const mediaOrder = Array.from(this.el.querySelectorAll('[data-media-id]'))
      .map(item => item.dataset.mediaId);
    
    this.pushEvent('reorder_media', {
      section_id: sectionId,
      media_order: mediaOrder
    });
  }
};

export default MediaSortable;