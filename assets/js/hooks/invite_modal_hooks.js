// Invite Modal Hooks
export const InviteModalHook = {
  mounted() {
    this.setupKeyboardHandling();
    this.setupClipboard();
  },

  setupKeyboardHandling() {
    // Handle escape key to close modal
    this.handleEvent("keydown", (e) => {
      if (e.key === "Escape") {
        this.pushEvent("close_modal", {});
      }
    });

    // Handle enter key in search input
    const searchInput = this.el.querySelector('input[type="text"]:not([readonly])');
    if (searchInput) {
      searchInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') {
          e.preventDefault();
          // Focus first search result if available
          const firstResult = this.el.querySelector('[data-user-id]');
          if (firstResult) {
            firstResult.click();
          }
        }
      });
    }
  },

  setupClipboard() {
    // Handle copy to clipboard events
    this.handleEvent("copy_to_clipboard", ({ text }) => {
      if (navigator.clipboard && window.isSecureContext) {
        navigator.clipboard.writeText(text).then(() => {
          console.log('Copied to clipboard');
        }).catch((err) => {
          console.error('Failed to copy: ', err);
          this.fallbackCopyTextToClipboard(text);
        });
      } else {
        this.fallbackCopyTextToClipboard(text);
      }
    });
  },

  fallbackCopyTextToClipboard(text) {
    const textArea = document.createElement("textarea");
    textArea.value = text;
    
    // Avoid scrolling to bottom
    textArea.style.top = "0";
    textArea.style.left = "0";
    textArea.style.position = "fixed";
    textArea.style.opacity = "0";

    document.body.appendChild(textArea);
    textArea.focus();
    textArea.select();

    try {
      const successful = document.execCommand('copy');
      if (!successful) {
        throw new Error('Copy command failed');
      }
    } catch (err) {
      console.error('Fallback copy failed: ', err);
    }

    document.body.removeChild(textArea);
  }
};