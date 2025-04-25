// assets/js/hooks.js
const Hooks = {}

Hooks.Countdown = {
  mounted() {
    this.countdownInterval = setInterval(() => {
      this.updateCountdown()
    }, 1000)
    
    this.updateCountdown()
  },
  
  destroyed() {
    clearInterval(this.countdownInterval)
  },
  
  updateCountdown() {
    const startsAt = new Date(this.el.dataset.startsAt)
    const now = new Date()
    
    if (now >= startsAt) {
      this.el.innerHTML = "Event has started!"
      clearInterval(this.countdownInterval)
      
      // Auto-reload the page when the event starts
      window.location.reload()
      return
    }
    
    const diff = Math.floor((startsAt - now) / 1000)
    
    const hours = Math.floor(diff / 3600)
    const minutes = Math.floor((diff % 3600) / 60)
    const seconds = diff % 60
    
    this.el.querySelector('.hours').textContent = hours.toString().padStart(2, '0')
    this.el.querySelector('.minutes').textContent = minutes.toString().padStart(2, '0')
    this.el.querySelector('.seconds').textContent = seconds.toString().padStart(2, '0')
  }
}

Hooks.ShowHidePrice = {
  mounted() {
    this.toggleVisibility()
    
    document.getElementById('event_admission_type').addEventListener('change', () => {
      this.toggleVisibility()
    })
  },
  
  toggleVisibility() {
    const admission = document.getElementById('event_admission_type').value
    const requiredType = this.el.dataset.admissionType
    
    if (admission === requiredType) {
      this.el.closest('.field').style.display = 'block'
    } else {
      this.el.closest('.field').style.display = 'none'
    }
  }
}

Hooks.ShowHideMaxAttendees = {
  mounted() {
    this.toggleVisibility()
    
    document.getElementById('event_admission_type').addEventListener('change', () => {
      this.toggleVisibility()
    })
  },
  
  toggleVisibility() {
    const admission = document.getElementById('event_admission_type').value
    const requiredType = this.el.dataset.admissionType
    
    if (admission === requiredType) {
      this.el.closest('.field').style.display = 'block'
    } else {
      this.el.closest('.field').style.display = 'none'
    }
  }
}

export default Hooks