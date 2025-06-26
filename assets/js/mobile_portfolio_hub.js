// assets/js/mobile_portfolio_hub.js
// Mobile Event Handler for Portfolio Hub - Enhanced Touch Interactions

class MobilePortfolioHub {
  constructor() {
    this.setupEventListeners();
    this.setupTouchGestures();
    this.setupPullToRefresh();
    this.setupVirtualKeyboard();
    this.setupPerformanceOptimizations();
  }

  // ============================================================================
  // TOUCH GESTURE MANAGEMENT
  // ============================================================================

  setupTouchGestures() {
    let touchStartX = 0;
    let touchStartY = 0;
    let touchEndX = 0;
    let touchEndY = 0;
    let isGesturing = false;
    let gestureStartTime = 0;

    const gestureThreshold = 50; // Minimum distance for swipe
    const restraint = 100; // Maximum perpendicular distance
    const timeThreshold = 500; // Maximum time for swipe (ms)

    document.addEventListener('touchstart', (e) => {
      const touch = e.touches[0];
      touchStartX = touch.clientX;
      touchStartY = touch.clientY;
      gestureStartTime = Date.now();
      isGesturing = true;
      
      // Show gesture hint if enabled
      this.showGestureHint();
    }, { passive: true });

    document.addEventListener('touchmove', (e) => {
      if (!isGesturing) return;
      
      const touch = e.touches[0];
      touchEndX = touch.clientX;
      touchEndY = touch.clientY;
      
      // Show real-time gesture feedback
      this.updateGestureIndicator(touchStartX, touchStartY, touchEndX, touchEndY);
    }, { passive: true });

    document.addEventListener('touchend', (e) => {
      if (!isGesturing) return;
      
      const gestureTime = Date.now() - gestureStartTime;
      const deltaX = touchEndX - touchStartX;
      const deltaY = touchEndY - touchStartY;
      const absDeltaX = Math.abs(deltaX);
      const absDeltaY = Math.abs(deltaY);
      
      this.hideGestureIndicator();
      
      // Validate gesture
      if (gestureTime <= timeThreshold) {
        if (absDeltaX >= gestureThreshold && absDeltaY <= restraint) {
          // Horizontal swipe
          const direction = deltaX > 0 ? 'right' : 'left';
          this.handleSwipeGesture(direction, { deltaX, deltaY, time: gestureTime });
        } else if (absDeltaY >= gestureThreshold && absDeltaX <= restraint) {
          // Vertical swipe
          const direction = deltaY > 0 ? 'down' : 'up';
          this.handleSwipeGesture(direction, { deltaX, deltaY, time: gestureTime });
        }
      }
      
      isGesturing = false;
    }, { passive: true });
  }

  handleSwipeGesture(direction, details) {
    const event = new CustomEvent('mobile-swipe', {
      detail: { direction, ...details }
    });
    
    // Send to LiveView
    if (window.liveSocket && window.liveSocket.isConnected()) {
      window.liveSocket.execJS(document.body, `phx-hook="MobileGestures"`, {
        gesture: 'swipe',
        direction: direction,
        details: details
      });
    }
    
    // Visual feedback
    this.showGestureFeedback(direction);
    
    // Haptic feedback (if supported)
    this.triggerHapticFeedback('light');
  }

  // ============================================================================
  // PULL TO REFRESH
  // ============================================================================

  setupPullToRefresh() {
    let startY = 0;
    let currentY = 0;
    let isPulling = false;
    let pullDistance = 0;
    const pullThreshold = 80;
    const maxPull = 120;

    const pullIndicator = this.createPullIndicator();

    document.addEventListener('touchstart', (e) => {
      if (window.scrollY <= 0 && !this.isModalOpen()) {
        startY = e.touches[0].clientY;
        isPulling = true;
      }
    }, { passive: true });

    document.addEventListener('touchmove', (e) => {
      if (!isPulling || window.scrollY > 0) return;
      
      currentY = e.touches[0].clientY;
      pullDistance = Math.min(currentY - startY, maxPull);
      
      if (pullDistance > 10) {
        e.preventDefault(); // Prevent scroll
        
        const progress = Math.min(pullDistance / pullThreshold, 1);
        this.updatePullIndicator(pullIndicator, pullDistance, progress >= 1);
        
        // Add elastic resistance
        const resistance = pullDistance > pullThreshold ? 0.5 : 1;
        document.body.style.transform = `translateY(${pullDistance * resistance}px)`;
      }
    }, { passive: false });

    document.addEventListener('touchend', (e) => {
      if (!isPulling) return;
      
      document.body.style.transform = '';
      
      if (pullDistance >= pullThreshold) {
        this.triggerRefresh();
        this.triggerHapticFeedback('medium');
      }
      
      this.hidePullIndicator(pullIndicator);
      isPulling = false;
      pullDistance = 0;
    }, { passive: true });
  }

