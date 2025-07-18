// Section Modal Functionality for PATCH 4
// Add this to your app.js file or include as separate JS file

// Global modal management
window.sectionModals = {
  openModals: new Set(),
  
  open(sectionId) {
    const modal = document.getElementById(`modal-${sectionId}`);
    if (!modal) return;
    
    // Add to tracking
    this.openModals.add(sectionId);
    
    // Show modal with animation
    modal.classList.remove('hidden');
    modal.style.opacity = '0';
    
    // Animate in
    requestAnimationFrame(() => {
      modal.style.transition = 'opacity 300ms ease';
      modal.style.opacity = '1';
    });
    
    // Prevent body scroll
    document.body.classList.add('modal-open');
    
    // Focus management
    this.trapFocus(modal);
    
    // Escape key handler
    this.addEscapeListener(sectionId);
  },
  
  close(sectionId) {
    const modal = document.getElementById(`modal-${sectionId}`);
    if (!modal) return;
    
    // Remove from tracking
    this.openModals.delete(sectionId);
    
    // Animate out
    modal.style.transition = 'opacity 300ms ease';
    modal.style.opacity = '0';
    
    setTimeout(() => {
      modal.classList.add('hidden');
      modal.style.transition = '';
    }, 300);
    
    // Restore body scroll if no modals open
    if (this.openModals.size === 0) {
      document.body.classList.remove('modal-open');
    }
    
    // Remove escape listener
    this.removeEscapeListener(sectionId);
  },
  
  trapFocus(modal) {
    const focusableElements = modal.querySelectorAll(
      'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    );
    
    if (focusableElements.length === 0) return;
    
    const firstElement = focusableElements[0];
    const lastElement = focusableElements[focusableElements.length - 1];
    
    // Focus first element
    firstElement.focus();
    
    // Tab trap
    modal.addEventListener('keydown', (e) => {
      if (e.key === 'Tab') {
        if (e.shiftKey) {
          if (document.activeElement === firstElement) {
            e.preventDefault();
            lastElement.focus();
          }
        } else {
          if (document.activeElement === lastElement) {
            e.preventDefault();
            firstElement.focus();
          }
        }
      }
    });
  },
  
  addEscapeListener(sectionId) {
    const handler = (e) => {
      if (e.key === 'Escape') {
        this.close(sectionId);
      }
    };
    
    document.addEventListener('keydown', handler);
    // Store handler for removal
    document._escapeHandlers = document._escapeHandlers || {};
    document._escapeHandlers[sectionId] = handler;
  },
  
  removeEscapeListener(sectionId) {
    const handler = document._escapeHandlers?.[sectionId];
    if (handler) {
      document.removeEventListener('keydown', handler);
      delete document._escapeHandlers[sectionId];
    }
  }
};

// Global functions for template calls
window.openSectionModal = function(sectionId) {
  window.sectionModals.open(sectionId);
  
  // Analytics tracking (optional)
  if (window.gtag) {
    gtag('event', 'section_modal_open', {
      section_id: sectionId,
      section_type: document.querySelector(`[data-section-id="${sectionId}"]`)?.dataset.sectionType
    });
  }
};

window.closeSectionModal = function(sectionId, event) {
  // Prevent closing when clicking inside modal content
  if (event && event.target.closest('.modal-content') && !event.target.closest('.modal-close')) {
    return;
  }
  
  window.sectionModals.close(sectionId);
};

window.shareSectionContent = function(sectionId) {
  const section = document.querySelector(`[data-section-id="${sectionId}"]`);
  const title = section?.querySelector('.section-title')?.textContent || 'Portfolio Section';
  
  if (navigator.share) {
    navigator.share({
      title: title,
      text: `Check out this section from my portfolio: ${title}`,
      url: `${window.location.href}#section-${sectionId}`
    }).catch(err => console.log('Error sharing:', err));
  } else {
    // Fallback: copy to clipboard
    const url = `${window.location.href}#section-${sectionId}`;
    navigator.clipboard.writeText(url).then(() => {
      // Show notification
      showNotification('Link copied to clipboard!');
    });
  }
};

// Notification helper
window.showNotification = function(message, type = 'success') {
  const notification = document.createElement('div');
  notification.className = `fixed top-4 right-4 z-50 px-4 py-2 rounded-lg text-white ${
    type === 'success' ? 'bg-green-500' : 'bg-red-500'
  } transform translate-x-full transition-transform duration-300`;
  notification.textContent = message;
  
  document.body.appendChild(notification);
  
  // Animate in
  requestAnimationFrame(() => {
    notification.style.transform = 'translateX(0)';
  });
  
  // Auto remove
  setTimeout(() => {
    notification.style.transform = 'translateX(100%)';
    setTimeout(() => notification.remove(), 300);
  }, 3000);
};

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
  // Add modal-open class styles if not present
  if (!document.getElementById('modal-styles')) {
    const style = document.createElement('style');
    style.id = 'modal-styles';
    style.textContent = `
      .modal-open {
        overflow: hidden;
      }
      
      .scrollbar-thin {
        scrollbar-width: thin;
      }
      
      .scrollbar-thumb-gray-300::-webkit-scrollbar-thumb {
        background-color: #d1d5db;
        border-radius: 6px;
      }
      
      .scrollbar-track-gray-100::-webkit-scrollbar-track {
        background-color: #f3f4f6;
        border-radius: 6px;
      }
      
      .scrollbar-thin::-webkit-scrollbar {
        width: 6px;
        height: 6px;
      }
      
      .line-clamp-2 {
        display: -webkit-box;
        -webkit-line-clamp: 2;
        -webkit-box-orient: vertical;
        overflow: hidden;
      }
    `;
    document.head.appendChild(style);
  }
  
  // Handle direct links to sections
  if (window.location.hash.startsWith('#section-')) {
    const sectionId = window.location.hash.replace('#section-', '');
    setTimeout(() => {
      openSectionModal(sectionId);
    }, 500);
  }
  
  console.log('✅ Section modals initialized');
});