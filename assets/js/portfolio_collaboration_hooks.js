// assets/js/portfolio_collaboration_hooks.js
// Real-time collaboration hooks for portfolio editing

export const PortfolioCollaboration = {
  mounted() {
    this.initializeCollaboration()
    this.setupOperationalTransform()
    this.setupPresenceIndicators()
    this.setupMobileOptimizations()
  },

  destroyed() {
    this.cleanupCollaboration()
  },

  // ============================================================================
  // COLLABORATION INITIALIZATION
  // ============================================================================

  initializeCollaboration() {
    this.collaborationState = {
      isCollaborating: false,
      operationVersion: 0,
      pendingOperations: [],
      collaborators: new Map(),
      sectionLocks: new Map(),
      cursorPositions: new Map()
    }

    // Listen for collaboration events
    this.handleEvent('collaboration_started', (data) => {
      this.startCollaboration(data)
    })

    this.handleEvent('collaborator_joined', (data) => {
      this.addCollaborator(data.user)
      this.showNotification(`${data.user.username} joined the collaboration`, 'info')
    })

    this.handleEvent('collaborator_left', (data) => {
      this.removeCollaborator(data.user_id)
      this.showNotification(`${data.username} left the collaboration`, 'info')
    })

    this.handleEvent('operation_received', (data) => {
      this.applyRemoteOperation(data.operation)
    })

    this.handleEvent('section_locked', (data) => {
      this.updateSectionLock(data.section_id, data.user, true)
    })

    this.handleEvent('section_unlocked', (data) => {
      this.updateSectionLock(data.section_id, data.user, false)
    })

    this.handleEvent('cursor_position_update', (data) => {
      this.updateCollaboratorCursor(data.user_id, data.section_id, data.position)
    })
  },

  startCollaboration(data) {
    this.collaborationState.isCollaborating = true
    this.collaborationState.operationVersion = data.version || 0
    
    // Setup real-time text editing
    this.setupRealTimeTextEditing()
    
    // Initialize collaborator list
    data.collaborators.forEach(collaborator => {
      this.addCollaborator(collaborator)
    })

    // Show collaboration UI
    this.showCollaborationInterface()
    
    console.log('✅ Portfolio collaboration started')
  },

  // ============================================================================
  // OPERATIONAL TRANSFORM IMPLEMENTATION
  // ============================================================================

  setupOperationalTransform() {
    // Listen for text changes in editable areas
    this.el.addEventListener('input', (e) => {
      if (this.collaborationState.isCollaborating && this.isEditableElement(e.target)) {
        this.handleTextChange(e)
      }
    })

    // Listen for selection changes
    document.addEventListener('selectionchange', () => {
      if (this.collaborationState.isCollaborating) {
        this.handleSelectionChange()
      }
    })
  },

  handleTextChange(event) {
    const element = event.target
    const sectionId = this.getSectionId(element)
    
    if (!sectionId) return

    // Create operation from change
    const operation = this.createOperationFromChange(element, event)
    
    if (operation) {
      // Apply locally
      this.applyLocalOperation(operation)
      
      // Send to server
      this.pushEvent('section_content_change', {
        section_id: sectionId,
        content: element.value || element.textContent,
        operation: operation
      })
    }
  },

  createOperationFromChange(element, event) {
    // Simple operation creation - in production use proper diff algorithms
    const currentContent = element.value || element.textContent
    const previousContent = element.dataset.previousContent || ''
    
    // Store current content for next comparison
    element.dataset.previousContent = currentContent

    if (currentContent === previousContent) return null

    // Determine operation type
    if (currentContent.length > previousContent.length) {
      // Insert operation
      const insertPos = this.findInsertPosition(previousContent, currentContent)
      const insertText = currentContent.slice(insertPos, insertPos + (currentContent.length - previousContent.length))
      
      return {
        type: 'insert',
        position: insertPos,
        content: insertText,
        length: insertText.length,
        timestamp: Date.now()
      }
    } else if (currentContent.length < previousContent.length) {
      // Delete operation
      const deletePos = this.findDeletePosition(previousContent, currentContent)
      const deleteLength = previousContent.length - currentContent.length
      
      return {
        type: 'delete',
        position: deletePos,
        length: deleteLength,
        timestamp: Date.now()
      }
    } else {
      // Replace operation
      return {
        type: 'replace',
        position: 0,
        content: currentContent,
        length: currentContent.length,
        timestamp: Date.now()
      }
    }
  },

  applyLocalOperation(operation) {
    // Add to pending operations
    this.collaborationState.pendingOperations.push(operation)
    this.collaborationState.operationVersion++
    
    // Show visual feedback
    this.showLocalEditIndicator(operation)
  },

  applyRemoteOperation(operation) {
    const sectionElement = this.getSectionElement(operation.section_id)
    if (!sectionElement) return

    // Transform operation against pending operations
    const transformedOp = this.transformOperation(operation, this.collaborationState.pendingOperations)
    
    // Apply the transformed operation
    this.applyOperationToElement(sectionElement, transformedOp)
    
    // Show visual feedback for remote edit
    this.showRemoteEditIndicator(operation.user_id, operation.section_id)
    
    // Update operation version
    this.collaborationState.operationVersion = Math.max(
      this.collaborationState.operationVersion, 
      operation.version || 0
    )
  },

  transformOperation(operation, pendingOps) {
    // Simple operational transform - in production use proper OT library
    let transformedOp = { ...operation }
    
    pendingOps.forEach(pendingOp => {
      transformedOp = this.transformTwoOperations(transformedOp, pendingOp)
    })
    
    return transformedOp
  },

  transformTwoOperations(op1, op2) {
    if (op1.type === 'insert' && op2.type === 'insert') {
      if (op1.position <= op2.position) {
        return op1
      } else {
        return { ...op1, position: op1.position + op2.length }
      }
    } else if (op1.type === 'delete' && op2.type === 'insert') {
      if (op1.position <= op2.position) {
        return op1
      } else {
        return { ...op1, position: op1.position + op2.length }
      }
    } else if (op1.type === 'insert' && op2.type === 'delete') {
      if (op1.position <= op2.position) {
        return op1
      } else {
        return { ...op1, position: Math.max(0, op1.position - op2.length) }
      }
    }
    
    return op1
  },

  applyOperationToElement(element, operation) {
    const currentContent = element.value || element.textContent
    let newContent = currentContent
    
    switch (operation.type) {
      case 'insert':
        newContent = currentContent.slice(0, operation.position) + 
                   operation.content + 
                   currentContent.slice(operation.position)
        break
        
      case 'delete':
        newContent = currentContent.slice(0, operation.position) + 
                   currentContent.slice(operation.position + operation.length)
        break
        
      case 'replace':
        newContent = operation.content
        break
    }
    
    // Apply the change
    if (element.value !== undefined) {
      element.value = newContent
    } else {
      element.textContent = newContent
    }
    
    // Update stored content
    element.dataset.previousContent = newContent
    
    // Trigger change event
    element.dispatchEvent(new Event('input', { bubbles: true }))
  },

  // ============================================================================
  // PRESENCE AND CURSOR TRACKING
  // ============================================================================

  setupPresenceIndicators() {
    // Create presence indicator container
    this.presenceContainer = this.createPresenceContainer()
    
    // Setup cursor tracking
    this.setupCursorTracking()
  },

  createPresenceContainer() {
    const container = document.createElement('div')
    container.className = 'collaboration-presence-indicators fixed top-4 right-4 z-50 space-y-2'
    document.body.appendChild(container)
    return container
  },

  addCollaborator(user) {
    this.collaborationState.collaborators.set(user.id, user)
    this.updatePresenceIndicators()
  },

  removeCollaborator(userId) {
    this.collaborationState.collaborators.delete(userId)
    this.removeCursorIndicator(userId)
    this.updatePresenceIndicators()
  },

  updatePresenceIndicators() {
    if (!this.presenceContainer) return
    
    this.presenceContainer.innerHTML = ''
    
    this.collaborationState.collaborators.forEach(user => {
      const indicator = this.createPresenceIndicator(user)
      this.presenceContainer.appendChild(indicator)
    })
  },

  createPresenceIndicator(user) {
    const indicator = document.createElement('div')
    indicator.className = 'flex items-center space-x-2 bg-white shadow-lg rounded-lg px-3 py-2 border border-gray-200'
    indicator.innerHTML = `
      <img src="${user.avatar_url || '/images/default-avatar.png'}" 
           alt="${user.username}" 
           class="w-6 h-6 rounded-full">
      <span class="text-sm font-medium text-gray-900">${user.username}</span>
      <div class="w-2 h-2 bg-green-400 rounded-full animate-pulse"></div>
    `
    return indicator
  },

  setupCursorTracking() {
    // Track cursor position in text areas
    this.el.addEventListener('selectionchange', () => {
      this.updateCursorPosition()
    }, true)
    
    this.el.addEventListener('click', () => {
      this.updateCursorPosition()
    })
  },

  updateCursorPosition() {
    const selection = window.getSelection()
    if (selection.rangeCount === 0) return
    
    const range = selection.getRangeAt(0)
    const element = range.commonAncestorContainer
    const sectionId = this.getSectionId(element.nodeType === Node.TEXT_NODE ? element.parentElement : element)
    
    if (sectionId) {
      const position = range.startOffset
      
      // Debounce cursor updates
      clearTimeout(this.cursorUpdateTimeout)
      this.cursorUpdateTimeout = setTimeout(() => {
        this.pushEvent('cursor_position_update', {
          section_id: sectionId,
          position: position
        })
      }, 100)
    }
  },

  updateCollaboratorCursor(userId, sectionId, position) {
    this.collaborationState.cursorPositions.set(userId, { sectionId, position })
    this.renderCursorIndicator(userId, sectionId, position)
  },

  renderCursorIndicator(userId, sectionId, position) {
    const user = this.collaborationState.collaborators.get(userId)
    if (!user) return
    
    const sectionElement = this.getSectionElement(sectionId)
    if (!sectionElement) return
    
    // Remove existing cursor
    this.removeCursorIndicator(userId)
    
    // Create cursor indicator
    const cursor = document.createElement('div')
    cursor.className = `collaboration-cursor collaboration-cursor-${userId} absolute w-0.5 h-5 bg-blue-500 pointer-events-none z-10`
    cursor.dataset.userId = userId
    
    // Position cursor
    this.positionCursor(cursor, sectionElement, position)
    
    // Add user label
    const label = document.createElement('div')
    label.className = 'absolute -top-6 left-0 bg-blue-500 text-white text-xs px-2 py-1 rounded whitespace-nowrap'
    label.textContent = user.username
    cursor.appendChild(label)
    
    sectionElement.style.position = 'relative'
    sectionElement.appendChild(cursor)
  },

  positionCursor(cursor, element, position) {
    // Simple positioning - in production use proper text measurement
    const text = element.value || element.textContent || ''
    const lines = text.substring(0, position).split('\n')
    const lineNumber = lines.length - 1
    const columnNumber = lines[lines.length - 1].length
    
    // Estimate position (this is simplified)
    const lineHeight = 20 // Approximate line height
    const charWidth = 8   // Approximate character width
    
    cursor.style.top = `${lineNumber * lineHeight}px`
    cursor.style.left = `${columnNumber * charWidth}px`
  },

  removeCursorIndicator(userId) {
    const existingCursor = document.querySelector(`.collaboration-cursor-${userId}`)
    if (existingCursor) {
      existingCursor.remove()
    }
  },

  // ============================================================================
  // MOBILE OPTIMIZATIONS
  // ============================================================================

  setupMobileOptimizations() {
    if (this.isMobile()) {
      this.setupMobileCollaboration()
    }
  },

  setupMobileCollaboration() {
    // Setup touch-friendly collaboration controls
    this.setupTouchGestures()
    this.setupVoiceInput()
    this.optimizeForMobile()
  },

  setupTouchGestures() {
    let startX, startY
    
    this.el.addEventListener('touchstart', (e) => {
      startX = e.touches[0].clientX
      startY = e.touches[0].clientY
    })
    
    this.el.addEventListener('touchend', (e) => {
      if (!startX || !startY) return
      
      const endX = e.changedTouches[0].clientX
      const endY = e.changedTouches[0].clientY
      
      const deltaX = endX - startX
      const deltaY = endY - startY
      
      // Detect gestures
      if (Math.abs(deltaX) > Math.abs(deltaY) && Math.abs(deltaX) > 50) {
        if (deltaX > 0) {
          this.handleGesture('swipe_right', e.target)
        } else {
          this.handleGesture('swipe_left', e.target)
        }
      }
      
      startX = startY = null
    })
    
    // Double tap detection
    let lastTap = 0
    this.el.addEventListener('touchend', (e) => {
      const currentTime = Date.now()
      const tapLength = currentTime - lastTap
      
      if (tapLength < 500 && tapLength > 0) {
        this.handleGesture('double_tap', e.target)
      }
      
      lastTap = currentTime
    })
  },

  handleGesture(gestureType, target) {
    const sectionId = this.getSectionId(target)
    if (!sectionId) return
    
    this.pushEvent('mobile_gesture_edit', {
      section_id: sectionId,
      gesture: {
        type: gestureType,
        position: this.getCursorPosition(target)
      }
    })
    
    // Show gesture feedback
    this.showGestureFeedback(gestureType, target)
  },

  setupVoiceInput() {
    if ('webkitSpeechRecognition' in window || 'SpeechRecognition' in window) {
      this.speechRecognition = new (window.SpeechRecognition || window.webkitSpeechRecognition)()
      this.speechRecognition.continuous = true
      this.speechRecognition.interimResults = true
      
      this.speechRecognition.onresult = (event) => {
        this.handleVoiceResult(event)
      }
      
      this.speechRecognition.onerror = (event) => {
        console.error('Speech recognition error:', event.error)
      }
    }
  },

  startVoiceInput(sectionId) {
    if (this.speechRecognition) {
      this.currentVoiceSectionId = sectionId
      this.speechRecognition.start()
      this.showVoiceInputIndicator(true)
    }
  },

  stopVoiceInput() {
    if (this.speechRecognition) {
      this.speechRecognition.stop()
      this.showVoiceInputIndicator(false)
    }
  },

  handleVoiceResult(event) {
    let transcript = ''
    
    for (let i = event.resultIndex; i < event.results.length; i++) {
      if (event.results[i].isFinal) {
        transcript += event.results[i][0].transcript
      }
    }
    
    if (transcript && this.currentVoiceSectionId) {
      this.pushEvent('mobile_voice_edit', {
        section_id: this.currentVoiceSectionId,
        voice_content: transcript
      })
    }
  },

  optimizeForMobile() {
    // Add mobile-specific CSS classes
    this.el.classList.add('mobile-collaboration-active')
    
    // Adjust viewport for better mobile experience
    const viewport = document.querySelector('meta[name="viewport"]')
    if (viewport) {
      viewport.content = 'width=device-width, initial-scale=1, user-scalable=no'
    }
  },

  // ============================================================================
  // VISUAL FEEDBACK AND NOTIFICATIONS
  // ============================================================================

  showLocalEditIndicator(operation) {
    const sectionElement = this.getSectionElement(operation.section_id)
    if (!sectionElement) return
    
    // Add visual indicator for local edit
    sectionElement.classList.add('local-edit-active')
    setTimeout(() => {
      sectionElement.classList.remove('local-edit-active')
    }, 500)
  },

  showRemoteEditIndicator(userId, sectionId) {
    const sectionElement = this.getSectionElement(sectionId)
    const user = this.collaborationState.collaborators.get(userId)
    
    if (!sectionElement || !user) return
    
    // Show remote edit indicator
    sectionElement.classList.add('remote-edit-active')
    
    // Show user indicator
    this.showTemporaryUserIndicator(sectionElement, user)
    
    setTimeout(() => {
      sectionElement.classList.remove('remote-edit-active')
    }, 1000)
  },

  showTemporaryUserIndicator(element, user) {
    const indicator = document.createElement('div')
    indicator.className = 'absolute top-0 right-0 bg-blue-500 text-white text-xs px-2 py-1 rounded-bl-lg z-20'
    indicator.textContent = `${user.username} editing`
    
    element.style.position = 'relative'
    element.appendChild(indicator)
    
    setTimeout(() => {
      indicator.remove()
    }, 2000)
  },

  updateSectionLock(sectionId, user, isLocked) {
    const sectionElement = this.getSectionElement(sectionId)
    if (!sectionElement) return
    
    if (isLocked) {
      this.collaborationState.sectionLocks.set(sectionId, user)
      sectionElement.classList.add('section-locked')
      this.showSectionLockIndicator(sectionElement, user)
    } else {
      this.collaborationState.sectionLocks.delete(sectionId)
      sectionElement.classList.remove('section-locked')
      this.removeSectionLockIndicator(sectionElement)
    }
  },

  showSectionLockIndicator(element, user) {
    const lockIndicator = document.createElement('div')
    lockIndicator.className = 'section-lock-indicator absolute top-2 right-2 bg-red-500 text-white text-xs px-2 py-1 rounded flex items-center space-x-1 z-20'
    lockIndicator.innerHTML = `
      <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
        <path fill-rule="evenodd" d="M5 9V7a5 5 0 0110 0v2a2 2 0 012 2v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5a2 2 0 012-2zm8-2v2H7V7a3 3 0 016 0z" clip-rule="evenodd"/>
      </svg>
      <span>${user.username}</span>
    `
    
    element.style.position = 'relative'
    element.appendChild(lockIndicator)
  },

  removeSectionLockIndicator(element) {
    const indicator = element.querySelector('.section-lock-indicator')
    if (indicator) {
      indicator.remove()
    }
  },

  showGestureFeedback(gestureType, target) {
    const feedback = document.createElement('div')
    feedback.className = 'gesture-feedback absolute bg-blue-500 text-white text-xs px-2 py-1 rounded z-30'
    feedback.textContent = this.getGestureDisplayName(gestureType)
    
    // Position near target
    const rect = target.getBoundingClientRect()
    feedback.style.left = `${rect.left}px`
    feedback.style.top = `${rect.top - 30}px`
    feedback.style.position = 'fixed'
    
    document.body.appendChild(feedback)
    
    setTimeout(() => {
      feedback.remove()
    }, 1000)
  },

  showVoiceInputIndicator(active) {
    let indicator = document.querySelector('.voice-input-indicator')
    
    if (active) {
      if (!indicator) {
        indicator = document.createElement('div')
        indicator.className = 'voice-input-indicator fixed bottom-4 left-4 bg-red-500 text-white px-3 py-2 rounded-lg flex items-center space-x-2 z-50'
        indicator.innerHTML = `
          <svg class="w-4 h-4 animate-pulse" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M7 4a3 3 0 016 0v4a3 3 0 11-6 0V4zm4 10.93A7.001 7.001 0 0017 8a1 1 0 10-2 0A5 5 0 015 8a1 1 0 00-2 0 7.001 7.001 0 006 6.93V17H6a1 1 0 100 2h8a1 1 0 100-2h-3v-2.07z" clip-rule="evenodd"/>
          </svg>
          <span>Listening...</span>
        `
        document.body.appendChild(indicator)
      }
    } else {
      if (indicator) {
        indicator.remove()
      }
    }
  },

  showNotification(message, type = 'info') {
    const notification = document.createElement('div')
    notification.className = `collaboration-notification fixed top-4 left-1/2 transform -translate-x-1/2 px-4 py-2 rounded-lg text-white z-50 ${this.getNotificationClass(type)}`
    notification.textContent = message
    
    document.body.appendChild(notification)
    
    setTimeout(() => {
      notification.remove()
    }, 3000)
  },

  showCollaborationInterface() {
    // Add collaboration-specific UI elements
    this.el.classList.add('collaboration-active')
    
    // Show collaboration toolbar if it exists
    const toolbar = document.querySelector('.collaboration-toolbar')
    if (toolbar) {
      toolbar.style.display = 'flex'
    }
  },

  // ============================================================================
  // UTILITY FUNCTIONS
  // ============================================================================

  getSectionId(element) {
    // Find the section ID from the element or its parents
    let current = element
    while (current && current !== this.el) {
      if (current.dataset.sectionId) {
        return current.dataset.sectionId
      }
      current = current.parentElement
    }
    return null
  },

  getSectionElement(sectionId) {
    return this.el.querySelector(`[data-section-id="${sectionId}"]`)
  },

  isEditableElement(element) {
    return element.tagName === 'TEXTAREA' || 
           element.tagName === 'INPUT' || 
           element.contentEditable === 'true'
  },

  getCursorPosition(element) {
    if (element.selectionStart !== undefined) {
      return element.selectionStart
    }
    
    const selection = window.getSelection()
    if (selection.rangeCount > 0) {
      return selection.getRangeAt(0).startOffset
    }
    
    return 0
  },

  findInsertPosition(oldText, newText) {
    // Simple diff to find insert position
    for (let i = 0; i < Math.min(oldText.length, newText.length); i++) {
      if (oldText[i] !== newText[i]) {
        return i
      }
    }
    return oldText.length
  },

  findDeletePosition(oldText, newText) {
    // Simple diff to find delete position
    for (let i = 0; i < Math.min(oldText.length, newText.length); i++) {
      if (oldText[i] !== newText[i]) {
        return i
      }
    }
    return newText.length
  },

  isMobile() {
    return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent)
  },

  getGestureDisplayName(gestureType) {
    const names = {
      'swipe_right': 'Indent',
      'swipe_left': 'Unindent',
      'double_tap': 'Bold'
    }
    return names[gestureType] || gestureType
  },

  getNotificationClass(type) {
    const classes = {
      'info': 'bg-blue-500',
      'success': 'bg-green-500',
      'warning': 'bg-yellow-500',
      'error': 'bg-red-500'
    }
    return classes[type] || classes.info
  },

  cleanupCollaboration() {
    // Remove event listeners
    if (this.cursorUpdateTimeout) {
      clearTimeout(this.cursorUpdateTimeout)
    }
    
    // Remove presence indicators
    if (this.presenceContainer) {
      this.presenceContainer.remove()
    }
    
    // Remove cursor indicators
    document.querySelectorAll('.collaboration-cursor').forEach(cursor => {
      cursor.remove()
    })
    
    // Stop voice recognition
    if (this.speechRecognition) {
      this.speechRecognition.stop()
    }
    
    // Clean up classes
    this.el.classList.remove('collaboration-active', 'mobile-collaboration-active')
  }
}

// Export for use in main hooks file
export default PortfolioCollaboration