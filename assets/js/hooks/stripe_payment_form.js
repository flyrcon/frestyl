// assets/js/hooks/stripe_payment_form.js
const StripePaymentForm = {
  mounted() {
    // Load Stripe
    const stripe = Stripe(this.el.dataset.publicKey);
    const elements = stripe.elements();
    
    // Create card element
    const cardElement = elements.create('card');
    cardElement.mount('#card-element');
    
    // Handle form submission
    document.getElementById('submit-payment').addEventListener('click', async (event) => {
      event.preventDefault();
      this.disableForm();
      
      const billingPeriod = document.querySelector('input[name="billing_period"]:checked').value;
      const planId = document.getElementById('plan_id').value;
      
      try {
        const { paymentMethod, error } = await stripe.createPaymentMethod({
          type: 'card',
          card: cardElement,
        });
        
        if (error) {
          this.handleError(error);
          return;
        }
        
        // Store payment method ID in form
        document.getElementById('payment_method_id').value = paymentMethod.id;
        
        // Submit form via AJAX
        const formData = new FormData();
        formData.append('plan_id', planId);
        formData.append('payment_method_id', paymentMethod.id);
        formData.append('is_yearly', billingPeriod === 'yearly');
        
        const response = await fetch('/subscriptions', {
          method: 'POST',
          body: formData,
          headers: {
            'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
          }
        });
        
        if (response.ok) {
          window.location.href = '/account/subscription';
        } else {
          const data = await response.json();
          this.handleError({ message: data.error || 'An error occurred during payment processing.' });
        }
      } catch (err) {
        this.handleError({ message: 'An unexpected error occurred. Please try again.' });
      }
    });
    
    // Handle card element change events
    cardElement.addEventListener('change', (event) => {
      const displayError = document.getElementById('card-errors');
      if (event.error) {
        displayError.textContent = event.error.message;
      } else {
        displayError.textContent = '';
      }
    });
  },
  
  disableForm() {
    document.getElementById('submit-payment').disabled = true;
    document.getElementById('submit-payment').textContent = 'Processing...';
  },
  
  enableForm() {
    document.getElementById('submit-payment').disabled = false;
    document.getElementById('submit-payment').textContent = 'Subscribe Now';
  },
  
  handleError(error) {
    const errorElement = document.getElementById('card-errors');
    errorElement.textContent = error.message;
    this.enableForm();
  }
};

export default StripePaymentForm;