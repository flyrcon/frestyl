import "phoenix_html";
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar";

// Import only the hooks we need, avoiding conflicts
import SessionHooks from "./hooks/session_hooks";
import StreamQualityHook from "./hooks/stream_quality";
import MediaUploadHooks from "./hooks/upload_hooks";

// Import utilities
import { setupImageProcessing } from "./image_processor";
import "./analytics";
import Chart from 'chart.js/auto';
import 'chartjs-adapter-date-fns';

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");

// Define ONLY the chat hooks we need for the chat system
const ChatHooks = {
AutoResize: {
  mounted() {
    console.log("AutoResize hook mounted"); // Debug log
    this.setupAutoResize();
    this.setupKeyHandlers();
    this.setupTypingIndicator();
  },

  setupTypingIndicator() {
    const textarea = this.el;
    console.log("Setting up typing indicator for:", textarea); // Debug log
    
    if (!textarea) return;
    
    let typingTimer;
    const TYPING_TIMEOUT = 1000;
    
    textarea.addEventListener('input', (e) => {
      console.log("Input event triggered, value:", e.target.value); // Debug log
      
      if (e.target.value.trim().length > 0) {
        console.log("Sending typing_start event"); // Debug log
        this.pushEvent("typing_start", {});
        
        clearTimeout(typingTimer);
        
        typingTimer = setTimeout(() => {
          console.log("Sending typing_stop event (timeout)"); // Debug log
          this.pushEvent("typing_stop", {});
        }, TYPING_TIMEOUT);
      } else {
        console.log("Sending typing_stop event (empty)"); // Debug log
        this.pushEvent("typing_stop", {});
        clearTimeout(typingTimer);
      }
    });
    
    textarea.addEventListener('blur', () => {
      console.log("Textarea lost focus, sending typing_stop"); // Debug log
      this.pushEvent("typing_stop", {});
      clearTimeout(typingTimer);
    });
  }
},

    setupKeyHandlers() {
      const textarea = this.el;
      if (!textarea) return;
      
      // Handle Enter key for form submission
      textarea.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
          e.preventDefault();
          const form = textarea.closest('form');
          if (form) {
            // Check if there's content or files before submitting
            const hasContent = textarea.value.trim().length > 0;
            const fileInput = form.querySelector('[data-phx-upload-ref]');
            const hasFiles = fileInput && fileInput.files && fileInput.files.length > 0;
            
            if (hasContent || hasFiles) {
              // Trigger the form submit event
              const submitEvent = new Event('submit', { 
                bubbles: true, 
                cancelable: true 
              });
              form.dispatchEvent(submitEvent);
            }
          }
        }
      });
    },

    setupTypingIndicator() {
      const textarea = this.el;
      if (!textarea) {
        console.log("No textarea found for typing indicator!");
        return;
      }
      
      console.log("Setting up typing indicator on:", textarea); // Debug line
      
      let typingTimer;
      const TYPING_TIMEOUT = 1000; // Stop typing after 1 second of inactivity
      
      // Start typing indicator
      textarea.addEventListener('input', (e) => {
        console.log("Input detected:", e.target.value); // Debug line
        
        // Only trigger if there's actual content
        if (e.target.value.trim().length > 0) {
          console.log("Sending typing_start event"); // Debug line
          this.pushEvent("typing_start", {});
          
          // Clear previous timer
          clearTimeout(typingTimer);
          
          // Set new timer to stop typing
          typingTimer = setTimeout(() => {
            console.log("Sending typing_stop event (timeout)"); // Debug line
            this.pushEvent("typing_stop", {});
          }, TYPING_TIMEOUT);
        } else {
          // If field is empty, stop typing immediately
          console.log("Sending typing_stop event (empty field)"); // Debug line
          this.pushEvent("typing_stop", {});
          clearTimeout(typingTimer);
        }
      });
      
      // Stop typing when textarea loses focus
      textarea.addEventListener('blur', () => {
        console.log("Sending typing_stop event (blur)"); // Debug line
        this.pushEvent("typing_stop", {});
        clearTimeout(typingTimer);
      });
    }
  },

  DragAndDrop: {
    mounted() {
      this.dragCounter = 0;
      this.overlay = document.getElementById('drag-overlay');
      
      // Bind event listeners
      document.addEventListener('dragenter', this.handleDragEnter.bind(this));
      document.addEventListener('dragleave', this.handleDragLeave.bind(this));
      document.addEventListener('dragover', this.handleDragOver.bind(this));
      document.addEventListener('drop', this.handleDrop.bind(this));
    },

    destroyed() {
      // Clean up event listeners
      document.removeEventListener('dragenter', this.handleDragEnter);
      document.removeEventListener('dragleave', this.handleDragLeave);
      document.removeEventListener('dragover', this.handleDragOver);
      document.removeEventListener('drop', this.handleDrop);
    },

    handleDragEnter(e) {
      e.preventDefault();
      this.dragCounter++;
      if (this.dragCounter === 1) {
        this.overlay.classList.remove('hidden');
      }
    },

    handleDragLeave(e) {
      e.preventDefault();
      this.dragCounter--;
      if (this.dragCounter === 0) {
        this.overlay.classList.add('hidden');
      }
    },

    handleDragOver(e) {
      e.preventDefault();
    },

    handleDrop(e) {
      e.preventDefault();
      this.dragCounter = 0;
      this.overlay.classList.add('hidden');
      
      // Let LiveView handle the drop if it's in the target area
      const dropTarget = document.querySelector('[phx-drop-target]');
      if (dropTarget && (dropTarget.contains(e.target) || e.target === dropTarget)) {
        // LiveView will handle this
        return;
      }
    }
  },

  MessageForm: {
    mounted() {
      console.log("MessageForm hook mounted!"); // Debug line
      
      // Handle the reset form event
      this.handleEvent("reset-form", () => {
        const textarea = this.el.querySelector('textarea[name="content"]');
        if (textarea) {
          textarea.value = '';
          textarea.style.height = 'auto';
          textarea.focus();
          
          // Stop typing indicator when form is reset
          console.log("Sending typing_stop event (form reset)"); // Debug line
          this.pushEvent("typing_stop", {});
        }
      });
    }
  }
};

