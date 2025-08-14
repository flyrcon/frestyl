// assets/js/hooks/fabric_canvas.js
// Fabric.js integration for responsive storyboard canvas with touch support


const FabricCanvas = {
  mounted() {
    this.panelId = this.el.dataset.panelId;
    this.deviceType = this.el.dataset.deviceType;
    this.selectedTool = this.el.dataset.selectedTool;
    this.zoomLevel = parseFloat(this.el.dataset.zoomLevel) || 1.0;
    this.collaborationEnabled = this.el.dataset.collaborationEnabled === 'true';
    this.canvasData = JSON.parse(this.el.dataset.canvasData);
    
    // Canvas state
    this.canvas = null;
    this.isDrawing = false;
    this.currentPath = null;
    this.lastPointerEvent = null;
    
    // Mobile touch state
    this.touchStartTime = 0;
    this.touchStartPos = null;
    this.isPalmRejectionActive = false;
    
    // Collaboration state
    this.remoteCursors = new Map();
    this.operationQueue = [];
    
    this.initializeCanvas();
    this.setupEventListeners();
    this.setupMobileOptimizations();
    
    // Notify component canvas is ready
    this.pushEvent('canvas_ready', {});
  },

  initializeCanvas() {
    const canvasElement = this.el.querySelector(`#fabric-canvas-${this.panelId}`);
    
    // Calculate responsive dimensions
    const dimensions = this.calculateCanvasDimensions();
    
    // Create Fabric.js canvas
    this.canvas = new fabric.Canvas(canvasElement, {
      width: dimensions.width,
      height: dimensions.height,
      backgroundColor: this.canvasData.background || '#ffffff',
      selection: this.selectedTool === 'select',
      isDrawingMode: this.selectedTool === 'pen' || this.selectedTool === 'brush',
      enableRetinaScaling: true,
      imageSmoothingEnabled: true
    });

    // Configure canvas for device type
    this.configureCanvasForDevice();
    
    // Load existing canvas data
    this.loadCanvasData();
    
    // Set up drawing tools
    this.updateDrawingTool();
    
    // Apply zoom level
    this.canvas.setZoom(this.zoomLevel);
    
    console.log(`Canvas initialized for panel ${this.panelId} on ${this.deviceType}`);
  },

  calculateCanvasDimensions() {
    const container = this.el.querySelector('.canvas-container');
    const containerRect = container.getBoundingClientRect();
    
    const baseWidth = this.canvasData.width || 800;
    const baseHeight = this.canvasData.height || 600;
    
    switch (this.deviceType) {
      case 'mobile':
        // Full width, maintain aspect ratio
        const aspectRatio = baseHeight / baseWidth;
        const mobileWidth = Math.min(containerRect.width, window.innerWidth - 32);
        return {
          width: mobileWidth,
          height: mobileWidth * aspectRatio
        };
        
      case 'tablet':
        // Responsive sizing for tablet
        return {
          width: Math.min(baseWidth, containerRect.width * 0.8),
          height: Math.min(baseHeight, containerRect.height * 0.6)
        };
        
      case 'preview':
        // Small preview size
        return {
          width: Math.min(300, containerRect.width),
          height: Math.min(200, containerRect.height)
        };
        
      default:
        // Desktop - use actual dimensions
        return {
          width: baseWidth,
          height: baseHeight
        };
    }
  },

  configureCanvasForDevice() {
    if (this.deviceType === 'mobile') {
      // Mobile-specific optimizations
      this.canvas.freeDrawingBrush.width = 3;
      this.canvas.targetFindTolerance = 15; // Larger touch targets
      this.canvas.perPixelTargetFind = true;
      
      // Disable fabric.js built-in gestures to handle custom ones
      this.canvas.allowTouchScrolling = false;
      
    } else if (this.deviceType === 'tablet') {
      // Tablet optimizations
      this.canvas.freeDrawingBrush.width = 2;
      this.canvas.targetFindTolerance = 10;
      
    } else {
      // Desktop settings
      this.canvas.freeDrawingBrush.width = 1;
      this.canvas.targetFindTolerance = 5;
    }
  },

  setupEventListeners() {
    // Canvas drawing events
    this.canvas.on('path:created', (e) => this.handlePathCreated(e));
    this.canvas.on('object:added', (e) => this.handleObjectAdded(e));
    this.canvas.on('object:modified', (e) => this.handleObjectModified(e));
    this.canvas.on('object:removed', (e) => this.handleObjectRemoved(e));
    
    // Mouse/touch events for collaboration
    this.canvas.on('mouse:move', (e) => this.handleMouseMove(e));
    this.canvas.on('mouse:down', (e) => this.handleMouseDown(e));
    this.canvas.on('mouse:up', (e) => this.handleMouseUp(e));
    
    // Selection events
    this.canvas.on('selection:created', (e) => this.handleSelectionCreated(e));
    this.canvas.on('selection:updated', (e) => this.handleSelectionUpdated(e));
    this.canvas.on('selection:cleared', (e) => this.handleSelectionCleared(e));
    
    // Window resize
    window.addEventListener('resize', () => this.handleResize());
    
    // Context menu for desktop
    if (this.deviceType !== 'mobile') {
      this.canvas.on('mouse:down', (e) => this.handleContextMenu(e));
    }
  },

  setupMobileOptimizations() {
    if (this.deviceType !== 'mobile') return;
    
    const canvasElement = this.canvas.upperCanvasEl;
    
    // Touch event handling
    canvasElement.addEventListener('touchstart', (e) => this.handleTouchStart(e), { passive: false });
    canvasElement.addEventListener('touchmove', (e) => this.handleTouchMove(e), { passive: false });
    canvasElement.addEventListener('touchend', (e) => this.handleTouchEnd(e), { passive: false });
    
    // Prevent default touch behaviors
    canvasElement.addEventListener('touchstart', (e) => e.preventDefault());
    canvasElement.addEventListener('touchmove', (e) => e.preventDefault());
  },

  handleTouchStart(e) {
    this.touchStartTime = Date.now();
    this.touchStartPos = this.getTouchPosition(e.touches[0]);
    
    // Palm rejection: ignore touches with large contact area
    if (e.touches[0].radiusX > 20 || e.touches[0].radiusY > 20) {
      this.activatePalmRejection();
      e.preventDefault();
      return;
    }
    
    // Multi-touch gesture detection
    if (e.touches.length === 2) {
      this.handlePinchStart(e);
      e.preventDefault();
      return;
    }
    
    // Single touch for drawing
    if (e.touches.length === 1 && !this.isPalmRejectionActive) {
      this.startDrawing(this.touchStartPos);
    }
  },

  handleTouchMove(e) {
    if (this.isPalmRejectionActive) {
      e.preventDefault();
      return;
    }
    
    if (e.touches.length === 2) {
      this.handlePinchMove(e);
      e.preventDefault();
      return;
    }
    
    if (e.touches.length === 1 && this.isDrawing) {
      const currentPos = this.getTouchPosition(e.touches[0]);
      this.continueDraw(currentPos);
    }
  },

  handleTouchEnd(e) {
    // Deactivate palm rejection after a delay
    setTimeout(() => {
      this.isPalmRejectionActive = false;
      this.hidePalmRejectionIndicator();
    }, 100);
    
    if (e.touches.length === 0) {
      this.endDrawing();
    }
  },

  activatePalmRejection() {
    this.isPalmRejectionActive = true;
    this.showPalmRejectionIndicator();
  },

  showPalmRejectionIndicator() {
    const indicator = this.el.querySelector('#palm-rejection-indicator');
    if (indicator) {
      indicator.style.opacity = '1';
    }
  },

  hidePalmRejectionIndicator() {
    const indicator = this.el.querySelector('#palm-rejection-indicator');
    if (indicator) {
      indicator.style.opacity = '0';
    }
  },

  handlePinchStart(e) {
    this.initialPinchDistance = this.getPinchDistance(e.touches);
    this.initialZoom = this.canvas.getZoom();
  },

  handlePinchMove(e) {
    const currentDistance = this.getPinchDistance(e.touches);
    const scale = currentDistance / this.initialPinchDistance;
    const newZoom = Math.min(Math.max(this.initialZoom * scale, 0.1), 3.0);
    
    this.canvas.setZoom(newZoom);
    this.zoomLevel = newZoom;
    
    // Update zoom in component
    this.pushEvent('canvas_resized', {
      dimensions: {
        width: this.canvas.width,
        height: this.canvas.height,
        zoom: newZoom
      }
    });
  },

  getPinchDistance(touches) {
    const dx = touches[0].clientX - touches[1].clientX;
    const dy = touches[0].clientY - touches[1].clientY;
    return Math.sqrt(dx * dx + dy * dy);
  },

  getTouchPosition(touch) {
    const rect = this.canvas.upperCanvasEl.getBoundingClientRect();
    return {
      x: touch.clientX - rect.left,
      y: touch.clientY - rect.top
    };
  },

  startDrawing(position) {
    if (this.selectedTool === 'pen' || this.selectedTool === 'brush') {
      this.isDrawing = true;
      this.canvas.isDrawingMode = true;
    }
  },

  continueDraw(position) {
    // Drawing continues automatically with Fabric.js
  },

  endDrawing() {
    this.isDrawing = false;
  },

  loadCanvasData() {
    if (this.canvasData.objects && this.canvasData.objects.length > 0) {
      // Load objects from canvas data
      this.canvas.loadFromJSON(this.canvasData, () => {
        this.canvas.renderAll();
        console.log('Canvas data loaded');
      });
    }
  },

  updateDrawingTool() {
    // Reset canvas modes
    this.canvas.isDrawingMode = false;
    this.canvas.selection = false;
    
    switch (this.selectedTool) {
      case 'pen':
        this.canvas.isDrawingMode = true;
        this.canvas.freeDrawingBrush = new fabric.PencilBrush(this.canvas);
        this.canvas.freeDrawingBrush.width = this.deviceType === 'mobile' ? 3 : 2;
        this.canvas.freeDrawingBrush.color = '#000000';
        break;
        
      case 'brush':
        this.canvas.isDrawingMode = true;
        this.canvas.freeDrawingBrush = new fabric.CircleBrush(this.canvas);
        this.canvas.freeDrawingBrush.width = this.deviceType === 'mobile' ? 8 : 5;
        this.canvas.freeDrawingBrush.color = '#000000';
        break;
        
      case 'eraser':
        this.canvas.isDrawingMode = true;
        this.canvas.freeDrawingBrush = new fabric.EraserBrush(this.canvas);
        this.canvas.freeDrawingBrush.width = this.deviceType === 'mobile' ? 10 : 8;
        break;
        
      case 'select':
        this.canvas.selection = true;
        break;
        
      case 'text':
        this.setupTextTool();
        break;
        
      case 'rectangle':
        this.setupShapeTool('rectangle');
        break;
        
      case 'circle':
        this.setupShapeTool('circle');
        break;
        
      case 'line':
        this.setupShapeTool('line');
        break;
    }
  },

  setupTextTool() {
    this.canvas.on('mouse:down', (e) => {
      if (this.selectedTool === 'text') {
        const pointer = this.canvas.getPointer(e.e);
        const text = new fabric.IText('Click to edit', {
          left: pointer.x,
          top: pointer.y,
          fontSize: this.deviceType === 'mobile' ? 18 : 16,
          fill: '#000000',
          editable: true
        });
        
        this.canvas.add(text);
        this.canvas.setActiveObject(text);
        text.enterEditing();
      }
    });
  },

  setupShapeTool(shapeType) {
    let isDown = false;
    let origX, origY;
    let shape;
    
    this.canvas.on('mouse:down', (e) => {
      if (this.selectedTool === shapeType) {
        isDown = true;
        const pointer = this.canvas.getPointer(e.e);
        origX = pointer.x;
        origY = pointer.y;
        
        switch (shapeType) {
          case 'rectangle':
            shape = new fabric.Rect({
              left: origX,
              top: origY,
              width: 0,
              height: 0,
              fill: 'transparent',
              stroke: '#000000',
              strokeWidth: 2
            });
            break;
            
          case 'circle':
            shape = new fabric.Circle({
              left: origX,
              top: origY,
              radius: 0,
              fill: 'transparent',
              stroke: '#000000',
              strokeWidth: 2
            });
            break;
            
          case 'line':
            shape = new fabric.Line([origX, origY, origX, origY], {
              stroke: '#000000',
              strokeWidth: 2
            });
            break;
        }
        
        this.canvas.add(shape);
      }
    });
    
    this.canvas.on('mouse:move', (e) => {
      if (!isDown || this.selectedTool !== shapeType) return;
      
      const pointer = this.canvas.getPointer(e.e);
      
      switch (shapeType) {
        case 'rectangle':
          const width = Math.abs(pointer.x - origX);
          const height = Math.abs(pointer.y - origY);
          shape.set({
            left: Math.min(origX, pointer.x),
            top: Math.min(origY, pointer.y),
            width: width,
            height: height
          });
          break;
          
        case 'circle':
          const radius = Math.sqrt(Math.pow(pointer.x - origX, 2) + Math.pow(pointer.y - origY, 2)) / 2;
          shape.set({
            radius: radius,
            left: origX - radius,
            top: origY - radius
          });
          break;
          
        case 'line':
          shape.set({ x2: pointer.x, y2: pointer.y });
          break;
      }
      
      this.canvas.renderAll();
    });
    
    this.canvas.on('mouse:up', () => {
      isDown = false;
    });
  },

  // Canvas event handlers
  handlePathCreated(e) {
    const path = e.path;
    this.broadcastDrawingOperation({
      type: 'add_path',
      path: path.toObject()
    });
  },

  handleObjectAdded(e) {
    if (e.target && e.target.type !== 'path') {
      this.broadcastDrawingOperation({
        type: 'add_object',
        object: e.target.toObject()
      });
    }
  },

  handleObjectModified(e) {
    this.broadcastDrawingOperation({
      type: 'update_object',
      object_id: e.target.id,
      updates: e.target.toObject()
    });
  },

  handleObjectRemoved(e) {
    this.broadcastDrawingOperation({
      type: 'delete_object',
      object_id: e.target.id
    });
  },

  handleMouseMove(e) {
    if (this.collaborationEnabled) {
      const pointer = this.canvas.getPointer(e.e);
      this.pushEvent('cursor_moved', { x: pointer.x, y: pointer.y });
    }
  },

  handleMouseDown(e) {
    this.lastPointerEvent = e;
  },

  handleMouseUp(e) {
    // Handle tool-specific actions
  },

  handleContextMenu(e) {
    if (e.e.button === 2) { // Right click
      e.e.preventDefault();
      const contextMenu = this.el.querySelector(`#context-menu-${this.panelId}`);
      if (contextMenu) {
        contextMenu.style.left = e.e.clientX + 'px';
        contextMenu.style.top = e.e.clientY + 'px';
        contextMenu.classList.remove('hidden');
        
        // Hide menu on click outside
        setTimeout(() => {
          document.addEventListener('click', () => {
            contextMenu.classList.add('hidden');
          }, { once: true });
        }, 100);
      }
    }
  },

  handleSelectionCreated(e) {
    // Handle object selection
  },

  handleSelectionUpdated(e) {
    // Handle selection changes
  },

  handleSelectionCleared(e) {
    // Handle selection clearing
  },

  handleResize() {
    // Recalculate canvas dimensions on window resize
    const newDimensions = this.calculateCanvasDimensions();
    this.canvas.setDimensions(newDimensions);
    this.canvas.renderAll();
  },

  broadcastDrawingOperation(operation) {
    // Add unique ID and timestamp
    operation.id = this.generateOperationId();
    operation.timestamp = Date.now();
    
    // Send to LiveView component
    this.pushEvent('drawing_operation', { operation: operation });
  },

  generateOperationId() {
    return `${this.panelId}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  },

  // LiveView event handlers
  handleEvent(event, payload) {
    switch (event) {
      case 'update_tool':
        this.selectedTool = payload.tool;
        this.updateDrawingTool();
        break;
        
      case 'update_zoom':
        this.zoomLevel = payload.zoom;
        this.canvas.setZoom(this.zoomLevel);
        break;
        
      case 'apply_remote_operation':
        this.applyRemoteOperation(payload.operation);
        break;
        
      case 'copy_selected_object':
        this.copySelectedObject();
        break;
        
      case 'delete_selected_object':
        this.deleteSelectedObject();
        break;
        
      case 'bring_selected_to_front':
        this.bringSelectedToFront();
        break;
        
      case 'send_selected_to_back':
        this.sendSelectedToBack();
        break;
    }
  },

  applyRemoteOperation(operation) {
    switch (operation.type) {
      case 'add_object':
        fabric.util.enlivenObjects([operation.object], (objects) => {
          this.canvas.add(objects[0]);
        });
        break;
        
      case 'add_path':
        fabric.util.enlivenObjects([operation.path], (objects) => {
          this.canvas.add(objects[0]);
        });
        break;
        
      case 'update_object':
        const obj = this.canvas.getObjects().find(o => o.id === operation.object_id);
        if (obj) {
          obj.set(operation.updates);
          this.canvas.renderAll();
        }
        break;
        
      case 'delete_object':
        const objToDelete = this.canvas.getObjects().find(o => o.id === operation.object_id);
        if (objToDelete) {
          this.canvas.remove(objToDelete);
        }
        break;
    }
  },

  copySelectedObject() {
    const activeObject = this.canvas.getActiveObject();
    if (activeObject) {
      activeObject.clone((cloned) => {
        cloned.set({
          left: cloned.left + 10,
          top: cloned.top + 10,
          id: this.generateOperationId()
        });
        this.canvas.add(cloned);
        this.canvas.setActiveObject(cloned);
      });
    }
  },

  deleteSelectedObject() {
    const activeObject = this.canvas.getActiveObject();
    if (activeObject) {
      this.canvas.remove(activeObject);
    }
  },

  bringSelectedToFront() {
    const activeObject = this.canvas.getActiveObject();
    if (activeObject) {
      this.canvas.bringToFront(activeObject);
    }
  },

  sendSelectedToBack() {
    const activeObject = this.canvas.getActiveObject();
    if (activeObject) {
      this.canvas.sendToBack(activeObject);
    }
  },

  // Canvas data management
  getCanvasData() {
    return {
      version: '1.0',
      width: this.canvas.width,
      height: this.canvas.height,
      background: this.canvas.backgroundColor,
      objects: this.canvas.toObject().objects,
      viewport: {
        zoom: this.canvas.getZoom(),
        pan_x: this.canvas.viewportTransform[4],
        pan_y: this.canvas.viewportTransform[5]
      }
    };
  },

  saveCanvas() {
    const canvasData = this.getCanvasData();
    this.pushEvent('canvas_data_updated', { canvas_data: canvasData });
  },

  exportCanvas(format = 'png') {
    switch (format) {
      case 'png':
        return this.canvas.toDataURL('image/png');
      case 'jpg':
        return this.canvas.toDataURL('image/jpeg', 0.8);
      case 'svg':
        return this.canvas.toSVG();
      case 'json':
        return JSON.stringify(this.getCanvasData());
      default:
        return this.canvas.toDataURL();
    }
  },

  clearCanvas() {
    this.canvas.clear();
    this.canvas.backgroundColor = this.canvasData.background || '#ffffff';
    this.saveCanvas();
  },

  // Performance optimizations
  optimizeForDevice() {
    if (this.deviceType === 'mobile') {
      // Reduce canvas quality for mobile performance
      this.canvas.enableRetinaScaling = false;
      this.canvas.imageSmoothingEnabled = false;
      
      // Limit object count
      const objects = this.canvas.getObjects();
      if (objects.length > 100) {
        console.warn('Too many objects for mobile, some may be hidden');
      }
    }
  },

  debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
      const later = () => {
        clearTimeout(timeout);
        func(...args);
      };
      clearTimeout(timeout);
      timeout = setTimeout(later, wait);
    };
  },

  destroyed() {
    // Clean up canvas and event listeners
    if (this.canvas) {
      this.canvas.dispose();
    }
    
    window.removeEventListener('resize', this.handleResize);
    
    // Clear any pending operations
    this.operationQueue = [];
    this.remoteCursors.clear();
    
    console.log(`Canvas ${this.panelId} destroyed`);
  }
};

export default FabricCanvas;