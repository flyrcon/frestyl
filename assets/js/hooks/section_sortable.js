// assets/js/hooks/section_sortable.js - FIXED VERSION
import Sortable from 'sortablejs';

const SortableSections = {
  mounted() {
    console.log('🔄 SortableSections hook mounted on:', this.el.id);
    this.initializeSortable();
  },

  updated() {
    console.log('🔄 SortableSections hook updated');
    this.destroySortable();
    this.initializeSortable();
  },

  destroyed() {
    console.log('🔄 SortableSections hook destroyed');
    this.destroySortable();
  },

  initializeSortable() {
    // Check if Sortable library is available
    if (typeof Sortable === 'undefined') {
      console.error('❌ Sortable library not found. Please install SortableJS.');
      return;
    }

    // Clean up any existing instance
    this.destroySortable();

    // Initialize sortable with proper configuration
    this.sortable = new Sortable(this.el, {
      animation: 200,
      ghostClass: 'section-ghost',
      chosenClass: 'section-chosen', 
      dragClass: 'section-drag',
      handle: '.section-drag-handle', // Only use the drag handle
      forceFallback: true, // Better mobile support
      
      onStart: (evt) => {
        console.log('🎯 Section drag started from index:', evt.oldIndex);
        evt.item.classList.add('dragging');
        document.body.classList.add('sections-reordering');
        this.el.classList.add('reordering-active');
      },

      onEnd: (evt) => {
        console.log('🎯 Section drag ended - Old:', evt.oldIndex, 'New:', evt.newIndex);
        
        evt.item.classList.remove('dragging');
        document.body.classList.remove('sections-reordering');
        this.el.classList.remove('reordering-active');
        
        // Only send event if position actually changed
        if (evt.oldIndex !== evt.newIndex) {
          // Get the new order of section IDs
          const sectionIds = Array.from(this.el.children)
            .map(child => child.getAttribute('data-section-id'))
            .filter(Boolean);

          console.log('📤 Sending reorder event with section IDs:', sectionIds);

          // Send the new order to LiveView
          this.pushEvent('reorder_sections', { 
            sections: sectionIds,
            old_index: evt.oldIndex,
            new_index: evt.newIndex
          });
        }
      }
    });

    console.log('✅ SortableSections initialized successfully');
  },

  destroySortable() {
    if (this.sortable) {
      this.sortable.destroy();
      this.sortable = null;
      console.log('🗑️ SortableSections destroyed');
    }
  }
};

export default SortableSections;