// Simple file test hook for debugging
const SimpleFileTest = {
  mounted() {
    console.log("SimpleFileTest hook mounted");
    
    const fileInput = document.getElementById('basic-file-input');
    const fileInfo = document.getElementById('file-info');
    
    if (fileInput && fileInfo) {
      fileInput.addEventListener('change', function(e) {
        console.log('File input changed', e.target.files);
        if (e.target.files.length > 0) {
          fileInfo.textContent = 'Selected: ' + e.target.files[0].name;
          fileInfo.style.color = 'green';
        } else {
          fileInfo.textContent = 'No files selected';
          fileInfo.style.color = 'red';
        }
      });
    }
    
    const clickArea = document.getElementById('click-test-area');
    const clickResult = document.getElementById('click-result');
    
    if (clickArea && clickResult) {
      clickArea.addEventListener('click', function() {
        console.log('Click test triggered');
        clickResult.textContent = '✅ JavaScript working! ' + new Date().toLocaleTimeString();
        clickResult.style.color = 'green';
      });
    }
  }
};

// Define other hook functions that your app needs
function createFileUploaderHook() {
  return {
    mounted() {
      console.log("FileUploader hook mounted - but this may conflict with LiveView uploads");
      // Don't implement file upload logic here - let LiveView handle it
    }
  };
}

const MessagesContainerHook = {
  mounted() {
    this.scrollToBottom();
  },
  updated() {
    this.scrollToBottom();
  },
  scrollToBottom() {
    this.el.scrollTop = this.el.scrollHeight;
  }
};

const TypingIndicatorHook = {
  mounted() {
    // Typing indicator logic
  }
};

const AutoResizeTextareaHook = {
  mounted() {
    this.resize();
    this.el.addEventListener('input', () => this.resize());
  },
  resize() {
    this.el.style.height = 'auto';
    this.el.style.height = (this.el.scrollHeight) + 'px';
  }
};

const MessageTextareaHook = {
  mounted() {
    this.el.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        const form = this.el.closest('form');
        if (form) {
          form.submit();
        }
      }
    });
  }
};

const ShowHidePriceHook = {
  mounted() {
    // Existing logic
  }
};

const ShowHideMaxAttendeesHook = {
  mounted() {
    // Existing logic
  }
};

const TimeSeriesChartHook = {
  mounted() {
    // Chart logic
  }
};

const StackedBarChartHook = {
  mounted() {
    // Chart logic
  }
};

const PieChartHook = {
  mounted() {
    // Chart logic
  }
};

const ImageProcessorHook = {
  mounted() {
    // Image processing logic
  }
};

// Combine all hooks - AVOID DUPLICATES
let Hooks = {
  // Chat hooks (simplified)
  ...ChatHooks
  ChatForm: ChatHooks.ChatForm,
  AutoResize: ChatHooks.AutoResize,
  
  // Media upload hooks (from upload_hooks.js)
  ...MediaUploadHooks,
  
  // Other hooks
  FileUploader: createFileUploaderHook(),
  MessagesContainer: MessagesContainerHook,
  SimpleFileTest: SimpleFileTest,
  TypingIndicator: TypingIndicatorHook,
  AutoResizeTextarea: AutoResizeTextareaHook,
  MessageTextarea: MessageTextareaHook,
  ShowHidePrice: ShowHidePriceHook,
  ShowHideMaxAttendees: ShowHideMaxAttendeesHook,
  TimeSeriesChart: TimeSeriesChartHook,
  StackedBarChart: StackedBarChartHook,
  PieChart: PieChartHook,
  ImageProcessor: ImageProcessorHook,
  SessionHooks,
  StreamQuality: StreamQualityHook
};

// Initialize LiveSocket
let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: Hooks
});

// Topbar Progress Indicator
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", () => topbar.show());
window.addEventListener("phx:page-loading-stop", () => topbar.hide());

// Connect LiveSocket
liveSocket.connect();
window.liveSocket = liveSocket;