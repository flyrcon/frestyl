// assets/js/hooks/narrative_beats_hooks.js

/**
 * Narrative Beats JavaScript Hooks
 * Handles real-time collaboration, audio integration, and UI interactions
 * for the Narrative Beats feature.
 */

// Story-to-Music Mapping Hook
export const StoryMusicMapper = {
  mounted() {
    this.setupMappingCanvas();
    this.setupDragAndDrop();
    this.setupMappingEvents();
  },

  setupMappingCanvas() {
    const canvas = this.el.querySelector('#mapping-canvas');
    if (!canvas) return;

    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.mappings = [];
    
    // Set canvas size
    this.resizeCanvas();
    window.addEventListener('resize', () => this.resizeCanvas());
    
    // Draw initial state
    this.drawMappings();
  },

  setupDragAndDrop() {
    // Story elements (left side)
    const storyElements = this.el.querySelectorAll('.story-element');
    storyElements.forEach(element => {
      element.draggable = true;
      element.addEventListener('dragstart', (e) => {
        e.dataTransfer.setData('text/plain', JSON.stringify({
          type: 'story',
          id: element.dataset.elementId,
          name: element.dataset.elementName,
          elementType: element.dataset.elementType
        }));
      });
    });

    // Musical elements (right side)
    const musicalElements = this.el.querySelectorAll('.musical-element');
    musicalElements.forEach(element => {
      element.addEventListener('dragover', (e) => e.preventDefault());
      element.addEventListener('drop', (e) => {
        e.preventDefault();
        const data = JSON.parse(e.dataTransfer.getData('text/plain'));
        this.createMapping(data, {
          type: 'musical',
          id: element.dataset.elementId,
          name: element.dataset.elementName,
          elementType: element.dataset.elementType
        });
      });
    });
  },

  setupMappingEvents() {
    this.handleEvent("mapping_created", (mapping) => {
      this.addMapping(mapping);
      this.drawMappings();
    });

    this.handleEvent("mapping_updated", (mapping) => {
      this.updateMapping(mapping);
      this.drawMappings();
    });

    this.handleEvent("mapping_deleted", (mappingId) => {
      this.removeMapping(mappingId);
      this.drawMappings();
    });
  },

  createMapping(storyElement, musicalElement) {
    const mapping = {
      id: Date.now(), // Temporary ID
      storyElement,
      musicalElement,
      intensity: 0.5,
      position: { x: 0, y: 0 }
    };

    this.pushEvent("create_story_music_mapping", {
      mapping: {
        story_element: storyElement.elementType,
        story_element_id: storyElement.id,
        musical_element: musicalElement.elementType,
        musical_element_data: { name: musicalElement.name },
        intensity_scale: mapping.intensity
      }
    });
  },

  addMapping(mapping) {
    this.mappings.push(mapping);
  },

  updateMapping(updatedMapping) {
    const index = this.mappings.findIndex(m => m.id === updatedMapping.id);
    if (index !== -1) {
      this.mappings[index] = updatedMapping;
    }
  },

  removeMapping(mappingId) {
    this.mappings = this.mappings.filter(m => m.id !== mappingId);
  },

  resizeCanvas() {
    if (!this.canvas) return;
    
    const container = this.canvas.parentElement;
    this.canvas.width = container.offsetWidth;
    this.canvas.height = container.offsetHeight;
  },

  drawMappings() {
    if (!this.ctx) return;

    this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);

    this.mappings.forEach(mapping => {
      this.drawMapping(mapping);
    });
  },

  drawMapping(mapping) {
    const { storyElement, musicalElement, intensity } = mapping;
    
    // Get element positions
    const storyEl = document.querySelector(`[data-element-id="${storyElement.id}"]`);
    const musicalEl = document.querySelector(`[data-element-id="${musicalElement.id}"]`);
    
    if (!storyEl || !musicalEl) return;

    const storyRect = storyEl.getBoundingClientRect();
    const musicalRect = musicalEl.getBoundingClientRect();
    const canvasRect = this.canvas.getBoundingClientRect();

    const startX = storyRect.right - canvasRect.left;
    const startY = storyRect.top + storyRect.height / 2 - canvasRect.top;
    const endX = musicalRect.left - canvasRect.left;
    const endY = musicalRect.top + musicalRect.height / 2 - canvasRect.top;

    // Draw connection line
    this.ctx.beginPath();
    this.ctx.moveTo(startX, startY);
    this.ctx.bezierCurveTo(
      startX + 50, startY,
      endX - 50, endY,
      endX, endY
    );
    
    // Line style based on intensity
    this.ctx.strokeStyle = `rgba(147, 51, 234, ${intensity})`;
    this.ctx.lineWidth = 2 + intensity * 3;
    this.ctx.stroke();

    // Draw intensity indicator
    const midX = (startX + endX) / 2;
    const midY = (startY + endY) / 2;
    
    this.ctx.beginPath();
    this.ctx.arc(midX, midY, 4 + intensity * 6, 0, 2 * Math.PI);
    this.ctx.fillStyle = `rgba(147, 51, 234, ${intensity})`;
    this.ctx.fill();
  }
};

