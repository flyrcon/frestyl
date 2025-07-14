const OptimizedSortableHooks = {
    SortableSections: {
    mounted() {
      console.log("📝 SortableSections hook mounted for PortfolioEditorFixed");
      this.initializeSortable();
      this.setupEventListeners();
    },

    updated() {
      // Only reinitialize if sections actually changed
      if (this.shouldReinitialize()) {
        console.log("🔄 Reinitializing sortable - sections changed");
        this.initializeSortable();
      }
    },

    shouldReinitialize() {
      const currentItems = this.el.querySelectorAll('[data-section-id]');
      const currentCount = currentItems.length;
      
      if (this.lastItemCount !== currentCount) {
        this.lastItemCount = currentCount;
        return true;
      }
      
      return false;
    },

    initializeSortable() {
      // Destroy existing sortable
      if (this.sortable) {
        this.sortable.destroy();
        this.sortable = null;
      }

      // Find the sections container
      const container = this.el.querySelector('#sections-list') || this.el;
      
      if (!container || typeof Sortable === 'undefined') {
        console.warn("⚠️ Sortable container or SortableJS not found");
        return;
      }

      try {
        this.sortable = Sortable.create(container, {
          handle: '.section-item',
          animation: 200,
          ghostClass: 'sortable-ghost',
          chosenClass: 'sortable-chosen',
          dragClass: 'sortable-drag',
          
          onStart: (evt) => {
            console.log("🎯 Drag started:", evt.oldIndex);
            document.body.classList.add('sorting-active');
          },
          
          onEnd: (evt) => {
            console.log("🎯 Drag ended:", evt.oldIndex, "->", evt.newIndex);
            document.body.classList.remove('sorting-active');
            
            if (evt.oldIndex !== evt.newIndex) {
              this.handleReorder();
            }
          }
        });

        this.lastItemCount = container.querySelectorAll('[data-section-id]').length;
        console.log("✅ SortableSections initialized successfully");
        
      } catch (error) {
        console.error("❌ Failed to initialize SortableJS:", error);
      }
    },

    handleReorder() {
      // Get all section IDs in their new order
      const sectionItems = this.el.querySelectorAll('[data-section-id]');
      const sectionIds = Array.from(sectionItems).map(item => 
        item.getAttribute('data-section-id')
      );

      console.log("🔄 New section order:", sectionIds);

      // Push the reorder event with the correct format
      this.pushEvent("reorder_sections", {
        section_ids: sectionIds
      });
    },

    setupEventListeners() {
      // Listen for section updates from PortfolioEditorFixed
      this.handleEvent("section_added", () => {
        setTimeout(() => this.initializeSortable(), 100);
      });

      this.handleEvent("section_deleted", () => {
        setTimeout(() => this.initializeSortable(), 100);
      });
    },

    destroyed() {
      if (this.sortable) {
        this.sortable.destroy();
      }
      document.body.classList.remove('sorting-active');
    }
  }
};