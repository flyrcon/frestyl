// assets/js/hooks/section_sortable.js - ENHANCED VERSION
const SectionSortable = {
  mounted() {
    console.log('SectionSortable hook mounted', this.el);
    this.initializeSortable();
  },

  updated() {
    console.log('SectionSortable hook updated');
    this.destroySortable();
    this.initializeSortable();
  },

  destroyed() {
    console.log('SectionSortable hook destroyed');
    this.destroySortable();
  },

  initializeSortable() {
    // Check if Sortable library is available
    if (typeof Sortable === 'undefined') {
      console.error('Sortable library not found. Please include SortableJS.');
      return;
    }

    // Clean up any existing instance
    this.destroySortable();

    // Initialize sortable with proper configuration
    this.sortable = new Sortable(this.el, {
      animation: 150,
      ghostClass: 'sortable-ghost',
      chosenClass: 'sortable-chosen',
      dragClass: 'sortable-drag',
      handle: '.drag-handle', // Only allow dragging by the drag handle
      forceFallback: true, // Better mobile support
      
      onStart: (evt) => {
        console.log('Drag started');
        evt.item.classList.add('dragging');
      },

      onEnd: (evt) => {
        console.log('Drag ended');
        evt.item.classList.remove('dragging');
        
        // Get the new order of section IDs
        const sectionIds = Array.from(this.el.children)
          .map(child => child.getAttribute('data-section-id'))
          .filter(Boolean);

        console.log('New section order:', sectionIds);

        // Send the new order to LiveView
        this.pushEvent('reorder_sections', { sections: sectionIds });
      }
    });

    console.log('Sortable initialized successfully');
  },

  destroySortable() {
    if (this.sortable) {
      this.sortable.destroy();
      this.sortable = null;
    }
  }
};

export default SectionSortable;