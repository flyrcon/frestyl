// assets/js/portfolio_hooks.js - ADD TO YOUR app.js
const PortfolioHooks = {

  // ============================================================================
  // 🔥 FIXED: TEMPLATE MANAGEMENT WITH PROPER PREVIEW UPDATES
  // ============================================================================
  TemplateManager: {
    mounted() {
      console.log("🎨 TemplateManager hook mounted");
      
      // Handle template changes with immediate preview refresh
      this.handleEvent("refresh_portfolio_preview", (data) => {
        console.log("🔄 Refreshing portfolio preview", data);
        this.refreshPreview(data.template);
      });

      // Handle scheduled preview refresh for styling changes
      this.handleEvent("schedule_preview_refresh", (data) => {
        console.log("⏰ Scheduling preview refresh", data);
        clearTimeout(this.refreshTimeout);
        this.refreshTimeout = setTimeout(() => {
          this.refreshPreview();
        }, data.delay || 500);
      });

      // Handle immediate CSS updates
      this.handleEvent("update_preview_css", (data) => {
        console.log("🎨 Updating preview CSS immediately", data);
        this.updatePreviewCSS(data.css);
      });

      // Handle template selection feedback
      this.handleEvent("template_selected", (data) => {
        console.log("✅ Template selected", data);
        this.showTemplateFeedback(data.template);
        this.refreshPreview(data.template);
      });

      // Handle customization reset
      this.handleEvent("customization_reset", (data) => {
        console.log("🔄 Customization reset", data);
        this.updatePreviewCSS(data.css);
        this.showFeedback("Customization reset to defaults");
      });
    },

    // 🔥 CRITICAL FIX: Improved preview refresh
    refreshPreview(template) {
      const iframe = document.getElementById("design-preview");
      if (iframe) {
        const baseUrl = iframe.src.split('?')[0];
        const newUrl = baseUrl + 
          "?preview=true" + 
          (template ? `&template=${template}` : "") +
          "&t=" + Date.now();
        
        console.log("🔄 Refreshing iframe:", newUrl);
        iframe.src = newUrl;
      } else {
        console.warn("⚠️ Preview iframe not found");
      }
    },

    // Update preview CSS immediately for better UX
    updatePreviewCSS(css) {
      if (!css) return;
      
      // Only update if this is the main template manager
      if (this.el.id === 'template-manager-main') {
        // Remove existing preview CSS
        const existingCSS = document.getElementById('template-preview-css');
        if (existingCSS) {
          existingCSS.remove();
        }

        // Add new CSS with template-specific ID
        const style = document.createElement('style');
        style.id = 'template-preview-css';
        style.innerHTML = css;
        document.head.appendChild(style);
        
        console.log("✅ Template preview CSS updated");
      }
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
  // 🔥 FIXED: COLOR PICKER WITH LIVE UPDATES
  // ============================================================================
  ColorPickerLive: {
    mounted() {
      console.log("🎨 Live Color Picker mounted");
      this.setupColorPickers();
    },

    setupColorPickers() {
      // Handle all color inputs
      const colorInputs = this.el.querySelectorAll('input[type="color"], input[type="text"]');
      
      colorInputs.forEach(input => {
        // Debounced update for text inputs
        if (input.type === 'text') {
          let timeout;
          input.addEventListener('input', (e) => {
            clearTimeout(timeout);
            timeout = setTimeout(() => {
              if (this.isValidHexColor(e.target.value)) {
                this.updateColor(input, e.target.value);
              }
            }, 300);
          });
        }
        
        // Immediate update for color inputs
        if (input.type === 'color') {
          input.addEventListener('change', (e) => {
            this.updateColor(input, e.target.value);
          });
        }
      });
    },

    updateColor(input, color) {
      const colorType = this.getColorType(input);
      if (colorType) {
        console.log(`🎨 Updating ${colorType} color to ${color}`);
        
        // Update CSS custom property immediately
        document.documentElement.style.setProperty(`--${colorType}-color`, color);
        
        // Update both text and color inputs
        const container = input.closest('div');
        if (container) {
          const textInput = container.querySelector('input[type="text"]');
          const colorInput = container.querySelector('input[type="color"]');
          
          if (textInput && textInput !== input) {
            textInput.value = color;
          }
          if (colorInput && colorInput !== input) {
            colorInput.value = color;
          }
        }
        
        // Trigger preview update
        this.pushEvent(`update_${colorType}_color`, { value: color });
      }
    },

    getColorType(input) {
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
  // 🔥 FIXED: TEMPLATE SELECTOR WITH VISUAL FEEDBACK
  // ============================================================================
  TemplateSelector: {
    mounted() {
      console.log("🎨 Template Selector mounted");
      this.el.addEventListener('click', (e) => {
        const templateCard = e.target.closest('.template-preview-card');
        if (templateCard) {
          // Add loading state
          const loading = templateCard.querySelector('.template-loading');
          if (loading) {
            loading.classList.remove('hidden');
            loading.classList.add('flex');
          }
          
          // Update selection immediately for better UX
          this.updateTemplateSelection(templateCard);
        }
      });
    },
    
    updateTemplateSelection(selectedCard) {
      // Remove selection from all cards
      const allCards = document.querySelectorAll('.template-preview-card');
      allCards.forEach(card => {
        card.classList.remove('border-blue-500', 'shadow-lg', 'ring-2', 'ring-blue-200', 'bg-blue-50');
        card.classList.add('border-gray-200', 'bg-white');
        
        // Hide selection indicator
        const indicator = card.querySelector('.absolute.top-2.right-2');
        if (indicator) {
          indicator.style.display = 'none';
        }
      });
      
      // Add selection to clicked card
      selectedCard.classList.remove('border-gray-200', 'bg-white');
      selectedCard.classList.add('border-blue-500', 'shadow-lg', 'ring-2', 'ring-blue-200', 'bg-blue-50');
      
      // Show selection indicator
      const indicator = selectedCard.querySelector('.absolute.top-2.right-2');
      if (indicator) {
        indicator.style.display = 'flex';
      }
    }
  },

  // ============================================================================
  // 🔥 FIXED: PREVIEW IFRAME MANAGEMENT
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

      // Prevent iframe content from affecting parent page
      const iframe = this.el.querySelector('iframe');
      if (iframe) {
        iframe.onload = () => {
          try {
            // Isolate iframe content
            if (iframe.contentDocument) {
              iframe.contentDocument.body.style.isolation = 'isolate';
            }
          } catch (e) {
            // Cross-origin, ignore
          }
        };
      }
    }
  },

  // ============================================================================
  // 🔥 FIXED: SECTION MANAGEMENT FEEDBACK
  // ============================================================================
  SectionManager: {
    mounted() {
      console.log("📝 SectionManager hook mounted");
      
      this.handleEvent("section_added", (data) => {
        console.log("➕ Section added:", data.section);
        this.showSectionFeedback("Section added successfully!", "success");
      });

      this.handleEvent("section_updated", (data) => {
        console.log("✏️ Section updated:", data.section);
        this.showSectionFeedback("Section updated successfully!", "success");
      });

      this.handleEvent("section_deleted", (data) => {
        console.log("🗑️ Section deleted:", data.section_id);
        this.showSectionFeedback("Section deleted successfully!", "info");
      });

      this.handleEvent("section_reordered", (data) => {
        console.log("🔄 Sections reordered:", data.new_order);
        this.showSectionFeedback("Section order updated!", "info");
      });

      // Handle section content auto-save
      this.setupAutoSave();
    },

    setupAutoSave() {
      // Auto-save for text areas and inputs in sections
      const sectionInputs = this.el.querySelectorAll('textarea, input[type="text"]');
      
      sectionInputs.forEach(input => {
        let timeout;
        input.addEventListener('input', (e) => {
          clearTimeout(timeout);
          
          // Show saving indicator
          this.showSavingIndicator(input);
          
          timeout = setTimeout(() => {
            this.autoSaveSection(input, e.target.value);
          }, 1000); // Auto-save after 1 second of no typing
        });
      });
    },

    autoSaveSection(input, value) {
      const sectionId = input.closest('[data-section-id]')?.getAttribute('data-section-id');
      const fieldName = input.getAttribute('name') || input.getAttribute('data-field');
      
      if (sectionId && fieldName) {
        console.log(`💾 Auto-saving section ${sectionId}, field ${fieldName}`);
        
        this.pushEvent("save_section_field", {
          section_id: sectionId,
          field: fieldName,
          value: value
        });
        
        this.hideSavingIndicator(input);
        this.showSavedIndicator(input);
      }
    },

    showSavingIndicator(input) {
      const indicator = input.parentElement.querySelector('.saving-indicator');
      if (indicator) {
        indicator.textContent = 'Saving...';
        indicator.className = 'saving-indicator text-xs text-yellow-600';
      }
    },

    showSavedIndicator(input) {
      const indicator = input.parentElement.querySelector('.saving-indicator');
      if (indicator) {
        indicator.textContent = 'Saved';
        indicator.className = 'saving-indicator text-xs text-green-600';
        
        setTimeout(() => {
          indicator.textContent = '';
        }, 2000);
      }
    },

    hideSavingIndicator(input) {
      const indicator = input.parentElement.querySelector('.saving-indicator');
      if (indicator) {
        indicator.textContent = '';
      }
    },

    showSectionFeedback(message, type) {
      const colors = {
        success: 'bg-green-500',
        error: 'bg-red-500',
        info: 'bg-blue-500',
        warning: 'bg-yellow-500'
      };

      const feedback = document.createElement('div');
      feedback.className = `fixed bottom-4 right-4 ${colors[type] || colors.info} text-white px-4 py-2 rounded-lg shadow-lg z-50 transition-all transform translate-y-full`;
      feedback.textContent = message;
      document.body.appendChild(feedback);

      setTimeout(() => {
        feedback.classList.remove('translate-y-full');
      }, 100);

      setTimeout(() => {
        feedback.classList.add('translate-y-full');
        setTimeout(() => feedback.remove(), 300);
      }, 3000);
    }
  },

  // ============================================================================
  // 🔥 FIXED: VIDEO INTRO MANAGEMENT
  // ============================================================================
  VideoIntroManager: {
    mounted() {
      console.log("🎥 VideoIntroManager hook mounted");
      
      this.handleEvent("video_intro_visibility_toggled", (data) => {
        console.log("👁️ Video intro visibility toggled:", data);
        const message = data.visible ? 
          "Video introduction is now visible on your portfolio" : 
          "Video introduction is now hidden from your portfolio";
        this.showVideoFeedback(message, data.visible ? "success" : "info");
      });

      this.handleEvent("video_intro_uploaded", (data) => {
        console.log("📹 Video intro uploaded:", data);
        this.showVideoFeedback("Video introduction uploaded successfully!", "success");
      });
    },

    showVideoFeedback(message, type) {
      const colors = {
        success: 'bg-green-500',
        info: 'bg-blue-500',
        error: 'bg-red-500'
      };

      const feedback = document.createElement('div');
      feedback.className = `fixed top-4 left-1/2 transform -translate-x-1/2 ${colors[type]} text-white px-6 py-3 rounded-lg shadow-lg z-50 transition-all`;
      feedback.innerHTML = `
        <div class="flex items-center space-x-2">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
          </svg>
          <span>${message}</span>
        </div>
      `;
      document.body.appendChild(feedback);

      setTimeout(() => {
        feedback.style.opacity = '0';
        feedback.style.transform = 'translate(-50%, -20px)';
        setTimeout(() => feedback.remove(), 300);
      }, 4000);
    }
  },
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

