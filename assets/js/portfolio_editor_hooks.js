// assets/js/portfolio_editor_hooks.js

// Hook for sortable sections with drag and drop
const SortableSections = {
  mounted() {
    const container = this.el;
    let draggedElement = null;
    let placeholder = null;

    // Make sections sortable
    this.makeSortable(container);
    
    // Listen for section visibility changes
    this.handleEvent("section_visibility_changed", (data) => {
      this.updateSectionVisibility(data.section_id, data.visible);
    });
  },

  makeSortable(container) {
    const sections = container.querySelectorAll('[data-section-id]');
    
    sections.forEach(section => {
      section.draggable = true;
      section.style.cursor = 'grab';
      
      section.addEventListener('dragstart', this.handleDragStart.bind(this));
      section.addEventListener('dragover', this.handleDragOver.bind(this));
      section.addEventListener('drop', this.handleDrop.bind(this));
      section.addEventListener('dragend', this.handleDragEnd.bind(this));
    });
  },

  handleDragStart(e) {
    draggedElement = e.target.closest('[data-section-id]');
    draggedElement.style.opacity = '0.5';
    draggedElement.style.cursor = 'grabbing';
    
    // Create placeholder
    placeholder = document.createElement('div');
    placeholder.className = 'h-24 bg-blue-100 border-2 border-blue-300 border-dashed rounded-xl flex items-center justify-center text-blue-600 font-medium';
    placeholder.innerHTML = '<span>Drop section here</span>';
    
    e.dataTransfer.effectAllowed = 'move';
    e.dataTransfer.setData('text/html', draggedElement.outerHTML);
  },

  handleDragOver(e) {
    e.preventDefault();
    e.dataTransfer.dropEffect = 'move';
    
    const afterElement = this.getDragAfterElement(e.clientY);
    const container = this.el;
    
    if (afterElement == null) {
      container.appendChild(placeholder);
    } else {
      container.insertBefore(placeholder, afterElement);
    }
  },

  handleDrop(e) {
    e.preventDefault();
    
    if (draggedElement && placeholder.parentNode) {
      placeholder.parentNode.insertBefore(draggedElement, placeholder);
      placeholder.remove();
      
      // Send new order to server
      this.updateSectionOrder();
    }
  },

  handleDragEnd(e) {
    if (draggedElement) {
      draggedElement.style.opacity = '';
      draggedElement.style.cursor = 'grab';
      draggedElement = null;
    }
    
    if (placeholder && placeholder.parentNode) {
      placeholder.remove();
    }
  },

  getDragAfterElement(y) {
    const draggableElements = [...this.el.querySelectorAll('[data-section-id]:not([style*="opacity: 0.5"])')]
      .filter(el => el !== draggedElement);
    
    return draggableElements.reduce((closest, child) => {
      const box = child.getBoundingClientRect();
      const offset = y - box.top - box.height / 2;
      
      if (offset < 0 && offset > closest.offset) {
        return { offset: offset, element: child };
      } else {
        return closest;
      }
    }, { offset: Number.NEGATIVE_INFINITY }).element;
  },

  updateSectionOrder() {
    const sections = this.el.querySelectorAll('[data-section-id]');
    const sectionIds = Array.from(sections).map(section => 
      section.getAttribute('data-section-id')
    );
    
    this.pushEvent("reorder_sections", { sections: sectionIds });
  },

  updateSectionVisibility(sectionId, visible) {
    const sectionCard = this.el.querySelector(`[data-section-id="${sectionId}"]`);
    
    if (sectionCard) {
      // Update card appearance
      if (visible) {
        sectionCard.classList.remove('opacity-75');
        sectionCard.classList.add('opacity-100');
        sectionCard.style.backgroundColor = '';
      } else {
        sectionCard.classList.remove('opacity-100');
        sectionCard.classList.add('opacity-75');
        sectionCard.style.backgroundColor = '#f9fafb';
      }

      // Update visibility button
      const toggleButton = sectionCard.querySelector(`[phx-click="toggle_section_visibility"]`);
      if (toggleButton) {
        const svg = toggleButton.querySelector('svg');
        
        if (visible) {
          // Visible icon
          svg.innerHTML = `
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
          `;
          toggleButton.className = "p-2 rounded-lg transition-colors text-green-600 hover:text-green-700 hover:bg-green-50";
          toggleButton.title = "Hide section";
        } else {
          // Hidden icon
          svg.innerHTML = `
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.878 9.878L3 3m6.878 6.878L12 12m0 0l3.122 3.122m0 0L21 21"/>
          `;
          toggleButton.className = "p-2 rounded-lg transition-colors text-gray-500 hover:text-gray-600 hover:bg-gray-100";
          toggleButton.title = "Show section";
        }
      }

      // Update hidden badge
      const badgeContainer = sectionCard.querySelector('.flex.items-center.space-x-2');
      let hiddenBadge = badgeContainer ? badgeContainer.querySelector('.bg-yellow-100') : null;

      if (visible && hiddenBadge) {
        hiddenBadge.remove();
      } else if (!visible && !hiddenBadge && badgeContainer) {
        const badge = document.createElement('span');
        badge.className = 'inline-flex items-center px-2 py-1 text-xs font-medium bg-yellow-100 text-yellow-800 rounded-full';
        badge.textContent = 'Hidden';
        badgeContainer.appendChild(badge);
      }
    }
  }
};

