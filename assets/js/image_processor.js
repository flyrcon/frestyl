// assets/js/image_processor.js
export function setupImageCompression(maxWidth = 1920, maxHeight = 1080, quality = 0.8) {
  window.addEventListener("phx:compress-images", (e) => {
    const { inputId } = e.detail;
    const input = document.getElementById(inputId);
    if (!input || !input.files || input.files.length === 0) return;
    
    processFiles(input.files, maxWidth, maxHeight, quality).then(processedFiles => {
      // Create a new DataTransfer object
      const dataTransfer = new DataTransfer();
      
      // Add compressed files
      processedFiles.forEach(file => dataTransfer.items.add(file));
      
      // Update the file input
      input.files = dataTransfer.files;
      
      // Dispatch change event to trigger LiveView update
      input.dispatchEvent(new Event('change', { bubbles: true }));
    });
  });
}

async function processFiles(files, maxWidth, maxHeight, quality) {
  const processedFiles = [];
  
  for (const file of Array.from(files)) {
    if (!file.type.startsWith('image/')) {
      // Not an image, keep as is
      processedFiles.push(file);
      continue;
    }
    
    try {
      const processedFile = await processImage(file, maxWidth, maxHeight, quality);
      processedFiles.push(processedFile);
    } catch (error) {
      console.error('Error processing image:', error);
      processedFiles.push(file); // Use original on error
    }
  }
  
  return processedFiles;
}

async function processImage(file, maxWidth, maxHeight, quality) {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => {
      // Calculate new dimensions maintaining aspect ratio
      let width = img.width;
      let height = img.height;
      
      if (width > maxWidth || height > maxHeight) {
        const ratio = Math.min(maxWidth / width, maxHeight / height);
        width = Math.floor(width * ratio);
        height = Math.floor(height * ratio);
      }
      
      // Create canvas for resizing
      const canvas = document.createElement('canvas');
      canvas.width = width;
      canvas.height = height;
      const ctx = canvas.getContext('2d');
      ctx.drawImage(img, 0, 0, width, height);
      
      // Convert to blob
      canvas.toBlob((blob) => {
        if (!blob) {
          reject(new Error('Canvas to Blob conversion failed'));
          return;
        }
        
        // Create a new File object
        const processedFile = new File([blob], file.name, {
          type: file.type,
          lastModified: file.lastModified
        });
        
        resolve(processedFile);
      }, file.type, quality);
    };
    
    img.onerror = () => {
      reject(new Error('Failed to load image'));
    };
    
    img.src = URL.createObjectURL(file);
  });
}