// Notification management hooks
export const NotificationManager = {
  mounted() {
    this.notifications = new Map();
  },

  destroyed() {
    // Clear all timers when component is destroyed
    this.notifications.forEach(timer => clearTimeout(timer));
    this.notifications.clear();
  }
};

export const NotificationItem = {
  mounted() {
    const id = this.el.dataset.notificationId;
    const autoDismiss = this.el.dataset.autoDismiss === "true";
    const dismissAfter = parseInt(this.el.dataset.dismissAfter) || 5000;

    // Add entrance animation
    this.el.style.transform = "translateX(100%) scale(0.8)";
    this.el.style.opacity = "0";
    
    requestAnimationFrame(() => {
      this.el.style.transition = "all 0.3s cubic-bezier(0.34, 1.56, 0.64, 1)";
      this.el.style.transform = "translateX(0) scale(1)";
      this.el.style.opacity = "1";
    });

    // Set up auto-dismiss if enabled
    if (autoDismiss) {
      this.setupProgressBar(dismissAfter);
      this.dismissTimer = setTimeout(() => {
        this.dismiss();
      }, dismissAfter);
    }
  },

  setupProgressBar(duration) {
    const progressBar = this.el.querySelector('.notification-progress');
    if (progressBar) {
      progressBar.style.transition = `width ${duration}ms linear`;
      progressBar.style.width = '0%';
    }
  },

  dismiss() {
    // Add exit animation
    this.el.style.transition = "all 0.3s ease-in";
    this.el.style.transform = "translateX(100%) scale(0.8)";
    this.el.style.opacity = "0";
    
    setTimeout(() => {
      const id = this.el.dataset.notificationId;
      this.pushEvent("dismiss_notification", { id });
    }, 300);
  },

  destroyed() {
    if (this.dismissTimer) {
      clearTimeout(this.dismissTimer);
    }
  }
};