// assets/js/hooks/rating_canvas_hook.js
export const RatingCanvas = {
  mounted() {
    this.canvas = this.el.querySelector('canvas') || this.el;
    this.ctx = this.canvas.getContext('2d');
    this.isActive = false;
    this.currentRating = { x: 50, y: 50 }; // Default center position
    
    this.setupCanvas();
    this.setupEventListeners();
    this.drawInterface();
  },

  setupCanvas() {
    // Set canvas size
    const rect = this.canvas.parentElement.getBoundingClientRect();
    this.canvas.width = rect.width || 300;
    this.canvas.height = rect.height || 200;
  },

  setupEventListeners() {
    // Mouse events
    this.canvas.addEventListener('mousedown', (e) => this.startRating(e));
    this.canvas.addEventListener('mousemove', (e) => this.updateRating(e));
    this.canvas.addEventListener('mouseup', (e) => this.endRating(e));
    this.canvas.addEventListener('mouseleave', (e) => this.endRating(e));

    // Touch events for mobile
    this.canvas.addEventListener('touchstart', (e) => {
      e.preventDefault();
      const touch = e.touches[0];
      this.startRating(this.getTouchMouseEvent(touch, 'mousedown'));
    });

    this.canvas.addEventListener('touchmove', (e) => {
      e.preventDefault();
      const touch = e.touches[0];
      this.updateRating(this.getTouchMouseEvent(touch, 'mousemove'));
    });

    this.canvas.addEventListener('touchend', (e) => {
      e.preventDefault();
      this.endRating();
    });
  },

  getTouchMouseEvent(touch, type) {
    return {
      type: type,
      clientX: touch.clientX,
      clientY: touch.clientY,
      preventDefault: () => {}
    };
  },

  startRating(e) {
    this.isActive = true;
    this.updateRatingPosition(e);
  },

  updateRating(e) {
    if (!this.isActive) return;
    this.updateRatingPosition(e);
  },

  endRating(e) {
    if (!this.isActive) return;
    this.isActive = false;
    
    // Send rating to LiveView
    this.pushEvent("rating_updated", {
      primary_score: this.currentRating.x,
      secondary_score: this.currentRating.y,
      rating_coordinates: {
        x: this.currentRating.x,
        y: this.currentRating.y
      }
    });
  },

  updateRatingPosition(e) {
    const rect = this.canvas.getBoundingClientRect();
    const x = ((e.clientX - rect.left) / rect.width) * 100;
    const y = ((e.clientY - rect.top) / rect.height) * 100;
    
    // Clamp values between 0 and 100
    this.currentRating.x = Math.max(0, Math.min(100, x));
    this.currentRating.y = Math.max(0, Math.min(100, y));
    
    this.drawInterface();
  },

  drawInterface() {
    const ctx = this.ctx;
    const width = this.canvas.width;
    const height = this.canvas.height;
    
    // Clear canvas
    ctx.clearRect(0, 0, width, height);
    
    // Draw gradient background
    this.drawGradientBackground(ctx, width, height);
    
    // Draw current rating position
    this.drawRatingIndicator(ctx, width, height);
    
    // Draw axis labels
    this.drawAxisLabels(ctx, width, height);
  },

  drawGradientBackground(ctx, width, height) {
    // Horizontal gradient (red to green)
    const horizontalGradient = ctx.createLinearGradient(0, 0, width, 0);
    horizontalGradient.addColorStop(0, '#ef4444'); // Red
    horizontalGradient.addColorStop(0.5, '#eab308'); // Yellow
    horizontalGradient.addColorStop(1, '#22c55e'); // Green
    
    // Vertical gradient for secondary dimension
    const verticalGradient = ctx.createLinearGradient(0, height, 0, 0);
    verticalGradient.addColorStop(0, '#8b5cf6'); // Purple
    verticalGradient.addColorStop(1, '#06b6d4'); // Cyan
    
    // Draw base horizontal gradient
    ctx.fillStyle = horizontalGradient;
    ctx.fillRect(0, 0, width, height);
    
    // Overlay vertical gradient with reduced opacity
    ctx.globalCompositeOperation = 'multiply';
    ctx.fillStyle = verticalGradient;
    ctx.fillRect(0, 0, width, height);
    ctx.globalCompositeOperation = 'source-over';
  },

  drawRatingIndicator(ctx, width, height) {
    const x = (this.currentRating.x / 100) * width;
    const y = (this.currentRating.y / 100) * height;
    
    // Draw white circle with black border
    ctx.beginPath();
    ctx.arc(x, y, 8, 0, 2 * Math.PI);
    ctx.fillStyle = 'white';
    ctx.fill();
    ctx.strokeStyle = 'black';
    ctx.lineWidth = 2;
    ctx.stroke();
    
    // Draw crosshairs
    ctx.beginPath();
    ctx.moveTo(x - 12, y);
    ctx.lineTo(x + 12, y);
    ctx.moveTo(x, y - 12);
    ctx.lineTo(x, y + 12);
    ctx.strokeStyle = 'rgba(0, 0, 0, 0.5)';
    ctx.lineWidth = 1;
    ctx.stroke();
  },

  drawAxisLabels(ctx, width, height) {
    ctx.fillStyle = 'rgba(0, 0, 0, 0.7)';
    ctx.font = '12px -apple-system, BlinkMacSystemFont, sans-serif';
    ctx.textAlign = 'center';
    
    // Bottom labels (Quality axis)
    ctx.fillText('Poor Quality', 50, height - 5);
    ctx.fillText('High Quality', width - 50, height - 5);
    
    // Side labels (Secondary dimension)
    ctx.save();
    ctx.translate(10, height / 2);
    ctx.rotate(-Math.PI / 2);
    ctx.fillText('Collaboration', 0, 0);
    ctx.restore();
  }
};