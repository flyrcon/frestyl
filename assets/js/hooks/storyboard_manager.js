// assets/js/hooks/storyboard_manager.js
// Main storyboard manager hook for coordinating canvas interactions

const StoryboardManager = {
  mounted() {
    this.storyId = this.el.dataset.storyId;
    this.deviceType = this.el.dataset.deviceType;
    this.collaborationEnabled = this.el.dataset.collaborationEnabled === 'true';
    
    // Manager state
    this.activePanelId = null;
    this.canvasInstances = new Map();
    this.collaboratorCursors = new Map();
    
    console.log(`Storyboard manager initialized for story ${this.storyId}`);
    
    this.setupEventListeners();
    this.detectDeviceType();
  },

  setupEventListeners() {
    // Listen for panel selection events
    this.handleEvent('panel_selected', (payload) => {
      this.handlePanelSelection(payload.panel_id);
    });

    // Listen for collaboration events
    this.handleEvent('collaborator_joined', (payload) => {
      this.handleCollaboratorJoined(payload.user);
    });

    this.handleEvent('collaborator_left', (payload) => {
      this.handleCollaboratorLeft(payload.user);
    });

    // Handle canvas ready events from child components
    this.handleEvent('canvas_ready', (payload) => {
      this.registerCanvasInstance(payload.panel_id, payload.canvas);
    });
  },

  detectDeviceType() {
    // Update device type based on current viewport
    const width = window.innerWidth;
    let newDeviceType;
    
    if (width < 768) {
      newDeviceType = 'mobile';
    } else if (width < 1024) {
      newDeviceType = 'tablet';
    } else {
      newDeviceType = 'desktop';
    }

    if (newDeviceType !== this.deviceType) {
      this.deviceType = newDeviceType;
      this.pushEvent('device_type_changed', { device_type: newDeviceType });
    }
  },

  handlePanelSelection(panelId) {
    // Update active panel
    this.activePanelId = panelId;
    
    // Update UI to reflect selection
    this.updatePanelSelectionUI(panelId);
    
    // Focus the canvas if it exists
    const canvas = this.canvasInstances.get(panelId);
    if (canvas) {
      canvas.focus();
    }
  },

  handleCollaboratorJoined(user) {
    console.log(`Collaborator joined: ${user.username}`);
    
    // Add to collaborators tracking
    this.collaboratorCursors.set(user.id, {
      username: user.username,
      color: this.generateUserColor(user.id),
      position: { x: 0, y: 0 }
    });

    // Update UI
    this.updateCollaborationUI();
  },

  handleCollaboratorLeft(user) {
    console.log(`Collaborator left: ${user.username}`);
    
    // Remove from tracking
    this.collaboratorCursors.delete(user.id);
    
    // Update UI
    this.updateCollaborationUI();
  },

  registerCanvasInstance(panelId, canvas) {
    this.canvasInstances.set(panelId, canvas);
    console.log(`Registered canvas for panel ${panelId}`);
  },

  updatePanelSelectionUI(selectedPanelId) {
    // Update panel card active states
    const panelCards = this.el.querySelectorAll('.panel-card');
    panelCards.forEach(card => {
      const panelId = card.dataset.panelId;
      if (panelId === selectedPanelId) {
        card.classList.add('active');
      } else {
        card.classList.remove('active');
      }
    });
  },

  updateCollaborationUI() {
    // Update collaborator count and indicators
    const collaboratorCount = this.collaboratorCursors.size;
    const indicators = this.el.querySelectorAll('.collaboration-indicator');
    
    indicators.forEach(indicator => {
      const countEl = indicator.querySelector('.collaborator-count');
      if (countEl) {
        countEl.textContent = collaboratorCount;
      }
    });
  },

  generateUserColor(userId) {
    // Generate consistent color for user
    const colors = [
      '#3B82F6', '#EF4444', '#10B981', '#F59E0B', 
      '#8B5CF6', '#F97316', '#EC4899', '#14B8A6'
    ];
    
    // Simple hash of user ID to color index
    let hash = 0;
    for (let i = 0; i < userId.length; i++) {
      hash = ((hash << 5) - hash + userId.charCodeAt(i)) & 0xffffffff;
    }
    
    return colors[Math.abs(hash) % colors.length];
  },

  // Public methods for canvas coordination
  syncAllCanvases() {
    // Sync state across all canvas instances
    this.canvasInstances.forEach((canvas, panelId) => {
      canvas.syncWithManager();
    });
  },

  exportAllPanels(format = 'png') {
    // Export all panels in sequence
    const exports = [];
    
    this.canvasInstances.forEach((canvas, panelId) => {
      const exportData = canvas.exportCanvas(format);
      exports.push({
        panel_id: panelId,
        data: exportData
      });
    });
    
    return exports;
  },

  focusPanel(panelId) {
    const canvas = this.canvasInstances.get(panelId);
    if (canvas) {
      canvas.focus();
      this.handlePanelSelection(panelId);
    }
  },

  // Window resize handler
  handleResize() {
    this.detectDeviceType();
    
    // Notify all canvas instances of resize
    this.canvasInstances.forEach(canvas => {
      canvas.handleResize();
    });
  },

  destroyed() {
    // Clean up canvas instances
    this.canvasInstances.clear();
    this.collaboratorCursors.clear();
    
    // Remove window listeners
    window.removeEventListener('resize', this.handleResize);
    
    console.log(`Storyboard manager destroyed for story ${this.storyId}`);
  }
};

// Add window resize listener
if (typeof window !== 'undefined') {
  window.addEventListener('resize', () => {
    // Find all active storyboard managers and notify them
    document.querySelectorAll('[phx-hook="StoryboardManager"]').forEach(el => {
      if (el.view && el.view.handleResize) {
        el.view.handleResize();
      }
    });
  });
}

export default StoryboardManager;