// Hook for color picker synchronization
const ColorPicker = {
  mounted() {
    const colorInput = this.el.querySelector('input[type="color"]');
    const textInput = this.el.querySelector('input[type="text"]');
    
    if (colorInput && textInput) {
      // Sync color picker to text input
      colorInput.addEventListener('change', (e) => {
        textInput.value = e.target.value;
        textInput.dispatchEvent(new Event('input', { bubbles: true }));
      });
      
      // Sync text input to color picker
      textInput.addEventListener('input', (e) => {
        if (this.isValidHexColor(e.target.value)) {
          colorInput.value = e.target.value;
        }
      });
    }
  },
  
  isValidHexColor(hex) {
    return /^#([0-9A-F]{3}){1,2}$/i.test(hex);
  }
};

// Hook for character counter
const CharacterCounter = {
  mounted() {
    const textarea = this.el.querySelector('textarea[name="meta_description"]');
    const counter = this.el.querySelector('#meta-counter');
    
    if (textarea && counter) {
      const updateCounter = () => {
        const length = textarea.value.length;
        counter.textContent = length;
        
        // Update color based on length
        if (length > 160) {
          counter.className = 'text-red-500 font-semibold';
        } else if (length > 140) {
          counter.className = 'text-yellow-500 font-semibold';
        } else {
          counter.className = 'text-gray-500';
        }
      };
      
      textarea.addEventListener('input', updateCounter);
      updateCounter(); // Initial update
    }
  }
};

