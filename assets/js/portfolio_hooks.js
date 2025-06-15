// assets/js/portfolio_hooks.js - ADD TO YOUR app.js
const PortfolioHooks = {
  // ============================================================================
  // SORTABLE SECTIONS - FIXED DRAG AND DROP
  // ============================================================================
  SortableSections: {
    mounted() {
      console.log("🔄 SortableSections hook mounted");
      
      const container = this.el;
      let draggedElement = null;
      let placeholder = null;

      // Add drag handles and make sections draggable
      const sections = container.querySelectorAll('.section-item');
      sections.forEach(section => {
        section.draggable = true;
        
        // Find or create drag handle
        let dragHandle = section.querySelector('.section-drag-handle');
        if (!dragHandle) {
          // If no drag handle exists, make the whole section draggable
          dragHandle = section;
        }

        section.addEventListener('dragstart', (e) => {
          console.log("🎯 Drag started for section:", section.dataset.sectionId);
          draggedElement = section;
          e.dataTransfer.effectAllowed = 'move';
          e.dataTransfer.setData('text/html', section.outerHTML);
          
          // Create placeholder
          placeholder = document.createElement('div');
          placeholder.className = 'section-placeholder bg-blue-100 border-2 border-dashed border-blue-300 rounded-lg p-4 mb-4';
          placeholder.innerHTML = '<p class="text-blue-600 text-center">Drop section here</p>';
          
          // Add visual feedback
          section.style.opacity = '0.5';
          section.classList.add('dragging');
        });

        section.addEventListener('dragend', (e) => {
          console.log("🏁 Drag ended");
          section.style.opacity = '1';
          section.classList.remove('dragging');
          
          if (placeholder && placeholder.parentNode) {
            placeholder.remove();
          }
        });

        section.addEventListener('dragover', (e) => {
          e.preventDefault();
          e.dataTransfer.dropEffect = 'move';
          
          if (draggedElement && section !== draggedElement) {
            const rect = section.getBoundingClientRect();
            const midpoint = rect.top + rect.height / 2;
            
            if (e.clientY < midpoint) {
              section.parentNode.insertBefore(placeholder, section);
            } else {
              section.parentNode.insertBefore(placeholder, section.nextSibling);
            }
          }
        });

        section.addEventListener('drop', (e) => {
          e.preventDefault();
          
          if (draggedElement && placeholder) {
            // Insert dragged element where placeholder is
            placeholder.parentNode.insertBefore(draggedElement, placeholder);
            placeholder.remove();
            
            // Get new order
            const newOrder = Array.from(container.querySelectorAll('.section-item'))
              .map(el => el.dataset.sectionId)
              .filter(id => id); // Remove any undefined values
            
            console.log("📋 New section order:", newOrder);
            
            // Send to server
            this.pushEvent("reorder_sections", { sections: newOrder });
            
            // Visual feedback
            draggedElement.classList.add('section-updated');
            setTimeout(() => {
              draggedElement.classList.remove('section-updated');
            }, 1000);
          }
        });
      });
    }
  },

  // ============================================================================
  // REAL-TIME TEMPLATE PREVIEW
  // ============================================================================
  TemplatePreview: {
    mounted() {
      console.log("🎨 TemplatePreview hook mounted");
      
      // Listen for template updates from server
      this.handleEvent("template_applied", (data) => {
        console.log("🎨 Template applied:", data.template);
        this.updatePreviewCSS(data.css);
        this.showTemplateFeedback(data.template);
      });

      this.handleEvent("customization_updated", (data) => {
        console.log("🎨 Customization updated");
        this.updatePreviewCSS(data.css);
      });

      this.handleEvent("customization_reset", (data) => {
        console.log("🔄 Customization reset");
        this.updatePreviewCSS(data.css);
        this.showFeedback("Customization reset to defaults");
      });
    },

    updatePreviewCSS(css) {
      // Remove existing preview CSS
      const existingCSS = document.getElementById('portfolio-preview-css');
      if (existingCSS) {
        existingCSS.remove();
      }

      // Add new CSS
      if (css) {
        document.head.insertAdjacentHTML('beforeend', css);
      }

      // Force re-render of preview elements
      const previewElements = document.querySelectorAll('.portfolio-preview, .template-preview-card');
      previewElements.forEach(el => {
        el.style.opacity = '0.8';
        setTimeout(() => {
          el.style.opacity = '1';
        }, 100);
      });
    },

    showTemplateFeedback(template) {
      // Show visual feedback that template was applied
      const templateCards = document.querySelectorAll('[phx-value-template]');
      templateCards.forEach(card => {
        if (card.getAttribute('phx-value-template') === template) {
          card.classList.add('template-applied');
          card.style.transform = 'scale(1.05)';
          setTimeout(() => {
            card.classList.remove('template-applied');
            card.style.transform = 'scale(1)';
          }, 500);
        }
      });
    },

    showFeedback(message) {
      // Create temporary feedback message
      const feedback = document.createElement('div');
      feedback.className = 'fixed top-4 right-4 bg-green-500 text-white px-4 py-2 rounded-lg shadow-lg z-50 transition-all';
      feedback.textContent = message;
      document.body.appendChild(feedback);

      setTimeout(() => {
        feedback.style.opacity = '0';
        feedback.style.transform = 'translateY(-20px)';
        setTimeout(() => feedback.remove(), 300);
      }, 2000);
    }
  },

  // ============================================================================
  // SECTION MANAGEMENT FEEDBACK
  // ============================================================================
  SectionManager: {
    mounted() {
      console.log("📝 SectionManager hook mounted");
      
      this.handleEvent("section_added", (data) => {
        console.log("➕ Section added:", data.section_id);
        this.highlightNewSection(data.section_id);
      });

      this.handleEvent("section_deleted", (data) => {
        console.log("🗑️ Section deleted:", data.section_id);
        this.showDeleteFeedback();
      });

      this.handleEvent("sections_reordered", (data) => {
        console.log("🔄 Sections reordered:", data.section_count);
        this.showReorderFeedback();
      });

      this.handleEvent("section_visibility_toggled", (data) => {
        console.log("👁️ Section visibility toggled:", data.section_id, data.visible);
        this.updateVisibilityIndicator(data.section_id, data.visible);
      });
    },

    highlightNewSection(sectionId) {
      setTimeout(() => {
        const section = document.querySelector(`[data-section-id="${sectionId}"]`);
        if (section) {
          section.classList.add('section-highlight');
          section.scrollIntoView({ behavior: 'smooth', block: 'center' });
          
          setTimeout(() => {
            section.classList.remove('section-highlight');
          }, 2000);
        }
      }, 100);
    },

    showDeleteFeedback() {
      // Animate remaining sections
      const sections = document.querySelectorAll('.section-item');
      sections.forEach((section, index) => {
        setTimeout(() => {
          section.style.transform = 'translateX(-10px)';
          setTimeout(() => {
            section.style.transform = 'translateX(0)';
          }, 150);
        }, index * 50);
      });
    },

    showReorderFeedback() {
      // Animate all sections to show new order
      const sections = document.querySelectorAll('.section-item');
      sections.forEach((section, index) => {
        setTimeout(() => {
          section.classList.add('section-reordered');
          setTimeout(() => {
            section.classList.remove('section-reordered');
          }, 300);
        }, index * 100);
      });
    },

    updateVisibilityIndicator(sectionId, visible) {
      const section = document.querySelector(`[data-section-id="${sectionId}"]`);
      if (section) {
        const indicator = section.querySelector('.visibility-indicator');
        if (indicator) {
          indicator.textContent = visible ? '👁️' : '🙈';
          indicator.title = visible ? 'Section is visible' : 'Section is hidden';
        }
        
        // Add visual feedback
        section.style.opacity = visible ? '1' : '0.6';
      }
    }
  },

  // ============================================================================
  // COLOR PICKER INTEGRATION
  // ============================================================================
  ColorPicker: {
    mounted() {
      console.log("🎨 ColorPicker hook mounted");
      
      // Enhanced color input handling
      const colorInputs = this.el.querySelectorAll('input[type="color"]');
      colorInputs.forEach(input => {
        input.addEventListener('change', (e) => {
          const color = e.target.value;
          console.log("🎨 Color changed:", color);
          
          // Immediate visual feedback
          this.updateColorPreview(color, e.target);
          
          // Debounced server update
          clearTimeout(this.colorUpdateTimeout);
          this.colorUpdateTimeout = setTimeout(() => {
            // The phx-change will handle the server update
          }, 300);
        });
      });

      // Text input synchronization
      const textInputs = this.el.querySelectorAll('input[type="text"]');
      textInputs.forEach(input => {
        input.addEventListener('input', (e) => {
          const color = e.target.value;
          if (this.isValidHexColor(color)) {
            // Update corresponding color input
            const colorInput = input.parentElement.querySelector('input[type="color"]');
            if (colorInput) {
              colorInput.value = color;
            }
            this.updateColorPreview(color, input);
          }
        });
      });
    },

    updateColorPreview(color, input) {
      // Update preview swatches immediately
      const previewElements = document.querySelectorAll('.color-swatch-primary, .color-swatch-secondary, .color-swatch-accent');
      const type = input.getAttribute('phx-value-type') || this.getColorTypeFromInput(input);
      
      if (type) {
        const targetClass = `.color-swatch-${type}`;
        const targetElements = document.querySelectorAll(targetClass);
        targetElements.forEach(el => {
          el.style.backgroundColor = color;
        });
      }
    },

    getColorTypeFromInput(input) {
      // Determine color type from input context
      const parent = input.closest('div');
      if (parent.textContent.includes('Primary')) return 'primary';
      if (parent.textContent.includes('Secondary')) return 'secondary';
      if (parent.textContent.includes('Accent')) return 'accent';
      return null;
    },

    isValidHexColor(color) {
      return /^#[0-9A-F]{6}$/i.test(color);
    }
  },

  // ============================================================================
  // PREVIEW IFRAME MANAGEMENT
  // ============================================================================
  PreviewFrame: {
    mounted() {
      console.log("📱 PreviewFrame hook mounted");
      
      this.handleEvent("refresh_preview", () => {
        const iframe = this.el.querySelector('iframe');
        if (iframe) {
          iframe.src = iframe.src; // Force reload
        }
      });

      this.handleEvent("toggle_preview", () => {
        const previewContainer = document.querySelector('.preview-container');
        if (previewContainer) {
          previewContainer.classList.toggle('preview-visible');
        }
      });
    }
  }
};

