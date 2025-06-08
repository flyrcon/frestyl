// Create this file: assets/js/hooks/sortable.js

const Sortable = {
  mounted() {
    this.initializeSortable();
  },

  updated() {
    this.initializeSortable();
  },

  initializeSortable() {
    // Clean up any existing sortable instance
    if (this.sortable) {
      this.sortable.destroy();
    }

    // Initialize sortable
    this.sortable = new window.Sortable(this.el, {
      animation: 150,
      ghostClass: 'sortable-ghost',
      chosenClass: 'sortable-chosen',
      dragClass: 'sortable-drag',
      handle: '.cursor-move', // Only allow dragging by the drag handle
      
      onEnd: (evt) => {
        // Get the new order of section IDs
        const sectionIds = Array.from(this.el.children).map(child => 
          child.getAttribute('data-id')
        ).filter(Boolean);

        // Send the new order to LiveView
        this.pushEvent('reorder_sections', { sections: sectionIds });
      }
    });
  },

  destroyed() {
    if (this.sortable) {
      this.sortable.destroy();
    }
  }
};

export default Sortable;

