// File: assets/js/hooks/time_machine_controller.js
// Time Machine portfolio layout controller with iOS-style animations

const TimeMachineController = {
  mounted() {
    console.log('🕰️ Time Machine Controller mounted');
    
    this.currentIndex = 0;
    this.totalCards = parseInt(this.el.dataset.totalCards) || 0;
    this.scrollDirection = this.el.dataset.scrollDirection || 'vertical';
    this.isAnimating = false;
    this.touchStartX = 0;
    this.touchStartY = 0;
    this.wheelTimeout = null;
    
    // Initialize the controller
    this.init();
  },

  updated() {
    console.log('🕰️ Time Machine Controller updated');
    this.totalCards = parseInt(this.el.dataset.totalCards) || 0;
    this.scrollDirection = this.el.dataset.scrollDirection || 'vertical';
    this.updateCardPositions();
    this.updateNavigation();
  },

  init() {
    console.log('🕰️ Initializing Time Machine with', this.totalCards, 'cards');
    
    // Set up global TimeMachine object for external access
    window.TimeMachine = {
      navigateToCard: this.navigateToCard.bind(this),
      navigateNext: this.navigateNext.bind(this),
      navigatePrevious: this.navigatePrevious.bind(this),
      bringToFront: this.bringToFront.bind(this),
      toggleScrollDirection: this.toggleScrollDirection.bind(this),
      exit: this.exit.bind(this)
    };

    // Initial setup
    this.updateCardPositions();
    this.updateNavigation();
    this.updateProgress();
    this.setupEventListeners();
  },

  setupEventListeners() {
    this.setupKeyboardNavigation();
    this.setupTouchNavigation();
    this.setupWheelNavigation();
  },

  navigateToCard(index) {
    if (this.isAnimating || index < 0 || index >= this.totalCards || index === this.currentIndex) {
      return;
    }

    console.log('🕰️ Navigating to card', index);
    
    this.isAnimating = true;
    this.currentIndex = index;
    this.updateCardPositions();
    this.updateNavigation();
    this.updateProgress();

    // iOS-style animation timing
    setTimeout(() => { 
      this.isAnimating = false; 
    }, 800);
  },

  navigateNext() {
    this.navigateToCard(this.currentIndex + 1);
  },

  navigatePrevious() {
    this.navigateToCard(this.currentIndex - 1);
  },

  bringToFront(index) {
    this.navigateToCard(index);
  },

  updateCardPositions() {
    const cards = this.el.querySelectorAll('.time-machine-card');
    
    cards.forEach((card, index) => {
      const relativeIndex = index - this.currentIndex;
      const absIndex = Math.abs(relativeIndex);

      let transform, opacity, filter, zIndex;

      if (relativeIndex === 0) {
        // Front card - full visibility
        transform = 'translateZ(0px) rotateY(0deg) rotateX(0deg) scale(1)';
        opacity = 1;
        filter = 'blur(0px)';
        zIndex = 50;
      } else if (relativeIndex > 0) {
        // Cards behind - book-like stacking with blur
        const depth = absIndex * 30;
        const rotation = Math.min(absIndex * 2, 10); // Cap rotation
        const scale = Math.max(0.85, 1 - (absIndex * 0.05));
        const blur = Math.min(absIndex * 1.5, 8); // Cap blur
        
        transform = `translateZ(-${depth}px) rotateY(-${rotation}deg) rotateX(-1deg) scale(${scale})`;
        opacity = Math.max(0.4, 1 - (absIndex * 0.25));
        filter = `blur(${blur}px)`;
        zIndex = 50 - absIndex;
      } else {
        // Cards in front - hidden but positioned for smooth transition
        const depth = absIndex * 30;
        const rotation = Math.min(absIndex * 2, 10);
        const scale = Math.max(0.85, 1 - (absIndex * 0.05));
        
        transform = `translateZ(-${depth}px) rotateY(${rotation}deg) rotateX(1deg) scale(${scale})`;
        opacity = 0;
        filter = 'blur(0px)';
        zIndex = 50 - absIndex;
      }

      // Apply transforms with iOS-style easing
      card.style.transform = transform;
      card.style.opacity = opacity;
      card.style.filter = filter;
      card.style.zIndex = zIndex;
    });
  },

  updateNavigation() {
    // Update navigation dots
    const dots = document.querySelectorAll('.nav-dot');
    dots.forEach((dot, index) => {
      if (index === this.currentIndex) {
        dot.className = 'nav-dot w-2 h-2 rounded-full transition-all duration-300 bg-gray-900 scale-125';
      } else {
        dot.className = 'nav-dot w-2 h-2 rounded-full transition-all duration-300 bg-gray-300 hover:bg-gray-400';
      }
    });

    // Update arrow buttons based on scroll direction
    const updateButton = (id, disabled) => {
      const btn = document.getElementById(id);
      if (btn) {
        btn.disabled = disabled;
        btn.style.opacity = disabled ? '0.3' : '1';
      }
    };

    if (this.scrollDirection === 'horizontal') {
      updateButton('nav-left', this.currentIndex === 0);
      updateButton('nav-right', this.currentIndex === this.totalCards - 1);
    } else {
      updateButton('nav-up', this.currentIndex === 0);
      updateButton('nav-down', this.currentIndex === this.totalCards - 1);
    }
  },

  updateProgress() {
    const currentSpan = document.getElementById('current-card-num');
    if (currentSpan) {
      currentSpan.textContent = this.currentIndex + 1;
    }
  },

  setupKeyboardNavigation() {
    this.keyboardHandler = (e) => {
      if (this.isAnimating) return;

      switch(e.key) {
        case 'ArrowRight':
          e.preventDefault();
          if (this.scrollDirection === 'horizontal') {
            this.navigateNext();
          }
          break;
        case 'ArrowLeft':
          e.preventDefault();
          if (this.scrollDirection === 'horizontal') {
            this.navigatePrevious();
          }
          break;
        case 'ArrowDown':
          e.preventDefault();
          if (this.scrollDirection === 'vertical') {
            this.navigateNext();
          }
          break;
        case 'ArrowUp':
          e.preventDefault();
          if (this.scrollDirection === 'vertical') {
            this.navigatePrevious();
          }
          break;
        case 'Escape':
          this.exit();
          break;
      }
    };

    document.addEventListener('keydown', this.keyboardHandler);
  },

  setupTouchNavigation() {
    this.touchStartHandler = (e) => {
      this.touchStartX = e.touches[0].clientX;
      this.touchStartY = e.touches[0].clientY;
    };

    this.touchEndHandler = (e) => {
      if (!this.touchStartX || !this.touchStartY || this.isAnimating) return;

      const endX = e.changedTouches[0].clientX;
      const endY = e.changedTouches[0].clientY;
      const diffX = this.touchStartX - endX;
      const diffY = this.touchStartY - endY;

      // iOS-style minimum swipe distance
      const minSwipeDistance = 80;
      if (Math.abs(diffX) < minSwipeDistance && Math.abs(diffY) < minSwipeDistance) return;

      if (this.scrollDirection === 'horizontal') {
        if (Math.abs(diffX) > Math.abs(diffY)) {
          if (diffX > 0) {
            this.navigateNext(); // Swipe left = next
          } else {
            this.navigatePrevious(); // Swipe right = previous
          }
        }
      } else {
        if (Math.abs(diffY) > Math.abs(diffX)) {
          if (diffY > 0) {
            this.navigateNext(); // Swipe up = next
          } else {
            this.navigatePrevious(); // Swipe down = previous
          }
        }
      }

      this.touchStartX = 0;
      this.touchStartY = 0;
    };

    this.el.addEventListener('touchstart', this.touchStartHandler, { passive: true });
    this.el.addEventListener('touchend', this.touchEndHandler, { passive: true });
  },

  setupWheelNavigation() {
    this.wheelHandler = (e) => {
      if (this.isAnimating) return;

      // Prevent default scrolling
      e.preventDefault();

      // Clear existing timeout
      if (this.wheelTimeout) {
        clearTimeout(this.wheelTimeout);
      }

      // Debounce wheel events for smoother navigation
      this.wheelTimeout = setTimeout(() => {
        if (this.scrollDirection === 'vertical') {
          if (e.deltaY > 0) {
            this.navigateNext();
          } else {
            this.navigatePrevious();
          }
        } else {
          if (e.deltaX > 0) {
            this.navigateNext();
          } else {
            this.navigatePrevious();
          }
        }
      }, 100);
    };

    document.addEventListener('wheel', this.wheelHandler, { passive: false });
  },

  toggleScrollDirection() {
    this.scrollDirection = this.scrollDirection === 'vertical' ? 'horizontal' : 'vertical';
    
    // Update element data attribute
    this.el.dataset.scrollDirection = this.scrollDirection;

    // Update navigation visibility
    this.updateNavigation();
    
    // Show brief notification
    this.showNotification(`Scroll direction: ${this.scrollDirection}`);

    // Notify LiveView of the change
    this.pushEvent('scroll_direction_changed', { 
      direction: this.scrollDirection 
    });
  },

  showNotification(message) {
    // Create temporary notification
    const notification = document.createElement('div');
    notification.className = 'fixed top-20 left-1/2 transform -translate-x-1/2 z-50 bg-black/80 text-white px-4 py-2 rounded-lg text-sm backdrop-blur-sm transition-opacity duration-300';
    notification.textContent = message;
    notification.style.opacity = '0';
    
    document.body.appendChild(notification);
    
    // Animate in
    setTimeout(() => {
      notification.style.opacity = '1';
    }, 10);
    
    // Remove after delay
    setTimeout(() => {
      notification.style.opacity = '0';
      setTimeout(() => {
        if (document.body.contains(notification)) {
          document.body.removeChild(notification);
        }
      }, 300);
    }, 2000);
  },

  exit() {
    // Notify LiveView to return to normal portfolio view
    this.pushEvent('exit_time_machine', {});
    
    // Fallback: use browser back if LiveView doesn't handle it
    setTimeout(() => {
      window.history.back();
    }, 100);
  },

  // Handle window resize
  handleResize() {
    if (!this.isAnimating) {
      setTimeout(() => {
        this.updateCardPositions();
      }, 100);
    }
  },

  destroyed() {
    console.log('🕰️ Time Machine Controller destroyed');
    
    // Clean up event listeners
    if (this.keyboardHandler) {
      document.removeEventListener('keydown', this.keyboardHandler);
    }
    
    if (this.wheelHandler) {
      document.removeEventListener('wheel', this.wheelHandler);
    }
    
    if (this.touchStartHandler) {
      this.el.removeEventListener('touchstart', this.touchStartHandler);
    }
    
    if (this.touchEndHandler) {
      this.el.removeEventListener('touchend', this.touchEndHandler);
    }
    
    // Clear timeouts
    if (this.wheelTimeout) {
      clearTimeout(this.wheelTimeout);
    }
    
    // Remove global TimeMachine object
    if (window.TimeMachine) {
      delete window.TimeMachine;
    }
    
    // Remove resize listener
    window.removeEventListener('resize', this.resizeHandler);
  }
};

// Handle window resize
TimeMachineController.resizeHandler = function() {
  if (window.TimeMachine && window.TimeMachine.handleResize) {
    window.TimeMachine.handleResize();
  }
};

window.addEventListener('resize', TimeMachineController.resizeHandler);

export default TimeMachineController;