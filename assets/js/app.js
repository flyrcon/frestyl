// assets/js/app.js

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

// Assuming MediaUploadHooks exports an object of hooks { HookName1: {}, ... }
// We will modify hooks/upload_hooks.js to remove the conflicting DragDrop hook.
import MediaUploadHooks from "./hooks/upload_hooks"

// Assuming setupImageProcessing is a function defined in image_processor.js
// Ensure this function is correctly defined and exported from its file.
import { setupImageProcessing } from "./image_processor";

// Import our analytics module
import "./analytics"
// require("phoenix_html") // Already imported above, can remove this duplicate

// Import Chart.js for visualization components
import Chart from 'chart.js/auto'
import 'chartjs-adapter-date-fns' // For time-series charts

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

// Debug helper for hooks - keep this handy!
const debugHook = (name, method, details = {}) => {
  console.log(`Hook: ${name}.${method}`, details);
};

// --- Define Individual Hook Factory Functions or Objects ---

// Define the function that creates the FileUploader hook instance.
// This hook is responsible *solely* for the drag-and-drop and file selection logic
// for the element with phx-hook="FileUploader".
// Modify your createFileUploaderHook function in app.js
const createFileUploaderHook = () => ({
  mounted() {
    console.log("FileUploader hook mounted");
    const fileInput = this.el.querySelector('input[type="file"]');
    const dropZone = this.el.querySelector('.border-dashed');
    
    if (!fileInput) {
      console.error("FileUploader: No file input found");
      return;
    }
    
    if (!dropZone) {
      console.error("FileUploader: No dropzone found");
      return;
    }
    
    console.log("FileUploader: Found elements", { fileInput, dropZone });
    
    // Make drop zone clickable
    dropZone.addEventListener('click', (e) => {
      if (e.target !== fileInput && e.target.tagName !== 'BUTTON') {
        console.log("FileUploader: Dropzone clicked");
        fileInput.click();
      }
    });
    
    // Setup drag and drop
    dropZone.addEventListener('dragover', (e) => {
      e.preventDefault();
      dropZone.classList.add('border-blue-500');
      dropZone.classList.remove('border-gray-300');
    });
    
    dropZone.addEventListener('dragleave', (e) => {
      e.preventDefault();
      dropZone.classList.remove('border-blue-500');
      dropZone.classList.add('border-gray-300');
    });
    
    dropZone.addEventListener('drop', (e) => {
      e.preventDefault();
      console.log("FileUploader: Files dropped", e.dataTransfer.files);
      
      dropZone.classList.remove('border-blue-500');
      dropZone.classList.add('border-gray-300');
      
      if (e.dataTransfer.files.length > 0) {
        // Directly assign files to the input
        fileInput.files = e.dataTransfer.files;
        
        // Trigger change event
        fileInput.dispatchEvent(new Event('change', { bubbles: true }));
        console.log("FileUploader: Files assigned to input", fileInput.files);
      }
    });
  }
});

// --- Define Other Individual Hooks (Not related to core file assignment) ---

// These hooks appear independent of the core drag/drop file assignment.
// Keep their definitions as they are, but ensure they are correctly added to the main Hooks object.

const MessagesContainerHook = { /* ... (your original MessagesContainer code) ... */
  mounted() {
    debugHook('MessagesContainer', 'mounted');
    this.scrollToBottom();
    this.handleEvent("chat-message-sent", () => { this.scrollToBottom(); });
  },
  updated() { this.scrollToBottom(); },
  destroyed() { debugHook('MessagesContainer', 'destroyed'); },
  scrollToBottom() { this.el.scrollTop = this.el.scrollHeight; }
};

const TypingIndicatorHook = { /* ... (your original TypingIndicator code) ... */
  mounted() { debugHook('TypingIndicator', 'mounted'); /* ... */ },
  destroyed() { debugHook('TypingIndicator', 'destroyed'); }
};

const AutoResizeTextareaHook = { /* ... (your original AutoResizeTextarea code) ... */
  mounted() { debugHook('AutoResizeTextarea', 'mounted'); this.resize(); this.el.addEventListener("input", () => this.resize()); },
   resize() { this.el.style.height = "auto"; this.el.style.height = (this.el.scrollHeight) + "px"; },
   destroyed() { debugHook('AutoResizeTextarea', 'destroyed'); }
};

