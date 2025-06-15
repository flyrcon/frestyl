// Add this to your app.js or create a separate hooks file
// assets/js/pdf_download_hook.js

export const PdfDownloadHook = {
  mounted() {
    // Listen for PDF download events from LiveView
    this.handleEvent("download_pdf", (data) => {
      this.downloadPdf(data);
    });
  },

  downloadPdf(data) {
    try {
      // Convert base64 back to binary
      const binaryString = atob(data.data);
      const bytes = new Uint8Array(binaryString.length);
      
      for (let i = 0; i < binaryString.length; i++) {
        bytes[i] = binaryString.charCodeAt(i);
      }

      // Create blob from binary data
      const blob = new Blob([bytes], { type: data.content_type });
      
      // Create download URL
      const url = window.URL.createObjectURL(blob);
      
      // Create temporary download link
      const link = document.createElement('a');
      link.href = url;
      link.download = data.filename;
      link.style.display = 'none';
      
      // Add to DOM, click, and remove
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      
      // Clean up the URL
      window.URL.revokeObjectURL(url);
      
      // Show success message
      this.showToast(`PDF "${data.filename}" downloaded successfully!`, 'success');
      
    } catch (error) {
      console.error('PDF download error:', error);
      this.showToast('Failed to download PDF. Please try again.', 'error');
    }
  },

  showToast(message, type = 'info') {
    // Create toast notification
    const toast = document.createElement('div');
    toast.className = `fixed top-4 right-4 z-50 px-6 py-4 rounded-lg shadow-lg text-white max-w-sm transition-all duration-300 transform translate-x-full`;
    
    // Set color based on type
    const colors = {
      success: 'bg-green-500',
      error: 'bg-red-500',
      info: 'bg-blue-500'
    };
    toast.classList.add(colors[type] || colors.info);
    
    // Add content
    toast.innerHTML = `
      <div class="flex items-center space-x-3">
        <div class="flex-shrink-0">
          ${type === 'success' ? '✓' : type === 'error' ? '✗' : 'ℹ'}
        </div>
        <div class="flex-1">
          <p class="text-sm font-medium">${message}</p>
        </div>
        <button class="flex-shrink-0 text-white hover:text-gray-200" onclick="this.parentElement.parentElement.remove()">
          ✕
        </button>
      </div>
    `;
    
    // Add to DOM
    document.body.appendChild(toast);
    
    // Animate in
    setTimeout(() => {
      toast.classList.remove('translate-x-full');
    }, 100);
    
    // Auto remove after 5 seconds
    setTimeout(() => {
      toast.classList.add('translate-x-full');
      setTimeout(() => {
        if (toast.parentElement) {
          toast.remove();
        }
      }, 300);
    }, 5000);
  }
};

// Alternative approach using the modern File System Access API (for supported browsers)
export const ModernPdfDownloadHook = {
  mounted() {
    this.handleEvent("download_pdf", (data) => {
      this.downloadPdfModern(data);
    });
  },

  async downloadPdfModern(data) {
    try {
      // Check if File System Access API is supported
      if ('showSaveFilePicker' in window) {
        // Modern approach - shows native save dialog
        const fileHandle = await window.showSaveFilePicker({
          suggestedName: data.filename,
          types: [{
            description: 'PDF files',
            accept: {
              'application/pdf': ['.pdf']
            }
          }]
        });

        // Convert base64 to binary
        const binaryString = atob(data.data);
        const bytes = new Uint8Array(binaryString.length);
        
        for (let i = 0; i < binaryString.length; i++) {
          bytes[i] = binaryString.charCodeAt(i);
        }

        // Write to selected file
        const writable = await fileHandle.createWritable();
        await writable.write(bytes);
        await writable.close();

        this.showToast(`PDF saved successfully!`, 'success');
        
      } else {
        // Fallback to traditional download
        this.downloadPdf(data);
      }
      
    } catch (error) {
      if (error.name === 'AbortError') {
        // User cancelled the save dialog
        this.showToast('Save cancelled', 'info');
      } else {
        console.error('PDF save error:', error);
        this.showToast('Failed to save PDF. Please try again.', 'error');
      }
    }
  },

  // Include the same downloadPdf and showToast methods as above
  downloadPdf(data) {
    // Same implementation as PdfDownloadHook
  },

  showToast(message, type = 'info') {
    // Same implementation as PdfDownloadHook
  }
};

// Usage in app.js:
// import { PdfDownloadHook, ModernPdfDownloadHook } from "./pdf_download_hook"
// 
// let Hooks = {
//   PdfDownload: ModernPdfDownloadHook // Use modern version with save dialog
// }
//
// let liveSocket = new LiveSocket("/live", Socket, {
//   params: {_csrf_token: csrfToken},
//   hooks: Hooks
// })