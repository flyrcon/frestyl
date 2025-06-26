// assets/js/hooks/resume_upload_experience.js
export const ResumeUploadExperience = {
  mounted() {
    this.initializeUploadZone()
    this.initializeAnimations()
    this.initializeProgressAnimations()
    
    // Listen for processing updates from server
    this.handleEvent("update_processing_step", ({ stage, progress }) => {
      this.updateProcessingStep(stage, progress)
    })
  },

  initializeUploadZone() {
    const uploadZone = this.el.querySelector('#upload-zone')
    const fileInput = this.el.querySelector('#resume-file-input')
    
    if (!uploadZone || !fileInput) return

    // Enhanced drag and drop
    uploadZone.addEventListener('dragover', (e) => {
      e.preventDefault()
      uploadZone.classList.add('dragover')
      this.addDragAnimation()
    })

    uploadZone.addEventListener('dragleave', (e) => {
      e.preventDefault()
      uploadZone.classList.remove('dragover')
      this.removeDragAnimation()
    })

    uploadZone.addEventListener('drop', (e) => {
      e.preventDefault()
      uploadZone.classList.remove('dragover')
      this.removeDragAnimation()
      
      const files = e.dataTransfer.files
      if (files.length > 0) {
        // Trigger file input with dropped file
        fileInput.files = files
        
        // Create visual feedback
        this.showFilePreview(files[0])
        
        // Trigger change event
        const event = new Event('change', { bubbles: true })
        fileInput.dispatchEvent(event)
      }
    })

    // File input change handler
    fileInput.addEventListener('change', (e) => {
      if (e.target.files.length > 0) {
        this.showFilePreview(e.target.files[0])
        this.animateFileAccepted()
      }
    })
  },

  addDragAnimation() {
    const uploadZone = this.el.querySelector('#upload-zone')
    if (uploadZone) {
      uploadZone.style.transform = 'scale(1.05)'
      uploadZone.style.borderColor = 'rgba(102, 126, 234, 0.8)'
      uploadZone.style.backgroundColor = 'rgba(102, 126, 234, 0.2)'
    }
  },

  removeDragAnimation() {
    const uploadZone = this.el.querySelector('#upload-zone')
    if (uploadZone) {
      uploadZone.style.transform = 'scale(1)'
      uploadZone.style.borderColor = 'rgba(102, 126, 234, 0.4)'
      uploadZone.style.backgroundColor = 'rgba(102, 126, 234, 0.1)'
    }
  },

  showFilePreview(file) {
    // Create a temporary preview element
    const uploadZone = this.el.querySelector('#upload-zone')
    if (!uploadZone) return

    // Add a subtle glow effect
    uploadZone.style.boxShadow = '0 0 30px rgba(102, 126, 234, 0.4)'
    
    // Update the upload icon to show success
    const uploadIcon = uploadZone.querySelector('svg')
    if (uploadIcon) {
      uploadIcon.innerHTML = `
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
              d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
      `
      uploadIcon.parentElement.classList.add('bg-green-500')
      uploadIcon.parentElement.classList.remove('bg-gradient-to-r', 'from-indigo-500', 'to-purple-500')
    }

    // Update text
    const titleElement = uploadZone.querySelector('h3')
    const subtitleElement = uploadZone.querySelector('p')
    
    if (titleElement) titleElement.textContent = `✨ ${file.name} Ready!`
    if (subtitleElement) subtitleElement.textContent = 'Click "Transform to Portfolio" to begin'
  },

  animateFileAccepted() {
    const uploadZone = this.el.querySelector('#upload-zone')
    if (!uploadZone) return

    // Pulse animation
    uploadZone.style.animation = 'pulse 0.5s ease-in-out'
    
    setTimeout(() => {
      uploadZone.style.animation = ''
    }, 500)

    // Confetti effect (simple)
    this.createConfettiEffect()
  },

  createConfettiEffect() {
    const uploadZone = this.el.querySelector('#upload-zone')
    if (!uploadZone) return

    const colors = ['#667eea', '#764ba2', '#f093fb', '#f59e0b', '#10b981']
    
    for (let i = 0; i < 15; i++) {
      setTimeout(() => {
        const confetti = document.createElement('div')
        confetti.style.cssText = `
          position: absolute;
          width: 10px;
          height: 10px;
          background: ${colors[Math.floor(Math.random() * colors.length)]};
          top: 50%;
          left: 50%;
          border-radius: 50%;
          pointer-events: none;
          z-index: 1000;
          animation: confetti 1s ease-out forwards;
        `
        
        // Random direction
        const angle = (Math.PI * 2 * i) / 15
        const velocity = 50 + Math.random() * 50
        const x = Math.cos(angle) * velocity
        const y = Math.sin(angle) * velocity
        
        confetti.style.setProperty('--x', `${x}px`)
        confetti.style.setProperty('--y', `${y}px`)
        
        uploadZone.appendChild(confetti)
        
        setTimeout(() => confetti.remove(), 1000)
      }, i * 50)
    }
  },

  initializeAnimations() {
    // Stagger animation for floating elements
    const floatingElements = this.el.querySelectorAll('.animate-float')
    floatingElements.forEach((element, index) => {
      element.style.animationDelay = `${index * 0.5}s`
    })

    // Intersection observer for scroll animations
    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.classList.add('animate-fade-in')
        }
      })
    }, { threshold: 0.1 })

    // Observe elements that should animate on scroll
    const animateElements = this.el.querySelectorAll('.animate-on-scroll')
    animateElements.forEach(el => observer.observe(el))
  },

  initializeProgressAnimations() {
    // Add custom keyframes for confetti
    if (!document.querySelector('#confetti-styles')) {
      const style = document.createElement('style')
      style.id = 'confetti-styles'
      style.textContent = `
        @keyframes confetti {
          0% {
            transform: translate(0, 0) rotate(0deg);
            opacity: 1;
          }
          100% {
            transform: translate(var(--x), var(--y)) rotate(360deg);
            opacity: 0;
          }
        }
        
        @keyframes sparkle {
          0%, 100% { transform: scale(1) rotate(0deg); }
          50% { transform: scale(1.2) rotate(180deg); }
        }
        
        .processing-bg {
          background: linear-gradient(-45deg, #ee7752, #e73c7e, #23a6d5, #23d5ab);
          background-size: 400% 400%;
          animation: gradient 3s ease infinite;
        }
      `
      document.head.appendChild(style)
    }
  },

  updateProcessingStep(stage, progress) {
    // Update progress bar with smooth animation
    const progressBar = this.el.querySelector('#progress-bar')
    if (progressBar) {
      progressBar.style.width = `${progress}%`
    }

    // Update percentage
    const progressPercentage = this.el.querySelector('#progress-percentage')
    if (progressPercentage) {
      this.animateNumber(progressPercentage, parseInt(progressPercentage.textContent), progress)
    }

    // Add sparkle effects to completed steps
    this.addSparkleToCompletedSteps(stage)

    // Specific stage animations
    switch (stage) {
      case 'extracting':
        this.animateStepActivation('step-extract')
        break
      case 'analyzing':
        this.animateStepActivation('step-analyze')
        break
      case 'enhancing':
        this.animateStepActivation('step-enhance')
        break
      case 'creating':
        this.animateStepActivation('step-create')
        break
    }
  },

  animateNumber(element, from, to) {
    const duration = 500
    const startTime = performance.now()
    
    const animate = (currentTime) => {
      const elapsed = currentTime - startTime
      const progress = Math.min(elapsed / duration, 1)
      
      const currentNumber = Math.round(from + (to - from) * progress)
      element.textContent = `${currentNumber}%`
      
      if (progress < 1) {
        requestAnimationFrame(animate)
      }
    }
    
    requestAnimationFrame(animate)
  },

  animateStepActivation(stepId) {
    const step = this.el.querySelector(`#${stepId}`)
    if (!step) return

    // Remove opacity and add activation animation
    step.style.opacity = '1'
    step.style.transform = 'translateX(10px)'
    
    setTimeout(() => {
      step.style.transform = 'translateX(0)'
      step.style.transition = 'all 0.3s ease-out'
    }, 100)

    // Find the circle in this step and animate it
    const circle = step.querySelector('.w-6.h-6')
    if (circle) {
      circle.classList.add('bg-green-500')
      circle.classList.remove('bg-gray-300')
      
      // Add a brief scale animation
      circle.style.transform = 'scale(1.2)'
      setTimeout(() => {
        circle.style.transform = 'scale(1)'
        circle.style.transition = 'all 0.2s ease-out'
      }, 200)
    }
  },

  addSparkleToCompletedSteps(currentStage) {
    const stageOrder = ['extracting', 'analyzing', 'enhancing', 'creating']
    const currentIndex = stageOrder.indexOf(currentStage)
    
    // Add sparkles to all completed steps
    for (let i = 0; i <= currentIndex; i++) {
      const stepElement = this.el.querySelector(`#step-${stageOrder[i].replace('ing', '')}`)
      if (stepElement && !stepElement.querySelector('.sparkle')) {
        this.addSparkleEffect(stepElement)
      }
    }
  },

  addSparkleEffect(element) {
    const sparkle = document.createElement('div')
    sparkle.className = 'sparkle'
    sparkle.style.cssText = `
      position: absolute;
      top: -5px;
      right: -5px;
      width: 12px;
      height: 12px;
      background: linear-gradient(45deg, #ffd700, #ffed4a);
      border-radius: 50%;
      animation: sparkle 1.5s ease-in-out infinite;
      pointer-events: none;
    `
    
    const circle = element.querySelector('.w-6.h-6')
    if (circle) {
      circle.style.position = 'relative'
      circle.appendChild(sparkle)
    }
  },

  // Success experience enhancements
  enhanceSuccessExperience() {
    const successContainer = this.el.querySelector('#success-experience')
    if (!successContainer) return

    // Add entrance animation for enhancement cards
    const enhancementCards = successContainer.querySelectorAll('.bg-gradient-to-r.from-purple-50')
    enhancementCards.forEach((card, index) => {
      card.style.opacity = '0'
      card.style.transform = 'translateY(20px)'
      
      setTimeout(() => {
        card.style.transition = 'all 0.5s ease-out'
        card.style.opacity = '1'
        card.style.transform = 'translateY(0)'
      }, index * 150)
    })

    // Add hover effects for section previews
    const sectionPreviews = successContainer.querySelectorAll('.border-2.border-gray-200')
    sectionPreviews.forEach(preview => {
      preview.addEventListener('mouseenter', () => {
        preview.style.transform = 'translateY(-5px)'
        preview.style.boxShadow = '0 10px 25px rgba(0, 0, 0, 0.1)'
      })
      
      preview.addEventListener('mouseleave', () => {
        preview.style.transform = 'translateY(0)'
        preview.style.boxShadow = 'none'
      })
    })
  },

  // Error experience enhancements
  enhanceErrorExperience() {
    const errorContainer = this.el.querySelector('#error-experience')
    if (!errorContainer) return

    // Add shake animation to error message
    const errorMessage = errorContainer.querySelector('.bg-red-50')
    if (errorMessage) {
      errorMessage.style.animation = 'shake 0.5s ease-in-out'
      
      setTimeout(() => {
        errorMessage.style.animation = ''
      }, 500)
    }
  },

  updated() {
    // Re-run enhancements when the view updates
    setTimeout(() => {
      this.enhanceSuccessExperience()
      this.enhanceErrorExperience()
    }, 100)
  },

  destroyed() {
    // Clean up any intervals or observers
    if (this.observer) {
      this.observer.disconnect()
    }
  }
}

// Add shake animation keyframes
if (!document.querySelector('#shake-styles')) {
  const style = document.createElement('style')
  style.id = 'shake-styles'
  style.textContent = `
    @keyframes shake {
      0%, 100% { transform: translateX(0); }
      25% { transform: translateX(-5px); }
      75% { transform: translateX(5px); }
    }
  `
  document.head.appendChild(style)
}