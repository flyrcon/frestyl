// assets/js/hooks/chat_hooks.js

export const ChatScroller = {
  mounted() {
    this.scrollToBottom();
    this.setupScrollObserver();
    
    // Handle events from existing system
    this.handleEvent("chat-message-sent", () => {
      this.scrollToBottom();
    });
    
    // Observe for new message elements (from existing system)
    this.observer = new MutationObserver(() => {
      if (this.isNearBottom()) {
        this.scrollToBottom();
      }
    });
    
    this.observer.observe(this.el, { childList: true });
  },

  updated() {
    // Auto-scroll to bottom when new messages arrive
    if (this.isNearBottom()) {
      this.scrollToBottom();
    }
  },

  destroyed() {
    if (this.observer) {
      this.observer.disconnect();
    }
  },

  scrollToBottom() {
    this.el.scrollTop = this.el.scrollHeight;
  },

  isNearBottom() {
    const threshold = 100; // pixels from bottom
    return this.el.scrollHeight - this.el.scrollTop - this.el.clientHeight < threshold;
  },

  setupScrollObserver() {
    // Add scroll position tracking for auto-scroll behavior
    this.el.addEventListener('scroll', () => {
      const isAtBottom = this.isNearBottom();
      // You could emit events here to update component state if needed
    });
  }
};

export const AutoResizeTextarea = {
  mounted() {
    this.setupAutoResize();
    this.setupKeyboardShortcuts();
  },

  setupAutoResize() {
    const textarea = this.el;
    
    const resize = () => {
      // Reset height to auto to get the correct scrollHeight
      textarea.style.height = 'auto';
      
      // Set height based on scrollHeight, with min and max constraints
      const minHeight = 44; // matches min-height in CSS
      const maxHeight = 120; // matches max-height in CSS
      const newHeight = Math.min(Math.max(textarea.scrollHeight, minHeight), maxHeight);
      
      textarea.style.height = newHeight + 'px';
      
      // Update scroll if content exceeds max height
      if (textarea.scrollHeight > maxHeight) {
        textarea.style.overflowY = 'scroll';
      } else {
        textarea.style.overflowY = 'hidden';
      }
    };

    // Resize on input
    textarea.addEventListener('input', resize);
    
    // Resize on paste
    textarea.addEventListener('paste', () => {
      setTimeout(resize, 0);
    });

    // Initial resize
    resize();
  },

  setupKeyboardShortcuts() {
    const textarea = this.el;
    
    textarea.addEventListener('keydown', (e) => {
      // Send message on Cmd/Ctrl + Enter
      if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
        e.preventDefault();
        const form = textarea.closest('form');
        if (form) {
          form.dispatchEvent(new Event('submit', { bubbles: true }));
        }
      }
      
      // Prevent form submission on Enter without Shift
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        // The LiveView will handle this via phx-keydown
      }
    });
  }
};

