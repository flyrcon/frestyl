// Mobile Gestures Hook for Touch/Swipe Detection
const MobileGestures = {
  mounted() {
    this.startY = 0;
    this.startX = 0;
    this.currentY = 0;
    this.currentX = 0;
    this.isDragging = false;
    this.threshold = 50; // Minimum distance for swipe
    
    // Touch event listeners
    this.el.addEventListener('touchstart', this.handleTouchStart.bind(this), { passive: true });
    this.el.addEventListener('touchmove', this.handleTouchMove.bind(this), { passive: false });
    this.el.addEventListener('touchend', this.handleTouchEnd.bind(this), { passive: true });
    
    // Handle sheet drag for bottom sheet
    this.handleEl = this.el.querySelector('.handle') || this.el;
    this.sheet = this.el;
  },

  handleTouchStart(e) {
    this.startY = e.touches[0].clientY;
    this.startX = e.touches[0].clientX;
    this.isDragging = true;
  },

  handleTouchMove(e) {
    if (!this.isDragging) return;
    
    this.currentY = e.touches[0].clientY;
    this.currentX = e.touches[0].clientX;
    
    const diffY = this.currentY - this.startY;
    const diffX = this.currentX - this.startX;
    
    // If dragging down on bottom sheet, follow finger
    if (diffY > 0 && Math.abs(diffY) > Math.abs(diffX)) {
      e.preventDefault();
      const progress = Math.min(diffY / 200, 1); // Max drag distance of 200px
      this.sheet.style.transform = `translateY(${diffY}px)`;
      this.sheet.style.opacity = 1 - (progress * 0.3);
    }
  },

  handleTouchEnd(e) {
    if (!this.isDragging) return;
    this.isDragging = false;
    
    const diffY = this.currentY - this.startY;
    const diffX = this.currentX - this.startX;
    const absDiffY = Math.abs(diffY);
    const absDiffX = Math.abs(diffX);
    
    // Reset sheet position
    this.sheet.style.transform = '';
    this.sheet.style.opacity = '';
    
    // Determine swipe direction
    if (absDiffY > this.threshold || absDiffX > this.threshold) {
      let direction = '';
      
      if (absDiffY > absDiffX) {
        direction = diffY > 0 ? 'down' : 'up';
      } else {
        direction = diffX > 0 ? 'right' : 'left';
      }
      
      // Send swipe event to LiveView
      this.pushEvent("mobile_swipe", { direction: direction });
      
      // Auto-close sheet if swiped down significantly
      if (direction === 'down' && diffY > 100) {
        this.pushEvent("toggle_mobile_drawer", {});
      }
    }
  },

  destroyed() {
    this.el.removeEventListener('touchstart', this.handleTouchStart);
    this.el.removeEventListener('touchmove', this.handleTouchMove);
    this.el.removeEventListener('touchend', this.handleTouchEnd);
  }
};

export default MobileGestures;