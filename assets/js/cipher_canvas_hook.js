// assets/js/cipher_canvas_hook.js
export const CipherCanvas = {
  mounted() {
    this.canvas = this.el.querySelector('.cipher-canvas');
    this.infoPanel = this.el.querySelector('#infoPanel');
    this.audioVisualizer = this.el.querySelector('#audioVisualizer');
    this.uploadZone = this.el.querySelector('#uploadZone');
    
    this.nodes = [];
    this.connections = [];
    this.currentMode = 'galaxy';
    this.isPlaying = false;
    this.audioContext = null;
    this.currentAudio = null;
    this.analyser = null;
    this.selectedNode = null;
    
    this.camera = { x: 0, y: 0, zoom: 1 };
    this.isDragging = false;
    this.lastMouse = { x: 0, y: 0 };
    this.lastTouch = null;
    
    this.init();
    this.createParticles();
    this.loadMediaFiles();
    this.bindEvents();
    this.startAnimation();
  },

  updated() {
    this.loadMediaFiles();
  },

  init() {
    // Initialize Web Audio API
    try {
      this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
      this.analyser = this.audioContext.createAnalyser();
      this.analyser.fftSize = 128;
    } catch (e) {
      console.warn('Web Audio API not available:', e);
    }

    // Create visualizer bars
    this.audioVisualizer.innerHTML = '';
    for (let i = 0; i < 64; i++) {
      const bar = document.createElement('div');
      bar.className = 'visualizer-bar';
      bar.style.height = '10px';
      this.audioVisualizer.appendChild(bar);
    }
  },

  createParticles() {
    // Create floating particles in background
    for (let i = 0; i < 30; i++) {
      setTimeout(() => {
        const particle = document.createElement('div');
        particle.className = 'particle';
        
        const size = Math.random() * 3 + 1;
        particle.style.width = size + 'px';
        particle.style.height = size + 'px';
        particle.style.left = Math.random() * 100 + '%';
        particle.style.animationDuration = (Math.random() * 15 + 15) + 's';
        particle.style.animationDelay = Math.random() * 10 + 's';
        
        this.el.appendChild(particle);
        
        // Remove after animation
        setTimeout(() => {
          if (particle.parentNode) {
            particle.remove();
          }
        }, 30000);
      }, i * 200);
    }
    
    // Regenerate particles periodically
    setTimeout(() => this.createParticles(), 30000);
  },

  loadMediaFiles() {
    const filesDataAttr = this.el.querySelector('.cipher-canvas').dataset.files;
    console.log("Raw files data:", filesDataAttr);
    
    let filesData = [];
    try {
      filesData = filesDataAttr ? JSON.parse(filesDataAttr) : [];
      console.log("Parsed files data:", filesData);
    } catch (e) {
      console.error("Failed to parse files data:", e);
      filesData = [];
    }
    
    // Clear existing nodes
    this.nodes.forEach(node => {
      if (node.element && node.element.parentNode) {
        node.element.remove();
      }
    });
    this.nodes = [];

    console.log("Creating nodes for", filesData.length, "files");

    // Create nodes for each media file
    filesData.forEach((file, index) => {
      const node = this.createMediaNode(file, index);
      this.nodes.push(node);
      this.canvas.appendChild(node.element);
      console.log("Created node for:", file.filename);
    });

    // Arrange nodes in current mode
    if (this.nodes.length > 0) {
      setTimeout(() => {
        console.log("Arranging", this.nodes.length, "nodes");
        this.arrangeNodes();
      }, 100);
    } else {
      console.log("No nodes to arrange");
      this.showEmptyState();
    }
  },

  showEmptyState() {
    const emptyState = document.createElement('div');
    emptyState.className = 'empty-cosmos';
    emptyState.innerHTML = `
      <div style="
        position: absolute;
        top: 50%;
        left: 50%;
        transform: translate(-50%, -50%);
        text-align: center;
        color: white;
        z-index: 100;
      ">
        <div style="font-size: 64px; margin-bottom: 20px; opacity: 0.6;">🌌</div>
        <h3 style="margin: 0 0 10px 0; font-size: 24px;">Your cosmos is empty</h3>
        <p style="margin: 0; opacity: 0.8;">Upload some media files to see them float in space</p>
      </div>
    `;
    this.canvas.appendChild(emptyState);
  },

  createMediaNode(fileData, index) {
    console.log("Creating node for file:", fileData);
    
    const element = document.createElement('div');
    const size = this.getNodeSize(fileData);
    
    element.className = `media-node ${this.getMediaType(fileData)}-node`;
    element.style.width = size + 'px';
    element.style.height = size + 'px';
    element.style.opacity = '0';
    element.style.transform = 'scale(0.8)';
    element.dataset.fileId = fileData.id;

    const inner = document.createElement('div');
    inner.className = 'node-inner';

    // Add special effects for audio files
    if (this.getMediaType(fileData) === 'audio') {
      const ring = document.createElement('div');
      ring.className = 'audio-ring';
      inner.appendChild(ring);
    }

    // Add preview image for image files
    if (this.getMediaType(fileData) === 'image' && fileData.file_path) {
      const preview = document.createElement('img');
      preview.className = 'media-preview';
      preview.src = fileData.file_path;
      preview.alt = fileData.filename;
      preview.style.cssText = `
        position: absolute;
        width: 100%;
        height: 100%;
        object-fit: cover;
        border-radius: 50%;
      `;
      inner.appendChild(preview);
    } else {
      // Add file type indicator
      const typeIndicator = document.createElement('div');
      typeIndicator.className = 'file-type-indicator';
      typeIndicator.style.cssText = `
        position: absolute;
        top: 50%;
        left: 50%;
        transform: translate(-50%, -50%);
        color: white;
        font-size: 12px;
        font-weight: bold;
        text-shadow: 0 2px 4px rgba(0,0,0,0.5);
        pointer-events: none;
        z-index: 2;
      `;
      typeIndicator.textContent = this.getFileExtension(fileData.filename).toUpperCase();
      inner.appendChild(typeIndicator);
    }

    element.appendChild(inner);

    // Add interaction handlers
    element.addEventListener('click', (e) => {
      e.stopPropagation();
      this.selectNode(element, fileData);
    });

    element.addEventListener('mouseenter', () => {
      this.showNodeTooltip(element, fileData);
    });

    element.addEventListener('mouseleave', () => {
      this.hideNodeTooltip();
    });

    console.log("Created node element:", element);

    return { 
      element, 
      data: fileData, 
      position: { x: 0, y: 0 },
      index 
    };
  },

  getMediaType(fileData) {
    const extension = this.getFileExtension(fileData.filename).toLowerCase();
    
    if (['mp3', 'wav', 'ogg', 'flac', 'm4a', 'aac'].includes(extension)) {
      return 'audio';
    } else if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg'].includes(extension)) {
      return 'image';
    } else if (['mp4', 'avi', 'mov', 'wmv', 'flv', 'webm', 'mkv'].includes(extension)) {
      return 'video';
    } else {
      return 'document';
    }
  },

  getFileExtension(filename) {
    return filename.split('.').pop() || '';
  },

  getNodeSize(fileData) {
    const baseSize = 80;
    const sizeMultiplier = Math.min(2, Math.max(0.7, (fileData.file_size || 1000000) / 5000000));
    return Math.round(baseSize * sizeMultiplier);
  },

  arrangeNodes() {
    if (!this.nodes.length) return;
    
    const centerX = this.canvas.clientWidth / 2;
    const centerY = this.canvas.clientHeight / 2;

    switch (this.currentMode) {
      case 'galaxy':
        this.arrangeGalaxy(centerX, centerY);
        break;
      case 'constellation':
        this.arrangeConstellation(centerX, centerY);
        break;
      case 'flow':
        this.arrangeFlow(centerX, centerY);
        break;
      case 'neural':
        this.arrangeNeural(centerX, centerY);
        break;
    }

    // Add entrance animation
    this.nodes.forEach((node, i) => {
      setTimeout(() => {
        node.element.style.opacity = '1';
        node.element.style.transform += ' scale(1)';
      }, i * 100);
    });
  },

  arrangeGalaxy(centerX, centerY) {
    const spiralArms = 4;
    const nodesPerArm = Math.ceil(this.nodes.length / spiralArms);
    
    this.nodes.forEach((node, i) => {
      const arm = i % spiralArms;
      const positionInArm = Math.floor(i / spiralArms);
      const distance = 120 + (positionInArm * 80);
      const angle = (arm * Math.PI * 2 / spiralArms) + (positionInArm * 0.8);
      
      // Add some randomness for organic feel
      const randomOffset = 30;
      const x = centerX + Math.cos(angle) * distance + (Math.random() - 0.5) * randomOffset;
      const y = centerY + Math.sin(angle) * distance + (Math.random() - 0.5) * randomOffset;
      
      this.animateNodeTo(node, x, y, i * 50);
    });
  },

  arrangeConstellation(centerX, centerY) {
    // Group by media type
    const groups = {
      audio: this.nodes.filter(n => this.getMediaType(n.data) === 'audio'),
      image: this.nodes.filter(n => this.getMediaType(n.data) === 'image'),
      video: this.nodes.filter(n => this.getMediaType(n.data) === 'video'),
      document: this.nodes.filter(n => this.getMediaType(n.data) === 'document')
    };

    const groupAngles = { audio: 0, image: Math.PI/2, video: Math.PI, document: 3*Math.PI/2 };
    
    Object.entries(groups).forEach(([type, nodes]) => {
      const baseAngle = groupAngles[type];
      const radius = 150 + Math.random() * 100;
      
      nodes.forEach((node, i) => {
        const angle = baseAngle + (i - nodes.length/2) * 0.3;
        const distance = radius + i * 20;
        
        const x = centerX + Math.cos(angle) * distance;
        const y = centerY + Math.sin(angle) * distance;
        
        this.animateNodeTo(node, x, y, node.index * 30);
      });
    });
  },

  arrangeFlow(centerX, centerY) {
    const waveAmplitude = 150;
    const waveFrequency = 0.02;
    
    this.nodes.forEach((node, i) => {
      const x = centerX + (i - this.nodes.length / 2) * 100;
      const waveOffset = Math.sin(i * waveFrequency) * waveAmplitude;
      const y = centerY + waveOffset + (Math.random() - 0.5) * 50;
      
      this.animateNodeTo(node, x, y, i * 40);
    });
  },

  arrangeNeural(centerX, centerY) {
    const layers = Math.ceil(Math.sqrt(this.nodes.length));
    const nodesPerLayer = Math.ceil(this.nodes.length / layers);
    
    this.nodes.forEach((node, i) => {
      const layer = Math.floor(i / nodesPerLayer);
      const nodeInLayer = i % nodesPerLayer;
      const layerRadius = 80 + layer * 120;
      
      const angle = (nodeInLayer / nodesPerLayer) * Math.PI * 2;
      const x = centerX + Math.cos(angle) * layerRadius;
      const y = centerY + Math.sin(angle) * layerRadius;
      
      this.animateNodeTo(node, x, y, i * 60);
    });
  },

  animateNodeTo(node, x, y, delay = 0) {
    node.position = { x, y };
    
    setTimeout(() => {
      const nodeSize = parseInt(node.element.style.width) / 2;
      node.element.style.transform = `translate(${x - nodeSize}px, ${y - nodeSize}px) scale(1)`;
      node.element.style.opacity = '1';
    }, delay);
  },

  selectNode(element, fileData) {
    // Remove previous selection
    this.nodes.forEach(n => n.element.classList.remove('selected'));
    if (this.selectedNode) {
      this.selectedNode.classList.remove('playing');
    }
    
    // Select this node
    element.classList.add('selected');
    this.selectedNode = element;

    // Show info panel with file details
    const fileName = this.infoPanel.querySelector('#fileName');
    const fileDetails = this.infoPanel.querySelector('#fileDetails');
    
    fileName.textContent = fileData.filename;
    fileDetails.textContent = `Type: ${this.getMediaType(fileData)} • Size: ${this.formatFileSize(fileData.file_size)}`;
    
    this.infoPanel.classList.add('visible');

    // Handle audio playback
    if (this.getMediaType(fileData) === 'audio') {
      this.playAudioFile(element, fileData);
    }

    // Auto-hide info panel after 5 seconds
    setTimeout(() => {
      this.infoPanel.classList.remove('visible');
    }, 5000);

    // Add haptic feedback on mobile
    if ('vibrate' in navigator) {
      navigator.vibrate(50);
    }
  },

  playAudioFile(element, fileData) {
    // Stop current audio
    if (this.currentAudio) {
      this.currentAudio.pause();
      this.audioVisualizer.style.display = 'none';
    }

    // Add playing animation
    element.classList.add('playing');
    
    // Show audio visualizer
    this.audioVisualizer.style.display = 'flex';

    // If we have a real audio file, try to play it
    if (fileData.file_path && this.audioContext) {
      this.loadAndPlayAudio(fileData.file_path);
    } else {
      // Simulate audio visualization
      this.simulateAudioVisualization();
    }

    // Auto-stop after 15 seconds (demo)
    setTimeout(() => {
      element.classList.remove('playing');
      this.audioVisualizer.style.display = 'none';
      if (this.currentAudio) {
        this.currentAudio.pause();
      }
    }, 15000);
  },

  async loadAndPlayAudio(audioPath) {
    try {
      // Create audio element
      this.currentAudio = new Audio(audioPath);
      this.currentAudio.crossOrigin = 'anonymous';
      
      // Create audio context nodes
      const source = this.audioContext.createMediaElementSource(this.currentAudio);
      source.connect(this.analyser);
      this.analyser.connect(this.audioContext.destination);
      
      // Start playback
      await this.currentAudio.play();
      
      // Start real-time visualization
      this.visualizeRealAudio();
      
    } catch (error) {
      console.warn('Could not play audio:', error);
      // Fallback to simulation
      this.simulateAudioVisualization();
    }
  },

  visualizeRealAudio() {
    if (!this.analyser) return;
    
    const bufferLength = this.analyser.frequencyBinCount;
    const dataArray = new Uint8Array(bufferLength);
    const bars = this.audioVisualizer.querySelectorAll('.visualizer-bar');
    
    const animate = () => {
      if (this.audioVisualizer.style.display === 'none') return;
      
      this.analyser.getByteFrequencyData(dataArray);
      
      // Update visualizer bars with real frequency data
      for (let i = 0; i < bars.length; i++) {
        const barHeight = (dataArray[i] / 255) * 40 + 5;
        bars[i].style.height = barHeight + 'px';
        
        // Color based on frequency
        const hue = (i / bars.length) * 360;
        bars[i].style.background = `hsl(${hue}, 70%, 60%)`;
      }
      
      requestAnimationFrame(animate);
    };
    
    animate();
  },

  simulateAudioVisualization() {
    const bars = this.audioVisualizer.querySelectorAll('.visualizer-bar');
    let animationId;
    
    const animate = () => {
      if (this.audioVisualizer.style.display === 'none') {
        cancelAnimationFrame(animationId);
        return;
      }
      
      bars.forEach((bar, i) => {
        const height = Math.random() * 35 + 5;
        const intensity = Math.sin(Date.now() * 0.01 + i * 0.5) * 0.5 + 0.5;
        bar.style.height = (height * intensity) + 'px';
        
        // Dynamic color based on intensity
        const hue = 200 + intensity * 160; // Blue to red spectrum
        bar.style.background = `hsl(${hue}, 70%, ${50 + intensity * 30}%)`;
      });
      
      animationId = requestAnimationFrame(animate);
    };
    
    animate();
  },

  formatFileSize(bytes) {
    if (!bytes) return '0 B';
    
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(1024));
    return Math.round(bytes / Math.pow(1024, i) * 10) / 10 + ' ' + sizes[i];
  },

  showNodeTooltip(element, fileData) {
    // Create floating tooltip on hover
    const tooltip = document.createElement('div');
    tooltip.className = 'node-tooltip';
    tooltip.innerHTML = `
      <div style="
        position: absolute;
        bottom: 100%;
        left: 50%;
        transform: translateX(-50%);
        background: rgba(0,0,0,0.8);
        color: white;
        padding: 8px 12px;
        border-radius: 8px;
        font-size: 12px;
        white-space: nowrap;
        pointer-events: none;
        backdrop-filter: blur(10px);
        border: 1px solid rgba(255,255,255,0.2);
      ">
        ${fileData.filename}
      </div>
    `;
    
    element.appendChild(tooltip);
  },

  hideNodeTooltip() {
    document.querySelectorAll('.node-tooltip').forEach(tooltip => {
      tooltip.remove();
    });
  },

  bindEvents() {
    // Mode selector buttons
    this.el.querySelectorAll('.mode-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        this.el.querySelectorAll('.mode-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        this.currentMode = btn.dataset.mode;
        this.arrangeNodes();
      });
    });

    // Canvas interaction events
    this.canvas.addEventListener('mousedown', this.onMouseDown.bind(this));
    this.canvas.addEventListener('mousemove', this.onMouseMove.bind(this));
    this.canvas.addEventListener('mouseup', this.onMouseUp.bind(this));
    this.canvas.addEventListener('wheel', this.onWheel.bind(this));

    // Touch events for mobile
    this.canvas.addEventListener('touchstart', this.onTouchStart.bind(this));
    this.canvas.addEventListener('touchmove', this.onTouchMove.bind(this));
    this.canvas.addEventListener('touchend', this.onTouchEnd.bind(this));

    // Prevent context menu
    this.canvas.addEventListener('contextmenu', (e) => e.preventDefault());

    // Drag and drop for file uploads
    this.bindDropEvents();

    // Keyboard shortcuts
    document.addEventListener('keydown', (e) => {
      switch(e.key) {
        case '1': this.setMode('galaxy'); break;
        case '2': this.setMode('constellation'); break;
        case '3': this.setMode('flow'); break;
        case '4': this.setMode('neural'); break;
        case 'Escape': 
          this.infoPanel.classList.remove('visible');
          this.hideUploadZone();
          break;
        case ' ':
          e.preventDefault();
          if (this.selectedNode && this.getMediaType(this.selectedNode.dataset) === 'audio') {
            this.toggleAudioPlayback();
          }
          break;
        case 'u': // U key to upload
          e.preventDefault();
          this.pushEvent('open_upload_modal', {});
          break;
      }
    });

    // Window resize
    window.addEventListener('resize', () => {
      setTimeout(() => this.arrangeNodes(), 100);
    });

    // Action buttons in info panel
    this.infoPanel.querySelector('#downloadBtn')?.addEventListener('click', () => {
      if (this.selectedNode) {
        this.downloadFile(this.selectedNode.dataset);
      }
    });

    this.infoPanel.querySelector('#shareBtn')?.addEventListener('click', () => {
      if (this.selectedNode) {
        this.shareFile(this.selectedNode.dataset);
      }
    });
  },

  bindDropEvents() {
    // Show upload zone on drag enter
    this.el.addEventListener('dragenter', (e) => {
      e.preventDefault();
      this.showUploadZone();
    });

    this.el.addEventListener('dragover', (e) => {
      e.preventDefault();
      this.uploadZone.classList.add('dragover');
    });

    this.el.addEventListener('dragleave', (e) => {
      e.preventDefault();
      if (!this.el.contains(e.relatedTarget)) {
        this.hideUploadZone();
      }
    });

    this.el.addEventListener('drop', (e) => {
      e.preventDefault();
      this.hideUploadZone();
      // Trigger upload modal instead of direct file handling
      this.pushEvent('open_upload_modal', {});
    });
  },

  showUploadZone() {
    this.uploadZone.style.display = 'flex';
    setTimeout(() => {
      this.uploadZone.style.opacity = '1';
      this.uploadZone.style.transform = 'translate(-50%, -50%) scale(1)';
    }, 10);
  },

  hideUploadZone() {
    this.uploadZone.style.opacity = '0';
    this.uploadZone.style.transform = 'translate(-50%, -50%) scale(0.9)';
    this.uploadZone.classList.remove('dragover');
    setTimeout(() => {
      this.uploadZone.style.display = 'none';
    }, 300);
  },

  setMode(mode) {
    this.el.querySelectorAll('.mode-btn').forEach(btn => {
      btn.classList.toggle('active', btn.dataset.mode === mode);
    });
    this.currentMode = mode;
    this.arrangeNodes();
  },

  // Mouse interaction handlers
  onMouseDown(e) {
    if (e.target === this.canvas) {
      this.isDragging = true;
      this.lastMouse = { x: e.clientX, y: e.clientY };
      this.canvas.style.cursor = 'grabbing';
      e.preventDefault();
    }
  },

  onMouseMove(e) {
    if (!this.isDragging) return;
    
    const deltaX = e.clientX - this.lastMouse.x;
    const deltaY = e.clientY - this.lastMouse.y;
    
    this.camera.x += deltaX;
    this.camera.y += deltaY;
    
    this.updateCameraTransform();
    this.lastMouse = { x: e.clientX, y: e.clientY };
  },

  onMouseUp() {
    this.isDragging = false;
    this.canvas.style.cursor = 'grab';
  },

  onWheel(e) {
    e.preventDefault();
    
    const rect = this.canvas.getBoundingClientRect();
    const mouseX = e.clientX - rect.left;
    const mouseY = e.clientY - rect.top;
    
    const zoomFactor = e.deltaY > 0 ? 0.9 : 1.1;
    const newZoom = Math.max(0.3, Math.min(3, this.camera.zoom * zoomFactor));
    
    // Zoom towards mouse position
    const zoomChange = newZoom / this.camera.zoom;
    this.camera.x = mouseX - (mouseX - this.camera.x) * zoomChange;
    this.camera.y = mouseY - (mouseY - this.camera.y) * zoomChange;
    this.camera.zoom = newZoom;
    
    this.updateCameraTransform();
  },

  // Touch interaction handlers
  onTouchStart(e) {
    if (e.touches.length === 1) {
      const touch = e.touches[0];
      this.lastTouch = { x: touch.clientX, y: touch.clientY };
      this.isDragging = true;
    } else if (e.touches.length === 2) {
      // Pinch to zoom
      this.lastTouch = {
        x1: e.touches[0].clientX,
        y1: e.touches[0].clientY,
        x2: e.touches[1].clientX,
        y2: e.touches[1].clientY,
        distance: this.getTouchDistance(e.touches)
      };
    }
  },

  onTouchMove(e) {
    e.preventDefault();
    
    if (e.touches.length === 1 && this.isDragging) {
      // Pan gesture
      const touch = e.touches[0];
      const deltaX = touch.clientX - this.lastTouch.x;
      const deltaY = touch.clientY - this.lastTouch.y;
      
      this.camera.x += deltaX;
      this.camera.y += deltaY;
      
      this.updateCameraTransform();
      this.lastTouch = { x: touch.clientX, y: touch.clientY };
      
    } else if (e.touches.length === 2 && this.lastTouch.distance) {
      // Pinch zoom gesture
      const newDistance = this.getTouchDistance(e.touches);
      const zoomFactor = newDistance / this.lastTouch.distance;
      
      this.camera.zoom = Math.max(0.3, Math.min(3, this.camera.zoom * zoomFactor));
      this.updateCameraTransform();
      
      this.lastTouch.distance = newDistance;
    }
  },

  onTouchEnd() {
    this.isDragging = false;
    this.lastTouch = null;
  },

  getTouchDistance(touches) {
    const dx = touches[0].clientX - touches[1].clientX;
    const dy = touches[0].clientY - touches[1].clientY;
    return Math.sqrt(dx * dx + dy * dy);
  },

  updateCameraTransform() {
    this.canvas.style.transform = `translate(${this.camera.x}px, ${this.camera.y}px) scale(${this.camera.zoom})`;
  },

  downloadFile(fileData) {
    if (fileData.filePath) {
      const link = document.createElement('a');
      link.href = fileData.filePath;
      link.download = fileData.filename;
      link.click();
    }
  },

  shareFile(fileData) {
    if (navigator.share) {
      navigator.share({
        title: fileData.filename,
        text: `Check out this ${this.getMediaType(fileData)} file`,
        url: window.location.href
      });
    } else {
      // Fallback: copy to clipboard
      navigator.clipboard.writeText(window.location.href + '#' + fileData.filename);
      // Show feedback
      const toast = document.createElement('div');
      toast.textContent = 'Link copied to clipboard!';
      toast.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        background: rgba(0,0,0,0.8);
        color: white;
        padding: 12px 20px;
        border-radius: 8px;
        z-index: 1000;
        backdrop-filter: blur(10px);
      `;
      document.body.appendChild(toast);
      setTimeout(() => toast.remove(), 3000);
    }
  },

  toggleAudioPlayback() {
    if (this.currentAudio) {
      if (this.currentAudio.paused) {
        this.currentAudio.play();
        this.selectedNode.classList.add('playing');
        this.audioVisualizer.style.display = 'flex';
      } else {
        this.currentAudio.pause();
        this.selectedNode.classList.remove('playing');
        this.audioVisualizer.style.display = 'none';
      }
    }
  },

  startAnimation() {
    // Continuous animation loop for enhanced effects
    const animate = () => {
      const time = Date.now() * 0.001;
      
      // Subtle floating animation for nodes
      this.nodes.forEach((node, i) => {
        if (!this.isDragging && node.element.style.opacity === '1') {
          const floatOffset = Math.sin(time + i * 0.5) * 3;
          const currentTransform = node.element.style.transform;
          
          // Update only the Y position for floating effect
          const match = currentTransform.match(/translate\(([^,]+),\s*([^)]+)\)/);
          if (match) {
            const x = parseFloat(match[1]);
            const baseY = parseFloat(match[2]);
            const newY = node.position.y - 40 + floatOffset; // 40 is half node size
            node.element.style.transform = `translate(${x}px, ${newY}px) scale(1)`;
          }
        }
      });
      
      // Pulsing effect for audio nodes
      this.nodes.forEach(node => {
        if (this.getMediaType(node.data) === 'audio' && !node.element.classList.contains('playing')) {
          const pulse = 1 + Math.sin(time * 2 + node.index) * 0.05;
          node.element.querySelector('.node-inner').style.transform = `scale(${pulse})`;
        }
      });
      
      requestAnimationFrame(animate);
    };
    
    animate();
  },

  destroyed() {
    // Cleanup
    if (this.currentAudio) {
      this.currentAudio.pause();
    }
    if (this.audioContext) {
      this.audioContext.close();
    }
  }
};