console.log("Debug script loaded!");
window.addEventListener('DOMContentLoaded', () => {
  console.log("DOM fully loaded!");
  
  // Check if our hook element exists
  const uploadContainer = document.getElementById('media-upload-container');
  console.log("Upload container found:", !!uploadContainer);
  
  // Check if the file input exists
  const fileInput = document.querySelector('input[type="file"]');
  console.log("File input found:", !!fileInput);
});