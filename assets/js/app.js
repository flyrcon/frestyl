// assets/js/app.js - FIXED VERSION with clean PdfDownload hook

import "phoenix_html"
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import topbar from "../vendor/topbar"
import PortfolioHooks from "./portfolio_hooks" // Import our new hooks


// Import Video Capture Hook
import VideoCapture from "./hooks/video_capture"

// Import Sortable for drag-and-drop
import Sortable from 'sortablejs'

// Make Sortable globally available
window.Sortable = Sortable;

window.Chart = window.Chart || {};
if (typeof window.Chart._adapters === 'undefined') {
  window.Chart._adapters = {};
};

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

// FIXED: Portfolio-specific hooks with single PdfDownload definition
let Hooks = {
  // FIXED: Video Capture Hook
  VideoCapture,

  // Auto Focus Hook - for modal inputs
  AutoFocus: {
    mounted() {
      setTimeout(() => {
        this.el.focus();
        this.el.select(); // Also select text if it's an input
      }, 100);
    }
  },

  Hooks.SortableSections = PortfolioHooks.SortableSections
  Hooks.TemplatePreview = PortfolioHooks.TemplatePreview  
  Hooks.SectionManager = PortfolioHooks.SectionManager
  Hooks.ColorPicker = PortfolioHooks.ColorPicker
  Hooks.PreviewFrame = PortfolioHooks.PreviewFrame

  // SINGLE PDF DOWNLOAD HOOK - FIXED
  PdfDownload: {
    mounted() {
      console.log('🎯 PdfDownload hook mounted successfully on element:', this.el.id)
      
      this.handleEvent("download_pdf", (data) => {
        console.log('🎯 Received download_pdf event with data:', data)
        console.log('🎯 Filename:', data.filename)
        console.log('🎯 Size:', data.size)
        
        if (!data.data) {
          console.error('❌ No PDF data received!')
          this.showToast('No PDF data received. Please try again.', 'error')
          return
        }
        
        try {
          this.showPdfPreviewModal(data)
        } catch (error) {
          console.error('❌ Error showing PDF preview:', error)
          this.showToast(`Error showing PDF preview: ${error.message}`, 'error')
        }
      })
    },

    showPdfPreviewModal(data) {
      try {
        const byteCharacters = atob(data.data)
        const byteNumbers = new Array(byteCharacters.length)
        
        for (let i = 0; i < byteCharacters.length; i++) {
          byteNumbers[i] = byteCharacters.charCodeAt(i)
        }
        
        const byteArray = new Uint8Array(byteNumbers)
        const blob = new Blob([byteArray], { type: 'application/pdf' })
        const pdfUrl = window.URL.createObjectURL(blob)
        
        this.createStyledModal(pdfUrl, data.filename, data, () => {
          window.URL.revokeObjectURL(pdfUrl)
        })
        
      } catch (error) {
        console.error('❌ Error in showPdfPreviewModal:', error)
        this.showToast(`Failed to preview PDF: ${error.message}`, 'error')
      }
    },

    createStyledModal(pdfUrl, filename, originalData, onClose) {
      console.log('🎯 Creating fixed PDF modal...')
      
      const existingModal = document.getElementById('pdf-preview-modal')
      if (existingModal) {
        existingModal.remove()
      }

      const modal = document.createElement('div')
      modal.id = 'pdf-preview-modal'
      modal.className = 'fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50'
      modal.style.backdropFilter = 'blur(4px)'
      
      modal.innerHTML = `
        <div class="bg-white rounded-2xl shadow-2xl w-11/12 max-w-4xl h-5/6 max-h-[90vh] flex flex-col overflow-hidden">
          <!-- Modal Header with gradient - FIXED BUTTON COLORS -->
          <div class="bg-gradient-to-r from-blue-600 to-purple-600 px-6 py-4 rounded-t-2xl">
            <div class="flex items-center justify-between">
              <div class="flex items-center space-x-3">
                <div class="w-10 h-10 bg-white bg-opacity-20 rounded-lg flex items-center justify-center backdrop-blur">
                  <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                  </svg>
                </div>
                <div>
                  <h3 class="text-xl font-bold text-white">Portfolio PDF Preview</h3>
                  <p class="text-blue-100 text-sm">Review your portfolio before printing or saving</p>
                </div>
              </div>
              
              <!-- FIXED: Action buttons with proper visibility -->
              <div class="flex items-center space-x-2">
                <button id="pdf-print-btn" class="bg-blue-700 hover:bg-blue-800 text-white px-3 py-2 rounded-lg text-sm font-medium transition-all duration-200 flex items-center space-x-2 border border-blue-500">
                  <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z"/>
                  </svg>
                  <span class="text-white">Print</span>
                </button>
                
                <button id="pdf-download-btn" class="bg-green-600 hover:bg-green-700 text-white px-3 py-2 rounded-lg text-sm font-medium transition-all duration-200 flex items-center space-x-2 border border-green-500">
                  <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                  </svg>
                  <span class="text-white">Save</span>
                </button>
                
                <button id="pdf-close-btn" class="bg-gray-600 hover:bg-gray-700 text-white p-2 rounded-lg transition-colors border border-gray-500">
                  <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                  </svg>
                </button>
              </div>
            </div>
          </div>

          <!-- File info bar -->
          <div class="bg-gray-50 px-6 py-2 border-b border-gray-200">
            <div class="flex items-center justify-between text-xs">
              <div class="flex items-center space-x-3 text-gray-600">
                <span class="font-medium text-gray-900">${filename}</span>
                <span>•</span>
                <span>${this.formatFileSize(originalData.size)}</span>
                <span>•</span>
                <span class="text-green-600 font-medium">ATS-optimized</span>
              </div>
              <div class="text-gray-500">
                <span class="text-xs">ESC to close</span>
              </div>
            </div>
          </div>
          
          <!-- PDF Viewer Container -->
          <div class="flex-1 p-4 bg-gray-100 min-h-0 overflow-hidden">
            <div class="h-full bg-white rounded-lg shadow-inner overflow-hidden border border-gray-300">
              <iframe 
                src="${pdfUrl}#toolbar=1&navpanes=0&scrollbar=1&view=FitH" 
                class="w-full h-full border-0"
                type="application/pdf"
                title="Portfolio PDF Preview">
                <div class="flex flex-col items-center justify-center h-full p-6 text-center bg-gray-50">
                  <div class="w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center mb-4">
                    <svg class="w-8 h-8 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                    </svg>
                  </div>
                  <h4 class="text-lg font-semibold text-gray-900 mb-2">PDF Preview Not Available</h4>
                  <p class="text-gray-600 mb-6 max-w-sm">Your browser doesn't support inline PDF viewing. Use the download button to save the file.</p>
                  <button id="pdf-fallback-download" class="bg-blue-600 text-white px-6 py-3 rounded-lg font-medium hover:bg-blue-700 transition-colors flex items-center space-x-2">
                    <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                    </svg>
                    <span class="text-white">Download PDF</span>
                  </button>
                </div>
              </iframe>
            </div>
          </div>

          <!-- Footer -->
          <div class="bg-white px-6 py-3 border-t border-gray-200 rounded-b-2xl">
            <div class="flex items-center justify-between text-xs text-gray-600">
              <div class="flex items-center space-x-4">
                <span class="flex items-center space-x-1">
                  <svg class="w-3 h-3 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
                  </svg>
                  <span>ATS-compatible</span>
                </span>
                <span class="flex items-center space-x-1">
                  <svg class="w-3 h-3 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
                  </svg>
                  <span>Print-ready</span>
                </span>
              </div>
              <div class="text-gray-500">
                Click outside modal to close
              </div>
            </div>
          </div>
        </div>
      `

      document.body.appendChild(modal)
      
      modal.style.opacity = '0'
      modal.style.transform = 'scale(0.96)'
      modal.style.transition = 'all 0.25s ease-out'
      
      requestAnimationFrame(() => {
        modal.style.opacity = '1'
        modal.style.transform = 'scale(1)'
      })

      this.setupModalEventListeners(modal, pdfUrl, filename, originalData, onClose)
    },

    setupModalEventListeners(modal, pdfUrl, filename, originalData, onClose) {
      const printBtn = modal.querySelector('#pdf-print-btn')
      const downloadBtn = modal.querySelector('#pdf-download-btn')
      const closeBtn = modal.querySelector('#pdf-close-btn')
      const fallbackBtn = modal.querySelector('#pdf-fallback-download')
      const iframe = modal.querySelector('iframe')

      if (printBtn) {
        printBtn.addEventListener('click', () => {
          this.handlePrint(iframe, pdfUrl)
        })
      }

      if (downloadBtn) {
        downloadBtn.addEventListener('click', () => {
          this.handleDownload(originalData)
        })
      }

      if (fallbackBtn) {
        fallbackBtn.addEventListener('click', () => {
          this.handleDownload(originalData)
        })
      }

      const closeModal = () => {
        modal.style.opacity = '0'
        modal.style.transform = 'scale(0.95)'
        setTimeout(() => {
          modal.remove()
          onClose()
        }, 200)
      }

      if (closeBtn) {
        closeBtn.addEventListener('click', closeModal)
      }
      
      modal.addEventListener('click', (e) => {
        if (e.target === modal) {
          closeModal()
        }
      })

      const handleEscape = (e) => {
        if (e.key === 'Escape') {
          closeModal()
          document.removeEventListener('keydown', handleEscape)
        }
      }
      document.addEventListener('keydown', handleEscape)
    },

    handlePrint(iframe, pdfUrl) {
      try {
        if (iframe && iframe.contentWindow) {
          iframe.contentWindow.print()
        } else {
          throw new Error('Cannot access iframe content')
        }
      } catch (error) {
        const printWindow = window.open(pdfUrl, '_blank', 'width=800,height=600,toolbar=yes,scrollbars=yes,resizable=yes')
        if (printWindow) {
          printWindow.addEventListener('load', () => {
            setTimeout(() => printWindow.print(), 500)
          })
        } else {
          this.showToast('Please allow popups to print, or use Save to download the PDF.', 'error')
        }
      }
    },

    async handleDownload(data) {
      try {
        if ('showSaveFilePicker' in window) {
          await this.modernDownload(data)
        } else {
          this.traditionalDownload(data)
        }
      } catch (error) {
        if (error.name === 'AbortError') {
          this.showToast('Save cancelled', 'info')
        } else {
          this.showToast('Download failed. Please try again.', 'error')
        }
      }
    },

    async modernDownload(data) {
      const fileHandle = await window.showSaveFilePicker({
        suggestedName: data.filename,
        types: [{
          description: 'PDF files',
          accept: { 'application/pdf': ['.pdf'] }
        }]
      })

      const binaryString = atob(data.data)
      const bytes = new Uint8Array(binaryString.length)
      
      for (let i = 0; i < binaryString.length; i++) {
        bytes[i] = binaryString.charCodeAt(i)
      }

      const writable = await fileHandle.createWritable()
      await writable.write(bytes)
      await writable.close()

      this.showToast('PDF saved successfully!', 'success')
    },

    traditionalDownload(data) {
      const binaryString = atob(data.data)
      const bytes = new Uint8Array(binaryString.length)
      
      for (let i = 0; i < binaryString.length; i++) {
        bytes[i] = binaryString.charCodeAt(i)
      }

      const blob = new Blob([bytes], { type: data.content_type })
      const url = window.URL.createObjectURL(blob)
      
      const link = document.createElement('a')
      link.href = url
      link.download = data.filename
      link.style.display = 'none'
      
      document.body.appendChild(link)
      link.click()
      document.body.removeChild(link)
      
      window.URL.revokeObjectURL(url)
      
      this.showToast(`"${data.filename}" downloaded successfully!`, 'success')
    },

    formatFileSize(bytes) {
      if (!bytes) return 'Unknown size'
      
      const sizes = ['Bytes', 'KB', 'MB', 'GB']
      if (bytes === 0) return '0 Bytes'
      
      const i = Math.floor(Math.log(bytes) / Math.log(1024))
      return Math.round(bytes / Math.pow(1024, i) * 100) / 100 + ' ' + sizes[i]
    },

    showToast(message, type = 'info') {
      const toast = document.createElement('div')
      toast.className = `fixed top-4 right-4 z-50 px-6 py-4 rounded-lg shadow-lg text-white max-w-sm transition-all duration-300 transform translate-x-full`
      
      const colors = {
        success: 'bg-green-500',
        error: 'bg-red-500',
        info: 'bg-blue-500'
      }
      toast.classList.add(colors[type] || colors.info)
      
      const icons = {
        success: '✅',
        error: '❌',
        info: 'ℹ️'
      }
      
      toast.innerHTML = `
        <div class="flex items-center space-x-3">
          <div class="flex-shrink-0 text-lg">
            ${icons[type] || icons.info}
          </div>
          <div class="flex-1">
            <p class="text-sm font-medium">${message}</p>
          </div>
          <button class="flex-shrink-0 text-white hover:text-gray-200 ml-2" onclick="this.parentElement.parentElement.remove()">
            ✕
          </button>
        </div>
      `
      
      document.body.appendChild(toast)
      
      setTimeout(() => {
        toast.classList.remove('translate-x-full')
      }, 100)
      
      setTimeout(() => {
        if (toast.parentElement) {
          toast.classList.add('translate-x-full')
          setTimeout(() => toast.remove(), 300)
        }
      }, 5000)
    }
  },

  // Enhanced drag and drop for sections
  Hooks.SortableSections = {
    mounted() {
      const el = this.el;
      const sortable = new Sortable(el, {
        animation: 150,
        ghostClass: 'opacity-50',
        dragClass: 'shadow-2xl',
        handle: '.section-drag-handle',
        onEnd: (evt) => {
          if (evt.oldIndex !== evt.newIndex) {
            this.pushEvent("reorder_sections", {
              old: evt.oldIndex.toString(),
              new: evt.newIndex.toString()
            });
          }
        }
      });
      
      this.sortable = sortable;
    },
    
    destroyed() {
      if (this.sortable) {
        this.sortable.destroy();
      }
    }
  },

  // Enhanced drag and drop for media
  Hooks.SortableMedia = {
    mounted() {
      const el = this.el;
      const sectionId = el.dataset.sectionId;
      
      const sortable = new Sortable(el, {
        animation: 150,
        ghostClass: 'media-ghost',
        dragClass: 'media-drag',
        chosenClass: 'media-chosen',
        onEnd: (evt) => {
          if (evt.oldIndex !== evt.newIndex) {
            const mediaIds = Array.from(el.children).map(child => 
              child.dataset.mediaId
            );
            
            this.pushEvent("reorder_media", {
              section_id: sectionId,
              media_ids: mediaIds
            });
          }
        }
      });
      
      this.sortable = sortable;
    },
    
    destroyed() {
      if (this.sortable) {
        this.sortable.destroy();
      }
    }
  },

  // Add TemplateUpload to your existing hooks
  TemplateUpload: {
    mounted() {
      console.log('🎨 TemplateUpload hook mounted');
      
      this.dropZone = this.el;
      this.fileInput = this.el.querySelector('#template-file-input');
      this.filePreview = this.el.querySelector('#file-preview');
      this.fileName = this.el.querySelector('#file-name');
      this.removeBtn = this.el.querySelector('#remove-file');
      this.templateDataInput = document.querySelector('#template-data-input');
      this.importButton = document.querySelector('#import-button');
      
      this.setupEventListeners();
    },

    setupEventListeners() {
      // File input change
      if (this.fileInput) {
        this.fileInput.addEventListener('change', (e) => {
          if (e.target.files[0]) {
            this.handleFileSelect(e.target.files[0]);
          }
        });
      }

      // Remove file button
      if (this.removeBtn) {
        this.removeBtn.addEventListener('click', () => {
          this.clearFile();
        });
      }

      // Drag and drop events
      this.dropZone.addEventListener('dragover', (e) => {
        e.preventDefault();
        e.stopPropagation();
        this.dropZone.classList.add('border-indigo-400', 'bg-indigo-50');
      });

      this.dropZone.addEventListener('dragleave', (e) => {
        e.preventDefault();
        e.stopPropagation();
        this.dropZone.classList.remove('border-indigo-400', 'bg-indigo-50');
      });

      this.dropZone.addEventListener('drop', (e) => {
        e.preventDefault();
        e.stopPropagation();
        this.dropZone.classList.remove('border-indigo-400', 'bg-indigo-50');
        
        const files = e.dataTransfer.files;
        if (files.length > 0) {
          this.handleFileSelect(files[0]);
        }
      });
    },

    handleFileSelect(file) {
      console.log('📁 File selected:', file.name);
      
      // Validate file type
      if (!file.name.toLowerCase().endsWith('.json')) {
        this.showError('Please select a JSON file');
        return;
      }

      // Validate file size (max 1MB)
      if (file.size > 1024 * 1024) {
        this.showError('File too large. Maximum size is 1MB');
        return;
      }

      // Read file content
      const reader = new FileReader();
      
      reader.onload = (e) => {
        try {
          const content = e.target.result;
          
          // Validate JSON
          const templateData = JSON.parse(content);
          
          // Basic validation
          if (!templateData.template_name && !templateData.customization) {
            throw new Error('Invalid template format - missing required fields');
          }

          // Show file preview
          this.showFilePreview(file.name);
          
          // Set template data
          if (this.templateDataInput) {
            this.templateDataInput.value = content;
          }
          
          // Enable import button
          if (this.importButton) {
            this.importButton.disabled = false;
          }
          
          console.log('✅ Template file loaded successfully');
          
        } catch (error) {
          console.error('❌ Template file error:', error);
          this.showError('Invalid template file: ' + error.message);
        }
      };

      reader.onerror = () => {
        this.showError('Failed to read file');
      };

      reader.readAsText(file);
    },

    showFilePreview(filename) {
      if (this.fileName) {
        this.fileName.textContent = filename;
      }
      if (this.filePreview) {
        this.filePreview.classList.remove('hidden');
      }
    },

    clearFile() {
      // Clear file input
      if (this.fileInput) {
        this.fileInput.value = '';
      }
      
      // Hide preview
      if (this.filePreview) {
        this.filePreview.classList.add('hidden');
      }
      
      // Clear template data
      if (this.templateDataInput) {
        this.templateDataInput.value = '';
      }
      
      // Disable import button
      if (this.importButton) {
        this.importButton.disabled = true;
      }
      
      console.log('🗑️ File cleared');
    },

    showError(message) {
      // Remove existing error
      const existingError = this.el.querySelector('.upload-error');
      if (existingError) {
        existingError.remove();
      }
      
      // Create new error message
      const errorDiv = document.createElement('div');
      errorDiv.className = 'upload-error mt-2 p-2 bg-red-50 border border-red-200 rounded text-sm text-red-600';
      errorDiv.textContent = message;
      this.dropZone.appendChild(errorDiv);
      
      // Auto-hide after 5 seconds
      setTimeout(() => {
        if (errorDiv && errorDiv.parentNode) {
          errorDiv.remove();
        }
      }, 5000);
    },

    destroyed() {
      console.log('🎨 TemplateUpload hook destroyed');
    }
  },

  // Also add this hook for template export downloads
  TemplateExport: {
    mounted() {
      this.handleEvent("download_template", (data) => {
        console.log('📥 Downloading template:', data.filename);
        
        try {
          const blob = new Blob([data.data], { type: data.mime_type || 'application/json' });
          const url = window.URL.createObjectURL(blob);
          
          const link = document.createElement('a');
          link.href = url;
          link.download = data.filename;
          link.style.display = 'none';
          
          document.body.appendChild(link);
          link.click();
          document.body.removeChild(link);
          
          window.URL.revokeObjectURL(url);
          
          console.log('✅ Template downloaded successfully');
          
        } catch (error) {
          console.error('❌ Download failed:', error);
        }
      });
    }
  },

  // FIXED: Copy to Clipboard Hook
  CopyToClipboard: {
    mounted() {
      this.handleEvent('copy_to_clipboard', (payload) => {
        if (navigator.clipboard && navigator.clipboard.writeText) {
          navigator.clipboard.writeText(payload.text).then(() => {
            console.log('✅ Text copied to clipboard:', payload.text);
            
            // Show success feedback
            this.pushEvent('clipboard_success', {});
            
          }).catch(err => {
            console.error('❌ Failed to copy text:', err);
            this.fallbackCopyTextToClipboard(payload.text);
          });
        } else {
          // Fallback for older browsers
          this.fallbackCopyTextToClipboard(payload.text);
        }
      });
    },

    fallbackCopyTextToClipboard(text) {
      const textArea = document.createElement("textarea");
      textArea.value = text;
      
      // Avoid scrolling to bottom
      textArea.style.top = "0";
      textArea.style.left = "0";
      textArea.style.position = "fixed";

      document.body.appendChild(textArea);
      textArea.focus();
      textArea.select();

      try {
        const successful = document.execCommand('copy');
        if (successful) {
          console.log('✅ Fallback: Text copied to clipboard');
          this.pushEvent('clipboard_success', {});
        } else {
          console.error('❌ Fallback: Failed to copy text');
        }
      } catch (err) {
        console.error('❌ Fallback: Copy command failed:', err);
      }

      document.body.removeChild(textArea);
    }
  },

  // Rest of your hooks remain the same...
  SectionSortable: {
    mounted() {
      console.log('SectionSortable hook mounted', this.el);
      this.initializeSortable();
    },

    updated() {
      console.log('SectionSortable hook updated');
      this.destroySortable();
      this.initializeSortable();
    },

    destroyed() {
      console.log('SectionSortable hook destroyed');
      this.destroySortable();
    },

    initializeSortable() {
      if (typeof Sortable === 'undefined') {
        console.error('Sortable library not found. Please install SortableJS.');
        return;
      }

      this.destroySortable();

      this.sortable = new Sortable(this.el, {
        animation: 200,
        ghostClass: 'sortable-ghost',
        chosenClass: 'sortable-chosen',
        dragClass: 'sortable-drag',
        handle: '.drag-handle',
        forceFallback: true,
        
        onStart: (evt) => {
          console.log('Drag started');
          evt.item.classList.add('dragging');
          document.body.classList.add('sections-reordering');
        },

        onEnd: (evt) => {
          console.log('Drag ended');
          evt.item.classList.remove('dragging');
          document.body.classList.remove('sections-reordering');
          
          const sectionIds = Array.from(this.el.children)
            .map(child => child.getAttribute('data-section-id'))
            .filter(Boolean);

          console.log('New section order:', sectionIds);
          this.pushEvent('reorder_sections', { sections: sectionIds });
        }
      });

      console.log('SectionSortable initialized successfully');
    },

    destroySortable() {
      if (this.sortable) {
        this.sortable.destroy();
        this.sortable = null;
      }
    }
  },

  // Media Sortable Hook - for drag-and-drop media reordering
  MediaSortable: {
    mounted() {
      console.log('MediaSortable hook mounted', this.el);
      this.initializeSortable();
    },

    updated() {
      this.destroySortable();
      this.initializeSortable();
    },

    destroyed() {
      this.destroySortable();
    },

    initializeSortable() {
      if (typeof Sortable === 'undefined') return;

      this.destroySortable();

      this.sortable = new Sortable(this.el, {
        animation: 150,
        ghostClass: 'sortable-ghost',
        chosenClass: 'sortable-chosen',
        dragClass: 'sortable-drag',
        
        onEnd: (evt) => {
          const sectionId = this.el.getAttribute('data-section-id');
          const mediaIds = Array.from(this.el.children)
            .map(child => child.getAttribute('data-media-id'))
            .filter(Boolean);

          console.log('Media reordered:', mediaIds);
          this.pushEvent('reorder_media', { 
            section_id: sectionId, 
            media_order: mediaIds 
          });
        }
      });
    },

    destroySortable() {
      if (this.sortable) {
        this.sortable.destroy();
        this.sortable = null;
      }
    }
  }

  // Add other hooks here if needed...
};

