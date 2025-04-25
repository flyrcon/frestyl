// assets/js/hooks/ticket_purchase.js
const TicketPurchase = {
  mounted() {
    // Initialize Stripe
    const stripe = Stripe(this.el.dataset.publicKey);
    
    // Set up event handlers for purchase buttons
    this.el.querySelectorAll('[phx-click="purchase-ticket"]').forEach(button => {
      button.addEventListener('click', async (event) => {
        event.preventDefault();
        
        const ticketTypeId = button.getAttribute('phx-value-ticket-type-id');
        const quantitySelect = document.getElementById(`quantity-${ticketTypeId}`);
        const quantity = quantitySelect.value;
        
        this.disableButton(button);
        
        try {
          // Create checkout session
          const response = await fetch('/tickets/checkout', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
            },
            body: JSON.stringify({
              ticket_type_id: ticketTypeId,
              quantity: quantity
            })
          });
          
          const data = await response.json();
          
          if (data.sessionId) {
            // Redirect to Stripe Checkout
            stripe.redirectToCheckout({
              sessionId: data.sessionId
            }).then((result) => {
              if (result.error) {
                this.showError(button, result.error.message);
              }
            });
          } else if (data.error) {
            this.showError(button, data.error);
          }
        } catch (error) {
          this.showError(button, 'An unexpected error occurred. Please try again.');
        }
      });
    });
  },
  
  disableButton(button) {
    button.disabled = true;
    button.textContent = 'Processing...';
  },
  
  enableButton(button) {
    button.disabled = false;
    button.textContent = 'Buy Tickets';
  },
  
  showError(button, message) {
    this.enableButton(button);
    
    // Show error message
    const errorId = `error-${button.getAttribute('phx-value-ticket-type-id')}`;
    let errorEl = document.getElementById(errorId);
    
    if (!errorEl) {
      errorEl = document.createElement('div');
      errorEl.id = errorId;
      errorEl.className = 'text-red-600 text-sm mt-2';
      button.parentNode.appendChild(errorEl);
    }
    
    errorEl.textContent = message;
  }
};

export default TicketPurchase;