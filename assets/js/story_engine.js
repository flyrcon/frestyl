export const StoryEngine = {
  mounted() {
    this.initializeIntentFlow();
    this.setupFormatCards();
    this.initializeQuickActions();
  },

  initializeIntentFlow() {
    // Handle intent category selection
    this.el.addEventListener('click', (e) => {
      const intentCard = e.target.closest('.intent-category');
      if (intentCard) {
        this.updateIntentSelection(intentCard);
      }
    });
  },

  setupFormatCards() {
    // Add hover effects and interactions for format cards
    const formatCards = this.el.querySelectorAll('.story-format-card');
    
    formatCards.forEach(card => {
      card.addEventListener('mouseenter', () => {
        const preview = card.querySelector('.format-preview');
        if (preview) {
          preview.style.transform = 'scale(1.05)';
        }
      });

      card.addEventListener('mouseleave', () => {
        const preview = card.querySelector('.format-preview');
        if (preview) {
          preview.style.transform = 'scale(1)';
        }
      });
    });
  },

  initializeQuickActions() {
    // Handle quick action animations
    const quickButtons = this.el.querySelectorAll('[phx-click="quick_create"]');
    
    quickButtons.forEach(button => {
      button.addEventListener('click', () => {
        button.style.transform = 'scale(0.95)';
        setTimeout(() => {
          button.style.transform = 'scale(1)';
        }, 150);
      });
    });
  },

  updateIntentSelection(selectedCard) {
    // Remove active state from all cards
    this.el.querySelectorAll('.intent-category').forEach(card => {
      card.classList.remove('ring-2', 'ring-blue-500', 'bg-blue-50');
    });

    // Add active state to selected card
    selectedCard.classList.add('ring-2', 'ring-blue-500', 'bg-blue-50');
  },

  // LiveView event handlers
  handleEvent("intent_changed", {intent}) {
    console.log(`Intent changed to: ${intent}`);
    this.trackAnalytics("intent_selected", {intent});
  },

  handleEvent("show_upgrade_modal", modalData) {
    this.showUpgradeModal(modalData);
  },

  showUpgradeModal(data) {
    // Create and show upgrade modal
    const modal = document.createElement('div');
    modal.className = 'fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50';
    modal.innerHTML = `
      <div class="bg-white rounded-xl shadow-xl max-w-md w-full mx-4 p-6">
        <h3 class="text-lg font-semibold text-gray-900 mb-4">${data.title}</h3>
        <p class="text-gray-600 mb-6">${data.reason}</p>
        <div class="space-y-2 mb-6">
          ${data.benefits.map(benefit => `
            <div class="flex items-center space-x-2">
              <svg class="w-4 h-4 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
              </svg>
              <span class="text-sm text-gray-700">${benefit}</span>
            </div>
          `).join('')}
        </div>
        <div class="flex space-x-3">
          <button onclick="this.closest('.fixed').remove()" 
                  class="flex-1 bg-gray-200 text-gray-800 py-2 rounded-lg">
            Maybe Later
          </button>
          <button onclick="window.location.href='/billing/upgrade'" 
                  class="flex-1 bg-blue-600 text-white py-2 rounded-lg">
            ${data.price}
          </button>
        </div>
      </div>
    `;
    
    document.body.appendChild(modal);
  },

  trackAnalytics(event, data) {
    // Send analytics events
    if (window.analytics) {
      window.analytics.track(event, data);
    }
  }
};