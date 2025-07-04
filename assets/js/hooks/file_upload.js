const FileUpload = {
  mounted() {
    this.componentId = this.el.dataset.componentId;
    
    // Set up drag and drop
    this.el.addEventListener('dragover', this.handleDragOver.bind(this));
    this.el.addEventListener('dragleave', this.handleDragLeave.bind(this));
    this.el.addEventListener('drop', this.handleDrop.bind(this));
    this.el.addEventListener('click', this.handleClick.bind(this));
    
    // Create hidden file input
    this.fileInput = document.createElement('input');
    this.fileInput.type = 'file';
    this.fileInput.accept = 'video/*';
    this.fileInput.style.display = 'none';
    this.fileInput.addEventListener('change', this.handleFileSelect.bind(this));
    this.el.appendChild(this.fileInput);
  },

  handleDragOver(e) {
    e.preventDefault();
    this.el.classList.add('border-blue-400', 'bg-blue-50');
  },

  handleDragLeave(e) {
    e.preventDefault();
    this.el.classList.remove('border-blue-400', 'bg-blue-50');
  },

  handleDrop(e) {
    e.preventDefault();
    this.el.classList.remove('border-blue-400', 'bg-blue-50');
    
    const files = e.dataTransfer.files;
    if (files.length > 0) {
      this.processFile(files[0]);
    }
  },

  handleClick(e) {
    // Only trigger file input if clicking the drop zone directly
    if (e.target === this.el || e.target.closest('button')) {
      this.fileInput.click();
    }
  },

  handleFileSelect(e) {
    const files = e.target.files;
    if (files.length > 0) {
      this.processFile(files[0]);
    }
  },

  async processFile(file) {
    console.log("Processing file:", file.name, file.type, file.size);
    
    // Validate file type
    if (!file.type.startsWith('video/')) {
      alert('Please select a video file.');
      return;
    }

    // Validate file size (50MB limit)
    if (file.size > 50 * 1024 * 1024) {
      alert('File size must be under 50MB.');
      return;
    }

    try {
      // Convert file to base64
      const reader = new FileReader();
      reader.onload = () => {
        const base64Data = reader.result.split(',')[1];
        
        // Send to LiveView
        this.pushEvent("file_upload", {
          file_data: base64Data,
          file_name: file.name,
          file_type: file.type,
          file_size: file.size
        });
      };
      
      reader.readAsDataURL(file);

    } catch (error) {
      console.error("File processing failed:", error);
      alert('Failed to process file. Please try again.');
    }
  }
};

export default FileUpload;