// Global hooks reference
window.Hooks = Hooks;

// LiveSocket configuration
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: Hooks,
  
  // Enhanced DOM configuration
  dom: {
    onBeforeElUpdated(from, to) {
      // Preserve focus state
      if (from === document.activeElement) {
        to.focus();
      }
      
      // Preserve video states
      if (from.tagName === 'VIDEO' && to.tagName === 'VIDEO') {
        to.currentTime = from.currentTime;
        to.muted = from.muted;
        to.volume = from.volume;
        
        if (!from.paused && from.srcObject) {
          to.srcObject = from.srcObject;
        }
      }
      
      return true;
    }
  }
});

// Enhanced progress bar
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"});


window.addEventListener("phx:page-loading-start", _info => topbar.show(300));
window.addEventListener("phx:page-loading-stop", _info => topbar.hide());

// Connect LiveSocket
liveSocket.connect();

// Expose for debugging
window.liveSocket = liveSocket;

console.log('✅ Frestyl Portfolio app.js loaded with FIXED PdfDownload hook');

document.addEventListener('DOMContentLoaded', function() {
  console.log("🚀 Portfolio app initialized");
  
  // Global click handlers for better responsiveness
  document.addEventListener('click', function(e) {
    // Add visual feedback to buttons
    if (e.target.matches('button, .btn, [phx-click]')) {
      e.target.style.transform = 'scale(0.95)';
      setTimeout(() => {
        e.target.style.transform = 'scale(1)';
      }, 100);
    }
  });
  
  // Auto-save indicators
  let saveTimeout;
  document.addEventListener('input', function(e) {
    if (e.target.matches('[phx-change], [phx-blur]')) {
      // Show saving indicator
      clearTimeout(saveTimeout);
      showSavingIndicator();
      
      saveTimeout = setTimeout(() => {
        hideSavingIndicator();
      }, 1000);
    }
  });
});

function showSavingIndicator() {
  let indicator = document.getElementById('saving-indicator');
  if (!indicator) {
    indicator = document.createElement('div');
    indicator.id = 'saving-indicator';
    indicator.className = 'fixed top-4 left-1/2 transform -translate-x-1/2 bg-blue-500 text-white px-4 py-2 rounded-lg shadow-lg z-50 transition-all';
    indicator.innerHTML = '💾 Saving...';
    document.body.appendChild(indicator);
  }
  indicator.style.opacity = '1';
  indicator.style.transform = 'translate(-50%, 0)';
}

function hideSavingIndicator() {
  const indicator = document.getElementById('saving-indicator');
  if (indicator) {
    indicator.style.opacity = '0';
    indicator.style.transform = 'translate(-50%, -20px)';
    setTimeout(() => {
      if (indicator.parentNode) {
        indicator.parentNode.removeChild(indicator);
      }
    }, 300);
  }
}