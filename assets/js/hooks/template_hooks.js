// assets/js/hooks/template_hooks.js - Real-time Template Updates

const TemplateHooks = {
  // Template Preview Hook
  TemplatePreview: {
    mounted() {
      console.log("🎨 Template Preview Hook mounted");
      this.initializeTemplatePreview();
    },

    updated() {
      this.updateTemplatePreview();
    },

    initializeTemplatePreview() {
      // Handle template selection clicks
      this.el.addEventListener('click', (e) => {
        const templateCard = e.target.closest('.template-preview-card');
        if (templateCard) {
          this.showLoadingState(templateCard);
        }
      });
    },

    updateTemplatePreview() {
      // Update template preview when customization changes
      this.updateColorOverlays();
    },

    showLoadingState(card) {
      const loading = card.querySelector('.template-loading');
      if (loading) {
        loading.classList.remove('hidden');
        loading.classList.add('flex');
        
        // Remove loading state after animation
        setTimeout(() => {
          loading.classList.add('hidden');
          loading.classList.remove('flex');
        }, 1000);
      }
    },

    updateColorOverlays() {
      const selectedCards = document.querySelectorAll('.template-preview-card.border-blue-500');
      selectedCards.forEach(card => {
        const overlay = card.querySelector('[style*="linear-gradient"]');
        if (overlay) {
          const primaryColor = getComputedStyle(document.documentElement)
            .getPropertyValue('--portfolio-primary-color').trim();
          const secondaryColor = getComputedStyle(document.documentElement)
            .getPropertyValue('--portfolio-secondary-color').trim();
          
          if (primaryColor && secondaryColor) {
            overlay.style.background = `linear-gradient(135deg, ${primaryColor}, ${secondaryColor})`;
          }
        }
      });
    }
  },

  // Color Picker Hook
  ColorPicker: {
    mounted() {
      console.log("🎨 Color Picker Hook mounted");
      this.initializeColorPicker();
    },

    initializeColorPicker() {
      // Real-time color updates
      const colorInputs = this.el.querySelectorAll('input[type="color"], input[type="text"]');
      
      colorInputs.forEach(input => {
        input.addEventListener('input', this.debounce((e) => {
          this.updateColorPreview(e.target);
        }, 300));
        
        input.addEventListener('change', (e) => {
          this.updateColorPreview(e.target);
        });
      });
    },

    updateColorPreview(input) {
      const colorValue = input.value;
      const colorField = input.name;
      
      if (this.isValidColor(colorValue)) {
        // Update CSS variable immediately for preview
        this.updateCSSVariable(colorField, colorValue);
        
        // Update related elements
        this.updateColorSwatches(colorField, colorValue);
        this.updateTemplateOverlays();
      }
    },

    updateCSSVariable(field, value) {
      const varName = `--portfolio-${field.replace('_', '-')}`;
      document.documentElement.style.setProperty(varName, value);
    },

    updateColorSwatches(field, value) {
      const swatchClass = `.color-swatch-${field.replace('_color', '')}`;
      const swatches = document.querySelectorAll(swatchClass);
      
      swatches.forEach(swatch => {
        swatch.style.backgroundColor = value;
      });
    },

    updateTemplateOverlays() {
      // Update template selection overlays
      const overlays = document.querySelectorAll('.template-preview-card [style*="linear-gradient"]');
      overlays.forEach(overlay => {
        const primaryColor = getComputedStyle(document.documentElement)
          .getPropertyValue('--portfolio-primary-color').trim();
        const secondaryColor = getComputedStyle(document.documentElement)
          .getPropertyValue('--portfolio-secondary-color').trim();
        
        if (primaryColor && secondaryColor) {
          overlay.style.background = `linear-gradient(135deg, ${primaryColor}, ${secondaryColor})`;
        }
      });
    },

    isValidColor(color) {
      return /^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$/.test(color);
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
    }
  },

  // Typography Preview Hook
  TypographyPreview: {
    mounted() {
      console.log("🎨 Typography Preview Hook mounted");
      this.initializeTypographyPreview();
    },

    initializeTypographyPreview() {
      const fontButtons = this.el.querySelectorAll('button[phx-click="update_typography"]');
      
      fontButtons.forEach(button => {
        button.addEventListener('click', (e) => {
          const fontFamily = e.target.closest('button').getAttribute('phx-value-font');
          this.previewFontChange(fontFamily);
        });
      });
    },

    previewFontChange(fontFamily) {
      const fontCSS = this.getFontFamilyCSS(fontFamily);
      document.documentElement.style.setProperty('--portfolio-font-family', fontCSS);
      
      // Highlight selected font button
      const buttons = this.el.querySelectorAll('button[phx-click="update_typography"]');
      buttons.forEach(btn => {
        btn.classList.remove('border-blue-500', 'bg-blue-50');
        btn.classList.add('border-gray-200');
      });
      
      const selectedButton = this.el.querySelector(`button[phx-value-font="${fontFamily}"]`);
      if (selectedButton) {
        selectedButton.classList.remove('border-gray-200');
        selectedButton.classList.add('border-blue-500', 'bg-blue-50');
      }
    },

    getFontFamilyCSS(fontFamily) {
      const fontMap = {
        'Inter': "'Inter', system-ui, sans-serif",
        'Merriweather': "'Merriweather', Georgia, serif",
        'JetBrains Mono': "'JetBrains Mono', 'Fira Code', monospace",
        'Playfair Display': "'Playfair Display', Georgia, serif"
      };
      
      return fontMap[fontFamily] || "system-ui, sans-serif";
    }
  },

  // Background Preview Hook
  BackgroundPreview: {
    mounted() {
      console.log("🎨 Background Preview Hook mounted");
      this.initializeBackgroundPreview();
    },

    initializeBackgroundPreview() {
      const backgroundButtons = this.el.querySelectorAll('button[phx-click="update_background"]');
      
      backgroundButtons.forEach(button => {
        button.addEventListener('click', (e) => {
          const background = e.target.closest('button').getAttribute('phx-value-background');
          this.previewBackgroundChange(background);
        });
      });
    },

    previewBackgroundChange(background) {
      // Apply background preview to body or preview container
      const previewContainer = document.querySelector('.portfolio-preview-container') || document.body;
      
      // Remove existing background classes
      previewContainer.classList.remove('bg-gradient-ocean', 'bg-gradient-sunset', 'bg-dark-mode');
      
      // Apply new background
      switch(background) {
        case 'gradient-ocean':
          previewContainer.style.background = 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)';
          break;
        case 'gradient-sunset':
          previewContainer.style.background = 'linear-gradient(135deg, #f093fb 0%, #f5576c 100%)';
          break;
        case 'dark-mode':
          previewContainer.style.background = '#1a1a1a';
          previewContainer.style.color = '#ffffff';
          break;
        default:
          previewContainer.style.background = '#ffffff';
          previewContainer.style.color = '#1f2937';
      }
      
      // Update button selection
      this.updateBackgroundSelection(background);
    },

    updateBackgroundSelection(selectedBackground) {
      const buttons = this.el.querySelectorAll('button[phx-click="update_background"]');
      buttons.forEach(btn => {
        btn.classList.remove('border-blue-500', 'ring-2', 'ring-blue-200');
        btn.classList.add('border-gray-200');
      });
      
      const selectedButton = this.el.querySelector(`button[phx-value-background="${selectedBackground}"]`);
      if (selectedButton) {
        selectedButton.classList.remove('border-gray-200');
        selectedButton.classList.add('border-blue-500', 'ring-2', 'ring-blue-200');
      }
    }
  },

  // CSS Injection Hook
  CSSInjector: {
    mounted() {
      console.log("🎨 CSS Injector Hook mounted");
      this.setupEventListeners();
    },

    setupEventListeners() {
      // Listen for Phoenix events for CSS updates
      window.addEventListener('phx:template-changed', (e) => {
        console.log('🎨 Template changed event received:', e.detail);
        this.injectCSS(e.detail.css);
        this.showTemplateChangeAnimation();
      });

      window.addEventListener('phx:color-updated', (e) => {
        console.log('🎨 Color updated event received:', e.detail);
        this.injectCSS(e.detail.css);
        this.showColorUpdateAnimation(e.detail.field);
      });

      window.addEventListener('phx:typography-updated', (e) => {
        console.log('🎨 Typography updated event received:', e.detail);
        this.injectCSS(e.detail.css);
        this.showTypographyAnimation();
      });

      window.addEventListener('phx:background-updated', (e) => {
        console.log('🎨 Background updated event received:', e.detail);
        this.injectCSS(e.detail.css);
        this.showBackgroundAnimation();
      });
    },

    injectCSS(cssContent) {
      // Remove existing portfolio CSS
      const existingStyle = document.getElementById('portfolio-customization-css');
      if (existingStyle) {
        existingStyle.remove();
      }
      
      // Inject new CSS
      const style = document.createElement('style');
      style.id = 'portfolio-customization-css';
      style.innerHTML = cssContent;
      document.head.appendChild(style);
      
      console.log('🎨 CSS injected successfully');
    },

    showTemplateChangeAnimation() {
      // Add subtle animation to indicate template change
      const templateCards = document.querySelectorAll('.template-preview-card');
      templateCards.forEach(card => {
        card.style.transform = 'scale(0.98)';
        card.style.transition = 'transform 0.3s ease';
        
        setTimeout(() => {
          card.style.transform = 'scale(1)';
        }, 150);
      });
    },

    showColorUpdateAnimation(field) {
      // Animate color swatches
      const swatches = document.querySelectorAll(`.color-swatch-${field.replace('_color', '')}`);
      swatches.forEach(swatch => {
        swatch.style.transform = 'scale(1.1)';
        swatch.style.transition = 'transform 0.2s ease';
        
        setTimeout(() => {
          swatch.style.transform = 'scale(1)';
        }, 200);
      });
    },

    showTypographyAnimation() {
      // Animate typography preview
      const preview = document.querySelector('.portfolio-preview');
      if (preview) {
        preview.style.opacity = '0.7';
        preview.style.transition = 'opacity 0.2s ease';
        
        setTimeout(() => {
          preview.style.opacity = '1';
        }, 200);
      }
    },

    showBackgroundAnimation() {
      // Animate background change
      const body = document.body;
      body.style.transition = 'background 0.4s ease';
    }
  }
};

