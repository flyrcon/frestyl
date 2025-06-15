// assets/js/hooks/pdf_download.js
export const PdfDownload = {
  mounted() {
    this.handleEvent("pdf-ready", ({ download_url }) => {
      // Create a temporary link and trigger download
      const link = document.createElement('a');
      link.href = download_url;
      link.download = `portfolio-${Date.now()}.pdf`;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      
      // Show success message
      this.pushEvent("pdf-downloaded", { url: download_url });
    });
  },
  
  destroyed() {
    // Cleanup if needed
  }
};

// Alternative method for inline PDF exports
export const InlinePdfExport = {
  mounted() {
    this.el.addEventListener('click', (e) => {
      e.preventDefault();
      
      // Show loading state
      const originalText = this.el.textContent;
      this.el.textContent = 'Generating PDF...';
      this.el.disabled = true;
      
      // Get portfolio slug from data attribute
      const portfolioSlug = this.el.dataset.portfolioSlug;
      const exportFormat = this.el.dataset.exportFormat || 'portfolio';
      
      // Make request to PDF export endpoint
      fetch(`/api/portfolios/${portfolioSlug}/export`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({ format: exportFormat })
      })
      .then(response => {
        if (!response.ok) {
          throw new Error('Export failed');
        }
        return response.blob();
      })
      .then(blob => {
        // Create download link
        const url = window.URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.download = `portfolio-${portfolioSlug}-${exportFormat}.pdf`;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        window.URL.revokeObjectURL(url);
        
        // Reset button
        this.el.textContent = originalText;
        this.el.disabled = false;
        
        // Show success message
        this.pushEvent("pdf-export-success", { format: exportFormat });
      })
      .catch(error => {
        console.error('PDF export failed:', error);
        
        // Reset button
        this.el.textContent = originalText;
        this.el.disabled = false;
        
        // Show error message
        this.pushEvent("pdf-export-error", { error: error.message });
      });
    });
  }
};

// Hook for print functionality
export const PrintPortfolio = {
  mounted() {
    this.el.addEventListener('click', (e) => {
      e.preventDefault();
      
      // Add print-specific styles
      const printStyles = document.createElement('style');
      printStyles.textContent = `
        @media print {
          .no-print, header, nav, .action-buttons { 
            display: none !important; 
          }
          .portfolio-section { 
            break-inside: avoid; 
            margin-bottom: 20px; 
          }
          body { 
            margin: 0; 
            padding: 20px; 
            font-size: 12pt; 
            line-height: 1.4; 
          }
          .portfolio-section h2 { 
            color: #1f2937 !important; 
            font-size: 16pt; 
          }
          .portfolio-section h3 { 
            color: #374151 !important; 
            font-size: 14pt; 
          }
          .skills-grid, .projects-grid {
            display: flex !important;
            flex-wrap: wrap !important;
            gap: 8px !important;
          }
          .skill-tag, .project-card {
            border: 1px solid #ccc !important;
            padding: 4px 8px !important;
            margin: 2px !important;
            break-inside: avoid !important;
          }
        }
      `;
      
      document.head.appendChild(printStyles);
      
      // Trigger print
      window.print();
      
      // Remove print styles after printing
      setTimeout(() => {
        document.head.removeChild(printStyles);
      }, 1000);
    });
  }
};

// Hook for sharing functionality
export const SharePortfolio = {
  mounted() {
    this.handleEvent("copy-link", ({ url }) => {
      navigator.clipboard.writeText(url).then(() => {
        // Show success feedback
        this.pushEvent("link-copied", {});
      }).catch(err => {
        // Fallback for older browsers
        const textArea = document.createElement('textarea');
        textArea.value = url;
        document.body.appendChild(textArea);
        textArea.select();
        document.execCommand('copy');
        document.body.removeChild(textArea);
        
        this.pushEvent("link-copied", {});
      });
    });
  }
};