const ShowHidePriceHook = { /* ... (your original ShowHidePrice code) ... */
  mounted() { debugHook('ShowHidePrice', 'mounted'); /* ... */ },
  toggleVisibility(val) { debugHook('ShowHidePrice', 'toggleVisibility', {value: val}); /* ... */ }
};

const ShowHideMaxAttendeesHook = { /* ... (your original ShowHideMaxAttendees code) ... */
  mounted() { debugHook('ShowHideMaxAttendees', 'mounted'); /* ... */ },
  toggleVisibility(val) { debugHook('ShowHideMaxAttendees', 'toggleVisibility', {value: val}); /* ... */ }
};

const TimeSeriesChartHook = { /* ... (your original TimeSeriesChart code) ... */
  mounted() { debugHook('TimeSeriesChart', 'mounted'); /* ... */ }, updated() { debugHook('TimeSeriesChart', 'updated'); /* ... */ }, destroyed() { debugHook('TimeSeriesChart', 'destroyed'); if (this.chart) this.chart.destroy(); }
};

const StackedBarChartHook = { /* ... (your original StackedBarChart code) ... */
  mounted() { debugHook('StackedBarChart', 'mounted'); /* ... */ }, updated() { debugHook('StackedBarChart', 'updated'); /* ... */ }, destroyed() { debugHook('StackedBarChart', 'destroyed'); if (this.chart) this.chart.destroy(); }
};

const PieChartHook = { /* ... (your original PieChart code) ... */
  mounted() { debugHook('PieChart', 'mounted'); /* ... */ }, updated() { debugHook('PieChart', 'updated'); /* ... */ }, destroyed() { debugHook('PieChart', 'destroyed'); if (this.chart) this.chart.destroy(); }
};

const ImageProcessorHook = { /* ... (your original ImageProcessor code) ... */
   mounted() { debugHook('ImageProcessor', 'mounted'); if (typeof setupImageProcessing === "function") { setupImageProcessing(); } else { console.error("ImageProcessor: setupImageProcessing function not found"); } },
   destroyed() { debugHook('ImageProcessor', 'destroyed'); } // Add destroyed if needed
};


// --- Consolidate All Hooks into a Single Object ---
// Define the single object that will contain all your hooks,
// using the 'let' keyword to allow adding properties.

let Hooks = {
  // Add each defined hook object/instance as a property of the Hooks object
  MessagesContainer: MessagesContainerHook,
  TypingIndicator: TypingIndicatorHook,
  AutoResizeTextarea: AutoResizeTextareaHook,
  ShowHidePrice: ShowHidePriceHook,
  ShowHideMaxAttendees: ShowHideMaxAttendeesHook,
  TimeSeriesChart: TimeSeriesChartHook,
  StackedBarChart: StackedBarChartHook,
  PieChart: PieChartHook,
  ImageProcessor: ImageProcessorHook, // Assuming this is a hook used elsewhere

  // --- Add the primary File Upload Hook ---
  // Use the hook created by the factory function for the FileUploader name
  FileUploader: createFileUploaderHook(),

  // --- Review MediaUpload Hook ---
  // This hook definition looked like a duplicate of FileUploader's logic.
  // If phx-hook="MediaUpload" is used on a DIFFERENT element for a DIFFERENT purpose,
  // keep this definition and update its logic to be distinct.
  // If phx-hook="MediaUpload" is NOT used, or is used on the SAME element
  // as FileUploader, this definition is redundant and should be REMOVED.
  // For now, including it as a placeholder based on your original code, but comment it out
  // for testing the consolidated FileUploader logic.
  // MediaUpload: {
  //    mounted() { debugHook('MediaUpload', 'mounted - Review Usage!'); /* ... original MediaUpload logic ... */ },
  //    // ... other lifecycle methods ...
  // },


  // --- Merge External Hooks from hooks/upload_hooks.js ---
  // Use the spread syntax to include hooks from MediaUploadHooks.js.
  // Assuming MediaUploadHooks is an object { HookName1: {}, HookName2: {} }.
  // After removing the conflicting DragDrop from that file, other hooks like MediaPreview should be merged here.
  ...MediaUploadHooks // This should now include MediaPreview if it's in MediaUploadHooks
};


// --- Initialize LiveSocket ---
// Pass the single, consolidated Hooks object to LiveSocket

let liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  hooks: Hooks // Pass the combined Hooks object here
});


// --- Standard LiveView/Topbar Setup ---

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", info => topbar.show())
window.addEventListener("phx:page-loading-stop", info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket