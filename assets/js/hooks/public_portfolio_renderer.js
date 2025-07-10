// assets/js/hooks/public_portfolio_renderer.js
export const PublicPortfolioRenderer = {
  mounted() {
    this.initializeScrollManagement()
    this.initializeStickyNavigation()
    this.initializeVideoPlayback()
    this.initializeDeviceDetection()
    this.initializeAnimations()
    this.initializeLightbox()
    this.initializeContactForms()
    
    // Add resize listener for responsive updates
    this.resizeHandler = this.handleResize.bind(this)
    window.addEventListener('resize', this.resizeHandler)
    
    // Initial device detection
    this.detectDevice()
  },

  destroyed() {
    window.removeEventListener('resize', this.resizeHandler)
    this.cleanupScrollListeners()
    this.cleanupVideoPlayers()
  },

  // ============================================================================
  // SCROLL MANAGEMENT
  // ============================================================================

  initializeScrollManagement() {
    this.lastScrollPosition = 0
    this.scrollThrottle = null
    
    this.scrollHandler = () => {
      if (this.scrollThrottle) return
      
      this.scrollThrottle = setTimeout(() => {
        const scrollPosition = window.pageYOffset
        this.handleScrollChange(scrollPosition)
        this.updateActiveSection(scrollPosition)
        this.lastScrollPosition = scrollPosition
        this.scrollThrottle = null
      }, 16) // 60fps throttling
    }
    
    window.addEventListener('scroll', this.scrollHandler, { passive: true })
    
    // Handle scroll to section events
    this.handleEvent('scroll_to_element', ({ id }) => {
      this.scrollToElement(id)
    })
  },

  handleScrollChange(scrollPosition) {
    // Update sticky navigation visibility
    this.updateStickyNavigation(scrollPosition)
    
    // Send scroll position to LiveView for state management
    this.pushEvent('update_scroll_position', { position: scrollPosition })
    
    // Handle parallax effects (if enabled)
    if (this.el.dataset.enableAnimations === 'true') {
      this.updateParallaxEffects(scrollPosition)
    }
  },

  updateActiveSection(scrollPosition) {
    const sections = this.el.querySelectorAll('[id$="-section"]')
    let activeSection = null
    
    sections.forEach(section => {
      const rect = section.getBoundingClientRect()
      const isVisible = rect.top <= window.innerHeight / 2 && rect.bottom >= window.innerHeight / 2
      
      if (isVisible) {
        activeSection = section.id
      }
    })
    
    if (activeSection) {
      this.highlightActiveNavItem(activeSection)
    }
  },

  scrollToElement(elementId) {
    const element = document.getElementById(elementId)
    if (element) {
      const offsetTop = element.offsetTop - 80 // Account for sticky nav
      window.scrollTo({
        top: offsetTop,
        behavior: 'smooth'
      })
    }
  },

  cleanupScrollListeners() {
    if (this.scrollHandler) {
      window.removeEventListener('scroll', this.scrollHandler)
    }
    if (this.scrollThrottle) {
      clearTimeout(this.scrollThrottle)
    }
  },

  // ============================================================================
  // STICKY NAVIGATION
  // ============================================================================

  initializeStickyNavigation() {
    this.stickyNav = this.el.querySelector('#sticky-nav')
    if (!this.stickyNav) return
    
    this.stickyNavOffset = 100 // Show sticky nav after scrolling 100px
    this.stickyNavVisible = false
  },

  updateStickyNavigation(scrollPosition) {
    if (!this.stickyNav) return
    
    const shouldShow = scrollPosition > this.stickyNavOffset
    
    if (shouldShow && !this.stickyNavVisible) {
      this.showStickyNav()
    } else if (!shouldShow && this.stickyNavVisible) {
      this.hideStickyNav()
    }
  },

  showStickyNav() {
    if (!this.stickyNav) return
    
    this.stickyNav.style.transform = 'translateY(0)'
    this.stickyNav.style.opacity = '1'
    this.stickyNavVisible = true
  },

  hideStickyNav() {
    if (!this.stickyNav) return
    
    this.stickyNav.style.transform = 'translateY(-100%)'
    this.stickyNav.style.opacity = '0'
    this.stickyNavVisible = false
  },

  highlightActiveNavItem(activeSection) {
    // Remove active class from all nav items
    const navItems = this.el.querySelectorAll('.nav-link')
    navItems.forEach(item => {
      item.classList.remove('bg-blue-100', 'text-blue-700')
      item.classList.add('text-gray-600')
    })
    
    // Add active class to current section's nav item
    const activeNavItem = this.el.querySelector(`[phx-value-section="${activeSection}"]`)
    if (activeNavItem) {
      activeNavItem.classList.add('bg-blue-100', 'text-blue-700')
      activeNavItem.classList.remove('text-gray-600')
    }
  },

  // ============================================================================
  // VIDEO PLAYBACK
  // ============================================================================

  initializeVideoPlayback() {
    this.videoPlayers = new Map()
    
    // Handle video play events
    this.handleEvent('play_video', ({ video_id }) => {
      this.playVideo(video_id)
    })
    
    // Initialize existing videos
    this.setupVideoPlayers()
  },

  setupVideoPlayers() {
    const videoElements = this.el.querySelectorAll('video[data-video-id]')
    
    videoElements.forEach(video => {
      const videoId = video.dataset.videoId
      this.videoPlayers.set(videoId, {
        element: video,
        isPlaying: false
      })
      
      // Add click listener for inline play
      video.addEventListener('click', () => {
        this.toggleVideoPlayback(videoId)
      })
      
      // Handle autoplay policy
      this.handleVideoAutoplay(video)
    })
  },

  playVideo(videoId) {
    const playerData = this.videoPlayers.get(videoId)
    if (!playerData) return
    
    const video = playerData.element
    
    // Pause other videos first
    this.pauseAllVideos()
    
    // Play the selected video
    video.play().then(() => {
      playerData.isPlaying = true
      this.showVideoControls(video)
    }).catch(error => {
      console.warn('Video autoplay failed:', error)
      this.showPlayButton(video)
    })
  },

  toggleVideoPlayback(videoId) {
    const playerData = this.videoPlayers.get(videoId)
    if (!playerData) return
    
    const video = playerData.element
    
    if (playerData.isPlaying) {
      video.pause()
      playerData.isPlaying = false
    } else {
      this.playVideo(videoId)
    }
  },

  pauseAllVideos() {
    this.videoPlayers.forEach((playerData, videoId) => {
      if (playerData.isPlaying) {
        playerData.element.pause()
        playerData.isPlaying = false
      }
    })
  },

  handleVideoAutoplay(video) {
    // Check autoplay policy from dataset
    const autoplayPolicy = this.el.dataset.videoAutoplay || 'none'
    
    switch (autoplayPolicy) {
      case 'muted':
        video.muted = true
        video.autoplay = true
        break
      case 'hover':
        this.setupHoverPlayback(video)
        break
      case 'none':
      default:
        video.autoplay = false
        break
    }
  },

  setupHoverPlayback(video) {
    video.addEventListener('mouseenter', () => {
      if (!video.paused) return
      video.muted = true
      video.play().catch(() => {
        // Autoplay failed, ignore
      })
    })
    
    video.addEventListener('mouseleave', () => {
      if (video.paused) return
      video.pause()
      video.currentTime = 0
    })
  },

  showVideoControls(video) {
    video.controls = true
    video.muted = false
  },

  showPlayButton(video) {
    // Create and show a play button overlay
    const playButton = document.createElement('div')
    playButton.className = 'video-play-overlay'
    playButton.innerHTML = `
      <div class="play-button">
        <svg width="60" height="60" viewBox="0 0 60 60" fill="white">
          <circle cx="30" cy="30" r="30" fill="rgba(0,0,0,0.7)"/>
          <polygon points="24,18 24,42 42,30" fill="white"/>
        </svg>
      </div>
    `
    
    video.parentElement.appendChild(playButton)
    
    playButton.addEventListener('click', () => {
      video.play()
      playButton.remove()
    })
  },

  cleanupVideoPlayers() {
    this.videoPlayers.clear()
  },

  // ============================================================================
  // DEVICE DETECTION & RESPONSIVENESS
  // ============================================================================

  initializeDeviceDetection() {
    this.deviceBreakpoints = {
      mobile: 768,
      tablet: 1024,
      desktop: 1200
    }
  },

  detectDevice() {
    const width = window.innerWidth
    let deviceType = 'desktop'
    let isMobile = false
    
    if (width < this.deviceBreakpoints.mobile) {
      deviceType = 'mobile'
      isMobile = true
    } else if (width < this.deviceBreakpoints.tablet) {
      deviceType = 'tablet'
      isMobile = true
    }
    
    // Update component state
    this.pushEvent('device_change', {
      type: deviceType,
      is_mobile: isMobile
    })
    
    // Update CSS classes
    this.updateDeviceClasses(deviceType, isMobile)
  },

  updateDeviceClasses(deviceType, isMobile) {
    this.el.classList.remove('device-mobile', 'device-tablet', 'device-desktop')
    this.el.classList.add(`device-${deviceType}`)
    
    if (isMobile) {
      this.el.classList.add('is-mobile')
      this.initializeMobileOptimizations()
    } else {
      this.el.classList.remove('is-mobile')
    }
  },

  handleResize() {
    if (this.resizeTimeout) clearTimeout(this.resizeTimeout)
    
    this.resizeTimeout = setTimeout(() => {
      this.detectDevice()
    }, 150)
  },

  initializeMobileOptimizations() {
    // Add touch-friendly interactions
    this.setupTouchGestures()
    
    // Optimize scroll performance
    this.setupMobileScrollOptimizations()
    
    // Setup mobile-specific UI
    this.setupMobileUI()
  },

  setupTouchGestures() {
    // Add swipe gestures for mobile navigation
    let touchStartX = 0
    let touchStartY = 0
    
    this.el.addEventListener('touchstart', (e) => {
      touchStartX = e.touches[0].clientX
      touchStartY = e.touches[0].clientY
    }, { passive: true })
    
    this.el.addEventListener('touchend', (e) => {
      const touchEndX = e.changedTouches[0].clientX
      const touchEndY = e.changedTouches[0].clientY
      
      const deltaX = touchEndX - touchStartX
      const deltaY = touchEndY - touchStartY
      
      // Horizontal swipe detection
      if (Math.abs(deltaX) > Math.abs(deltaY) && Math.abs(deltaX) > 50) {
        if (deltaX > 0) {
          // Swipe right
          this.handleSwipeRight()
        } else {
          // Swipe left
          this.handleSwipeLeft()
        }
      }
    }, { passive: true })
  },

  setupMobileScrollOptimizations() {
    // Use passive scroll listeners for better performance
    // Reduce animation complexity on mobile
    if (this.el.classList.contains('is-mobile')) {
      this.el.style.setProperty('--animation-duration', '0.2s')
    }
  },

  setupMobileUI() {
    // Setup mobile-specific interactions
    const expandableBlocks = this.el.querySelectorAll('[data-mobile-expandable]')
    
    expandableBlocks.forEach(block => {
      this.setupMobileExpansion(block)
    })
  },

  setupMobileExpansion(block) {
    const trigger = block.querySelector('[data-mobile-trigger]')
    const content = block.querySelector('[data-mobile-content]')
    
    if (!trigger || !content) return
    
    trigger.addEventListener('click', () => {
      const isExpanded = block.classList.contains('expanded')
      
      if (isExpanded) {
        this.collapseMobileBlock(block, content)
      } else {
        this.expandMobileBlock(block, content)
      }
    })
  },

  expandMobileBlock(block, content) {
    block.classList.add('expanded')
    content.style.maxHeight = content.scrollHeight + 'px'
    content.style.opacity = '1'
  },

  collapseMobileBlock(block, content) {
    block.classList.remove('expanded')
    content.style.maxHeight = '0'
    content.style.opacity = '0'
  },

  handleSwipeRight() {
    // Handle swipe right gesture
    this.pushEvent('swipe_gesture', { direction: 'right' })
  },

  handleSwipeLeft() {
    // Handle swipe left gesture
    this.pushEvent('swipe_gesture', { direction: 'left' })
  },

  // ============================================================================
  // ANIMATIONS
  // ============================================================================

  initializeAnimations() {
    if (this.el.dataset.enableAnimations !== 'true') return
    
    this.setupIntersectionObserver()
    this.setupParallaxElements()
    this.setupScrollAnimations()
  },

  setupIntersectionObserver() {
    this.observerOptions = {
      threshold: 0.1,
      rootMargin: '0px 0px -50px 0px'
    }
    
    this.intersectionObserver = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          this.animateElementIn(entry.target)
        }
      })
    }, this.observerOptions)
    
    // Observe all animatable elements
    const animatableElements = this.el.querySelectorAll('[data-animate]')
    animatableElements.forEach(el => {
      this.intersectionObserver.observe(el)
    })
  },

  animateElementIn(element) {
    const animationType = element.dataset.animate || 'fadeInUp'
    
    element.classList.add('animate-in', `animate-${animationType}`)
    
    // Unobserve after animation
    this.intersectionObserver.unobserve(element)
  },

  setupParallaxElements() {
    this.parallaxElements = this.el.querySelectorAll('[data-parallax]')
  },

  updateParallaxEffects(scrollPosition) {
    this.parallaxElements.forEach(element => {
      const rate = parseFloat(element.dataset.parallax) || 0.5
      const yPos = -(scrollPosition * rate)
      element.style.transform = `translateY(${yPos}px)`
    })
  },

  setupScrollAnimations() {
    // Setup scroll-triggered animations
    const scrollTriggers = this.el.querySelectorAll('[data-scroll-trigger]')
    
    scrollTriggers.forEach(trigger => {
      this.intersectionObserver.observe(trigger)
    })
  },

  // ============================================================================
  // LIGHTBOX FUNCTIONALITY
  // ============================================================================

  initializeLightbox() {
    this.lightboxOpen = false
    this.currentLightboxIndex = 0
    this.lightboxItems = []
    
    // Handle lightbox events from LiveView
    this.handleEvent('open_lightbox', ({ media_id }) => {
      this.openLightbox(media_id)
    })
    
    // Setup keyboard navigation
    this.setupLightboxKeyboard()
  },

  openLightbox(mediaId) {
    // Collect all lightbox-able media items
    this.collectLightboxItems()
    
    // Find the index of the requested media
    const index = this.lightboxItems.findIndex(item => item.id === mediaId)
    if (index !== -1) {
      this.currentLightboxIndex = index
      this.showLightbox()
    }
  },

  collectLightboxItems() {
    this.lightboxItems = []
    const mediaElements = this.el.querySelectorAll('[data-lightbox-media]')
    
    mediaElements.forEach(element => {
      const mediaData = {
        id: element.dataset.mediaId,
        url: element.dataset.mediaUrl || element.src,
        type: element.dataset.mediaType || 'image',
        caption: element.dataset.mediaCaption || '',
        element: element
      }
      this.lightboxItems.push(mediaData)
    })
  },

  showLightbox() {
    if (this.lightboxItems.length === 0) return
    
    this.lightboxOpen = true
    
    // Create lightbox overlay
    this.createLightboxOverlay()
    
    // Show current media
    this.showLightboxMedia(this.currentLightboxIndex)
    
    // Prevent body scroll
    document.body.style.overflow = 'hidden'
  },

  createLightboxOverlay() {
    this.lightboxOverlay = document.createElement('div')
    this.lightboxOverlay.className = 'lightbox-overlay fixed inset-0 z-50 bg-black/90 flex items-center justify-center'
    
    this.lightboxOverlay.innerHTML = `
      <div class="lightbox-container relative max-w-full max-h-full p-4">
        <div class="lightbox-content"></div>
        <div class="lightbox-controls absolute top-4 right-4 flex space-x-2">
          <button class="lightbox-close w-10 h-10 bg-white/20 rounded-full flex items-center justify-center text-white hover:bg-white/30">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>
        <div class="lightbox-navigation">
          <button class="lightbox-prev absolute left-4 top-1/2 transform -translate-y-1/2 w-12 h-12 bg-white/20 rounded-full flex items-center justify-center text-white hover:bg-white/30">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"/>
            </svg>
          </button>
          <button class="lightbox-next absolute right-4 top-1/2 transform -translate-y-1/2 w-12 h-12 bg-white/20 rounded-full flex items-center justify-center text-white hover:bg-white/30">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
            </svg>
          </button>
        </div>
      </div>
    `
    
    document.body.appendChild(this.lightboxOverlay)
    
    // Setup event listeners
    this.setupLightboxEvents()
  },

  setupLightboxEvents() {
    const closeBtn = this.lightboxOverlay.querySelector('.lightbox-close')
    const prevBtn = this.lightboxOverlay.querySelector('.lightbox-prev')
    const nextBtn = this.lightboxOverlay.querySelector('.lightbox-next')
    
    closeBtn.addEventListener('click', () => this.closeLightbox())
    prevBtn.addEventListener('click', () => this.previousLightboxItem())
    nextBtn.addEventListener('click', () => this.nextLightboxItem())
    
    // Close on backdrop click
    this.lightboxOverlay.addEventListener('click', (e) => {
      if (e.target === this.lightboxOverlay) {
        this.closeLightbox()
      }
    })
  },

  setupLightboxKeyboard() {
    this.lightboxKeyHandler = (e) => {
      if (!this.lightboxOpen) return
      
      switch (e.key) {
        case 'Escape':
          this.closeLightbox()
          break
        case 'ArrowLeft':
          this.previousLightboxItem()
          break
        case 'ArrowRight':
          this.nextLightboxItem()
          break
      }
    }
    
    document.addEventListener('keydown', this.lightboxKeyHandler)
  },

  showLightboxMedia(index) {
    const media = this.lightboxItems[index]
    if (!media) return
    
    const contentContainer = this.lightboxOverlay.querySelector('.lightbox-content')
    
    if (media.type === 'video') {
      contentContainer.innerHTML = `
        <video controls autoplay class="max-w-full max-h-full">
          <source src="${media.url}" type="video/mp4">
        </video>
      `
    } else {
      contentContainer.innerHTML = `
        <img src="${media.url}" alt="${media.caption}" class="max-w-full max-h-full object-contain">
      `
    }
    
    // Show caption if available
    if (media.caption) {
      const caption = document.createElement('div')
      caption.className = 'lightbox-caption absolute bottom-4 left-4 right-4 text-white text-center'
      caption.textContent = media.caption
      this.lightboxOverlay.querySelector('.lightbox-container').appendChild(caption)
    }
  },

  previousLightboxItem() {
    if (this.currentLightboxIndex > 0) {
      this.currentLightboxIndex--
    } else {
      this.currentLightboxIndex = this.lightboxItems.length - 1
    }
    this.showLightboxMedia(this.currentLightboxIndex)
  },

  nextLightboxItem() {
    if (this.currentLightboxIndex < this.lightboxItems.length - 1) {
      this.currentLightboxIndex++
    } else {
      this.currentLightboxIndex = 0
    }
    this.showLightboxMedia(this.currentLightboxIndex)
  },

  closeLightbox() {
    this.lightboxOpen = false
    
    if (this.lightboxOverlay) {
      this.lightboxOverlay.remove()
      this.lightboxOverlay = null
    }
    
    // Restore body scroll
    document.body.style.overflow = 'auto'
  },

  // ============================================================================
  // CONTACT FORMS
  // ============================================================================

  initializeContactForms() {
    const contactForms = this.el.querySelectorAll('form[phx-submit]')
    
    contactForms.forEach(form => {
      this.setupFormValidation(form)
      this.setupFormSubmission(form)
    })
  },

  setupFormValidation(form) {
    const inputs = form.querySelectorAll('input, textarea')
    
    inputs.forEach(input => {
      input.addEventListener('blur', () => {
        this.validateInput(input)
      })
      
      input.addEventListener('input', () => {
        this.clearInputError(input)
      })
    })
  },

  validateInput(input) {
    const isValid = input.checkValidity()
    
    if (!isValid) {
      this.showInputError(input, input.validationMessage)
    } else {
      this.clearInputError(input)
    }
    
    return isValid
  },

  showInputError(input, message) {
    input.classList.add('border-red-500')
    
    let errorElement = input.nextElementSibling
    if (!errorElement || !errorElement.classList.contains('input-error')) {
      errorElement = document.createElement('div')
      errorElement.className = 'input-error text-red-500 text-sm mt-1'
      input.parentNode.insertBefore(errorElement, input.nextSibling)
    }
    
    errorElement.textContent = message
  },

  clearInputError(input) {
    input.classList.remove('border-red-500')
    
    const errorElement = input.nextElementSibling
    if (errorElement && errorElement.classList.contains('input-error')) {
      errorElement.remove()
    }
  },

  setupFormSubmission(form) {
    form.addEventListener('submit', (e) => {
      // Validate all inputs before submission
      const inputs = form.querySelectorAll('input, textarea')
      let isValid = true
      
      inputs.forEach(input => {
        if (!this.validateInput(input)) {
          isValid = false
        }
      })
      
      if (!isValid) {
        e.preventDefault()
        return false
      }
      
      // Show loading state
      const submitButton = form.querySelector('button[type="submit"]')
      if (submitButton) {
        const originalText = submitButton.textContent
        submitButton.textContent = 'Sending...'
        submitButton.disabled = true
        
        // Reset button after 5 seconds (in case of error)
        setTimeout(() => {
          submitButton.textContent = originalText
          submitButton.disabled = false
        }, 5000)
      }
    })
  }
}