export const EmojiPicker = {
  mounted() {
    this.setupEmojiPicker();
  },

  updated() {
    if (this.el.classList.contains('open')) {
      this.showPicker();
    } else {
      this.hidePicker();
    }
  },

  setupEmojiPicker() {
    // Hip-hop/urban culture focused emoji picker with music production vibes
    // Includes diverse skin tones representing the community
    this.emojis = [
      // Fire/Hot reactions
      '🔥', '💯', '🚀', '⚡', '💥', '🎯', '🔊', '📈',
      
      // Music & Studio
      '🎤', '🎧', '🎵', '🎶', '🎼', '🎹', '🥁', '🎺',
      '🎸', '🎻', '🪕', '🎷', '📻', '💿', '💽', '📀',
      
      // Hip-hop gestures & vibes (diverse skin tones)
      '🤟🏽', '🤟🏾', '🤟🏿', '🤘🏽', '🤘🏾', '🤘🏿', 
      '👌🏽', '👌🏾', '👌🏿', '🙌🏽', '🙌🏾', '🙌🏿',
      '💪🏽', '💪🏾', '💪🏿', '🫵🏽', '🫵🏾', '🫵🏿',
      '👏🏽', '👏🏾', '👏🏿', '✊🏽', '✊🏾', '✊🏿',
      '👊🏽', '👊🏾', '👊🏿', '🤜🏽', '🤜🏾', '🤜🏿',
      '🤛🏽', '🤛🏾', '🤛🏿', '🙏🏽', '🙏🏾', '🙏🏿',
      
      // Pointing & gestures (diverse)
      '👈🏽', '👈🏾', '👈🏿', '👉🏽', '👉🏾', '👉🏿',
      '👆🏽', '👆🏾', '👆🏿', '✌🏽', '✌🏾', '✌🏿',
      '🤞🏽', '🤞🏾', '🤞🏿', '🫰🏽', '🫰🏾', '🫰🏿',
      '🤏🏽', '🤏🏾', '🤏🏿', '🤌🏽', '🤌🏾', '🤌🏿',
      '👋🏽', '👋🏾', '👋🏿', '🤚🏽', '🤚🏾', '🤚🏿',
      '🫴🏽', '🫴🏾', '🫴🏿', '🫳🏽', '🫳🏾', '🫳🏿',
      '👐🏽', '👐🏾', '👐🏿', '🤲🏽', '🤲🏾', '🤲🏿',
      
      // Money & success
      '💰', '💸', '🤑', '💵', '💴', '💶', '💷', '🏆',
      '🥇', '🏅', '📊', '📈', '💹', '🎰', '🎲', '🃏',
      
      // Cool faces & expressions (diverse skin tones)
      '😎', '🤩', '😤', '🥶', '😈', '👹', '🤯', '🤤',
      '😵‍💫', '🥴', '😮‍💨', '🫨', '🤐', '🫡',
      
      // Crowns and symbols
      '👑', '💎', '⭐', '🌟', '💫', '✨',
      
      // Classic hip-hop symbols
      '🎪', '🎭', '🎨', '🖼️', '🎬', '📹', '📸', '⚖️',
      '🌆', '🌃', '🏙️', '🌉', '🗽', '🏢', '🚗', '🏎️',
      
      // Time & hustle
      '⏰', '⏲️', '⏱️', '🌙', '⚡', '🌪️', '🌊', '❄️'
    ];
  },

  showPicker() {
    if (this.pickerEl) return;

    this.pickerEl = document.createElement('div');
    this.pickerEl.className = 'absolute bottom-full mb-2 right-0 bg-black/90 backdrop-blur-sm rounded-lg p-3 grid grid-cols-8 gap-1 z-50 border border-white/20';
    this.pickerEl.style.width = '240px';

    this.emojis.forEach(emoji => {
      const button = document.createElement('button');
      button.textContent = emoji;
      button.className = 'w-6 h-6 text-lg hover:bg-white/10 rounded transition-colors';
      button.type = 'button';
      
      button.addEventListener('click', () => {
        this.insertEmoji(emoji);
        this.hidePicker();
      });
      
      this.pickerEl.appendChild(button);
    });

    this.el.style.position = 'relative';
    this.el.appendChild(this.pickerEl);

    // Close on click outside
    setTimeout(() => {
      document.addEventListener('click', this.handleOutsideClick, true);
    }, 0);
  },

  hidePicker() {
    if (this.pickerEl) {
      this.pickerEl.remove();
      this.pickerEl = null;
      document.removeEventListener('click', this.handleOutsideClick, true);
    }
  },

  handleOutsideClick(e) {
    if (!this.el.contains(e.target)) {
      this.hidePicker();
    }
  },

  insertEmoji(emoji) {
    const textarea = document.getElementById('message-input');
    if (textarea) {
      const start = textarea.selectionStart;
      const end = textarea.selectionEnd;
      const text = textarea.value;
      
      const newText = text.substring(0, start) + emoji + text.substring(end);
      textarea.value = newText;
      
      // Set cursor position after emoji
      const newPosition = start + emoji.length;
      textarea.setSelectionRange(newPosition, newPosition);
      
      // Trigger input event to update LiveView
      textarea.dispatchEvent(new Event('input', { bubbles: true }));
      textarea.focus();
    }
  },

  destroyed() {
    this.hidePicker();
  }
};