// Musical Timeline Hook
export const MusicalTimeline = {
  mounted() {
    this.setupTimeline();
    this.setupPlaybackControls();
    this.setupSectionDragging();
    this.currentPosition = 0;
    this.isPlaying = false;
  },

  setupTimeline() {
    this.timeline = this.el.querySelector('.timeline-container');
    this.playhead = this.el.querySelector('.playhead');
    this.sections = [];
    
    // Setup timeline click-to-seek
    this.timeline.addEventListener('click', (e) => {
      const rect = this.timeline.getBoundingClientRect();
      const position = (e.clientX - rect.left) / rect.width;
      this.seekTo(position);
    });
  },

  setupPlaybackControls() {
    this.handleEvent("playback_started", () => {
      this.isPlaying = true;
      this.startPlaybackAnimation();
    });

    this.handleEvent("playback_stopped", () => {
      this.isPlaying = false;
      this.stopPlaybackAnimation();
    });

    this.handleEvent("playback_position", (data) => {
      this.updatePosition(data.position);
    });
  },

  setupSectionDragging() {
    const sectionElements = this.el.querySelectorAll('.timeline-section');
    
    sectionElements.forEach(section => {
      this.makeDraggable(section);
    });
  },

  makeDraggable(element) {
    let isDragging = false;
    let startX = 0;
    let startLeft = 0;

    element.addEventListener('mousedown', (e) => {
      isDragging = true;
      startX = e.clientX;
      startLeft = parseInt(element.style.left || 0);
      
      document.addEventListener('mousemove', onMouseMove);
      document.addEventListener('mouseup', onMouseUp);
    });

    const onMouseMove = (e) => {
      if (!isDragging) return;
      
      const deltaX = e.clientX - startX;
      const newLeft = startLeft + deltaX;
      const timelineWidth = this.timeline.offsetWidth;
      const sectionWidth = element.offsetWidth;
      
      // Constrain within timeline bounds
      const constrainedLeft = Math.max(0, Math.min(newLeft, timelineWidth - sectionWidth));
      element.style.left = constrainedLeft + 'px';
      
      // Calculate new time position
      const newPosition = constrainedLeft / timelineWidth;
      this.updateSectionPosition(element.dataset.sectionId, newPosition);
    };

    const onMouseUp = () => {
      isDragging = false;
      document.removeEventListener('mousemove', onMouseMove);
      document.removeEventListener('mouseup', onMouseUp);
    };
  },

  seekTo(position) {
    this.currentPosition = position;
    this.updatePlayhead();
    
    this.pushEvent("seek_to_position", { position });
  },

  updatePosition(position) {
    this.currentPosition = position;
    this.updatePlayhead();
  },

  updatePlayhead() {
    if (this.playhead) {
      const timelineWidth = this.timeline.offsetWidth;
      this.playhead.style.left = (this.currentPosition * timelineWidth) + 'px';
    }
  },

  startPlaybackAnimation() {
    this.animationFrame = requestAnimationFrame(() => {
      if (this.isPlaying) {
        this.currentPosition += 0.001; // Simulate time progression
        if (this.currentPosition >= 1) {
          this.currentPosition = 1;
          this.isPlaying = false;
        }
        this.updatePlayhead();
        this.startPlaybackAnimation();
      }
    });
  },

  stopPlaybackAnimation() {
    if (this.animationFrame) {
      cancelAnimationFrame(this.animationFrame);
    }
  },

  updateSectionPosition(sectionId, position) {
    // Debounce updates to avoid too many server calls
    if (this.updateTimeout) {
      clearTimeout(this.updateTimeout);
    }
    
    this.updateTimeout = setTimeout(() => {
      this.pushEvent("update_section_position", {
        section_id: sectionId,
        position: position
      });
    }, 300);
  },

  destroyed() {
    this.stopPlaybackAnimation();
    if (this.updateTimeout) {
      clearTimeout(this.updateTimeout);
    }
  }
};

