export const ChatHooks = {
  AutoResize: {
    mounted() {
      this.resize();
      this.el.addEventListener('input', e => this.resize());
    },
    resize() {
      this.el.style.height = 'auto';
      this.el.style.height = (this.el.scrollHeight) + 'px';
      // Limit max height
      if (parseInt(this.el.style.height) > 200) {
        this.el.style.height = '200px';
        this.el.style.overflowY = 'auto';
      } else {
        this.el.style.overflowY = 'hidden';
      }
    }
  },
  
  FileUpload: {
    mounted() {
      this.el.addEventListener('change', (e) => {
        const files = Array.from(e.target.files || []);
        const dropTarget = document.querySelector(`[phx-drop-target="${this.el.dataset.target}"]`);
        
        if (dropTarget) {
          // Create a new DataTransfer for LiveView's upload handling
          const dataTransfer = new DataTransfer();
          files.forEach(file => dataTransfer.items.add(file));
          
          // Create a custom drop event for LiveView to pick up
          const dropEvent = new Event('drop', { bubbles: true });
          
          // Add the dataTransfer property to the event
          Object.defineProperty(dropEvent, 'dataTransfer', {
            value: dataTransfer
          });
          
          // Dispatch the event to the drop target
          dropTarget.dispatchEvent(dropEvent);
          
          // Clear input after upload is triggered
          this.el.value = '';
        }
      });
    }
  },
  
  DragAndDrop: {
    mounted() {
      const overlay = this.el;
      const dropZone = document.querySelector(`[phx-drop-target]`);
      let dragCounter = 0;
      
      // Handle drag enter events at document level
      document.addEventListener('dragenter', (e) => {
        e.preventDefault();
        dragCounter++;
        if (dragCounter === 1) {
          overlay.classList.remove('hidden');
        }
      });
      
      // Handle drag leave events at document level
      document.addEventListener('dragleave', (e) => {
        e.preventDefault();
        dragCounter--;
        if (dragCounter === 0) {
          overlay.classList.add('hidden');
        }
      });
      
      // Handle drag over to prevent default browser behavior
      document.addEventListener('dragover', (e) => {
        e.preventDefault();
      });
      
      // Handle drop events
      document.addEventListener('drop', (e) => {
        e.preventDefault();
        dragCounter = 0;
        overlay.classList.add('hidden');
        
        // If drop outside the drop zone, do nothing
        if (!dropZone.contains(e.target) && e.target !== dropZone) {
          return;
        }
        
        // Otherwise let LiveView handle the drop
      });
      
      // Reset counter on drop in any element
      document.addEventListener('drop', () => {
        dragCounter = 0;
        overlay.classList.add('hidden');
      });
    }
  },
  
  ScrollToBottom: {
    mounted() {
      this.scrollToBottom();
      
      // Observe changes to the messages container
      const observer = new MutationObserver(() => {
        this.scrollToBottom();
      });
      
      // Start observing the container for changes
      observer.observe(this.el, { 
        childList: true, 
        subtree: true 
      });
    },
    
    scrollToBottom() {
      this.el.scrollTop = this.el.scrollHeight;
    }
  }
};