export const TypingIndicator = {
  mounted() {
    this.typingTimer = null;
    this.isTyping = false;
  },

  startTyping() {
    if (!this.isTyping) {
      this.isTyping = true;
      this.pushEvent('typing_start');
    }
    
    // Clear existing timer
    if (this.typingTimer) {
      clearTimeout(this.typingTimer);
      this.typingTimer = null;
    }
  },

  destroyed() {
    this.stopTyping();
  }
};

export const MessageNotifications = {
  mounted() {
    this.setupNotificationPermissions();
    this.lastMessageCount = 0;
    
    // Initialize audio for notifications (from existing system)
    this.audio = new Audio("/sounds/notification.mp3");
    this.audio.volume = 0.3;
    
    // Handle events from existing system
    this.handleEvent("new_channel_message", () => {
      if (document.hidden) {
        this.audio.play();
      }
    });
  },

  updated() {
    // Check for new messages and show notifications
    const currentMessageCount = this.el.children.length;
    
    if (currentMessageCount > this.lastMessageCount && this.lastMessageCount > 0) {
      // New message received
      const newMessages = Array.from(this.el.children).slice(this.lastMessageCount);
      newMessages.forEach(messageEl => {
        this.showMessageNotification(messageEl);
      });
      
      // Play sound if window is not focused (existing functionality)
      if (document.hidden) {
        this.audio.play().catch(e => console.log('Audio play failed:', e));
      }
    }
    
    this.lastMessageCount = currentMessageCount;
  },

  async setupNotificationPermissions() {
    if ('Notification' in window && Notification.permission === 'default') {
      try {
        await Notification.requestPermission();
      } catch (error) {
        console.log('Notification permission request failed:', error);
      }
    }
  },

  showMessageNotification(messageEl) {
    // Only show notification if window is not focused
    if (document.hasFocus()) return;
    
    // Only show for other users' messages
    if (messageEl.classList.contains('own-message')) return;
    
    if ('Notification' in window && Notification.permission === 'granted') {
      const username = messageEl.querySelector('.message-username')?.textContent || 'Someone';
      const content = messageEl.querySelector('.message-content')?.textContent || 'New message';
      
      const notification = new Notification(`${username} in Studio`, {
        body: content.length > 50 ? content.substring(0, 47) + '...' : content,
        icon: '/images/logo.svg',
        tag: 'studio-chat', // Replace previous notifications
        requireInteraction: false
      });
      
      // Auto-close after 4 seconds
      setTimeout(() => notification.close(), 4000);
      
      // Focus window when notification is clicked
      notification.onclick = () => {
        window.focus();
        notification.close();
      };
    }
  }
};

