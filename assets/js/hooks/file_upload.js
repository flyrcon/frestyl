// assets/js/hooks/file_upload.js

const FileUpload = {
  mounted() {
    this.setupDragAndDrop();
  },

  setupDragAndDrop() {
    const dropZone = this.el.closest('.border-dashed');
    
    if (!dropZone) return;

    ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
      dropZone.addEventListener(eventName, this.preventDefaults, false);
    });

    ['dragenter', 'dragover'].forEach(eventName => {
      dropZone.addEventListener(eventName, () => this.highlight(dropZone), false);
    });

    ['dragleave', 'drop'].forEach(eventName => {
      dropZone.addEventListener(eventName, () => this.unhighlight(dropZone), false);
    });

    dropZone.addEventListener('drop', (e) => this.handleDrop(e), false);
  },

  preventDefaults(e) {
    e.preventDefault();
    e.stopPropagation();
  },

  highlight(element) {
    element.classList.add('border-blue-400', 'bg-blue-50');
  },

  unhighlight(element) {
    element.classList.remove('border-blue-400', 'bg-blue-50');
  },

  handleDrop(e) {
    const files = e.dataTransfer.files;
    
    if (files.length > 0) {
      // Trigger the file input with the dropped files
      this.el.files = files;
      
      // Dispatch change event to trigger LiveView upload
      const event = new Event('change', { bubbles: true });
      this.el.dispatchEvent(event);
    }
  }
};

export default FileUpload;