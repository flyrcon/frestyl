// assets/js/hooks/supreme_discovery.js
export const SupremeDiscovery = {
  mounted() {
    this.initializeGestures();
    this.initializeParticles();
    this.initializeKeyboardNavigation();
    this.initializeThemeTransitions();
    this.initializeAudioVisualization();
  },

  updated() {
    this.updateParticles();
    this.refreshAudioVisualization();
  },

  destroyed() {
    this.cleanup();
  },

  initializeGestures() {
    let startX = 0;
    let startY = 0;
    let currentX = 0;
    let currentY = 0;
    let isDragging = false;

    const container = this.el;

    // Touch events for mobile
    container.addEventListener('touchstart', (e) => {
      startX = e.touches[0].clientX;
      startY = e.touches[0].clientY;
      isDragging = true;
    }, { passive: true });

    container.addEventListener('touchmove', (e) => {
      if (!isDragging) return;
      
      currentX = e.touches[0].clientX;
      currentY = e.touches[0].clientY;
      
      const deltaX = currentX - startX;
      const deltaY = currentY - startY;
      
      // Only handle horizontal swipes for card navigation
      if (Math.abs(deltaX) > Math.abs(deltaY) && Math.abs(deltaX) > 50) {
        e.preventDefault();
      }
    }, { passive: false });

    container.addEventListener('touchend', (e) => {
      if (!isDragging) return;
      
      const deltaX = currentX - startX;
      const deltaY = currentY - startY;
      
      // Horizontal swipe detection
      if (Math.abs(deltaX) > Math.abs(deltaY) && Math.abs(deltaX) > 100) {
        if (deltaX > 0) {
          this.pushEvent("swipe_prev", {});
        } else {
          this.pushEvent("swipe_next", {});
        }
      }
      
      isDragging = false;
    }, { passive: true });

    // Mouse events for desktop (optional drag)
    container.addEventListener('mousedown', (e) => {
      startX = e.clientX;
      startY = e.clientY;
      isDragging = true;
      container.style.cursor = 'grabbing';
    });

    document.addEventListener('mousemove', (e) => {
      if (!isDragging) return;
      
      currentX = e.clientX;
      currentY = e.clientY;
    });

    document.addEventListener('mouseup', (e) => {
      if (!isDragging) return;
      
      const deltaX = currentX - startX;
      
      if (Math.abs(deltaX) > 150) {
        if (deltaX > 0) {
          this.pushEvent("swipe_prev", {});
        } else {
          this.pushEvent("swipe_next", {});
        }
      }
      
      isDragging = false;
      container.style.cursor = 'grab';
    });
  },

  initializeKeyboardNavigation() {
    document.addEventListener('keydown', (e) => {
      // Only handle when this component is active
      if (!this.el.closest('.revolutionary-discovery')) return;
      
      switch(e.key) {
        case 'ArrowLeft':
        case 'h':
          e.preventDefault();
          this.pushEvent("swipe_prev", {});
          break;
        case 'ArrowRight':
        case 'l':
          e.preventDefault();
          this.pushEvent("swipe_next", {});
          break;
        case 'Enter':
        case ' ':
          e.preventDefault();
          this.expandCurrentCard();
          break;
        case 'Escape':
          e.preventDefault();
          this.pushEvent("close_preview", {});
          break;
        case '1':
        case '2':
        case '3':
        case '4':
        case '5':
          e.preventDefault();
          const themeIndex = parseInt(e.key) - 1;
          this.quickSwitchTheme(themeIndex);
          break;
      }
    });
  },

  expandCurrentCard() {
    const activeCard = this.el.querySelector('.planetary-card[data-card-id]');
    if (activeCard) {
      const cardId = activeCard.dataset.cardId;
      this.pushEvent("expand_planet", { card_id: cardId });
    }
  },

  quickSwitchTheme(index) {
    const themes = ['cosmic_dreams', 'neon_cyberpunk', 'liquid_flow', 'crystal_matrix', 'organic_growth', 'clean_paper'];
    if (themes[index]) {
      this.pushEvent("switch_theme", { theme: themes[index] });
    }
  },

  initializeParticles() {
    this.particleSystem = {
      particles: [],
      maxParticles: 20,
      container: this.el.querySelector('.particles-container')
    };

    if (!this.particleSystem.container) return;

    // Create initial particles
    for (let i = 0; i < this.particleSystem.maxParticles; i++) {
      this.createParticle();
    }

    // Particle animation loop
    this.particleAnimationId = setInterval(() => {
      this.animateParticles();
    }, 100);
  },

  createParticle() {
    if (!this.particleSystem?.container) return;

    const particle = document.createElement('div');
    particle.className = 'particle absolute rounded-full pointer-events-none';
    
    // Random size and position
    const size = Math.random() * 4 + 2; // 2-6px
    particle.style.width = `${size}px`;
    particle.style.height = `${size}px`;
    particle.style.left = `${Math.random() * 100}%`;
    particle.style.bottom = '0px';
    particle.style.opacity = Math.random() * 0.6 + 0.2;
    
    // Random animation duration and delay
    const duration = Math.random() * 10 + 10; // 10-20s
    const delay = Math.random() * 5; // 0-5s delay
    
    particle.style.animationDuration = `${duration}s`;
    particle.style.animationDelay = `${delay}s`;
    particle.style.animationTimingFunction = 'linear';
    particle.style.animationIterationCount = 'infinite';
    particle.style.animationName = 'floatingParticles';

    this.particleSystem.container.appendChild(particle);
    this.particleSystem.particles.push(particle);

    // Remove particle after animation completes
    setTimeout(() => {
      if (particle.parentNode) {
        particle.parentNode.removeChild(particle);
        const index = this.particleSystem.particles.indexOf(particle);
        if (index > -1) {
          this.particleSystem.particles.splice(index, 1);
        }
      }
    }, (duration + delay) * 1000);
  },

  animateParticles() {
    // Occasionally create new particles
    if (this.particleSystem?.particles?.length < this.particleSystem.maxParticles && Math.random() < 0.3) {
      this.createParticle();
    }
  },

  updateParticles() {
    // Clean up old particles and potentially create new ones based on theme
    if (this.particleSystem?.container) {
      const theme = this.el.dataset.theme;
      this.adjustParticlesForTheme(theme);
    }
  },

  adjustParticlesForTheme(theme) {
    if (!this.particleSystem?.container) return;

    // Adjust particle colors and behavior based on theme
    const particles = this.particleSystem.container.querySelectorAll('.particle');
    particles.forEach(particle => {
      switch(theme) {
        case 'cosmic_dreams':
          particle.style.background = 'radial-gradient(circle, rgba(168,85,247,0.8), rgba(139,92,246,0.3))';
          break;
        case 'neon_cyberpunk':
          particle.style.background = 'radial-gradient(circle, rgba(240,147,251,0.8), rgba(245,117,165,0.3))';
          break;
        case 'liquid_flow':
          particle.style.background = 'radial-gradient(circle, rgba(79,172,254,0.8), rgba(0,242,254,0.3))';
          break;
        case 'crystal_matrix':
          particle.style.background = 'radial-gradient(circle, rgba(16,185,129,0.8), rgba(110,231,183,0.3))';
          break;
        case 'organic_growth':
          particle.style.background = 'radial-gradient(circle, rgba(251,146,60,0.8), rgba(254,215,170,0.3))';
          break;
        default:
          particle.style.background = 'radial-gradient(circle, rgba(99,102,241,0.6), rgba(139,92,246,0.2))';
      }
    });
  },

  initializeThemeTransitions() {
    // Smooth theme transitions with CSS custom properties
    const root = document.documentElement;
    
    this.themeTransitionObserver = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        if (mutation.type === 'attributes' && mutation.attributeName === 'data-theme') {
          this.handleThemeChange(mutation.target.dataset.theme);
        }
      });
    });

    this.themeTransitionObserver.observe(this.el, {
      attributes: true,
      attributeFilter: ['data-theme']
    });
  },

  handleThemeChange(newTheme) {
    // Add theme transition class
    this.el.classList.add('theme-transitioning');
    
    // Trigger haptic feedback if supported
    if (navigator.vibrate) {
      navigator.vibrate(50);
    }
    
    // Update particles for new theme
    this.adjustParticlesForTheme(newTheme);
    
    // Remove transition class after animation
    setTimeout(() => {
      this.el.classList.remove('theme-transitioning');
    }, 800);
  },

  initializeAudioVisualization() {
    this.audioContexts = new Map();
    this.initializeExistingAudioElements();
  },

  initializeExistingAudioElements() {
    const audioElements = this.el.querySelectorAll('audio');
    audioElements.forEach(audio => {
      this.setupAudioVisualization(audio);
    });
  },

  setupAudioVisualization(audioElement) {
    if (this.audioContexts.has(audioElement)) return;

    try {
      const audioContext = new (window.AudioContext || window.webkitAudioContext)();
      const source = audioContext.createMediaElementSource(audioElement);
      const analyzer = audioContext.createAnalyser();
      
      analyzer.fftSize = 64;
      const bufferLength = analyzer.frequencyBinCount;
      const dataArray = new Uint8Array(bufferLength);

      source.connect(analyzer);
      analyzer.connect(audioContext.destination);

      this.audioContexts.set(audioElement, {
        context: audioContext,
        analyzer: analyzer,
        dataArray: dataArray,
        bufferLength: bufferLength
      });

      // Start visualization when audio plays
      audioElement.addEventListener('play', () => {
        this.startAudioVisualization(audioElement);
      });

      audioElement.addEventListener('pause', () => {
        this.stopAudioVisualization(audioElement);
      });

    } catch (error) {
      console.warn('Audio visualization not supported:', error);
    }
  },

  startAudioVisualization(audioElement) {
    const audioData = this.audioContexts.get(audioElement);
    if (!audioData) return;

    const visualize = () => {
      if (audioElement.paused || audioElement.ended) return;

      audioData.analyzer.getByteFrequencyData(audioData.dataArray);
      this.updateWaveformDisplay(audioElement, audioData.dataArray);
      
      requestAnimationFrame(visualize);
    };

    visualize();
  },

  stopAudioVisualization(audioElement) {
    // Stop visualization - handled by the paused check in visualize function
  },

  updateWaveformDisplay(audioElement, frequencyData) {
    // Find waveform container for this audio element
    const container = audioElement.closest('.musical-planet, .expanded-musical');
    if (!container) return;

    const waveformBars = container.querySelectorAll('.waveform-bar');
    if (waveformBars.length === 0) return;

    // Update waveform bars based on frequency data
    waveformBars.forEach((bar, index) => {
      if (index < frequencyData.length) {
        const height = (frequencyData[index] / 255) * 60; // Scale to max 60px
        bar.style.height = `${Math.max(2, height)}px`;
        bar.style.opacity = Math.max(0.3, frequencyData[index] / 255);
      }
    });
  },

  refreshAudioVisualization() {
    // Re-initialize audio elements after updates
    setTimeout(() => {
      this.initializeExistingAudioElements();
    }, 100);
  },

  cleanup() {
    // Clean up event listeners and intervals
    if (this.particleAnimationId) {
      clearInterval(this.particleAnimationId);
    }

    if (this.themeTransitionObserver) {
      this.themeTransitionObserver.disconnect();
    }

    // Clean up audio contexts
    this.audioContexts.forEach((audioData, audioElement) => {
      if (audioData.context && audioData.context.state !== 'closed') {
        audioData.context.close();
      }
    });
    this.audioContexts.clear();

    // Remove particles
    if (this.particleSystem?.container) {
      this.particleSystem.particles.forEach(particle => {
        if (particle.parentNode) {
          particle.parentNode.removeChild(particle);
        }
      });
    }
  }
};

