// assets/js/hooks.js
const Hooks = {}

Hooks.Countdown = {
  mounted() {
    this.countdownInterval = setInterval(() => {
      this.updateCountdown()
    }, 1000)
    
    this.updateCountdown()
  },
  
  destroyed() {
    clearInterval(this.countdownInterval)
  },
  
  updateCountdown() {
    const startsAt = new Date(this.el.dataset.startsAt)
    const now = new Date()
    
    if (now >= startsAt) {
      this.el.innerHTML = "Event has started!"
      clearInterval(this.countdownInterval)
      
      // Auto-reload the page when the event starts
      window.location.reload()
      return
    }
    
    const diff = Math.floor((startsAt - now) / 1000)
    
    const hours = Math.floor(diff / 3600)
    const minutes = Math.floor((diff % 3600) / 60)
    const seconds = diff % 60
    
    this.el.querySelector('.hours').textContent = hours.toString().padStart(2, '0')
    this.el.querySelector('.minutes').textContent = minutes.toString().padStart(2, '0')
    this.el.querySelector('.seconds').textContent = seconds.toString().padStart(2, '0')
  }
};

export const SortableSections = {
  mounted() {
    console.log("SortableSections hook mounted - basic version");
    // For now, just a placeholder to stop the error
  },
  
  updated() {
    // Placeholder
  }
};

Hooks.ShowHidePrice = {
  mounted() {
    this.toggleVisibility()
    
    document.getElementById('event_admission_type').addEventListener('change', () => {
      this.toggleVisibility()
    })
  },
  
  toggleVisibility() {
    const admission = document.getElementById('event_admission_type').value
    const requiredType = this.el.dataset.admissionType
    
    if (admission === requiredType) {
      this.el.closest('.field').style.display = 'block'
    } else {
      this.el.closest('.field').style.display = 'none'
    }
  }
}

Hooks.ShowHideMaxAttendees = {
  mounted() {
    this.toggleVisibility()
    
    document.getElementById('event_admission_type').addEventListener('change', () => {
      this.toggleVisibility()
    })
  },
  
  toggleVisibility() {
    const admission = document.getElementById('event_admission_type').value
    const requiredType = this.el.dataset.admissionType
    
    if (admission === requiredType) {
      this.el.closest('.field').style.display = 'block'
    } else {
      this.el.closest('.field').style.display = 'none'
    }
  }
}

// Auto-scroll for chat messages
Hooks.AutoScroll = {
  mounted() {
    this.scrollToBottom();
    this.observe();
    
    // Scroll to bottom when a new message is sent
    this.handleEvent("chat-message-sent", () => {
      this.scrollToBottom();
    });
  },
  
  observe() {
    // Observe when new messages are added
    this.observer = new MutationObserver(mutations => {
      // Only auto-scroll if already at the bottom or if the new message is from the current user
      if (this.isAtBottom() || this.isNewMessageFromCurrentUser(mutations)) {
        this.scrollToBottom();
      }
    });
    
    this.observer.observe(this.el, {
      childList: true,
      subtree: true
    });
  },
  
  isNewMessageFromCurrentUser(mutations) {
    const currentUserId = document.body.getAttribute('data-user-id');
    if (!currentUserId) return false;
    
    for (const mutation of mutations) {
      for (const node of mutation.addedNodes) {
        if (node.nodeType === Node.ELEMENT_NODE && node.dataset && node.dataset.userId === currentUserId) {
          return true;
        }
      }
    }
    
    return false;
  },
  
  updated() {
    if (this.isAtBottom()) {
      this.scrollToBottom();
    }
  },
  
  beforeDestroy() {
    if (this.observer) {
      this.observer.disconnect();
    }
  },
  
  scrollToBottom() {
    this.el.scrollTop = this.el.scrollHeight;
  },
  
  isAtBottom() {
    const threshold = 50; // pixels from bottom to consider "at bottom"
    return this.el.scrollHeight - this.el.scrollTop - this.el.clientHeight < threshold;
  }
};

// Auto-resize textarea as user types
Hooks.AutoResizeTextarea = {
  mounted() {
    this.resize();
    this.el.addEventListener('input', () => this.resize());
  },

  resize() {
    this.el.style.height = 'auto';
    const newHeight = Math.min(Math.max(this.el.scrollHeight, 40), 200); // Min 40px, max 200px
    this.el.style.height = `${newHeight}px`;
  }
};

// Type indicator with debouncing
Hooks.TypingIndicator = {
  mounted() {
    this.typingTimeout = null;
    this.lastTypingState = false;
    
    this.el.addEventListener('input', () => {
      const isTyping = this.el.value.trim().length > 0;
      
      // Only send typing events when the state changes
      if (isTyping !== this.lastTypingState) {
        this.pushEvent('typing', { typing: isTyping ? "true" : "false" });
        this.lastTypingState = isTyping;
      }
      
      // Reset timeout if user is typing
      if (isTyping) {
        clearTimeout(this.typingTimeout);
        
        // Set timeout to stop typing indicator after 3 seconds of inactivity
        this.typingTimeout = setTimeout(() => {
          this.pushEvent('typing', { typing: "false" });
          this.lastTypingState = false;
        }, 3000);
      }
    });
    
    // When form is submitted, immediately stop typing
    const form = this.el.closest('form');
    if (form) {
      form.addEventListener('submit', () => {
        clearTimeout(this.typingTimeout);
        this.pushEvent('typing', { typing: "false" });
        this.lastTypingState = false;
      });
    }
  },
  
  beforeDestroy() {
    clearTimeout(this.typingTimeout);
  }
};

// File upload handling
Hooks.FileUpload = {
  mounted() {
    this.el.addEventListener('change', (e) => {
      const files = e.target.files;
      if (!files || files.length === 0) return;
      
      // Show loading state
      this.pushEvent('upload-started', {});
      
      const formData = new FormData();
      for (let i = 0; i < files.length; i++) {
        formData.append('files[]', files[i]);
      }
      
      // Get CSRF token
      const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
      
      // Upload files
      fetch('/api/media/upload', {
        method: 'POST',
        headers: {
          'X-CSRF-Token': csrfToken
        },
        body: formData
      })
      .then(response => response.json())
      .then(data => {
        // Reset input
        this.el.value = '';
        
        // Send files to LiveView
        this.pushEvent('files-uploaded', { files: data.files });
      })
      .catch(error => {
        console.error('Upload error:', error);
        this.pushEvent('upload-error', { error: 'Failed to upload files' });
        this.el.value = '';
      });
    });
  }
};

// Toggle dropdown menu
Hooks.DropdownMenu = {
  mounted() {
    this.el.addEventListener('click', (e) => {
      const target = document.getElementById(this.el.dataset.target);
      if (target) {
        target.classList.toggle('hidden');
      }
      
      // Close when clicking outside
      const closeMenu = (event) => {
        if (!target.contains(event.target) && !this.el.contains(event.target)) {
          target.classList.add('hidden');
          document.removeEventListener('click', closeMenu);
        }
      };
      
      document.addEventListener('click', closeMenu);
    });
  }
};


export default Hooks;