  createPullIndicator() {
    const indicator = document.createElement('div');
    indicator.className = 'mobile-pull-indicator';
    indicator.innerHTML = `
      <div class="pull-spinner">
        <svg class="w-6 h-6 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
        </svg>
      </div>
      <span class="pull-text">Pull to refresh</span>
    `;
    
    document.body.appendChild(indicator);
    return indicator;
  }

  updatePullIndicator(indicator, distance, shouldRelease) {
    indicator.style.transform = `translateY(${Math.min(distance - 20, 60)}px)`;
    indicator.style.opacity = Math.min(distance / 40, 1);
    
    const text = indicator.querySelector('.pull-text');
    const spinner = indicator.querySelector('.pull-spinner');
    
    if (shouldRelease) {
      text.textContent = 'Release to refresh';
      spinner.classList.add('text-green-500');
    } else {
      text.textContent = 'Pull to refresh';
      spinner.classList.remove('text-green-500');
    }
  }

  hidePullIndicator(indicator) {
    indicator.style.transform = 'translateY(-100px)';
    indicator.style.opacity = '0';
    
    setTimeout(() => {
      if (indicator.parentNode) {
        indicator.parentNode.removeChild(indicator);
      }
    }, 300);
  }

  triggerRefresh() {
    // Send refresh event to LiveView
    if (window.liveSocket && window.liveSocket.isConnected()) {
      const view = this.findLiveView();
      if (view) {
        view.pushEvent('refresh_portfolios', {});
      }
    }
  }

  // ============================================================================
  // VIRTUAL KEYBOARD HANDLING
  // ============================================================================

  setupVirtualKeyboard() {
    let initialViewportHeight = window.innerHeight;
    
    const handleViewportChange = () => {
      const currentHeight = window.innerHeight;
      const heightDifference = initialViewportHeight - currentHeight;
      
      // Virtual keyboard is likely open if height decreased significantly
      if (heightDifference > 150) {
        document.body.classList.add('virtual-keyboard-open');
        this.adjustForVirtualKeyboard(heightDifference);
      } else {
        document.body.classList.remove('virtual-keyboard-open');
        this.resetVirtualKeyboardAdjustments();
      }
    };

    // Listen for viewport changes
    window.addEventListener('resize', handleViewportChange);
    window.addEventListener('orientationchange', () => {
      setTimeout(() => {
        initialViewportHeight = window.innerHeight;
        handleViewportChange();
      }, 500);
    });

    // Focus/blur events for inputs
    document.addEventListener('focusin', (e) => {
      if (this.isInputElement(e.target)) {
        setTimeout(() => {
          this.scrollToInput(e.target);
        }, 300);
      }
    });
  }

  adjustForVirtualKeyboard(keyboardHeight) {
    const activeElement = document.activeElement;
    if (this.isInputElement(activeElement)) {
      const elementRect = activeElement.getBoundingClientRect();
      const visibleHeight = window.innerHeight;
      
      if (elementRect.bottom > visibleHeight - 20) {
        const scrollAmount = elementRect.bottom - visibleHeight + 40;
        window.scrollBy(0, scrollAmount);
      }
    }
  }

  resetVirtualKeyboardAdjustments() {
    // Reset any keyboard-specific adjustments
    document.querySelectorAll('.keyboard-adjusted').forEach(el => {
      el.classList.remove('keyboard-adjusted');
      el.style.transform = '';
    });
  }

  scrollToInput(input) {
    const rect = input.getBoundingClientRect();
    const windowHeight = window.innerHeight;
    
    if (rect.bottom > windowHeight * 0.7) {
      input.scrollIntoView({
        behavior: 'smooth',
        block: 'center'
      });
    }
  }

  isInputElement(element) {
    const inputTypes = ['input', 'textarea', 'select'];
    return inputTypes.includes(element.tagName.toLowerCase()) ||
           element.contentEditable === 'true';
  }

  // ============================================================================
  // PERFORMANCE OPTIMIZATIONS
  // ============================================================================

