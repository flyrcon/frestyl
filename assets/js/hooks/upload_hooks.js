// assets/js/hooks/upload_hooks.js

// Assume this file exports an object containing hook definitions related to media uploads,
// *excluding* the core drag-and-drop file assignment functionality which is now in FileUploader in app.js.

const MediaUploadHooks = {
  // --- REMOVED CONFLICTING DRAGDROP HOOK ---
  // The DragDrop hook previously defined here has been removed because its
  // drag/drop event handling conflicted with the FileUploader hook in app.js.
  // Its styling logic has been moved into the FileUploader hook's highlight/unhighlight methods.
  // DragDrop: { ... } // This hook definition is gone.


  // --- Keep other non-conflicting hooks from this file ---
  // Example: Your MediaPreview hook
  MediaPreview: {
    // Ensure debugHook is defined or imported if used here
    // const debugHook = (name, method, details = {}) => { console.log(`Hook: ${name}.${method}`, details); };
    mounted() {
      // debugHook('MediaPreview', 'mounted'); // Uncomment if debugHook is available
      // For video and audio files, set up preview thumbnails
      if (this.el.dataset.mediaType === "video") {
        this.setupVideoThumbnail();
      }
      // ... any other setup for preview elements within this hook's element ...
    },

    // Logic to set up video thumbnail preview
    setupVideoThumbnail() {
      // debugHook('MediaPreview', 'setupVideoThumbnail'); // Uncomment if debugHook is available
      const videoElement = document.createElement("video");
      // Assuming data-media-url attribute exists on the hook's element (this.el)
      videoElement.src = this.el.dataset.mediaUrl;
      videoElement.muted = true; // Mute video playback
      videoElement.preload = "metadata"; // Only load metadata initially

      // Add listener to capture a frame once metadata is loaded
      videoElement.addEventListener("loadedmetadata", () => {
        // Create a canvas to draw the video frame
        const canvas = document.createElement("canvas");
        canvas.width = videoElement.videoWidth;
        canvas.height = videoElement.videoHeight;
        const ctx = canvas.getContext("2d");

        // Skip to a frame in the middle (or near the start) to get a representative thumbnail
        videoElement.currentTime = videoElement.duration / 2; // Seek to middle

        // Listen for the 'seeked' event to know when the video is positioned
        videoElement.addEventListener("seeked", () => {
           // Draw the current video frame onto the canvas
           ctx.drawImage(videoElement, 0, 0, canvas.width, canvas.height);

           // Convert the canvas content to an image URL (base64)
           const thumbnailUrl = canvas.toDataURL("image/jpeg"); // Choose format (jpeg often smaller)

           // Find an image element within the hook element to display the thumbnail
           const thumbnailElement = this.el.querySelector('.media-thumbnail'); // Assuming you have an <img> with class="media-thumbnail" in your template markup for previews
           if(thumbnailElement){
              thumbnailElement.src = thumbnailUrl; // Set the src of the thumbnail image
              thumbnailElement.style.display = 'block'; // Make sure the image element is visible
              // If the video element itself was briefly visible for loading metadata, hide it
              videoElement.style.display = 'none';
           } else {
              console.warn("MediaPreview hook: Thumbnail image element (.media-thumbnail) not found for video preview.");
              // You might display a fallback icon or message instead
           }
             // Clean up the temporary video and canvas elements if they are not needed anymore
             videoElement.remove();
             canvas.remove();
        });

         // Handle errors during video loading or seeking
        videoElement.addEventListener("error", (e) => {
            console.error("MediaPreview hook: Error loading or seeking video for thumbnail", e);
             // Display a fallback icon (like the file icon) or an error message in the UI
        });
      });

       // Note: Ensure the video element is removed from memory when the hook element is destroyed
       // this.el._tempVideoElement = videoElement; // Store reference if you need to clean up in destroyed()
    },

    // Clean up resources when the hook element is removed
    destroyed() {
         // debugHook('MediaPreview', 'destroyed'); // Uncomment if debugHook is available
         // Example cleanup:
         // if (this.el._tempVideoElement) {
         //    this.el._tempVideoElement.remove();
         //    delete this.el._tempVideoElement;
         // }
     },

    // Add updated() if the preview data can change dynamically
    // updated() { debugHook('MediaPreview', 'updated'); /* ... re-setup preview if needed ... */ }
  },

  // Add any other hooks that belong in this file here...
  // SomeOtherUploadHook: { mounted() { ... } }
};


// Export the object containing the hooks from this file
export default MediaUploadHooks;