// Character Instrument Visualizer Hook
export const CharacterInstrumentVisualizer = {
  mounted() {
    this.setupVisualization();
    this.setupAudioContext();
    this.characters = [];
  },

  setupVisualization() {
    this.canvas = this.el.querySelector('#character-viz-canvas');
    if (!this.canvas) return;

    this.ctx = this.canvas.getContext('2d');
    this.resizeCanvas();
    
    window.addEventListener('resize', () => this.resizeCanvas());
    
    // Setup animation loop
    this.animate();
  },

  setupAudioContext() {
    // Initialize audio analysis for character visualization
    if (!window.AudioContext && !window.webkitAudioContext) return;

    this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
    this.analyser = this.audioContext.createAnalyser();
    this.analyser.fftSize = 256;
    this.bufferLength = this.analyser.frequencyBinCount;
    this.dataArray = new Uint8Array(this.bufferLength);

    // Connect to audio engine if available
    this.connectToAudioEngine();
  },

  connectToAudioEngine() {
    // This would connect to the existing audio engine
    // For now, we'll simulate audio data
    this.simulateAudioData();
  },

  simulateAudioData() {
    // Simulate character activity with random data
    setInterval(() => {
      this.characters.forEach(character => {
        character.activity = Math.random() * 0.8 + 0.2;
        character.frequency = Math.random() * 1000 + 200;
      });
    }, 100);
  },

  resizeCanvas() {
    if (!this.canvas) return;
    
    const container = this.canvas.parentElement;
    this.canvas.width = container.offsetWidth;
    this.canvas.height = container.offsetHeight;
  },

  animate() {
    this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
    this.drawCharacters();
    
    requestAnimationFrame(() => this.animate());
  },

  drawCharacters() {
    if (!this.characters.length) return;

    const centerX = this.canvas.width / 2;
    const centerY = this.canvas.height / 2;
    const radius = Math.min(this.canvas.width, this.canvas.height) * 0.3;

    this.characters.forEach((character, index) => {
      const angle = (index / this.characters.length) * 2 * Math.PI;
      const x = centerX + Math.cos(angle) * radius;
      const y = centerY + Math.sin(angle) * radius;

      this.drawCharacter(character, x, y);
    });
  },

  drawCharacter(character, x, y) {
    const activity = character.activity || 0;
    const baseSize = 20;
    const size = baseSize + activity * 30;

    // Character circle
    this.ctx.beginPath();
    this.ctx.arc(x, y, size, 0, 2 * Math.PI);
    this.ctx.fillStyle = character.color || '#8B5CF6';
    this.ctx.globalAlpha = 0.7 + activity * 0.3;
    this.ctx.fill();

    // Character initial
    this.ctx.globalAlpha = 1;
    this.ctx.fillStyle = 'white';
    this.ctx.font = `${size * 0.6}px Arial`;
    this.ctx.textAlign = 'center';
    this.ctx.textBaseline = 'middle';
    this.ctx.fillText(character.name.charAt(0).toUpperCase(), x, y);

    // Activity waves
    if (activity > 0.3) {
      for (let i = 1; i <= 3; i++) {
        this.ctx.beginPath();
        this.ctx.arc(x, y, size + i * 15, 0, 2 * Math.PI);
        this.ctx.strokeStyle = character.color || '#8B5CF6';
        this.ctx.globalAlpha = (activity - 0.3) * (1 - i * 0.3);
        this.ctx.lineWidth = 2;
        this.ctx.stroke();
      }
    }

    this.ctx.globalAlpha = 1;
  },

  addCharacter(character) {
    this.characters.push({
      ...character,
      activity: 0,
      color: this.generateCharacterColor(character.instrument_type)
    });
  },

  updateCharacter(characterId, updates) {
    const character = this.characters.find(c => c.id === characterId);
    if (character) {
      Object.assign(character, updates);
    }
  },

  removeCharacter(characterId) {
    this.characters = this.characters.filter(c => c.id !== characterId);
  },

  generateCharacterColor(instrumentType) {
    const colors = {
      piano: '#8B5CF6',
      guitar: '#F59E0B',
      violin: '#EF4444',
      drums: '#10B981',
      flute: '#06B6D4',
      trumpet: '#F97316',
      synthesizer: '#EC4899',
      voice: '#8B5A2B',
      bass: '#6366F1',
      cello: '#DC2626'
    };
    
    return colors[instrumentType] || '#8B5CF6';
  },

  destroyed() {
    if (this.audioContext) {
      this.audioContext.close();
    }
  }
};