  setupPerformanceOptimizations() {
    // Throttle scroll events
    let scrollTimeout;
    window.addEventListener('scroll', () => {
      if (scrollTimeout) return;
      
      scrollTimeout = setTimeout(() => {
        this.handleScroll();
        scrollTimeout = null;
      }, 16); // ~60fps
    }, { passive: true });

    // Optimize images for mobile
    this.setupLazyLoading();
    
    // Preload critical resources
    this.preloadCriticalResources();
    
    // Setup intersection observer for viewport optimizations
    this.setupViewportOptimizations();
  }

  setupLazyLoading() {
    if ('IntersectionObserver' in window) {
      const imageObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
          if (entry.isIntersecting) {
            const img = entry.target;
            if (img.dataset.src) {
              img.src = img.dataset.src;
              img.removeAttribute('data-src');
              imageObserver.unobserve(img);
            }
          }
        });
      });

      document.querySelectorAll('img[data-src]').forEach(img => {
        imageObserver.observe(img);
      });
    }
  }

  setupViewportOptimizations() {
    if ('IntersectionObserver' in window) {
      const viewportObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
          const element = entry.target;
          
          if (entry.isIntersecting) {
            element.classList.add('in-viewport');
            this.activateElement(element);
          } else {
            element.classList.remove('in-viewport');
            this.deactivateElement(element);
          }
        });
      }, {
        rootMargin: '50px'
      });

      document.querySelectorAll('.mobile-portfolio-card').forEach(card => {
        viewportObserver.observe(card);
      });
    }
  }

  activateElement(element) {
    // Enable animations and interactions for visible elements
    element.classList.add('active');
  }

  deactivateElement(element) {
    // Disable expensive operations for off-screen elements
    element.classList.remove('active');
  }

  preloadCriticalResources() {
    // Preload critical CSS and fonts
    const criticalResources = [
      '/css/app.css',
      '/fonts/inter-var.woff2'
    ];

    criticalResources.forEach(resource => {
      const link = document.createElement('link');
      link.rel = 'preload';
      link.href = resource;
      link.as = resource.endsWith('.css') ? 'style' : 'font';
      if (link.as === 'font') {
        link.crossOrigin = 'anonymous';
      }
      document.head.appendChild(link);
    });
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  showGestureHint() {
    // Show subtle hint about available gestures
    const hint = document.querySelector('.gesture-hint');
    if (hint) {
      hint.classList.add('visible');
      setTimeout(() => hint.classList.remove('visible'), 2000);
    }
  }

  updateGestureIndicator(startX, startY, endX, endY) {
    const deltaX = endX - startX;
    const deltaY = endY - startY;
    const direction = this.getGestureDirection(deltaX, deltaY);
    
    let indicator = document.querySelector('.mobile-swipe-indicator');
    if (!indicator) {
      indicator = this.createGestureIndicator();
    }
    
    const text = this.getGestureText(direction);
    indicator.querySelector('.swipe-text').textContent = text;
    indicator.classList.add('show');
  }

  hideGestureIndicator() {
    const indicator = document.querySelector('.mobile-swipe-indicator');
    if (indicator) {
      indicator.classList.remove('show');
    }
  }

  createGestureIndicator() {
    const indicator = document.createElement('div');
    indicator.className = 'mobile-swipe-indicator';
    indicator.innerHTML = '<span class="swipe-text"></span>';
    document.body.appendChild(indicator);
    return indicator;
  }

  getGestureDirection(deltaX, deltaY) {
    if (Math.abs(deltaX) > Math.abs(deltaY)) {
      return deltaX > 0 ? 'right' : 'left';
    } else {
      return deltaY > 0 ? 'down' : 'up';
    }
  }

  getGestureText(direction) {
    const texts = {
      'right': 'Swipe right to open sidebar',
      'left': 'Swipe left to filter',
      'up': 'Swipe up for actions',
      'down': 'Swipe down to refresh'
    };
    return texts[direction] || 'Swipe detected';
  }

  showGestureFeedback(direction) {
    const feedback = document.createElement('div');
    feedback.className = 'gesture-feedback';
    feedback.textContent = `Swiped ${direction}`;
    document.body.appendChild(feedback);
    
    setTimeout(() => {
      feedback.remove();
    }, 1000);
  }

  triggerHapticFeedback(type = 'light') {
    if ('vibrate' in navigator) {
      const patterns = {
        'light': 10,
        'medium': 20,
        'heavy': 30
      };
      navigator.vibrate(patterns[type] || 10);
    }
  }

  handleScroll() {
    const scrollY = window.scrollY;
    
    // Update scroll-based animations
    document.querySelectorAll('.scroll-animated').forEach(el => {
      const rect = el.getBoundingClientRect();
      const progress = Math.max(0, Math.min(1, (window.innerHeight - rect.top) / window.innerHeight));
      el.style.setProperty('--scroll-progress', progress);
    });
    
    // Hide/show floating elements based on scroll
    const fab = document.querySelector('.mobile-fab');
    if (fab) {
      if (scrollY > 100) {
        fab.classList.add('visible');
      } else {
        fab.classList.remove('visible');
      }
    }
  }

  isModalOpen() {
    return document.querySelector('.modal, .mobile-modal, [role="dialog"]') !== null;
  }

  findLiveView() {
    const liveViewElement = document.querySelector('[data-phx-main]');
    return liveViewElement ? window.liveSocket.getViewByEl(liveViewElement) : null;
  }

  // ============================================================================
  // EVENT LISTENERS SETUP
  // ============================================================================

  setupEventListeners() {
    // Prevent default touch behaviors that interfere with gestures
    document.addEventListener('touchmove', (e) => {
      if (e.target.closest('.prevent-scroll')) {
        e.preventDefault();
      }
    }, { passive: false });

    // Handle orientation changes
    window.addEventListener('orientationchange', () => {
      setTimeout(() => {
        this.handleOrientationChange();
      }, 100);
    });

    // Handle focus management for mobile
    document.addEventListener('focusin', (e) => {
      if (e.target.matches('input, textarea, select')) {
        this.handleInputFocus(e.target);
      }
    });

    document.addEventListener('focusout', (e) => {
      if (e.target.matches('input, textarea, select')) {
        this.handleInputBlur(e.target);
      }
    });

    // Handle click events with touch delay optimization
    document.addEventListener('click', (e) => {
      if (e.target.closest('.mobile-fast-click')) {
        e.preventDefault();
        e.stopPropagation();
        this.handleFastClick(e.target);
      }
    }, true);

    // Handle long press events
    this.setupLongPressHandling();
    
    // Handle double tap events
    this.setupDoubleTapHandling();
  }

  handleOrientationChange() {
    // Update viewport height for proper mobile layout
    const vh = window.innerHeight * 0.01;
    document.documentElement.style.setProperty('--vh', `${vh}px`);
    
    // Trigger layout recalculation
    this.recalculateLayout();
    
    // Send orientation change to LiveView
    const orientation = window.innerHeight > window.innerWidth ? 'portrait' : 'landscape';
    if (window.liveSocket && window.liveSocket.isConnected()) {
      const view = this.findLiveView();
      if (view) {
        view.pushEvent('orientation_changed', { orientation });
      }
    }
  }

  handleInputFocus(input) {
    // Add focused class for styling
    input.classList.add('mobile-input-focused');
    
    // Ensure input is visible above virtual keyboard
    setTimeout(() => {
      const rect = input.getBoundingClientRect();
      const viewport = window.innerHeight;
      
      if (rect.bottom > viewport * 0.6) {
        input.scrollIntoView({
          behavior: 'smooth',
          block: 'center'
        });
      }
    }, 300);
  }

  handleInputBlur(input) {
    input.classList.remove('mobile-input-focused');
  }

  handleFastClick(element) {
    // Immediate response for better perceived performance
    element.classList.add('mobile-clicked');
    
    setTimeout(() => {
      element.classList.remove('mobile-clicked');
    }, 150);
    
    // Trigger the actual click event
    const event = new Event('click', { bubbles: true });
    element.dispatchEvent(event);
  }

  setupLongPressHandling() {
    let pressTimer;
    let isLongPress = false;

    document.addEventListener('touchstart', (e) => {
      if (e.target.closest('.mobile-long-press')) {
        isLongPress = false;
        pressTimer = setTimeout(() => {
          isLongPress = true;
          this.handleLongPress(e.target, e);
        }, 500);
      }
    }, { passive: true });

    document.addEventListener('touchend', (e) => {
      if (pressTimer) {
        clearTimeout(pressTimer);
        pressTimer = null;
      }
      
      if (isLongPress) {
        e.preventDefault();
        e.stopPropagation();
      }
    }, { passive: false });

    document.addEventListener('touchmove', () => {
      if (pressTimer) {
        clearTimeout(pressTimer);
        pressTimer = null;
      }
    }, { passive: true });
  }

  handleLongPress(element, event) {
    // Trigger haptic feedback
    this.triggerHapticFeedback('medium');
    
    // Add visual feedback
    element.classList.add('mobile-long-pressed');
    
    setTimeout(() => {
      element.classList.remove('mobile-long-pressed');
    }, 200);
    
    // Send long press event to LiveView
    if (window.liveSocket && window.liveSocket.isConnected()) {
      const view = this.findLiveView();
      if (view) {
        const data = {
          element_id: element.id || element.dataset.id,
          element_class: element.className,
          coordinates: {
            x: event.touches[0].clientX,
            y: event.touches[0].clientY
          }
        };
        view.pushEvent('mobile_long_press', data);
      }
    }
  }

  setupDoubleTapHandling() {
    let lastTap = 0;
    const doubleTapDelay = 300;

    document.addEventListener('touchend', (e) => {
      const currentTime = new Date().getTime();
      const tapLength = currentTime - lastTap;
      
      if (tapLength < doubleTapDelay && tapLength > 0) {
        if (e.target.closest('.mobile-double-tap')) {
          e.preventDefault();
          this.handleDoubleTap(e.target, e);
        }
      }
      
      lastTap = currentTime;
    }, { passive: false });
  }

  handleDoubleTap(element, event) {
    // Trigger haptic feedback
    this.triggerHapticFeedback('light');
    
    // Add visual feedback
    element.classList.add('mobile-double-tapped');
    
    setTimeout(() => {
      element.classList.remove('mobile-double-tapped');
    }, 300);
    
    // Send double tap event to LiveView
    if (window.liveSocket && window.liveSocket.isConnected()) {
      const view = this.findLiveView();
      if (view) {
        const data = {
          element_id: element.id || element.dataset.id,
          coordinates: {
            x: event.changedTouches[0].clientX,
            y: event.changedTouches[0].clientY
          }
        };
        view.pushEvent('mobile_double_tap', data);
      }
    }
  }

  recalculateLayout() {
    // Force layout recalculation for mobile
    document.querySelectorAll('.mobile-responsive').forEach(el => {
      el.style.height = 'auto';
      const height = el.scrollHeight;
      el.style.height = `${height}px`;
    });
  }

  // ============================================================================
  // PUBLIC API METHODS
  // ============================================================================

  // Method to be called when LiveView connects
  init() {
    console.log('Mobile Portfolio Hub initialized');
    this.handleOrientationChange();
    this.setupAccessibilityFeatures();
  }

  // Method to be called when LiveView disconnects
  destroy() {
    console.log('Mobile Portfolio Hub destroyed');
    this.cleanup();
  }

  // Setup accessibility features
  setupAccessibilityFeatures() {
    // Focus management
    this.setupFocusManagement();
    
    // Screen reader support
    this.setupScreenReaderSupport();
    
    // High contrast mode detection
    this.detectHighContrastMode();
    
    // Reduced motion support
    this.detectReducedMotion();
  }

  setupFocusManagement() {
    // Ensure proper focus order for mobile
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Tab') {
        this.manageFocusOrder(e);
      }
    });
  }

  manageFocusOrder(event) {
    const focusableElements = document.querySelectorAll(
      'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    );
    
    const visibleElements = Array.from(focusableElements).filter(el => {
      return el.offsetWidth > 0 && el.offsetHeight > 0;
    });
    
    const currentIndex = visibleElements.indexOf(document.activeElement);
    
    if (event.shiftKey) {
      // Shift + Tab (backwards)
      if (currentIndex <= 0) {
        event.preventDefault();
        visibleElements[visibleElements.length - 1].focus();
      }
    } else {
      // Tab (forwards)
      if (currentIndex >= visibleElements.length - 1) {
        event.preventDefault();
        visibleElements[0].focus();
      }
    }
  }

  setupScreenReaderSupport() {
    // Add ARIA live regions for dynamic content
    const liveRegion = document.createElement('div');
    liveRegion.setAttribute('aria-live', 'polite');
    liveRegion.setAttribute('aria-atomic', 'true');
    liveRegion.className = 'sr-only';
    liveRegion.id = 'mobile-live-region';
    document.body.appendChild(liveRegion);
  }

  announceToScreenReader(message) {
    const liveRegion = document.getElementById('mobile-live-region');
    if (liveRegion) {
      liveRegion.textContent = message;
    }
  }

  detectHighContrastMode() {
    if (window.matchMedia('(prefers-contrast: high)').matches) {
      document.body.classList.add('high-contrast');
    }
  }

  detectReducedMotion() {
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      document.body.classList.add('reduced-motion');
    }
  }

  cleanup() {
    // Remove event listeners and clean up resources
    const indicators = document.querySelectorAll('.mobile-swipe-indicator, .mobile-pull-indicator');
    indicators.forEach(indicator => indicator.remove());
    
    // Reset body styles
    document.body.style.transform = '';
    document.body.classList.remove('virtual-keyboard-open', 'high-contrast', 'reduced-motion');
  }

  // ============================================================================
  // INTEGRATION METHODS FOR LIVEVIEW
  // ============================================================================

  // Method to update mobile state from LiveView
  updateState(state) {
    if (state.showMobileMenu !== undefined) {
      this.toggleMobileMenu(state.showMobileMenu);
    }
    
    if (state.showMobileSidebar !== undefined) {
      this.toggleMobileSidebar(state.showMobileSidebar);
    }
    
    if (state.gesturesEnabled !== undefined) {
      this.mobile_gesture_enabled = state.gesturesEnabled;
    }
  }

  toggleMobileMenu(show) {
    const menu = document.querySelector('.mobile-menu');
    if (menu) {
      menu.classList.toggle('open', show);
    }
  }

  toggleMobileSidebar(show) {
    const sidebar = document.querySelector('.mobile-sidebar');
    if (sidebar) {
      sidebar.classList.toggle('open', show);
    }
  }

  // Method to get current mobile state
  getCurrentState() {
    return {
      orientation: window.innerHeight > window.innerWidth ? 'portrait' : 'landscape',
      viewportHeight: window.innerHeight,
      viewportWidth: window.innerWidth,
      isVirtualKeyboardOpen: document.body.classList.contains('virtual-keyboard-open'),
      supportsTouch: 'ontouchstart' in window,
      devicePixelRatio: window.devicePixelRatio || 1
    };
  }
}