// Additional CSS for enhanced interactions
const additionalStyles = `
  .theme-transitioning {
    transition: all 0.8s cubic-bezier(0.4, 0, 0.2, 1) !important;
  }
  
  .theme-transitioning * {
    transition: all 0.8s cubic-bezier(0.4, 0, 0.2, 1) !important;
  }
  
  .planetary-card:hover {
    transform: scale(1.05) translateZ(0);
    z-index: 10;
  }
  
  .satellite {
    animation-play-state: running;
  }
  
  .planetary-card:hover .satellite {
    animation-play-state: paused;
  }
  
  @media (prefers-reduced-motion: reduce) {
    .particle,
    .satellite,
    .planet-core {
      animation: none !important;
    }
  }
  
  .waveform-bar {
    transition: height 0.1s ease-out, opacity 0.1s ease-out;
  }
  
  .audio-controls audio {
    width: 100%;
    height: 40px;
    background: rgba(255, 255, 255, 0.1);
    border-radius: 20px;
  }
  
  .audio-controls audio::-webkit-media-controls-panel {
    background-color: rgba(255, 255, 255, 0.1);
    border-radius: 20px;
  }
  
  /* Custom scrollbar for modal content */
  .modal-content::-webkit-scrollbar {
    width: 8px;
  }
  
  .modal-content::-webkit-scrollbar-track {
    background: rgba(255, 255, 255, 0.1);
    border-radius: 4px;
  }
  
  .modal-content::-webkit-scrollbar-thumb {
    background: rgba(255, 255, 255, 0.3);
    border-radius: 4px;
  }
  
  .modal-content::-webkit-scrollbar-thumb:hover {
    background: rgba(255, 255, 255, 0.5);
  }
`;

// Inject additional styles
if (!document.getElementById('supreme-discovery-styles')) {
  const styleSheet = document.createElement('style');
  styleSheet.id = 'supreme-discovery-styles';
  styleSheet.textContent = additionalStyles;
  document.head.appendChild(styleSheet);
}