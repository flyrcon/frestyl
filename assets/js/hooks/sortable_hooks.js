// assets/js/hooks/sortable_hooks.js - CLEAN VERSION
import Sortable from 'sortablejs';

const SortableHooks = {
  // FIXED: Section Sortable Hook - Working drag and drop
  SectionSortable: {
    mounted() {
      console.log('🔄 SectionSortable hook mounted on:', this.el.id);
      this.initializeSortable();
    },

    updated() {
      console.log('🔄 SectionSortable hook updated');
      this.destroySortable();
      this.initializeSortable();
    },

    destroyed() {
      console.log('🔄 SectionSortable hook destroyed');
      this.destroySortable();
    },

    initializeSortable() {
      if (typeof Sortable === 'undefined') {
        console.error('❌ Sortable library not found. Please install SortableJS.');
        return;
      }

      this.destroySortable();

      this.sortable = new Sortable(this.el, {
        animation: 200,
        ghostClass: 'section-ghost',
        chosenClass: 'section-chosen',
        dragClass: 'section-drag',
        handle: '.drag-handle',
        forceFallback: true,
        
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
          
          if (evt.oldIndex !== evt.newIndex) {
            const sectionIds = Array.from(this.el.children)
              .map(child => child.getAttribute('data-section-id'))
              .filter(Boolean);

            console.log('📤 Sending reorder event with section IDs:', sectionIds);
            
            this.pushEvent('reorder_sections', { 
              sections: sectionIds 
            });
          }
        }
      });

      console.log('✅ SectionSortable initialized successfully');
    },

    destroySortable() {
      if (this.sortable) {
        this.sortable.destroy();
        this.sortable = null;
        console.log('🗑️ SectionSortable destroyed');
      }
    }
  },

  // Media Sortable Hook
  MediaSortable: {
    mounted() {
      console.log('🖼️ MediaSortable hook mounted');
      this.initializeSortable();
    },

    updated() {
      this.destroySortable();
      this.initializeSortable();
    },

    destroyed() {
      this.destroySortable();
    },

    initializeSortable() {
      if (typeof Sortable === 'undefined') return;

      this.destroySortable();

      this.sortable = new Sortable(this.el, {
        animation: 150,
        ghostClass: 'media-ghost',
        chosenClass: 'media-chosen',
        dragClass: 'media-drag',
        handle: '.media-drag-handle',
        
        onStart: (evt) => {
          evt.item.classList.add('dragging');
          this.el.classList.add('media-reordering');
        },
        
        onEnd: (evt) => {
          evt.item.classList.remove('dragging');
          this.el.classList.remove('media-reordering');
          
          if (evt.oldIndex !== evt.newIndex) {
            const sectionId = this.el.getAttribute('data-section-id');
            const mediaIds = Array.from(this.el.children)
              .map(child => child.getAttribute('data-media-id'))
              .filter(Boolean);

            this.pushEvent('reorder_media', { 
              section_id: sectionId, 
              media_order: mediaIds 
            });
          }
        }
      });
    },

    destroySortable() {
      if (this.sortable) {
        this.sortable.destroy();
        this.sortable = null;
      }
    }
  },

  // Skills Sortable Hook
  SkillsSortable: {
    mounted() {
      console.log('🎯 SkillsSortable hook mounted');
      this.initializeSortable();
    },

    updated() {
      this.destroySortable();
      this.initializeSortable();
    },

    destroyed() {
      this.destroySortable();
    },

    initializeSortable() {
      if (typeof Sortable === 'undefined') return;

      this.destroySortable();

      this.sortable = new Sortable(this.el, {
        animation: 150,
        ghostClass: 'skill-ghost',
        chosenClass: 'skill-chosen',
        dragClass: 'skill-drag',
        
        onEnd: (evt) => {
          if (evt.oldIndex !== evt.newIndex) {
            const sectionId = this.el.getAttribute('data-section-id');
            const skillOrder = Array.from(this.el.children)
              .map((child, index) => ({
                index: index,
                text: child.textContent.trim()
              }));

            this.pushEvent('reorder_skills', {
              section_id: sectionId,
              skill_order: skillOrder
            });
          }
        }
      });
    },

    destroySortable() {
      if (this.sortable) {
        this.sortable.destroy();
        this.sortable = null;
      }
    }
  },

  // Experience Entries Sortable Hook
  ExperienceSortable: {
    mounted() {
      console.log('💼 ExperienceSortable hook mounted');
      this.initializeSortable();
    },

    updated() {
      this.destroySortable();
      this.initializeSortable();
    },

    destroyed() {
      this.destroySortable();
    },

    initializeSortable() {
      if (typeof Sortable === 'undefined') return;

      this.destroySortable();

      this.sortable = new Sortable(this.el, {
        animation: 200,
        ghostClass: 'experience-ghost',
        chosenClass: 'experience-chosen',
        dragClass: 'experience-drag',
        handle: '.experience-drag-handle',
        
        onStart: (evt) => {
          evt.item.classList.add('dragging');
          this.el.classList.add('experience-reordering');
        },
        
        onEnd: (evt) => {
          evt.item.classList.remove('dragging');
          this.el.classList.remove('experience-reordering');
          
          if (evt.oldIndex !== evt.newIndex) {
            const sectionId = this.el.getAttribute('data-section-id');
            
            this.pushEvent('reorder_experience_entries', {
              section_id: sectionId,
              old_index: evt.oldIndex,
              new_index: evt.newIndex
            });
          }
        }
      });
    },

    destroySortable() {
      if (this.sortable) {
        this.sortable.destroy();
        this.sortable = null;
      }
    }
  },

  // Education Entries Sortable Hook
  EducationSortable: {
    mounted() {
      console.log('🎓 EducationSortable hook mounted');
      this.initializeSortable();
    },

    updated() {
      this.destroySortable();
      this.initializeSortable();
    },

    destroyed() {
      this.destroySortable();
    },

    initializeSortable() {
      if (typeof Sortable === 'undefined') return;

      this.destroySortable();

      this.sortable = new Sortable(this.el, {
        animation: 200,
        ghostClass: 'education-ghost',
        chosenClass: 'education-chosen',
        dragClass: 'education-drag',
        handle: '.education-drag-handle',
        
        onStart: (evt) => {
          evt.item.classList.add('dragging');
          this.el.classList.add('education-reordering');
        },
        
        onEnd: (evt) => {
          evt.item.classList.remove('dragging');
          this.el.classList.remove('education-reordering');
          
          if (evt.oldIndex !== evt.newIndex) {
            const sectionId = this.el.getAttribute('data-section-id');
            
            this.pushEvent('reorder_education_entries', {
              section_id: sectionId,
              old_index: evt.oldIndex,
              new_index: evt.newIndex
            });
          }
        }
      });
    },

    destroySortable() {
      if (this.sortable) {
        this.sortable.destroy();
        this.sortable = null;
      }
    }
  }
};

export default SortableHooks;