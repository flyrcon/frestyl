// assets/js/hooks/studio_hooks.js

// Text Editor Hook
const TextEditor = {
  mounted() {
    // Save the initial content
    this.content = this.el.value;
    
    // Set up event listeners
    this.el.addEventListener('input', (e) => {
      const content = e.target.value;
      this.content = content;
      
      // Get selection
      const selectionStart = e.target.selectionStart;
      const selectionEnd = e.target.selectionEnd;
      
      // Push the update event
      this.pushEvent('text_update', {
        content: content,
        selection: { start: selectionStart, end: selectionEnd }
      });
    });
  }
};

// Audio Recorder Hook
const AudioRecorder = {
  mounted() {
    let mediaRecorder;
    let audioChunks = [];
    
    const startRecordingBtn = document.getElementById('start-recording');
    const stopRecordingBtn = document.getElementById('stop-recording');
    
    startRecordingBtn?.addEventListener('click', async () => {
      try {
        const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
        mediaRecorder = new MediaRecorder(stream);
        
        mediaRecorder.ondataavailable = (event) => {
          audioChunks.push(event.data);
        };
        
        mediaRecorder.onstop = () => {
          const audioBlob = new Blob(audioChunks, { type: 'audio/wav' });
          audioChunks = [];
          
          // Convert to base64 for sending to server
          const reader = new FileReader();
          reader.readAsDataURL(audioBlob);
          reader.onloadend = () => {
            const base64data = reader.result;
            this.pushEvent('audio_save_recording', { data: base64data });
          };
        };
        
        mediaRecorder.start();
        this.pushEvent('audio_toggle_record', {});
      } catch (err) {
        console.error('Error accessing microphone:', err);
      }
    });
    
    stopRecordingBtn?.addEventListener('click', () => {
      if (mediaRecorder && mediaRecorder.state === 'recording') {
        mediaRecorder.stop();
        this.pushEvent('audio_toggle_record', {});
      }
    });
  }
};

// Visual Canvas Hook
const VisualCanvas = {
  mounted() {
    let canvas, ctx;
    let isDrawing = false;
    let lastX = 0;
    let lastY = 0;
    
    const setupCanvas = () => {
      canvas = document.createElement('canvas');
      canvas.width = this.el.offsetWidth;
      canvas.height = this.el.offsetHeight;
      canvas.style.display = 'block';
      this.el.innerHTML = '';
      this.el.appendChild(canvas);
      
      ctx = canvas.getContext('2d');
      ctx.lineJoin = 'round';
      ctx.lineCap = 'round';
      ctx.lineWidth = 5;
    };
    
    setupCanvas();
    
    // Get the current tool and color from the component
    this.pushEvent('get_visual_state', {}, (reply) => {
      currentTool = reply.tool || 'brush';
      ctx.strokeStyle = reply.color || '#4f46e5';
    });
    
    canvas.addEventListener('mousedown', (e) => {
      isDrawing = true;
      [lastX, lastY] = [e.offsetX, e.offsetY];
    });
    
    canvas.addEventListener('mousemove', (e) => {
      if (!isDrawing) return;
      
      if (currentTool === 'brush') {
        ctx.beginPath();
        ctx.moveTo(lastX, lastY);
        ctx.lineTo(e.offsetX, e.offsetY);
        ctx.stroke();
        
        [lastX, lastY] = [e.offsetX, e.offsetY];
      }
    });
    
    canvas.addEventListener('mouseup', () => {
      isDrawing = false;
      
      // Send the canvas data to the server
      const imageData = canvas.toDataURL('image/png');
      this.pushEvent('visual_save_drawing', { data: imageData });
    });
    
    canvas.addEventListener('mouseout', () => {
      isDrawing = false;
    });
  }
};

export default {
  TextEditor,
  AudioRecorder,
  VisualCanvas
};