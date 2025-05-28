import "phoenix_html";
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar";

// Import only the hooks we need, avoiding conflicts
import SessionHooks from "./hooks/session_hooks";
import StreamQualityHook from "./hooks/stream_quality";
import { VideoCapture } from "./video_capture_hook";

// Import utilities
import { setupImageProcessing } from "./image_processor";
import "./analytics";
import Chart from 'chart.js/auto';
import 'chartjs-adapter-date-fns';
import { VideoCapture } from "./hooks/video_capture";

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");

// Chat hooks for the chat system
const ChatHooks = {
  AutoResize: {
    mounted() {
      console.log("AutoResize hook mounted");
      this.setupAutoResize();
      this.setupKeyHandlers();
      this.setupTypingIndicator();
    },

    setupAutoResize() {
      const textarea = this.el;
      if (!textarea) return;
      
      const resize = () => {
        textarea.style.height = 'auto';
        textarea.style.height = textarea.scrollHeight + 'px';
      };
      
      textarea.addEventListener('input', resize);
      resize(); // Initial resize
    },

    setupKeyHandlers() {
      const textarea = this.el;
      if (!textarea) return;
      
      textarea.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
          e.preventDefault();
          const form = textarea.closest('form');
          if (form) {
            const hasContent = textarea.value.trim().length > 0;
            const fileInput = form.querySelector('[data-phx-upload-ref]');
            const hasFiles = fileInput && fileInput.files && fileInput.files.length > 0;
            
            if (hasContent || hasFiles) {
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
      
      console.log("Setting up typing indicator on:", textarea);
      
      let typingTimer;
      const TYPING_TIMEOUT = 1000;
      
      textarea.addEventListener('input', (e) => {
        console.log("Input detected:", e.target.value);
        
        if (e.target.value.trim().length > 0) {
          console.log("Sending typing_start event");
          this.pushEvent("typing_start", {});
          
          clearTimeout(typingTimer);
          
          typingTimer = setTimeout(() => {
            console.log("Sending typing_stop event (timeout)");
            this.pushEvent("typing_stop", {});
          }, TYPING_TIMEOUT);
        } else {
          console.log("Sending typing_stop event (empty field)");
          this.pushEvent("typing_stop", {});
          clearTimeout(typingTimer);
        }
      });
      
      textarea.addEventListener('blur', () => {
        console.log("Sending typing_stop event (blur)");
        this.pushEvent("typing_stop", {});
        clearTimeout(typingTimer);
      });
    }
  },

  DragAndDrop: {
    mounted() {
      this.dragCounter = 0;
      this.overlay = document.getElementById('drag-overlay');
      
      document.addEventListener('dragenter', this.handleDragEnter.bind(this));
      document.addEventListener('dragleave', this.handleDragLeave.bind(this));
      document.addEventListener('dragover', this.handleDragOver.bind(this));
      document.addEventListener('drop', this.handleDrop.bind(this));
    },

    destroyed() {
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
      
      const dropTarget = document.querySelector('[phx-drop-target]');
      if (dropTarget && (dropTarget.contains(e.target) || e.target === dropTarget)) {
        return;
      }
    }
  },

  MessageForm: {
    mounted() {
      console.log("MessageForm hook mounted!");
      
      this.handleEvent("reset-form", () => {
        const textarea = this.el.querySelector('textarea[name="content"]');
        if (textarea) {
          textarea.value = '';
          textarea.style.height = 'auto';
          textarea.focus();
          
          console.log("Sending typing_stop event (form reset)");
          this.pushEvent("typing_stop", {});
        }
      });
    }
  }
};

// File test hook for debugging
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

// Create file uploader hook
function createFileUploaderHook() {
  return {
    mounted() {
      console.log("FileUploader hook mounted - but this may conflict with LiveView uploads");
    }
  };
}

// Other utility hooks
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
    // Typing indicator logic if needed
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

// Chart hooks
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

// Chat auto-scroll hook
const ChatScroll = {
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

const SoundCheck = {
  mounted() {
    console.log("SoundCheck hook mounted");
    
    // Auto-start network test
    setTimeout(() => {
      this.testNetwork();
    }, 1000);
    
    // Handle permission requests
    this.handleEvent("request_media_permissions", () => {
      this.requestPermissions();
    });
    
    // Handle speaker tests
    this.handleEvent("test_speaker_audio", () => {
      this.testSpeakers();
    });
  },

  async requestPermissions() {
    try {
      console.log("Requesting media permissions...");
      
      const stream = await navigator.mediaDevices.getUserMedia({
        audio: true,
        video: true
      });
      
      console.log("Got stream:", stream);
      
      // Check what we got
      const audioTracks = stream.getAudioTracks();
      const videoTracks = stream.getVideoTracks();
      
      // Set up microphone monitoring
      if (audioTracks.length > 0) {
        this.monitorMicrophone(stream);
      }
      
      // Send success
      this.pushEvent("permissions_granted", {
        audio: audioTracks.length > 0,
        video: videoTracks.length > 0
      });
      
      // Store for cleanup
      this.mediaStream = stream;
      
    } catch (error) {
      console.error("Permission denied:", error);
      this.pushEvent("permissions_denied", {});
    }
  },

  monitorMicrophone(stream) {
    try {
      if (!window.AudioContext && !window.webkitAudioContext) {
        console.log("AudioContext not supported");
        return;
      }
      
      const audioContext = new (window.AudioContext || window.webkitAudioContext)();
      const analyser = audioContext.createAnalyser();
      const microphone = audioContext.createMediaStreamSource(stream);
      const dataArray = new Uint8Array(analyser.frequencyBinCount);

      microphone.connect(analyser);
      analyser.fftSize = 256;

      const updateLevel = () => {
        analyser.getByteFrequencyData(dataArray);
        
        // Calculate average
        let sum = 0;
        for (let i = 0; i < dataArray.length; i++) {
          sum += dataArray[i];
        }
        const average = sum / dataArray.length;
        const level = Math.round((average / 255) * 100);
        
        // Send update
        this.pushEvent("microphone_level_update", { level: level });
        
        if (this.mediaStream && this.mediaStream.active) {
          requestAnimationFrame(updateLevel);
        }
      };

      updateLevel();
      
    } catch (error) {
      console.error("Error monitoring microphone:", error);
    }
  },

  testSpeakers() {
    console.log("Testing speakers...");
    
    try {
      // Create AudioContext
      const audioContext = new (window.AudioContext || window.webkitAudioContext)();
      
      // Resume context if suspended
      if (audioContext.state === 'suspended') {
        audioContext.resume();
      }
      
      // Create oscillator
      const oscillator = audioContext.createOscillator();
      const gainNode = audioContext.createGain();
      
      oscillator.connect(gainNode);
      gainNode.connect(audioContext.destination);
      
      // Configure
      oscillator.frequency.value = 440; // A4 note
      gainNode.gain.value = 0.1; // Quiet
      
      // Play for 1 second
      oscillator.start();
      
      setTimeout(() => {
        oscillator.stop();
        this.pushEvent("speakers_test_complete", { success: true });
      }, 1000);
      
    } catch (error) {
      console.error("Speaker test failed:", error);
      this.pushEvent("speakers_test_complete", { success: false });
    }
  },

  testNetwork() {
    console.log("Testing network...");
    
    const startTime = performance.now();
    
    // Use a small image test
    fetch('/favicon.ico?' + Date.now())
      .then(response => {
        if (!response.ok) throw new Error('Network error');
        return response.blob();
      })
      .then(() => {
        const endTime = performance.now();
        const duration = endTime - startTime;
        
        // Determine quality
        let quality;
        if (duration < 200) {
          quality = "good";
        } else if (duration < 1000) {
          quality = "fair";
        } else {
          quality = "poor";
        }
        
        console.log(`Network test: ${duration}ms = ${quality}`);
        this.pushEvent("network_test_complete", { quality: quality });
      })
      .catch(error => {
        console.error("Network test failed:", error);
        this.pushEvent("network_test_complete", { quality: "poor" });
      });
  },

    Hooks.SkillsInput = {
    mounted() {
      this.el.addEventListener("keydown", (e) => {
        if (e.key === "Enter") {
          e.preventDefault()
          const value = e.target.value.trim()
          if (value) {
            // Clear the input after adding
            setTimeout(() => {
              e.target.value = ""
            }, 100)
          }
        }
      })
    }
  }


  destroyed() {
    // Clean up
    if (this.mediaStream) {
      this.mediaStream.getTracks().forEach(track => track.stop());
    }
  }
};

const Hooks = {
  ColorPicker: {
    mounted() {
      console.log("ColorPicker hook mounted"); // Debug log
      const element = this.el;
      
      element.addEventListener("input", (ev) => {
        const color = ev.target.value;
        console.log("Color picker input:", color); // Debug log
        
        // Update CSS custom property immediately for preview
        document.documentElement.style.setProperty('--theme-color', color);
        
        // Update the text input
        const textInput = document.querySelector('input[type="text"][phx-value-field="theme_color"]');
        if (textInput) {
          textInput.value = color;
        }
      });
      
      element.addEventListener("change", (ev) => {
        const color = ev.target.value;
        console.log("Color picker change:", color); // Debug log
        
        // Push the final color value to LiveView
        this.pushEvent("update_color", {
          color: color,
          name: "Custom"
        });
      });
    }
  }
};

// Combine all hooks - NO DUPLICATES
let Hooks = {
  // Chat hooks
  ...ChatHooks,
  ChatScroll,
  
  // Media upload hooks
  ...MediaUploadHooks,
  
  // Session hooks
  ...SessionHooks,
  
  // Other hooks
  FileUploader: createFileUploaderHook(),
  MessagesContainer: MessagesContainerHook,
  SimpleFileTest: SimpleFileTest,
  TypingIndicator: TypingIndicatorHook,
  AutoResizeTextarea: AutoResizeTextareaHook,
  MessageTextarea: MessageTextareaHook,
  ShowHidePrice: ShowHidePriceHook,
  SoundCheck: SoundCheck,
  ShowHideMaxAttendees: ShowHideMaxAttendeesHook,
  TimeSeriesChart: TimeSeriesChartHook,
  StackedBarChart: StackedBarChartHook,
  PieChart: PieChartHook,
  ImageProcessor: ImageProcessorHook,
  StreamQuality: StreamQualityHook,
  VideoCapture: VideoCapture
};

window.addEventListener('phx:download_pdf', (event) => {
  const { data, filename } = event.detail;
  const blob = new Blob([Uint8Array.from(atob(data), c => c.charCodeAt(0))], {
    type: 'application/pdf'
  });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  link.click();
  URL.revokeObjectURL(url);
});

window.addEventListener('phx:show_export_loading', () => {
  // Show loading indicator
  showToast('Generating PDF...', 'info');
});

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
window.Hooks = Hooks