export const FileUpload = {
  mounted() {
    this.setupDragAndDrop();
    this.setupFileInput();
  },

  setupDragAndDrop() {
    const chatContainer = this.el.closest('.chat-container');
    if (!chatContainer) return;

    // Prevent default drag behaviors
    ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
      chatContainer.addEventListener(eventName, this.preventDefaults, false);
      document.body.addEventListener(eventName, this.preventDefaults, false);
    });

    // Highlight drop area
    ['dragenter', 'dragover'].forEach(eventName => {
      chatContainer.addEventListener(eventName, this.highlight.bind(this), false);
    });

    ['dragleave', 'drop'].forEach(eventName => {
      chatContainer.addEventListener(eventName, this.unhighlight.bind(this), false);
    });

    // Handle dropped files
    chatContainer.addEventListener('drop', this.handleDrop.bind(this), false);
  },

  setupFileInput() {
    // Create hidden file input
    this.fileInput = document.createElement('input');
    this.fileInput.type = 'file';
    this.fileInput.multiple = true;
    this.fileInput.accept = 'audio/*,image/*,.pdf,.doc,.docx,.txt';
    this.fileInput.style.display = 'none';
    
    this.fileInput.addEventListener('change', (e) => {
      this.handleFiles(e.target.files);
    });
    
    document.body.appendChild(this.fileInput);
  },

  preventDefaults(e) {
    e.preventDefault();
    e.stopPropagation();
  },

  highlight(e) {
    const chatContainer = this.el.closest('.chat-container');
    if (chatContainer) {
      chatContainer.classList.add('drag-over');
    }
  },

  unhighlight(e) {
    const chatContainer = this.el.closest('.chat-container');
    if (chatContainer) {
      chatContainer.classList.remove('drag-over');
    }
  },

  handleDrop(e) {
    const dt = e.dataTransfer;
    const files = dt.files;
    this.handleFiles(files);
  },

  handleFiles(files) {
    if (files.length === 0) return;
    
    // Convert FileList to Array
    const fileArray = Array.from(files);
    
    // Validate files
    const validFiles = fileArray.filter(file => this.isValidFile(file));
    
    if (validFiles.length !== fileArray.length) {
      this.showError('Some files were rejected. Only audio, image, and document files are allowed.');
    }
    
    if (validFiles.length > 0) {
      this.uploadFiles(validFiles);
    }
  },

  isValidFile(file) {
    const maxSize = 50 * 1024 * 1024; // 50MB
    const allowedTypes = [
      'audio/', 'image/', 'application/pdf', 
      'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'text/plain'
    ];
    
    if (file.size > maxSize) {
      return false;
    }
    
    return allowedTypes.some(type => file.type.startsWith(type));
  },

  async uploadFiles(files) {
    // Show upload progress UI
    this.showUploadProgress(files);
    
    try {
      // Use Phoenix LiveView uploads or custom upload logic
      for (const file of files) {
        await this.uploadFile(file);
      }
      
      this.hideUploadProgress();
      this.pushEvent('files_uploaded', { count: files.length });
      
    } catch (error) {
      this.hideUploadProgress();
      this.showError('Upload failed. Please try again.');
      console.error('Upload error:', error);
    }
  },

  async uploadFile(file) {
    // This would integrate with your existing file upload system
    // For now, we'll simulate the upload
    return new Promise((resolve) => {
      setTimeout(() => {
        resolve({ id: Date.now(), name: file.name, size: file.size });
      }, 1000 + Math.random() * 2000);
    });
  },

  showUploadProgress(files) {
    // Create upload progress overlay
    const overlay = document.createElement('div');
    overlay.className = 'fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50';
    overlay.innerHTML = `
      <div class="bg-white/10 backdrop-blur-xl rounded-2xl p-6 max-w-md w-full mx-4 border border-white/20">
        <h3 class="text-white font-bold mb-4">Uploading Files</h3>
        <div class="space-y-2">
          ${files.map((file, index) => `
            <div class="flex items-center space-x-3">
              <div class="flex-1">
                <div class="text-white text-sm truncate">${file.name}</div>
                <div class="w-full bg-white/20 rounded-full h-2 mt-1">
                  <div class="upload-progress-${index} bg-gradient-to-r from-purple-500 to-pink-500 h-2 rounded-full transition-all duration-300" style="width: 0%"></div>
                </div>
              </div>
            </div>
          `).join('')}
        </div>
      </div>
    `;
    
    document.body.appendChild(overlay);
    this.uploadOverlay = overlay;
    
    // Simulate progress
    files.forEach((file, index) => {
      this.simulateProgress(index);
    });
  },

  simulateProgress(index) {
    const progressBar = document.querySelector(`.upload-progress-${index}`);
    if (!progressBar) return;
    
    let progress = 0;
    const interval = setInterval(() => {
      progress += Math.random() * 20;
      if (progress >= 100) {
        progress = 100;
        clearInterval(interval);
      }
      progressBar.style.width = `${progress}%`;
    }, 200);
  },

  hideUploadProgress() {
    if (this.uploadOverlay) {
      this.uploadOverlay.remove();
      this.uploadOverlay = null;
    }
  },

  showError(message) {
    // Create temporary error notification
    const error = document.createElement('div');
    error.className = 'fixed top-4 right-4 bg-red-500/90 backdrop-blur-sm text-white px-4 py-2 rounded-lg z-50 transform translate-x-full transition-transform';
    error.textContent = message;
    
    document.body.appendChild(error);
    
    // Animate in
    setTimeout(() => {
      error.style.transform = 'translateX(0)';
    }, 100);
    
    // Remove after 5 seconds
    setTimeout(() => {
      error.style.transform = 'translateX(100%)';
      setTimeout(() => error.remove(), 300);
    }, 5000);
  },

  openFileDialog() {
    this.fileInput.click();
  },

  destroyed() {
    if (this.fileInput) {
      this.fileInput.remove();
    }
    if (this.uploadOverlay) {
      this.uploadOverlay.remove();
    }
  }
};

