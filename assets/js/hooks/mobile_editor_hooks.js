// Mobile Portfolio Editor Hooks
const MobileEditorHooks = {
  MobileNavigation: {
    mounted() {
      this.setupMobileNavigation();
      this.setupSwipeGestures();
    },
    
    setupMobileNavigation() {
      // Handle mobile nav backdrop clicks
      this.handleEvent('mobile_nav_opened', () => {
        document.body.style.overflow = 'hidden';
      });
      
      this.handleEvent('mobile_nav_closed', () => {
        document.body.style.overflow = '';
      });
    },
    
    setupSwipeGestures() {
      let startX = 0;
      let currentX = 0;
      let isDragging = false;
      
      this.el.addEventListener('touchstart', (e) => {
        startX = e.touches[0].clientX;
        isDragging = true;
      });
      
      this.el.addEventListener('touchmove', (e) => {
        if (!isDragging) return;
        currentX = e.touches[0].clientX;
        const deltaX = currentX - startX;
        
        // Swipe right to open nav (from left edge)
        if (startX < 20 && deltaX > 50) {
          this.pushEvent('toggle_mobile_nav');
          isDragging = false;
        }
      });
      
      this.el.addEventListener('touchend', () => {
        isDragging = false;
      });
    }
  },
  
  PreviewDevice: {
    mounted() {
      this.setupDevicePreview();
    },
    
    setupDevicePreview() {
      this.handleEvent('device_changed', ({ device }) => {
        const iframe = document.getElementById('portfolio-preview');
        if (iframe) {
          iframe.className = this.getDeviceClasses(device);
        }
      });
    },
    
    getDeviceClasses(device) {
      const baseClasses = 'border-0 transition-all duration-300';
      
      switch (device) {
        case 'mobile':
          return `${baseClasses} w-full h-full max-w-sm mx-auto border-2 border-gray-300 rounded-lg`;
        case 'tablet':
          return `${baseClasses} w-full h-full max-w-2xl mx-auto border-2 border-gray-300 rounded-lg`;
        case 'desktop':
          return `${baseClasses} w-full h-full`;
        default:
          return `${baseClasses} w-full h-full`;
      }
    }
  },
  
  QuickAdd: {
    mounted() {
      this.setupQuickAdd();
    },
    
    setupQuickAdd() {
      // Auto-close quick add when clicking outside
      document.addEventListener('click', (e) => {
        const quickAddButton = document.querySelector('[phx-click="toggle_quick_add"]');
        const quickAddMenu = document.querySelector('.quick-add-menu');
        
        if (quickAddButton && quickAddMenu && 
            !quickAddButton.contains(e.target) && 
            !quickAddMenu.contains(e.target)) {
          this.pushEvent('close_quick_add');
        }
      });
    }
  }
};

// Export mobile hooks
window.MobileEditorHooks = MobileEditorHooks;