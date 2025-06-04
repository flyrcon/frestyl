// assets/js/hooks/mobile_chat_hook.js
export const MobileChatHook = {
  mounted() {
    this.setupSwipeGestures();
    this.setupKeyboardHandling();
    this.initializeHapticFeedback();
  },

  setupSwipeGestures() {
    let startY = 0;
    let startX = 0;
    let currentY = 0;
    let isVerticalSwipe = false;

    this.el.addEventListener('touchstart', (e) => {
      startY = e.touches[0].clientY;
      startX = e.touches[0].clientX;
      isVerticalSwipe = false;
    }, { passive: true });

    this.el.addEventListener('touchmove', (e) => {
      currentY = e.touches[0].clientY;
      const deltaY = currentY - startY;
      const deltaX = Math.abs(e.touches[0].clientX - startX);

      // Detect vertical swipe down to close
      if (deltaY > 50 && deltaX < 50 && !isVerticalSwipe) {
        isVerticalSwipe = true;
        this.pushEvent("swipe_close", {});
      }
    }, { passive: true });
  },

  setupKeyboardHandling() {
    // Handle virtual keyboard on mobile
    if ('visualViewport' in window) {
      const viewport = window.visualViewport;

      const handleViewportChange = () => {
        const chatPanel = this.el.querySelector('.mobile-chat-container');
        if (chatPanel) {
          chatPanel.style.height = '${viewport.height}px';
        }
      };

      viewport.addEventListener('resize', handleViewportChange);
      viewport.addEventListener('scroll', handleViewportChange);

      this.handleEvent("mobile_chat_toggled", ({ open }) => {
        if (open) {
          handleViewportChange();
        }
      });
    }
  },

  initializeHapticFeedback() {
    this.handleEvent("mobile_haptic_feedback", ({ type }) => {
      if ('vibrate' in navigator) {
        switch (type) {
          case 'light':
            navigator.vibrate(10);
            break;
          case 'medium':
            navigator.vibrate(25);
            break;
          case 'heavy':
            navigator.vibrate([50, 10, 50]);
            break;
          case 'error':
            navigator.vibrate([100, 50, 100]);
            break;
          default:
            navigator.vibrate(10);
        }
      }
    });
  }
};

export const MobileChatScroll = {
  mounted() {
    this.scrollToBottom();
    this.observer = new mutationObserver(() => {
      this.scrollToBottom();
    });

    this.observer.observe(this.el, {
      childList: true,
      subtree: true
    });
  },

  updated() {
    this.scrollToBottom();
  },

  scrollToBottom() {
    requestAnimationFrame(() => {
      this.el.scrollTop = this.el.scrollHeight;
    });
  },

  destroyed() {
    if (this.observer) {
      this.observer.disconnect();
    }
  }
};

export const MobileAutoResizeTextarea = {
  mounted() {
    this.textarea = this.el;
    this.textarea.style.height = 'auto';
    this.textarea.style.overflowY = 'hidden';

    this.handleResize = this.handleResize.bind(this);
    this.textarea.addEventListener('input', this.handleResize);

    // Handle event to update value from Elixir
    this.handleEvent("update_message_input_value", ({ value }) => {
      this.textarea.value = value;
      this.handleResize();
    });

    this.handleEvent("clear_message_input", () => {
      this.textarea.value = "";
      this.handleResize();
    });
  },

  handleResize() {
    this.textarea.style.height = 'auto';
    this.textarea.style.height = Math.min(this.textarea.scrollHeight, 120) + 'px';
  },

  destroyed() {
    if (this.textarea) {
      this.textarea.removeEventListener('input', this.handleResize);
    }
  }
};

export const LongPressMessage = {
  mounted() {
    this.messageId = this.el.dataset.messageId;
    this.longPressTimer = null;
    this.isLongPress = false;

    this.el.addEventListener('touchstart', this.handleTouchStart.bind(this), { passive: false });
    this.el.addEventListener('touchend', this.handleTouchEnd.bind(this), { passive: false });
    this.el.addEventListener('touchcancel', this.handleTouchCancel.bind(this), { passive: false });
    this.el.addEventListener('touchmove', this.handleTouchMove.bind(this), { passive: false });
  },


  handleTouchStart(e) {
    this.isLongPress = false;
    this.longPressTimer = setTimeout(() => {
      this.isLongPress = true;
      this.pushEvent("long_press_message", { message_id: this.messageId });
    }, 500); // 500 ms for long press
  },

  handleTouchEnd(e) {
    if (this.longPressTimer) {
      clearTimeout(this.longPressTimer);
    }

    if (this.isLongPress) {
      e.preventDefault();
      e.stopPropagation();
    }
  },

  handleTouchCancel(e) {
    if (this.longPressTimer) {
      clearTimeout(this.longPressTimer);
    }
    this.isLongPress = false;
  },

  handleTouchMove(e) {
    if (this.longPressTimer) {
      clearTimeout(this.longPressTimer);
    }
    this.isLongPress = false;
  },

  destroyed() {
    if (this.longPressTimer) {
      clearTimeout(this.longPressTimer);
    }
  }
};

// Also update the existing ChatScrollManager for desktop
export const ChatScrollManager = {
  mounted() {
    this.scrollToBottom();
    this.observer = new mutationObserver(() => {
      this.scrollToBottom();
    });

    this.observer.observe(this.el, {
      childList: true,
      subtree: true
    });
  },

  updated() {
    this.scrollToBottom();
  },

  scrollToBottom() {
    requestAnimationFrame(() => {
      this.el.scrollTop = this.el.scrollHeight;
    });
  },

  destroyed() {
    if (this.observer) {
      this.observer.disconnect();
    }
  }
};

export const AutoResizeTextarea = {
  mounted() {
    this.textarea = this.el;
    this.textarea.style.height = 'auto';
    this.textarea.style.overflowY = 'hidden';

    this.handleResize = this.handleResize.bind(this);
    this.textarea.addEventListener('input', this.handleResize);

    // Handle event to update value from Elixir
    this.handleEvent("update_message_input_value", ({ value }) => {
      this.textarea.value = value;
      this.handleResize();
    });

    this.handleEvent("clear_message_input", () => {
      this.textarea.value = "";
      this.handleResize();
    });
  },

  handleResize() {
    this.textarea.style.height = 'auto';
    this.textarea.style.height = Math.min(this.textarea.scrollHeight, 120) + 'px';
  },

  destroyed() {
    if (this.textarea) {
      this.textarea.removeEventListener('input', this.handleResize);
    }
  }
};