// Channel Chat Presence (from existing system)
export const ChannelPresence = {
  mounted() {
    this.handleEvent("presence_state", presences => {
      this.updatePresenceList(presences);
    });
    
    this.handleEvent("presence_diff", diff => {
      this.updatePresenceDiff(diff);
    });
  },
  
  updatePresenceList(presences) {
    // Handle initial presence state
    console.log("Presence list:", presences);
    // You can emit events to update UI components here
    window.dispatchEvent(new CustomEvent('presence_updated', { 
      detail: { presences } 
    }));
  },
  
  updatePresenceDiff(diff) {
    // Handle presence changes (joins/leaves)
    console.log("Presence diff:", diff);
    window.dispatchEvent(new CustomEvent('presence_diff', { 
      detail: { diff } 
    }));
  }
};

// Auto-scroll hook (alias for compatibility with existing system)
export const AutoScroll = ChatScroller;

// Message sound hook (enhanced version of existing)
export const MessageSound = {
  mounted() {
    this.audio = new Audio("/sounds/notification.mp3");
    this.audio.volume = 0.3;
    
    this.handleEvent("new_channel_message", () => {
      if (document.hidden) {
        this.audio.play().catch(e => console.log('Audio play failed:', e));
      }
    });
    
    // Also listen for new studio messages
    this.handleEvent("new_studio_message", () => {
      if (document.hidden) {
        this.audio.play().catch(e => console.log('Audio play failed:', e));
      }
    });
  }
};

// Export all hooks for easy import (compatible with existing system)
export const ChatHooks = {
  ChatScroller,
  AutoResizeTextarea,
  EmojiPicker,
  TypingIndicator,
  MessageNotifications,
  FileUpload,
  ChannelPresence,
  AutoScroll, // Alias for existing system
  MessageSound
};

// Default export for backward compatibility
let ChatHooks = {};

ChatHooks.Typing = {
  mounted() {
    this.typingTimer = null;
    this.isTyping = false;

    this.el.addEventListener("input", () => {
      this.startTyping();
    });
  },

  startTyping() {
    if (!this.isTyping) {
      this.isTyping = true;
      this.pushEvent("typing_start");
    }

    if (this.typingTimer) {
      clearTimeout(this.typingTimer);
    }

    // Stop typing after 3 seconds of inactivity
    this.typingTimer = setTimeout(() => {
      this.stopTyping();
    }, 3000);
  },

  stopTyping() {
    if (this.isTyping) {
      this.isTyping = false;
      this.pushEvent("typing_stop");
    }

    if (this.typingTimer) {
      clearTimeout(this.typingTimer);
      this.typingTimer = null;
    }
  }
};

export default ChatHooks;