// ============================================================================
// LIVEVIEW HOOKS INTEGRATION
// ============================================================================

// Phoenix LiveView Hooks
window.MobilePortfolioHooks = {
  MobileGestures: {
    mounted() {
      this.mobileHub = new MobilePortfolioHub();
      this.mobileHub.init();
    },
    
    updated() {
      // Handle updates from LiveView
      if (this.mobileHub) {
        this.mobileHub.updateState(this.el.dataset);
      }
    },
    
    destroyed() {
      if (this.mobileHub) {
        this.mobileHub.destroy();
      }
    }
  },

  MobilePullRefresh: {
    mounted() {
      this.setupPullToRefresh();
    },
    
    setupPullToRefresh() {
      // Simplified pull-to-refresh specifically for this element
      let startY = 0;
      let isPulling = false;
      
      this.el.addEventListener('touchstart', (e) => {
        if (this.el.scrollTop <= 0) {
          startY = e.touches[0].clientY;
          isPulling = true;
        }
      }, { passive: true });
      
      this.el.addEventListener('touchmove', (e) => {
        if (!isPulling) return;
        
        const currentY = e.touches[0].clientY;
        const pullDistance = currentY - startY;
        
        if (pullDistance > 50) {
          this.showPullIndicator();
        }
      }, { passive: true });
      
      this.el.addEventListener('touchend', (e) => {
        if (isPulling) {
          const currentY = e.changedTouches[0].clientY;
          const pullDistance = currentY - startY;
          
          if (pullDistance > 80) {
            this.pushEvent('mobile_pull_refresh', {});
          }
          
          this.hidePullIndicator();
        }
        
        isPulling = false;
      }, { passive: true });
    },
    
    showPullIndicator() {
      // Add visual indicator for pull-to-refresh
      this.el.classList.add('pulling');
    },
    
    hidePullIndicator() {
      this.el.classList.remove('pulling');
    }
  }
};

// ============================================================================
// INITIALIZATION
// ============================================================================

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
  // Set up global mobile optimizations
  const vh = window.innerHeight * 0.01;
  document.documentElement.style.setProperty('--vh', `${vh}px`);
  
  // Add mobile class to body
  document.body.classList.add('mobile-optimized');
  
  // Initialize mobile hub if not using LiveView hooks
  if (!window.liveSocket) {
    window.mobilePortfolioHub = new MobilePortfolioHub();
    window.mobilePortfolioHub.init();
  }
});

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
  module.exports = MobilePortfolioHub;
}