// Emotional Progression Builder Hook
export const EmotionalProgressionBuilder = {
  mounted() {
    this.setupChordBuilder();
    this.setupProgressionPlayer();
    this.chords = [];
  },

  setupChordBuilder() {
    this.chordPalette = this.el.querySelector('.chord-palette');
    this.progressionArea = this.el.querySelector('.progression-area');
    
    if (!this.chordPalette || !this.progressionArea) return;

    // Setup drag and drop for chord building
    this.setupChordDragDrop();
    
    // Setup progression editing
    this.setupProgressionEditing();
  },

  setupChordDragDrop() {
    const chordButtons = this.chordPalette.querySelectorAll('.chord-button');
    
    chordButtons.forEach(button => {
      button.draggable = true;
      button.addEventListener('dragstart', (e) => {
        e.dataTransfer.setData('text/plain', JSON.stringify({
          chord: button.dataset.chord,
          type: button.dataset.chordType
        }));
      });
    });

    this.progressionArea.addEventListener('dragover', (e) => e.preventDefault());
    this.progressionArea.addEventListener('drop', (e) => {
      e.preventDefault();
      const data = JSON.parse(e.dataTransfer.getData('text/plain'));
      this.addChordToProgression(data.chord);
    });
  },

  setupProgressionEditing() {
    this.progressionArea.addEventListener('click', (e) => {
      if (e.target.classList.contains('chord-slot')) {
        this.removeChordFromProgression(e.target.dataset.index);
      }
    });
  },

  setupProgressionPlayer() {
    this.playButton = this.el.querySelector('.play-progression-btn');
    if (this.playButton) {
      this.playButton.addEventListener('click', () => {
        this.playProgression();
      });
    }
  },

  addChordToProgression(chord) {
    this.chords.push(chord);
    this.updateProgressionDisplay();
    this.updateProgressionInput();
  },

  removeChordFromProgression(index) {
    this.chords.splice(index, 1);
    this.updateProgressionDisplay();
    this.updateProgressionInput();
  },

  updateProgressionDisplay() {
    if (!this.progressionArea) return;

    this.progressionArea.innerHTML = '';
    
    this.chords.forEach((chord, index) => {
      const chordElement = document.createElement('div');
      chordElement.className = 'chord-slot bg-purple-100 text-purple-800 px-3 py-2 rounded-lg cursor-pointer hover:bg-purple-200 transition-colors';
      chordElement.textContent = chord;
      chordElement.dataset.index = index;
      this.progressionArea.appendChild(chordElement);
    });

    // Add empty slot for next chord
    if (this.chords.length < 8) {
      const emptySlot = document.createElement('div');
      emptySlot.className = 'chord-slot empty border-2 border-dashed border-gray-300 px-3 py-2 rounded-lg text-gray-400 text-center';
      emptySlot.textContent = 'Drop chord here';
      this.progressionArea.appendChild(emptySlot);
    }
  },

  updateProgressionInput() {
    const input = this.el.querySelector('input[name="progression[chord_progression]"]');
    if (input) {
      input.value = this.chords.join(', ');
    }
  },

  playProgression() {
    // Integrate with audio engine to play the chord progression
    this.pushEvent("play_chord_progression", {
      chords: this.chords
    });

    // Visual feedback
    this.chords.forEach((chord, index) => {
      setTimeout(() => {
        this.highlightChord(index);
      }, index * 1000); // 1 second per chord
    });
  },

  highlightChord(index) {
    const chordSlots = this.progressionArea.querySelectorAll('.chord-slot:not(.empty)');
    
    // Clear previous highlights
    chordSlots.forEach(slot => slot.classList.remove('playing'));
    
    // Highlight current chord
    if (chordSlots[index]) {
      chordSlots[index].classList.add('playing');
      setTimeout(() => {
        chordSlots[index].classList.remove('playing');
      }, 900);
    }
  }
};

