const PortfolioEditorFixedHooks = {
  MobileNavigation: {
    mounted() {
      console.log("📱 MobileNavigation hook mounted");
    }
  },
  
  FloatingButtons: {
    mounted() {
      console.log("📱 FloatingButtons hook mounted");
    }
  },
  
  PreviewDevice: {
    mounted() {
      console.log("📱 PreviewDevice hook mounted");
    }
  },
  
  LivePreviewManager: {
    mounted() {
      console.log("🖥️ LivePreviewManager hook mounted");
      this.setupPreviewRefresh();
    },

    setupPreviewRefresh() {
      this.handleEvent("refresh_portfolio_preview", (data) => {
        console.log("🔄 Refreshing portfolio preview", data);
        const iframe = document.getElementById('portfolio-preview');
        if (iframe) {
          const url = new URL(iframe.src);
          url.searchParams.set('t', Date.now());
          iframe.src = url.toString();
        }
      });
    }
  }
};

export default PortfolioEditorFixedHooks;