// Utility functions
window.TemplateUtils = {
  // Update all color-related elements
  updateAllColors() {
    const primaryColor = getComputedStyle(document.documentElement)
      .getPropertyValue('--portfolio-primary-color').trim();
    const secondaryColor = getComputedStyle(document.documentElement)
      .getPropertyValue('--portfolio-secondary-color').trim();
    const accentColor = getComputedStyle(document.documentElement)
      .getPropertyValue('--portfolio-accent-color').trim();

    // Update color swatches
    this.updateColorSwatches('primary', primaryColor);
    this.updateColorSwatches('secondary', secondaryColor);
    this.updateColorSwatches('accent', accentColor);
    
    // Update template overlays
    this.updateTemplateOverlays(primaryColor, secondaryColor);
  },

  updateColorSwatches(type, color) {
    const swatches = document.querySelectorAll(`.color-swatch-${type}`);
    swatches.forEach(swatch => {
      swatch.style.backgroundColor = color;
    });
  },

  updateTemplateOverlays(primary, secondary) {
    const overlays = document.querySelectorAll('.template-preview-card [style*="linear-gradient"]');
    overlays.forEach(overlay => {
      overlay.style.background = `linear-gradient(135deg, ${primary}, ${secondary})`;
    });
  },

  // Preview refresh for iframe
  refreshPreview() {
    const previewFrame = document.querySelector('iframe[src*="/p/"]');
    if (previewFrame) {
      previewFrame.src = previewFrame.src + '&t=' + Date.now();
    }
  },

  // Smooth transitions
  addSmoothTransitions() {
    const style = document.createElement('style');
    style.innerHTML = `
      .portfolio-preview * {
        transition: color 0.2s ease, background-color 0.2s ease, border-color 0.2s ease !important;
      }
      .template-preview-card {
        transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1) !important;
      }
      .color-swatch-primary,
      .color-swatch-secondary,
      .color-swatch-accent {
        transition: background-color 0.2s ease, transform 0.2s ease !important;
      }
    `;
    document.head.appendChild(style);
  }
};

// Initialize smooth transitions on load
document.addEventListener('DOMContentLoaded', () => {
  window.TemplateUtils.addSmoothTransitions();
});

export default TemplateHooks;