// Real-time Collaboration Hook
export const NarrativeBeatsCollaboration = {
  mounted() {
    this.setupPresence();
    this.setupCollaborationEvents();
    this.collaborators = new Map();
  },

  setupPresence() {
    // Track user presence and cursors
    this.handleEvent("presence_diff", (diff) => {
      this.updateCollaborators(diff);
    });

    // Send periodic presence updates
    this.presenceInterval = setInterval(() => {
      this.pushEvent("update_presence", {
        active_tab: this.getCurrentTab(),
        cursor_position: this.getCursorPosition(),
        last_activity: Date.now()
      });
    }, 5000);
  },

  setupCollaborationEvents() {
    this.handleEvent("collaborator_joined", (collaborator) => {
      this.showCollaboratorNotification(`${collaborator.name} joined the session`);
      this.addCollaboratorCursor(collaborator);
    });

    this.handleEvent("collaborator_left", (collaborator) => {
      this.showCollaboratorNotification(`${collaborator.name} left the session`);
      this.removeCollaboratorCursor(collaborator.id);
    });

    this.handleEvent("collaborator_action", (action) => {
      this.showCollaboratorAction(action);
    });
  },

  updateCollaborators(diff) {
    // Update collaborator presence
    if (diff.joins) {
      Object.entries(diff.joins).forEach(([userId, presence]) => {
        this.collaborators.set(userId, presence);
        this.updateCollaboratorCursor(userId, presence);
      });
    }

    if (diff.leaves) {
      Object.keys(diff.leaves).forEach(userId => {
        this.collaborators.delete(userId);
        this.removeCollaboratorCursor(userId);
      });
    }
  },

  addCollaboratorCursor(collaborator) {
    const cursor = document.createElement('div');
    cursor.id = `collaborator-cursor-${collaborator.id}`;
    cursor.className = 'collaborator-cursor fixed pointer-events-none z-50 transition-all duration-200';
    cursor.innerHTML = `
      <div class="bg-purple-600 text-white px-2 py-1 rounded text-xs whitespace-nowrap">
        ${collaborator.name}
      </div>
      <div class="w-0 h-0 border-l-4 border-r-4 border-t-4 border-transparent border-t-purple-600"></div>
    `;
    
    document.body.appendChild(cursor);
  },

  updateCollaboratorCursor(userId, presence) {
    const cursor = document.getElementById(`collaborator-cursor-${userId}`);
    if (cursor && presence.cursor_position) {
      cursor.style.left = presence.cursor_position.x + 'px';
      cursor.style.top = presence.cursor_position.y + 'px';
    }
  },

  removeCollaboratorCursor(userId) {
    const cursor = document.getElementById(`collaborator-cursor-${userId}`);
    if (cursor) {
      cursor.remove();
    }
  },

  showCollaboratorNotification(message) {
    // Create and show notification
    const notification = document.createElement('div');
    notification.className = 'fixed top-4 right-4 bg-purple-600 text-white px-4 py-2 rounded-lg shadow-lg z-50 transition-all duration-300';
    notification.textContent = message;
    
    document.body.appendChild(notification);
    
    setTimeout(() => {
      notification.style.opacity = '0';
      setTimeout(() => notification.remove(), 300);
    }, 3000);
  },

  showCollaboratorAction(action) {
    // Show what other collaborators are doing
    const actionIndicator = document.createElement('div');
    actionIndicator.className = 'collaboration-action fixed bottom-4 left-4 bg-blue-600 text-white px-3 py-2 rounded-lg shadow-lg z-50';
    actionIndicator.textContent = `${action.user_name} ${action.action}`;
    
    document.body.appendChild(actionIndicator);
    
    setTimeout(() => {
      actionIndicator.remove();
    }, 2000);
  },

  getCurrentTab() {
    const activeTab = document.querySelector('.tab-button.active');
    return activeTab ? activeTab.dataset.tab : 'overview';
  },

  getCursorPosition() {
    // Return last known mouse position
    return this.lastCursorPosition || { x: 0, y: 0 };
  },

  destroyed() {
    if (this.presenceInterval) {
      clearInterval(this.presenceInterval);
    }
    
    // Clean up collaborator cursors
    this.collaborators.forEach((_, userId) => {
      this.removeCollaboratorCursor(userId);
    });
  }
};

// Export all hooks
const NarrativeBeatsHooks = {
  StoryMusicMapper,
  MusicalTimeline,
  CharacterInstrumentVisualizer,
  EmotionalProgressionBuilder,
  NarrativeBeatsCollaboration
};

export default NarrativeBeatsHooks;