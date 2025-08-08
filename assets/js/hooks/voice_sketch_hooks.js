export const VoiceSketchCanvas = {
  mounted() {
    this.canvas = this.el;
    this.ctx = this.canvas.getContext('2d');
    this.isDrawing = false;
    this.currentStroke = [];
    this.strokes = [];
    
    // Set up canvas
    this.resizeCanvas();
    this.setupEventListeners();
    
    // Load existing strokes
    this.loadExistingStrokes();
  },

  updated() {
    this.updateToolSettings();
  },

  resizeCanvas() {
    const rect = this.canvas.parentElement.getBoundingClientRect();
    this.canvas.width = rect.width;
    this.canvas.height = rect.height;
    this.redrawCanvas();
  },

  setupEventListeners() {
    // Mouse events
    this.canvas.addEventListener('mousedown', (e) => this.startDrawing(e));
    this.canvas.addEventListener('mousemove', (e) => this.draw(e));
    this.canvas.addEventListener('mouseup', (e) => this.stopDrawing(e));
    this.canvas.addEventListener('mouseout', (e) => this.stopDrawing(e));

    // Touch events for mobile
    this.canvas.addEventListener('touchstart', (e) => {
      e.preventDefault();
      const touch = e.touches[0];
      const mouseEvent = new MouseEvent('mousedown', {
        clientX: touch.clientX,
        clientY: touch.clientY
      });
      this.canvas.dispatchEvent(mouseEvent);
    });

    this.canvas.addEventListener('touchmove', (e) => {
      e.preventDefault();
      const touch = e.touches[0];
      const mouseEvent = new MouseEvent('mousemove', {
        clientX: touch.clientX,
        clientY: touch.clientY
      });
      this.canvas.dispatchEvent(mouseEvent);
    });

    this.canvas.addEventListener('touchend', (e) => {
      e.preventDefault();
      const mouseEvent = new MouseEvent('mouseup', {});
      this.canvas.dispatchEvent(mouseEvent);
    });

    // Window resize
    window.addEventListener('resize', () => this.resizeCanvas());
  },

  startDrawing(e) {
    if (this.el.dataset.recordingState === 'idle') return;
    
    this.isDrawing = true;
    this.currentStroke = [];
    
    const point = this.getPointFromEvent(e);
    this.currentStroke.push(point);
    
    this.ctx.beginPath();
    this.ctx.moveTo(point.x, point.y);
  },

  draw(e) {
    if (!this.isDrawing) return;
    
    const point = this.getPointFromEvent(e);
    this.currentStroke.push(point);
    
    // Draw current stroke
    this.ctx.lineTo(point.x, point.y);
    this.ctx.stroke();
  },

  stopDrawing(e) {
    if (!this.isDrawing) return;
    
    this.isDrawing = false;
    
    if (this.currentStroke.length > 1) {
      // Send stroke to server
      const strokeData = {
        stroke_data: {
          points: this.currentStroke,
          tool_settings: this.getToolSettings()
        },
        tool_type: this.el.dataset.currentTool,
        color: this.el.dataset.currentColor,
        stroke_width: parseFloat(this.el.dataset.currentStrokeWidth),
        layer_id: this.el.dataset.currentLayer,
        start_timestamp: this.getAudioTimestamp(),
        end_timestamp: this.getAudioTimestamp() + this.getStrokeDuration()
      };

      this.pushEvent('add_stroke', strokeData);
    }
    
    this.currentStroke = [];
  },

  getPointFromEvent(e) {
    const rect = this.canvas.getBoundingClientRect();
    return {
      x: e.clientX - rect.left,
      y: e.clientY - rect.top,
      pressure: e.pressure || 1.0,
      timestamp: Date.now()
    };
  },

  getToolSettings() {
    return {
      tool: this.el.dataset.currentTool,
      color: this.el.dataset.currentColor,
      width: parseFloat(this.el.dataset.currentStrokeWidth),
      layer: this.el.dataset.currentLayer
    };
  },

  updateToolSettings() {
    const tool = this.el.dataset.currentTool;
    const color = this.el.dataset.currentColor;
    const width = this.el.dataset.currentStrokeWidth;

    this.ctx.strokeStyle = color;
    this.ctx.lineWidth = width;
    this.ctx.lineCap = 'round';
    this.ctx.lineJoin = 'round';

    // Tool-specific settings
    switch(tool) {
      case 'pen':
        this.ctx.globalCompositeOperation = 'source-over';
        break;
      case 'eraser':
        this.ctx.globalCompositeOperation = 'destination-out';
        break;
      case 'highlighter':
        this.ctx.globalCompositeOperation = 'source-over';
        this.ctx.globalAlpha = 0.5;
        break;
      default:
        this.ctx.globalCompositeOperation = 'source-over';
        this.ctx.globalAlpha = 1.0;
    }
  },

  loadExistingStrokes() {
    // Load strokes from server data
    // This would be populated from the session data
  },

  redrawCanvas() {
    this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
    
    // Redraw all strokes
    this.strokes.forEach(stroke => {
      this.drawStroke(stroke);
    });
  },

  drawStroke(stroke) {
    if (stroke.stroke_data.points.length < 2) return;

    this.ctx.strokeStyle = stroke.color;
    this.ctx.lineWidth = stroke.stroke_width;
    this.ctx.lineCap = 'round';
    this.ctx.lineJoin = 'round';

    this.ctx.beginPath();
    this.ctx.moveTo(stroke.stroke_data.points[0].x, stroke.stroke_data.points[0].y);
    
    stroke.stroke_data.points.forEach(point => {
      this.ctx.lineTo(point.x, point.y);
    });
    
    this.ctx.stroke();
  },

  getAudioTimestamp() {
    const audio = document.getElementById('voice-sketch-audio');
    return audio ? Math.floor(audio.currentTime * 1000) : 0;
  },

  getStrokeDuration() {
    return this.currentStroke.length > 0 ? 
      this.currentStroke[this.currentStroke.length - 1].timestamp - this.currentStroke[0].timestamp : 0;
  },

  // LiveView event handlers
  handleEvent("stroke_added", {stroke}) {
    this.strokes.push(stroke);
    this.drawStroke(stroke);
  },

  handleEvent("collaborator_stroke_added", {stroke}) {
    // Different visual indication for collaborator strokes
    this.strokes.push(stroke);
    this.drawStroke(stroke);
    this.showCollaboratorIndicator(stroke);
  }
};

export const VoiceSketchAudio = {
  mounted() {
    this.audio = this.el;
    this.setupAudioEventListeners();
  },

  setupAudioEventListeners() {
    this.audio.addEventListener('timeupdate', () => {
      const position = Math.floor(this.audio.currentTime * 1000);
      this.pushEvent('audio_position_update', {position});
    });

    this.audio.addEventListener('play', () => {
      this.pushEvent('audio_play', {});
    });

    this.audio.addEventListener('pause', () => {
      this.pushEvent('audio_pause', {});
    });

    this.audio.addEventListener('ended', () => {
      this.pushEvent('audio_ended', {});
    });
  },

  handleEvent("sync_to_position", {position}) {
    this.audio.currentTime = position / 1000;
  }
};