// assets/js/hooks/comments_hooks.js

export const AutoScrollComments = {
  mounted() {
    this.shouldAutoScroll = true;
    this.lastCommentCount = this.countComments();
    
    // Scroll to bottom on mount if there are few comments
    if (this.lastCommentCount <= 5) {
      this.scrollToBottom();
    }
  },

  updated() {
    const currentCommentCount = this.countComments();
    
    // Only auto-scroll if new comments were added and user is near bottom
    if (currentCommentCount > this.lastCommentCount && this.isNearBottom()) {
      this.scrollToBottom();
    }
    
    this.lastCommentCount = currentCommentCount;
  },

  countComments() {
    return this.el.querySelectorAll('[data-comment-id]').length;
  },

  isNearBottom() {
    const threshold = 100; // pixels from bottom
    return (this.el.scrollTop + this.el.clientHeight + threshold) >= this.el.scrollHeight;
  },

  scrollToBottom() {
    setTimeout(() => {
      this.el.scrollTo({
        top: this.el.scrollHeight,
        behavior: 'smooth'
      });
    }, 100);
  }
};