// Hook for form auto-save
const AutoSave = {
  mounted() {
    this.saveTimeout = null;
    this.lastSaved = new Date();
    
    // Listen for form changes
    this.el.addEventListener('input', this.handleInput.bind(this));
    this.el.addEventListener('change', this.handleInput.bind(this));
    
    // Update save status indicator
    this.updateSaveStatus();
  },
  
  destroyed() {
    if (this.saveTimeout) {
      clearTimeout(this.saveTimeout);
    }
  },
  
  handleInput(e) {
    // Don't auto-save certain inputs
    if (e.target.type === 'file' || e.target.type === 'submit') {
      return;
    }
    
    // Clear existing timeout
    if (this.saveTimeout) {
      clearTimeout(this.saveTimeout);
    }
    
    // Set new timeout for auto-save
    this.saveTimeout = setTimeout(() => {
      this.autoSave();
    }, 2000); // Save after 2 seconds of inactivity
  },
  
  autoSave() {
    const form = this.el.closest('form');
    if (form) {
      // Get form data
      const formData = new FormData(form);
      const data = Object.fromEntries(formData.entries());
      
      // Send to server
      this.pushEvent("auto_save", data);
      this.lastSaved = new Date();
      this.updateSaveStatus();
    }
  },
  
  updateSaveStatus() {
    const indicator = document.querySelector('.save-status');
    if (indicator) {
      const timeAgo = this.getTimeAgo(this.lastSaved);
      indicator.textContent = `Auto-saved ${timeAgo}`;
    }
  },
  
  getTimeAgo(date) {
    const seconds = Math.floor((new Date() - date) / 1000);
    
    if (seconds < 60) return 'just now';
    if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
    if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`;
    return `${Math.floor(seconds / 86400)}d ago`;
  }
};

// Hook for responsive preview frame
const PreviewFrame = {
  mounted() {
    this.iframe = this.el.querySelector('iframe');
    this.deviceButtons = this.el.querySelectorAll('[data-device]');
    
    // Add device preview controls if they don't exist
    this.addDeviceControls();
    
    // Handle device switching
    this.deviceButtons.forEach(button => {
      button.addEventListener('click', (e) => {
        const device = e.target.getAttribute('data-device');
        this.switchDevice(device);
      });
    });
    
    // Handle iframe load
    if (this.iframe) {
      this.iframe.addEventListener('load', () => {
        this.enhancePreview();
      });
    }
  },
  
  addDeviceControls() {
    const container = this.el.querySelector('.preview-controls');
    if (!container) return;
    
    const devicesHTML = `
      <div class="flex items-center space-x-2 bg-gray-100 rounded-lg p-1">
        <button data-device="desktop" class="px-3 py-1 rounded-md text-sm font-medium bg-white text-gray-900 shadow-sm">
          Desktop
        </button>
        <button data-device="tablet" class="px-3 py-1 rounded-md text-sm font-medium text-gray-600 hover:text-gray-900">
          Tablet
        </button>
        <button data-device="mobile" class="px-3 py-1 rounded-md text-sm font-medium text-gray-600 hover:text-gray-900">
          Mobile
        </button>
      </div>
    `;
    
    container.innerHTML = devicesHTML;
    this.deviceButtons = container.querySelectorAll('[data-device]');
  },
  
  switchDevice(device) {
    if (!this.iframe) return;
    
    // Update button states
    this.deviceButtons.forEach(btn => {
      if (btn.getAttribute('data-device') === device) {
        btn.className = 'px-3 py-1 rounded-md text-sm font-medium bg-white text-gray-900 shadow-sm';
      } else {
        btn.className = 'px-3 py-1 rounded-md text-sm font-medium text-gray-600 hover:text-gray-900';
      }
    });
    
    // Update iframe dimensions
    const container = this.iframe.parentElement;
    container.className = container.className.replace(/device-\w+/g, '');
    container.classList.add(`device-${device}`);
    
    // Apply device-specific styles
    switch (device) {
      case 'mobile':
        this.iframe.style.width = '375px';
        this.iframe.style.height = '667px';
        this.iframe.style.transform = 'scale(0.8)';
        break;
      case 'tablet':
        this.iframe.style.width = '768px';
        this.iframe.style.height = '1024px';
        this.iframe.style.transform = 'scale(0.7)';
        break;
      default: // desktop
        this.iframe.style.width = '100%';
        this.iframe.style.height = '100%';
        this.iframe.style.transform = 'scale(0.8)';
    }
  },
  
  enhancePreview() {
    // Add preview enhancements like click indicators, etc.
    try {
      const iframeDoc = this.iframe.contentDocument;
      if (iframeDoc) {
        // Add preview-specific styles
        const style = iframeDoc.createElement('style');
        style.textContent = `
          * { pointer-events: none !important; }
          body::before {
            content: '';
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: rgba(0,0,0,0.01);
            z-index: 9999;
            pointer-events: none;
          }
        `;
        iframeDoc.head.appendChild(style);
      }
    } catch (e) {
      // Cross-origin restrictions may prevent this
      console.log('Preview enhancement blocked by CORS');
    }
  }
};

// Hook for dynamic form fields based on section type
const DynamicFormFields = {
  mounted() {
    const sectionTypeSelect = this.el.querySelector('select[name="section_type"]');
    const layoutTypeSelect = this.el.querySelector('select[name="layout_type"]');
    
    if (sectionTypeSelect) {
      sectionTypeSelect.addEventListener('change', this.handleSectionTypeChange.bind(this));
    }
    
    if (layoutTypeSelect) {
      layoutTypeSelect.addEventListener('change', this.handleLayoutTypeChange.bind(this));
    }
  },
  
  handleSectionTypeChange(e) {
    const sectionType = e.target.value;
    this.pushEvent("section_type_changed", { section_type: sectionType });
  },
  
  handleLayoutTypeChange(e) {
    const layoutType = e.target.value;
    this.toggleConditionalFields(layoutType);
  },
  
  toggleConditionalFields(layoutType) {
    // Show/hide fields based on layout type
    const videoFields = this.el.querySelectorAll('[data-field="video"]');
    const embedFields = this.el.querySelectorAll('[data-field="embed"]');
    const imageFields = this.el.querySelectorAll('[data-field="image"]');
    
    // Hide all conditional fields first
    [videoFields, embedFields, imageFields].flat().forEach(field => {
      field.style.display = 'none';
    });
    
    // Show relevant fields
    switch (layoutType) {
      case 'video':
        videoFields.forEach(field => field.style.display = 'block');
        break;
      case 'embed':
        embedFields.forEach(field => field.style.display = 'block');
        break;
      case 'image_text':
      case 'gallery':
        imageFields.forEach(field => field.style.display = 'block');
        break;
    }
  }
};

// Hook for dropdown management
const DropdownManager = {
  mounted() {
    this.dropdown = this.el;
    this.isOpen = false;
    
    // Close dropdown when clicking outside
    document.addEventListener('click', this.handleOutsideClick.bind(this));
    
    // Handle toggle button
    const toggleButton = this.el.querySelector('[phx-click="toggle_create_dropdown"]');
    if (toggleButton) {
      toggleButton.addEventListener('click', this.handleToggle.bind(this));
    }
  },
  
  destroyed() {
    document.removeEventListener('click', this.handleOutsideClick);
  },
  
  handleToggle(e) {
    e.stopPropagation();
    this.isOpen = !this.isOpen;
    this.updateDropdownState();
  },
  
  handleOutsideClick(e) {
    if (this.isOpen && !this.dropdown.contains(e.target)) {
      this.isOpen = false;
      this.updateDropdownState();
      this.pushEvent("close_dropdown");
    }
  },
  
  updateDropdownState() {
    const dropdownMenu = this.dropdown.querySelector('.absolute');
    if (dropdownMenu) {
      dropdownMenu.style.display = this.isOpen ? 'block' : 'none';
    }
  }
};

// Hook for toast notifications
const ToastNotification = {
  mounted() {
    this.showToast();
    
    // Auto-hide after 5 seconds
    setTimeout(() => {
      this.hideToast();
    }, 5000);
  },
  
  showToast() {
    this.el.classList.remove('translate-x-full', 'opacity-0');
    this.el.classList.add('translate-x-0', 'opacity-100');
  },
  
  hideToast() {
    this.el.classList.remove('translate-x-0', 'opacity-100');
    this.el.classList.add('translate-x-full', 'opacity-0');
    
    // Remove from DOM after animation
    setTimeout(() => {
      if (this.el.parentNode) {
        this.el.parentNode.removeChild(this.el);
      }
    }, 300);
  }
};

// Export hooks for use in app.js
export const PortfolioEditorHooks = {
  SortableSections,
  ColorPicker,
  CharacterCounter,
  AutoSave,
  PreviewFrame,
  DynamicFormFields,
  DropdownManager,
  ToastNotification
};

// CSS for enhanced functionality
const PortfolioEditorCSS = `
  /* Drag and drop styles */
  [draggable="true"] {
    transition: opacity 0.2s ease;
  }
  
  [draggable="true"]:hover {
    cursor: grab;
  }
  
  [draggable="true"]:active {
    cursor: grabbing;
  }
  
  /* Device preview styles */
  .device-mobile .preview-container {
    max-width: 375px;
    margin: 0 auto;
  }
  
  .device-tablet .preview-container {
    max-width: 768px;
    margin: 0 auto;
  }
  
  .device-desktop .preview-container {
    max-width: 100%;
  }
  
  /* Form enhancement styles */
  .form-group {
    position: relative;
  }
  
  .form-group.has-error input,
  .form-group.has-error textarea,
  .form-group.has-error select {
    border-color: #ef4444;
    box-shadow: 0 0 0 3px rgba(239, 68, 68, 0.1);
  }
  
  .form-group.has-success input,
  .form-group.has-success textarea,
  .form-group.has-success select {
    border-color: #10b981;
    box-shadow: 0 0 0 3px rgba(16, 185, 129, 0.1);
  }
  
  /* Toast animation */
  .toast {
    transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  }
  
  /* Loading states */
  .loading {
    opacity: 0.6;
    pointer-events: none;
  }
  
  .loading::after {
    content: '';
    position: absolute;
    top: 50%;
    left: 50%;
    width: 20px;
    height: 20px;
    margin: -10px 0 0 -10px;
    border: 2px solid #f3f3f3;
    border-top: 2px solid #3498db;
    border-radius: 50%;
    animation: spin 1s linear infinite;
  }
  
  @keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }
  
  /* Responsive utilities */
  @media (max-width: 768px) {
    .hide-mobile {
      display: none !important;
    }
  }
  
  @media (min-width: 769px) {
    .hide-desktop {
      display: none !important;
    }
  }
`;

// Inject CSS into document
if (typeof document !== 'undefined') {
  const style = document.createElement('style');
  style.textContent = PortfolioEditorCSS;
  document.head.appendChild(style);
}