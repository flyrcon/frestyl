// assets/js/portfolio_studio_integration.js

/**
 * Portfolio Studio Integration
 * Handles the smooth transition from Portfolio to Studio collaboration
 */

export const PortfolioStudioIntegration = {
  mounted() {
    this.initializeEnhancementCards();
    this.initializeStudioWelcome();
    this.initializeQuarterlyReminders();
  },

  updated() {
    this.initializeEnhancementCards();
  },

  initializeEnhancementCards() {
    const enhancementCards = document.querySelectorAll('[data-enhancement-card]');
    
    enhancementCards.forEach(card => {
      // Add smooth hover animations
      card.addEventListener('mouseenter', () => {
        card.style.transform = 'translateY(-4px) scale(1.02)';
        card.style.boxShadow = '0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04)';
      });

      card.addEventListener('mouseleave', () => {
        card.style.transform = 'translateY(0) scale(1)';
        card.style.boxShadow = '';
      });

      // Add click ripple effect
      card.addEventListener('click', (e) => {
        const ripple = document.createElement('div');
        const rect = card.getBoundingClientRect();
        const size = Math.max(rect.width, rect.height);
        const x = e.clientX - rect.left - size / 2;
        const y = e.clientY - rect.top - size / 2;

        ripple.style.cssText = `
          position: absolute;
          width: ${size}px;
          height: ${size}px;
          left: ${x}px;
          top: ${y}px;
          background: rgba(139, 92, 246, 0.3);
          border-radius: 50%;
          transform: scale(0);
          animation: ripple 0.6s linear;
          pointer-events: none;
          z-index: 1;
        `;

        card.style.position = 'relative';
        card.style.overflow = 'hidden';
        card.appendChild(ripple);

        setTimeout(() => {
          ripple.remove();
        }, 600);
      });
    });

    // Add CSS for ripple animation if not exists
    if (!document.querySelector('#ripple-animation-styles')) {
      const style = document.createElement('style');
      style.id = 'ripple-animation-styles';
      style.textContent = `
        @keyframes ripple {
          to {
            transform: scale(4);
            opacity: 0;
          }
        }
      `;
      document.head.appendChild(style);
    }
  },

  initializeStudioWelcome() {
    // Check if user is new to Studio collaboration
    const hasSeenStudioWelcome = localStorage.getItem('frestyl_studio_welcome_seen');
    const enhancementSection = document.querySelector('[data-enhancement-section]');
    
    if (!hasSeenStudioWelcome && enhancementSection) {
      // Show a subtle pulsing animation on the first enhancement suggestion
      const firstSuggestion = enhancementSection.querySelector('[data-enhancement-card]');
      if (firstSuggestion) {
        firstSuggestion.classList.add('animate-pulse');
        
        // Add a tooltip
        this.showWelcomeTooltip(firstSuggestion);
      }
    }
  },

  showWelcomeTooltip(element) {
    const tooltip = document.createElement('div');
    tooltip.className = 'absolute -top-12 left-1/2 transform -translate-x-1/2 bg-purple-600 text-white text-sm px-3 py-2 rounded-lg shadow-lg z-50';
    tooltip.innerHTML = `
      <div class="relative">
        ✨ Try collaboration!
        <div class="absolute top-full left-1/2 transform -translate-x-1/2 border-4 border-transparent border-t-purple-600"></div>
      </div>
    `;

    element.style.position = 'relative';
    element.appendChild(tooltip);

    // Auto-hide after 5 seconds
    setTimeout(() => {
      tooltip.remove();
      element.classList.remove('animate-pulse');
    }, 5000);
  },

  initializeQuarterlyReminders() {
    const quarterlyReminders = document.querySelectorAll('[data-quarterly-reminder]');
    
    quarterlyReminders.forEach((reminder, index) => {
      // Stagger the appearance of reminders
      reminder.style.opacity = '0';
      reminder.style.transform = 'translateY(20px)';
      
      setTimeout(() => {
        reminder.style.transition = 'all 0.5s ease-out';
        reminder.style.opacity = '1';
        reminder.style.transform = 'translateY(0)';
      }, index * 200);
    });
  },

  // Handle portfolio enhancement selection
  handleEnhancementSelection(enhancementType, portfolioId) {
    // Show loading state
    this.showEnhancementLoadingState(enhancementType);
    
    // Track analytics
    this.trackEnhancementStart(enhancementType, portfolioId);
    
    // Show preparation modal
    this.showPreparationModal(enhancementType);
  },

  showEnhancementLoadingState(enhancementType) {
    const loadingOverlay = document.createElement('div');
    loadingOverlay.id = 'enhancement-loading';
    loadingOverlay.className = 'fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50';
    loadingOverlay.innerHTML = `
      <div class="bg-white rounded-xl p-8 max-w-md mx-4 text-center">
        <div class="animate-spin w-12 h-12 border-4 border-purple-600 border-t-transparent rounded-full mx-auto mb-4"></div>
        <h3 class="text-lg font-bold text-gray-900 mb-2">Setting up your Studio...</h3>
        <p class="text-gray-600">Preparing collaboration tools for ${this.formatEnhancementType(enhancementType)}</p>
      </div>
    `;
    
    document.body.appendChild(loadingOverlay);
  },

  showPreparationModal(enhancementType) {
    const tips = this.getEnhancementTips(enhancementType);
    
    setTimeout(() => {
      const loadingOverlay = document.getElementById('enhancement-loading');
      if (loadingOverlay) {
        loadingOverlay.innerHTML = `
          <div class="bg-white rounded-xl p-8 max-w-md mx-4">
            <div class="text-center mb-6">
              <div class="w-16 h-16 bg-gradient-to-r from-purple-600 to-indigo-600 rounded-full flex items-center justify-center mx-auto mb-4">
                <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
                </svg>
              </div>
              <h3 class="text-xl font-bold text-gray-900 mb-2">Studio Ready!</h3>
              <p class="text-gray-600">Your ${this.formatEnhancementType(enhancementType)} workspace is prepared</p>
            </div>
            
            <div class="bg-purple-50 rounded-lg p-4 mb-6">
              <h4 class="font-medium text-purple-900 mb-2">💡 Pro Tips:</h4>
              <ul class="text-sm text-purple-800 space-y-1">
                ${tips.map(tip => `<li>• ${tip}</li>`).join('')}
              </ul>
            </div>
            
            <button onclick="this.parentElement.parentElement.remove()" 
                    class="w-full py-3 bg-gradient-to-r from-purple-600 to-indigo-600 text-white rounded-lg font-medium hover:shadow-lg transition-all">
              Enter Studio →
            </button>
          </div>
        `;
      }
    }, 2000);
  },

  getEnhancementTips(enhancementType) {
    const tipMap = {
      'voice_intro': [
        'Write your script first in the editor',
        'Practice a few times before recording',
        'Keep it under 60 seconds for best impact'
      ],
      'enhance_writing': [
        'Share your current content for review',
        'Be specific about your goals',
        'Ask for feedback on tone and clarity'
      ],
      'background_music': [
        'Think about your portfolio\'s mood',
        'Consider your industry and audience',
        'Subtle is usually better than prominent'
      ],
      'quarterly_update': [
        'List your recent achievements',
        'Update project descriptions',
        'Add new skills and experiences'
      ]
    };

    return tipMap[enhancementType] || [
      'Communicate clearly with your collaborators',
      'Share specific feedback and goals',
      'Be open to creative suggestions'
    ];
  },

  formatEnhancementType(type) {
    const formatMap = {
      'voice_intro': 'Voice Introduction',
      'enhance_writing': 'Writing Enhancement',
      'background_music': 'Background Music',
      'design_feedback': 'Design Feedback',
      'quarterly_update': 'Quarterly Update'
    };

    return formatMap[type] || 'Portfolio Enhancement';
  },

  trackEnhancementStart(enhancementType, portfolioId) {
    // Analytics tracking
    if (window.analytics) {
      window.analytics.track('Portfolio Enhancement Started', {
        enhancement_type: enhancementType,
        portfolio_id: portfolioId,
        source: 'dashboard'
      });
    }
  },

  // Mark Studio welcome as seen
  markStudioWelcomeSeen() {
    localStorage.setItem('frestyl_studio_welcome_seen', 'true');
  },

  // Handle quarterly reminder interactions
  handleQuarterlyReminderClick(portfolioId) {
    this.trackQuarterlyUpdateStart(portfolioId);
    
    // Show preparation checklist
    this.showQuarterlyUpdateChecklist();
  },

  showQuarterlyUpdateChecklist() {
    const modal = document.createElement('div');
    modal.className = 'fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50';
    modal.innerHTML = `
      <div class="bg-white rounded-xl p-8 max-w-lg mx-4">
        <div class="text-center mb-6">
          <div class="w-16 h-16 bg-gradient-to-r from-yellow-500 to-orange-500 rounded-full flex items-center justify-center mx-auto mb-4">
            <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
            </svg>
          </div>
          <h3 class="text-xl font-bold text-gray-900 mb-2">Quarterly Update Checklist</h3>
          <p class="text-gray-600">Let's review what to update in your portfolio</p>
        </div>
        
        <div class="space-y-3 mb-6">
          <label class="flex items-center p-3 border border-gray-200 rounded-lg hover:bg-gray-50 cursor-pointer">
            <input type="checkbox" class="mr-3 text-purple-600 rounded">
            <div>
              <div class="font-medium text-gray-900">Recent Projects</div>
              <div class="text-sm text-gray-600">Add or update your latest work</div>
            </div>
          </label>
          
          <label class="flex items-center p-3 border border-gray-200 rounded-lg hover:bg-gray-50 cursor-pointer">
            <input type="checkbox" class="mr-3 text-purple-600 rounded">
            <div>
              <div class="font-medium text-gray-900">Skills & Technologies</div>
              <div class="text-sm text-gray-600">Update your technical skills list</div>
            </div>
          </label>
          
          <label class="flex items-center p-3 border border-gray-200 rounded-lg hover:bg-gray-50 cursor-pointer">
            <input type="checkbox" class="mr-3 text-purple-600 rounded">
            <div>
              <div class="font-medium text-gray-900">Professional Experience</div>
              <div class="text-sm text-gray-600">Add new roles or responsibilities</div>
            </div>
          </label>
          
          <label class="flex items-center p-3 border border-gray-200 rounded-lg hover:bg-gray-50 cursor-pointer">
            <input type="checkbox" class="mr-3 text-purple-600 rounded">
            <div>
              <div class="font-medium text-gray-900">Achievements & Metrics</div>
              <div class="text-sm text-gray-600">Highlight recent accomplishments</div>
            </div>
          </label>
        </div>
        
        <div class="flex space-x-3">
          <button onclick="this.closest('.fixed').remove()" 
                  class="flex-1 py-3 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors">
            Maybe Later
          </button>
          <button onclick="this.closest('.fixed').remove()" 
                  class="flex-1 py-3 bg-gradient-to-r from-yellow-500 to-orange-500 text-white rounded-lg hover:shadow-lg transition-all font-medium">
            Start Update
          </button>
        </div>
      </div>
    `;
    
    document.body.appendChild(modal);
  },

  trackQuarterlyUpdateStart(portfolioId) {
    if (window.analytics) {
      window.analytics.track('Quarterly Update Started', {
        portfolio_id: portfolioId,
        source: 'dashboard_reminder'
      });
    }
  },

  // Handle channel workspace transitions
  initializeChannelTransition() {
    // Listen for channel creation success
    this.handleEvent('channel_created', (data) => {
      this.showChannelTransitionSuccess(data.channel_type, data.channel_slug);
    });
  },

  showChannelTransitionSuccess(channelType, channelSlug) {
    const successMessage = document.createElement('div');
    successMessage.className = 'fixed bottom-4 right-4 bg-green-500 text-white p-4 rounded-lg shadow-lg z-50 transform translate-y-full transition-transform';
    successMessage.innerHTML = `
      <div class="flex items-center">
        <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
        </svg>
        Studio workspace created! Redirecting...
      </div>
    `;
    
    document.body.appendChild(successMessage);
    
    // Animate in
    setTimeout(() => {
      successMessage.style.transform = 'translateY(0)';
    }, 100);
    
    // Auto-remove
    setTimeout(() => {
      successMessage.style.transform = 'translateY(full)';
      setTimeout(() => successMessage.remove(), 300);
    }, 3000);
  },

  // Studio integration for existing portfolios
  addStudioOptionsToPortfolioCards() {
    const portfolioCards = document.querySelectorAll('[data-portfolio-card]');
    
    portfolioCards.forEach(card => {
      const portfolioId = card.dataset.portfolioId;
      
      // Add enhance button to portfolio card
      const actionsContainer = card.querySelector('.portfolio-actions');
      if (actionsContainer && !actionsContainer.querySelector('.enhance-btn')) {
        const enhanceBtn = document.createElement('button');
        enhanceBtn.className = 'enhance-btn w-full inline-flex items-center justify-center px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors text-sm font-medium';
        enhanceBtn.innerHTML = `
          <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
          </svg>
          Enhance with Studio
        `;
        
        enhanceBtn.addEventListener('click', (e) => {
          e.preventDefault();
          this.showEnhancementOptions(portfolioId);
        });
        
        actionsContainer.appendChild(enhanceBtn);
      }
    });
  },

  showEnhancementOptions(portfolioId) {
    const modal = document.createElement('div');
    modal.className = 'fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50';
    modal.innerHTML = `
      <div class="bg-white rounded-xl p-6 max-w-md mx-4">
        <div class="text-center mb-6">
          <h3 class="text-xl font-bold text-gray-900 mb-2">Enhance Your Portfolio</h3>
          <p class="text-gray-600">Choose what you'd like to improve with Studio collaboration</p>
        </div>
        
        <div class="space-y-3">
          <button class="enhancement-option w-full p-4 text-left border border-gray-200 rounded-lg hover:border-purple-300 hover:bg-purple-50 transition-all" 
                  data-type="voice_intro">
            <div class="flex items-center">
              <span class="text-2xl mr-3">🎙️</span>
              <div>
                <div class="font-medium text-gray-900">Add Voice Introduction</div>
                <div class="text-sm text-gray-600">Record a personal intro video</div>
              </div>
            </div>
          </button>
          
          <button class="enhancement-option w-full p-4 text-left border border-gray-200 rounded-lg hover:border-purple-300 hover:bg-purple-50 transition-all" 
                  data-type="enhance_writing">
            <div class="flex items-center">
              <span class="text-2xl mr-3">✍️</span>
              <div>
                <div class="font-medium text-gray-900">Enhance Writing</div>
                <div class="text-sm text-gray-600">Improve project descriptions</div>
              </div>
            </div>
          </button>
          
          <button class="enhancement-option w-full p-4 text-left border border-gray-200 rounded-lg hover:border-purple-300 hover:bg-purple-50 transition-all" 
                  data-type="background_music">
            <div class="flex items-center">
              <span class="text-2xl mr-3">🎵</span>
              <div>
                <div class="font-medium text-gray-900">Add Background Music</div>
                <div class="text-sm text-gray-600">Create custom portfolio music</div>
              </div>
            </div>
          </button>
          
          <button class="enhancement-option w-full p-4 text-left border border-gray-200 rounded-lg hover:border-purple-300 hover:bg-purple-50 transition-all" 
                  data-type="design_feedback">
            <div class="flex items-center">
              <span class="text-2xl mr-3">🎨</span>
              <div>
                <div class="font-medium text-gray-900">Get Design Feedback</div>
                <div class="text-sm text-gray-600">Review visual design choices</div>
              </div>
            </div>
          </button>
        </div>
        
        <div class="mt-6 flex space-x-3">
          <button onclick="this.closest('.fixed').remove()" 
                  class="flex-1 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors">
            Cancel
          </button>
        </div>
      </div>
    `;
    
    document.body.appendChild(modal);
    
    // Add click handlers for enhancement options
    modal.querySelectorAll('.enhancement-option').forEach(btn => {
      btn.addEventListener('click', () => {
        const enhancementType = btn.dataset.type;
        modal.remove();
        
        // Trigger LiveView event
        this.pushEvent('enhance_portfolio', {
          type: enhancementType,
          portfolio_id: portfolioId
        });
      });
    });
  },

  // Initialize everything when component mounts
  init() {
    this.initializeEnhancementCards();
    this.initializeStudioWelcome();
    this.initializeQuarterlyReminders();
    this.initializeChannelTransition();
    this.addStudioOptionsToPortfolioCards();
  }
};

// Initialize when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => {
    PortfolioStudioIntegration.init();
  });
} else {
  PortfolioStudioIntegration.init();
}