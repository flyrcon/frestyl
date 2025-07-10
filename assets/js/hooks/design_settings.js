// assets/js/hooks/design_settings.js
export const DesignSettings = {
  mounted() {
    this.initializeLivePreview()
    this.initializeColorPickers()
    this.initializePreviewWindow()
    
    // Handle live preview updates
    this.handleEvent('update_preview_css', ({ css }) => {
      this.updatePreviewCSS(css)
    })
    
    // Handle preview window opening
    this.handleEvent('open_preview_window', ({ url }) => {
      this.openPreviewWindow(url)
    })
    
    // Handle upgrade modal
    this.handleEvent('show_upgrade_modal', () => {
      this.showUpgradeModal()
    })
  },

  destroyed() {
    this.cleanupPreview()
  },

  // ============================================================================
  // LIVE PREVIEW MANAGEMENT
  // ============================================================================

  initializeLivePreview() {
    // Create or find preview container
    this.previewContainer = document.getElementById('live-preview-container')
    
    if (!this.previewContainer) {
      this.createPreviewContainer()
    }
    
    // Initialize CSS injection
    this.previewStyleElement = this.getOrCreateStyleElement()
  },

  createPreviewContainer() {
    // Only create if we're in editor mode and there's space
    const editorContainer = document.querySelector('.portfolio-editor')
    if (!editorContainer) return
    
    this.previewContainer = document.createElement('div')
    this.previewContainer.id = 'live-preview-container'
    this.previewContainer.className = 'fixed top-20 right-4 w-80 h-96 bg-white border border-gray-300 rounded-lg shadow-lg z-50 hidden'
    this.previewContainer.innerHTML = `
      <div class="flex items-center justify-between p-3 border-b border-gray-200">
        <h4 class="font-medium text-gray-900">Live Preview</h4>
        <div class="flex items-center space-x-2">
          <button id="preview-toggle-mobile" class="p-1 text-gray-500 hover:text-gray-700">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 18h.01M8 21h8a2 2 0 002-2V5a2 2 0 00-2-2H8a2 2 0 00-2 2v14a2 2 0 002 2z"/>
            </svg>
          </button>
          <button id="preview-close" class="p-1 text-gray-500 hover:text-gray-700">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>
      </div>
      <div class="flex-1 overflow-hidden">
        <iframe id="preview-iframe" class="w-full h-full border-0" src="about:blank"></iframe>
      </div>
    `
    
    document.body.appendChild(this.previewContainer)
    
    // Setup event listeners
    this.setupPreviewControls()
  },

  setupPreviewControls() {
    const closeBtn = this.previewContainer.querySelector('#preview-close')
    const mobileToggle = this.previewContainer.querySelector('#preview-toggle-mobile')
    
    closeBtn?.addEventListener('click', () => {
      this.hidePreview()
    })
    
    mobileToggle?.addEventListener('click', () => {
      this.toggleMobilePreview()
    })
  },

  getOrCreateStyleElement() {
    let styleElement = document.getElementById('design-preview-styles')
    
    if (!styleElement) {
      styleElement = document.createElement('style')
      styleElement.id = 'design-preview-styles'
      document.head.appendChild(styleElement)
    }
    
    return styleElement
  },

  updatePreviewCSS(css) {
    // Update the live preview styles
    if (this.previewStyleElement) {
      this.previewStyleElement.textContent = css
    }
    
    // Update preview iframe if it exists
    const previewIframe = document.getElementById('preview-iframe')
    if (previewIframe && previewIframe.contentDocument) {
      this.updateIframeCSS(previewIframe, css)
    }
    
    // Show visual feedback
    this.showUpdateFeedback()
  },

  updateIframeCSS(iframe, css) {
    try {
      const iframeDoc = iframe.contentDocument || iframe.contentWindow.document
      let styleElement = iframeDoc.getElementById('live-preview-styles')
      
      if (!styleElement) {
        styleElement = iframeDoc.createElement('style')
        styleElement.id = 'live-preview-styles'
        iframeDoc.head.appendChild(styleElement)
      }
      
      styleElement.textContent = css
    } catch (error) {
      console.warn('Could not update iframe CSS:', error)
    }
  },

  showUpdateFeedback() {
    // Create a subtle visual indicator that changes were applied
    const indicator = document.createElement('div')
    indicator.className = 'fixed top-4 right-4 bg-green-500 text-white px-3 py-2 rounded-lg text-sm z-50'
    indicator.textContent = 'Design Updated'
    
    document.body.appendChild(indicator)
    
    // Animate in
    indicator.style.transform = 'translateY(-20px)'
    indicator.style.opacity = '0'
    
    requestAnimationFrame(() => {
      indicator.style.transition = 'all 0.3s ease'
      indicator.style.transform = 'translateY(0)'
      indicator.style.opacity = '1'
      
      setTimeout(() => {
        indicator.style.transform = 'translateY(-20px)'
        indicator.style.opacity = '0'
        
        setTimeout(() => {
          document.body.removeChild(indicator)
        }, 300)
      }, 2000)
    })
  },

  // ============================================================================
  // COLOR PICKER ENHANCEMENTS
  // ============================================================================

  initializeColorPickers() {
    const colorInputs = this.el.querySelectorAll('input[type="color"]')
    
    colorInputs.forEach(input => {
      this.enhanceColorPicker(input)
    })
  },

  enhanceColorPicker(input) {
    // Add live preview on color change
    input.addEventListener('input', (e) => {
      this.previewColorChange(e.target)
    })
    
    // Add color validation for text inputs
    const textInput = input.parentElement.querySelector('input[type="text"]')
    if (textInput) {
      textInput.addEventListener('input', (e) => {
        this.validateColorInput(e.target, input)
      })
    }
  },

  previewColorChange(colorInput) {
    const colorKey = colorInput.getAttribute('phx-value-color')
    const colorValue = colorInput.value
    
    // Apply temporary CSS for instant preview
    this.applyTemporaryColorChange(colorKey, colorValue)
    
    // Sync with text input
    const textInput = colorInput.parentElement.querySelector('input[type="text"]')
    if (textInput) {
      textInput.value = colorValue
    }
  },

  validateColorInput(textInput, colorInput) {
    const value = textInput.value
    
    if (this.isValidHexColor(value)) {
      colorInput.value = value
      textInput.classList.remove('border-red-500')
      textInput.classList.add('border-green-500')
      
      // Apply preview
      const colorKey = colorInput.getAttribute('phx-value-color')
      this.applyTemporaryColorChange(colorKey, value)
    } else {
      textInput.classList.remove('border-green-500')
      textInput.classList.add('border-red-500')
    }
  },

  applyTemporaryColorChange(colorKey, colorValue) {
    const cssVar = `--${colorKey.replace('_', '-')}`
    document.documentElement.style.setProperty(cssVar, colorValue)
  },

  isValidHexColor(color) {
    return /^#[0-9A-Fa-f]{6}$/.test(color)
  },

  // ============================================================================
  // PREVIEW WINDOW MANAGEMENT
  // ============================================================================

  initializePreviewWindow() {
    this.previewWindow = null
    this.previewWindowCheckInterval = null
  },

  openPreviewWindow(url) {
    // Close existing preview window if open
    if (this.previewWindow && !this.previewWindow.closed) {
      this.previewWindow.close()
    }
    
    // Open new preview window
    const windowFeatures = 'width=1200,height=800,scrollbars=yes,resizable=yes,location=yes'
    this.previewWindow = window.open(url, 'portfolio_preview', windowFeatures)
    
    if (this.previewWindow) {
      this.previewWindow.focus()
      this.setupPreviewWindowCommunication()
    } else {
      this.showPreviewBlockedMessage()
    }
  },

  setupPreviewWindowCommunication() {
    // Check if window is still open periodically
    this.previewWindowCheckInterval = setInterval(() => {
      if (this.previewWindow.closed) {
        clearInterval(this.previewWindowCheckInterval)
        this.previewWindow = null
      }
    }, 1000)
    
    // Send current CSS to preview window when it loads
    this.previewWindow.addEventListener('load', () => {
      this.syncPreviewWindowCSS()
    })
  },

  syncPreviewWindowCSS() {
    if (this.previewWindow && this.previewStyleElement) {
      try {
        const css = this.previewStyleElement.textContent
        this.previewWindow.postMessage({
          type: 'UPDATE_CSS',
          css: css
        }, '*')
      } catch (error) {
        console.warn('Could not sync CSS with preview window:', error)
      }
    }
  },

  showPreviewBlockedMessage() {
    const message = document.createElement('div')
    message.className = 'fixed top-4 right-4 bg-yellow-500 text-white px-4 py-3 rounded-lg text-sm z-50 max-w-sm'
    message.innerHTML = `
      <div class="flex items-start space-x-3">
        <svg class="w-5 h-5 mt-0.5" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd"/>
        </svg>
        <div>
          <p class="font-medium">Popup Blocked</p>
          <p class="text-xs mt-1">Please allow popups to use the preview feature</p>
        </div>
      </div>
    `
    
    document.body.appendChild(message)
    
    setTimeout(() => {
      if (document.body.contains(message)) {
        document.body.removeChild(message)
      }
    }, 5000)
  },

  // ============================================================================
  // MOBILE PREVIEW TOGGLE
  // ============================================================================

  toggleMobilePreview() {
    const iframe = document.getElementById('preview-iframe')
    if (!iframe) return
    
    const container = iframe.parentElement
    const isMobile = container.classList.contains('mobile-preview')
    
    if (isMobile) {
      // Switch to desktop
      container.classList.remove('mobile-preview')
      iframe.style.width = '100%'
      iframe.style.height = '100%'
    } else {
      // Switch to mobile
      container.classList.add('mobile-preview')
      iframe.style.width = '375px'
      iframe.style.height = '667px'
      iframe.style.margin = '0 auto'
    }
  },

  hidePreview() {
    if (this.previewContainer) {
      this.previewContainer.classList.add('hidden')
    }
  },

  showPreview() {
    if (this.previewContainer) {
      this.previewContainer.classList.remove('hidden')
    }
  },

  // ============================================================================
  // UPGRADE MODAL
  // ============================================================================

  showUpgradeModal() {
    // Create upgrade modal
    const modal = document.createElement('div')
    modal.id = 'upgrade-modal'
    modal.className = 'fixed inset-0 z-50 overflow-y-auto'
    modal.innerHTML = `
      <div class="flex items-center justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
        <!-- Background overlay -->
        <div class="fixed inset-0 bg-black bg-opacity-50 transition-opacity" onclick="this.parentElement.parentElement.remove()"></div>
        
        <!-- Modal content -->
        <div class="inline-block align-bottom bg-white rounded-lg px-4 pt-5 pb-4 text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full sm:p-6">
          <div class="sm:flex sm:items-start">
            <div class="mx-auto flex-shrink-0 flex items-center justify-center h-12 w-12 rounded-full bg-purple-100 sm:mx-0 sm:h-10 sm:w-10">
              <svg class="h-6 w-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
              </svg>
            </div>
            <div class="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left">
              <h3 class="text-lg leading-6 font-medium text-gray-900">
                Unlock Premium Design Features
              </h3>
              <div class="mt-2">
                <p class="text-sm text-gray-500">
                  Get access to advanced styling options including gradient backgrounds, custom animations, and more design controls.
                </p>
                <div class="mt-4 space-y-2">
                  <div class="flex items-center text-sm text-gray-600">
                    <svg class="w-4 h-4 mr-2 text-green-500" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
                    </svg>
                    Gradient backgrounds
                  </div>
                  <div class="flex items-center text-sm text-gray-600">
                    <svg class="w-4 h-4 mr-2 text-green-500" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
                    </svg>
                    Advanced animations
                  </div>
                  <div class="flex items-center text-sm text-gray-600">
                    <svg class="w-4 h-4 mr-2 text-green-500" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
                    </svg>
                    Custom CSS injection
                  </div>
                  <div class="flex items-center text-sm text-gray-600">
                    <svg class="w-4 h-4 mr-2 text-green-500" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7-293a1 1 0 011.414 0z" clip-rule="evenodd"/>
                    </svg>
                    Priority support
                  </div>
                </div>
              </div>
            </div>
          </div>
          <div class="mt-5 sm:mt-4 sm:flex sm:flex-row-reverse">
            <button type="button" onclick="window.location.href='/subscription'" class="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-purple-600 text-base font-medium text-white hover:bg-purple-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-purple-500 sm:ml-3 sm:w-auto sm:text-sm">
              Upgrade Now
            </button>
            <button type="button" onclick="this.closest('#upgrade-modal').remove()" class="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:text-gray-500 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-purple-500 sm:mt-0 sm:w-auto sm:text-sm">
              Maybe Later
            </button>
          </div>
        </div>
      </div>
    `
    
    document.body.appendChild(modal)
    
    // Focus management
    modal.querySelector('button[onclick*="subscription"]')?.focus()
  },

  // ============================================================================
  // THEME TEMPLATE INTERACTIONS
  // ============================================================================

  initializeThemeTemplates() {
    const themeCards = this.el.querySelectorAll('[phx-click="select_theme_template"]')
    
    themeCards.forEach(card => {
      this.enhanceThemeCard(card)
    })
  },

  enhanceThemeCard(card) {
    // Add hover effects
    card.addEventListener('mouseenter', () => {
      this.previewTheme(card)
    })
    
    card.addEventListener('mouseleave', () => {
      this.clearThemePreview()
    })
  },

  previewTheme(themeCard) {
    const themeKey = themeCard.getAttribute('phx-value-theme')
    
    // Apply theme preview temporarily
    this.applyThemePreview(themeKey)
  },

  applyThemePreview(themeKey) {
    // This would apply temporary theme styles
    // Implementation depends on your theme system
    console.log('Previewing theme:', themeKey)
  },

  clearThemePreview() {
    // Clear temporary theme styles
    console.log('Clearing theme preview')
  },

  // ============================================================================
  // LAYOUT TYPE INTERACTIONS
  // ============================================================================

  initializeLayoutTypes() {
    const layoutCards = this.el.querySelectorAll('[phx-click="select_public_layout"]')
    
    layoutCards.forEach(card => {
      this.enhanceLayoutCard(card)
    })
  },

  enhanceLayoutCard(card) {
    // Add interactive preview
    card.addEventListener('mouseenter', () => {
      this.animateLayoutPreview(card)
    })
  },

  animateLayoutPreview(layoutCard) {
    const previewElement = layoutCard.querySelector('.h-16')
    if (previewElement) {
      previewElement.style.transform = 'scale(1.05)'
      previewElement.style.transition = 'transform 0.2s ease'
      
      setTimeout(() => {
        previewElement.style.transform = 'scale(1)'
      }, 200)
    }
  },

  // ============================================================================
  // DEBOUNCED UPDATES
  // ============================================================================

  setupDebouncedUpdates() {
    this.updateTimeouts = new Map()
    
    // Debounce color inputs
    const colorInputs = this.el.querySelectorAll('input[type="color"], input[type="text"]')
    colorInputs.forEach(input => {
      input.addEventListener('input', (e) => {
        this.debouncedUpdate(e.target, 500)
      })
    })
    
    // Debounce select inputs
    const selectInputs = this.el.querySelectorAll('select')
    selectInputs.forEach(select => {
      select.addEventListener('change', (e) => {
        this.debouncedUpdate(e.target, 200)
      })
    })
  },

  debouncedUpdate(element, delay) {
    const key = element.name || element.id || 'default'
    
    // Clear existing timeout
    if (this.updateTimeouts.has(key)) {
      clearTimeout(this.updateTimeouts.get(key))
    }
    
    // Set new timeout
    const timeout = setTimeout(() => {
      // Trigger the actual update
      element.dispatchEvent(new Event('change', { bubbles: true }))
      this.updateTimeouts.delete(key)
    }, delay)
    
    this.updateTimeouts.set(key, timeout)
  },

  // ============================================================================
  // CLEANUP
  // ============================================================================

  cleanupPreview() {
    // Close preview window
    if (this.previewWindow && !this.previewWindow.closed) {
      this.previewWindow.close()
    }
    
    // Clear intervals
    if (this.previewWindowCheckInterval) {
      clearInterval(this.previewWindowCheckInterval)
    }
    
    // Clear timeouts
    if (this.updateTimeouts) {
      this.updateTimeouts.forEach(timeout => clearTimeout(timeout))
      this.updateTimeouts.clear()
    }
    
    // Remove preview container
    if (this.previewContainer && document.body.contains(this.previewContainer)) {
      document.body.removeChild(this.previewContainer)
    }
    
    // Remove style element
    if (this.previewStyleElement && document.head.contains(this.previewStyleElement)) {
      document.head.removeChild(this.previewStyleElement)
    }
    
    // Remove upgrade modal if it exists
    const upgradeModal = document.getElementById('upgrade-modal')
    if (upgradeModal) {
      upgradeModal.remove()
    }
  }
}