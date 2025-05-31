import React, { useState, useEffect, useRef, useCallback } from 'react';
import { Play, Pause, Heart, Star, Lightbulb, Flame, MoreHorizontal, Search, Filter, Grid, List, BarChart3, Settings, ChevronLeft, ChevronRight, Download, Share2, MessageCircle, Volume2, Users, Calendar, Eye } from 'lucide-react';

// Complete Theme System - 6 Revolutionary Themes
const THEMES = {
  cosmic: {
    name: 'Cosmic Dreams',
    icon: '🌌',
    background: 'bg-gradient-to-br from-purple-900 via-blue-900 to-indigo-900',
    cardBg: 'bg-white/10 backdrop-blur-md border border-purple-500/30',
    cardHover: 'hover:bg-white/20 hover:border-purple-400/50 hover:scale-105',
    text: 'text-white',
    accent: 'text-cyan-300',
    button: 'bg-gradient-to-r from-purple-600 to-blue-600 hover:from-purple-500 hover:to-blue-500',
    glow: 'drop-shadow-[0_0_15px_rgba(147,51,234,0.5)]',
    particles: true
  },
  
  cyberpunk: {
    name: 'Neon Grid',
    icon: '⚡',
    background: 'bg-black',
    cardBg: 'bg-gradient-to-br from-green-500/10 to-cyan-500/10 backdrop-blur-sm border border-green-400/30',
    cardHover: 'hover:border-green-400/60 hover:from-green-400/20 hover:to-cyan-400/20 hover:scale-102',
    text: 'text-green-300',
    accent: 'text-cyan-300',
    button: 'bg-gradient-to-r from-green-500 to-cyan-500 hover:from-green-400 hover:to-cyan-400',
    glow: 'drop-shadow-[0_0_15px_rgba(34,197,94,0.8)]',
    scanlines: true
  },

  liquid: {
    name: 'Liquid Flow',
    icon: '🌊',
    background: 'bg-gradient-to-br from-blue-400 via-purple-500 to-pink-500',
    cardBg: 'bg-white/10 backdrop-blur-xl border border-white/20',
    cardHover: 'hover:bg-white/20 hover:border-white/40 hover:scale-105 hover:-rotate-1',
    text: 'text-white',
    accent: 'text-blue-200',
    button: 'bg-gradient-to-r from-blue-500 to-purple-500 hover:from-blue-400 hover:to-purple-400',
    glow: 'drop-shadow-[0_0_20px_rgba(59,130,246,0.6)]',
    morphing: true
  },

  crystal: {
    name: 'Crystal Matrix',
    icon: '🔮',
    background: 'bg-gradient-to-br from-gray-900 via-blue-900 to-purple-900',
    cardBg: 'bg-gradient-to-br from-white/5 to-blue-500/10 backdrop-blur-sm border border-white/20',
    cardHover: 'hover:from-white/10 hover:to-blue-500/20 hover:border-white/40 hover:scale-105 hover:rotate-1',
    text: 'text-gray-100',
    accent: 'text-blue-300',
    button: 'bg-gradient-to-r from-blue-600 to-purple-600 hover:from-blue-500 hover:to-purple-500',
    glow: 'drop-shadow-[0_0_25px_rgba(59,130,246,0.4)]',
    geometric: true
  },

  organic: {
    name: 'Organic Growth',
    icon: '🌿',
    background: 'bg-gradient-to-br from-green-800 via-emerald-700 to-teal-800',
    cardBg: 'bg-gradient-to-br from-green-900/30 to-emerald-800/30 backdrop-blur-sm border border-green-600/30',
    cardHover: 'hover:from-green-800/40 hover:to-emerald-700/40 hover:border-green-500/50 hover:scale-105',
    text: 'text-green-100',
    accent: 'text-emerald-300',
    button: 'bg-gradient-to-r from-green-600 to-emerald-600 hover:from-green-500 hover:to-emerald-500',
    glow: 'drop-shadow-[0_0_20px_rgba(34,197,94,0.4)]',
    branching: true
  },

  minimal: {
    name: 'Clean Paper',
    icon: '📐',
    background: 'bg-gray-50',
    cardBg: 'bg-white border border-gray-200 shadow-sm',
    cardHover: 'hover:shadow-lg hover:border-gray-300 hover:scale-102 hover:-translate-y-1',
    text: 'text-gray-900',
    accent: 'text-gray-600',
    button: 'bg-gray-900 hover:bg-gray-800 text-white',
    glow: 'drop-shadow-sm',
    clean: true
  }
};

// Revolutionary Discovery Interface
const RevolutionaryDiscoveryInterface = ({
  onViewSwitch,
  onThemeSwitch,
  onCardNavigation,
  onCardExpand,
  onFileSelect,
  onReaction,
  onPlayToggle,
  onSearch,
  onFilter,
  onBulkAction,
  onClearSelection,
  initialTheme = 'cosmic',
  initialView = 'discovery',
  initialCards = [],
  initialIndex = 0,
  expandedCard = null,
  isPlaying = false,
  selectedFiles = [],
  deviceType = 'desktop'
}) => {
  
  const [currentTheme, setCurrentTheme] = useState(initialTheme);
  const [viewMode, setViewMode] = useState(initialView);
  const [searchQuery, setSearchQuery] = useState('');
  const [showThemeSelector, setShowThemeSelector] = useState(false);
  const [showFilters, setShowFilters] = useState(false);
  const [cardIndex, setCardIndex] = useState(initialIndex);
  const [mousePosition, setMousePosition] = useState({ x: 0, y: 0 });
  const [gestureStart, setGestureStart] = useState(null);
  
  const containerRef = useRef(null);
  const theme = THEMES[currentTheme];
  const isMobile = deviceType === 'mobile';

  // Sample enhanced data structure
  const sampleCards = initialCards.length > 0 ? initialCards : [
    {
      id: 'group-1',
      type: 'group',
      title: 'Midnight Sessions',
      description: 'Late night creative vibes',
      primaryFile: {
        id: 1,
        title: 'Cosmic Symphony',
        type: 'audio',
        duration: '4:32',
        thumbnail: '🎼',
        artist: 'Luna Eclipse',
        bpm: 120,
        key: 'Am'
      },
      components: [
        { id: 2, title: 'Visual Companion', type: 'video', role: 'visual' },
        { id: 3, title: 'Cover Art', type: 'image', role: 'artwork' },
        { id: 4, title: 'Session Notes', type: 'document', role: 'documentation' }
      ],
      metadata: {
        channel: 'Creative Lab',
        session: 'Session #42',
        collaborators: ['Luna Eclipse', 'Digital Wanderer'],
        created: '2024-01-15',
        views: 1247,
        reactions: { heart: 89, fire: 34, star: 56, lightbulb: 23 }
      }
    },
    {
      id: 'group-2', 
      type: 'group',
      title: 'Neon Experiments',
      description: 'Cyberpunk audio-visual explorations',
      primaryFile: {
        id: 5,
        title: 'Electric Dreams',
        type: 'video',
        duration: '2:45',
        thumbnail: '🎬',
        artist: 'Cyber Phoenix',
        resolution: '4K'
      },
      components: [
        { id: 6, title: 'Soundtrack', type: 'audio', role: 'audio' },
        { id: 7, title: 'Making Of', type: 'video', role: 'documentary' },
        { id: 8, title: 'Stills', type: 'image', role: 'stills' }
      ],
      metadata: {
        channel: 'Visual Lab',
        session: 'Session #38',
        collaborators: ['Cyber Phoenix', 'Neon Artist'],
        created: '2024-01-12',
        views: 2341,
        reactions: { heart: 156, fire: 78, star: 92, lightbulb: 45 }
      }
    },
    {
      id: 'individual-1',
      type: 'individual',
      title: 'Solo Creation',
      primaryFile: {
        id: 9,
        title: 'Minimalist Melody',
        type: 'audio',
        duration: '3:15',
        thumbnail: '🎵',
        artist: 'Solo Creator',
        bpm: 95,
        key: 'C'
      },
      metadata: {
        channel: 'Personal',
        created: '2024-01-10',
        views: 487,
        reactions: { heart: 34, fire: 12, star: 28, lightbulb: 8 }
      }
    }
  ];

  // Theme switching with smooth transitions
  const switchTheme = useCallback((newTheme) => {
    setCurrentTheme(newTheme);
    onThemeSwitch?.(newTheme);
    setShowThemeSelector(false);
    
    // Trigger theme transition effects
    if (containerRef.current) {
      containerRef.current.style.transition = 'all 0.8s cubic-bezier(0.4, 0, 0.2, 1)';
    }
  }, [onThemeSwitch]);

  // View mode switching
  const switchView = useCallback((newView) => {
    setViewMode(newView);
    onViewSwitch?.(newView);
  }, [onViewSwitch]);

  // Card navigation with momentum
  const navigateCard = useCallback((direction) => {
    const maxIndex = sampleCards.length - 1;
    let newIndex = cardIndex;

    if (direction === 'next' && cardIndex < maxIndex) {
      newIndex = cardIndex + 1;
    } else if (direction === 'prev' && cardIndex > 0) {
      newIndex = cardIndex - 1;
    }

    if (newIndex !== cardIndex) {
      setCardIndex(newIndex);
      onCardNavigation?.(direction);
    }
  }, [cardIndex, sampleCards.length, onCardNavigation]);

  // Gesture handling for mobile
  const handleTouchStart = useCallback((e) => {
    if (!isMobile) return;
    setGestureStart({
      x: e.touches[0].clientX,
      y: e.touches[0].clientY,
      time: Date.now()
    });
  }, [isMobile]);

  const handleTouchEnd = useCallback((e) => {
    if (!isMobile || !gestureStart) return;
    
    const endX = e.changedTouches[0].clientX;
    const endY = e.changedTouches[0].clientY;
    const deltaX = endX - gestureStart.x;
    const deltaY = endY - gestureStart.y;
    const deltaTime = Date.now() - gestureStart.time;
    
    // Swipe detection
    if (Math.abs(deltaX) > 50 && deltaTime < 300) {
      if (deltaX > 0) {
        navigateCard('prev');
      } else {
        navigateCard('next');
      }
    }
    
    setGestureStart(null);
  }, [gestureStart, navigateCard, isMobile]);

  // Enhanced Card Component
  const DiscoveryCard = ({ card, index, isActive, isExpanded }) => {
    const [isHovered, setIsHovered] = useState(false);
    const primary = card.primaryFile;
    const reactions = card.metadata.reactions;

    const getTypeIcon = (type) => {
      switch (type) {
        case 'audio': return currentTheme === 'cosmic' ? '🌌' : currentTheme === 'cyberpunk' ? '⚡' : '🎵';
        case 'video': return currentTheme === 'cosmic' ? '🌟' : currentTheme === 'cyberpunk' ? '💾' : '🎬';
        case 'image': return currentTheme === 'cosmic' ? '✨' : currentTheme === 'cyberpunk' ? '🔋' : '🎨';
        default: return '📄';
      }
    };

    const cardScale = isActive ? 1 : isMobile ? 0.85 : 0.9;
    const cardOpacity = isActive ? 1 : 0.7;

    return (
      <div
        className={`
          ${theme.cardBg} ${isActive ? theme.cardHover : ''} 
          rounded-2xl p-6 cursor-pointer transition-all duration-500 transform
          ${theme.glow} relative overflow-hidden
        `}
        style={{
          transform: `scale(${cardScale}) translateX(${(index - cardIndex) * (isMobile ? 100 : 120)}%)`,
          opacity: cardOpacity,
          zIndex: isActive ? 10 : 1
        }}
        onMouseEnter={() => setIsHovered(true)}
        onMouseLeave={() => setIsHovered(false)}
        onClick={() => onCardExpand?.(card.id)}
      >
        {/* Background Effects */}
        {currentTheme === 'cosmic' && (
          <div className="absolute inset-0 bg-gradient-to-r from-purple-500/10 via-transparent to-blue-500/10 animate-pulse" />
        )}
        
        {/* Header */}
        <div className="flex items-center justify-between mb-4">
          <div className={`w-12 h-12 rounded-xl ${theme.button} flex items-center justify-center text-xl`}>
            {getTypeIcon(primary.type)}
          </div>
          <div className="flex items-center space-x-2">
            <span className={`text-xs ${theme.accent} opacity-60`}>
              {card.metadata.views?.toLocaleString()} views
            </span>
            <button className={`p-2 rounded-lg ${theme.cardBg} ${theme.text} hover:scale-110 transition-transform`}>
              <MoreHorizontal size={16} />
            </button>
          </div>
        </div>

        {/* Primary File Info */}
        <div className="mb-4">
          <h3 className={`${theme.text} font-bold text-xl mb-1`}>
            {card.title}
          </h3>
          <p className={`${theme.accent} text-sm mb-2`}>
            {primary.artist} • {primary.duration || primary.resolution}
          </p>
          <p className={`${theme.text} text-xs opacity-70`}>
            {card.description}
          </p>
        </div>

        {/* Metadata */}
        <div className={`${theme.text} text-xs opacity-60 mb-4 space-y-1`}>
          <div className="flex items-center space-x-4">
            <span>📺 {card.metadata.channel}</span>
            <span>🎙️ {card.metadata.session}</span>
          </div>
          <div className="flex items-center space-x-2">
            <Users size={12} />
            <span>{card.metadata.collaborators?.join(', ')}</span>
          </div>
        </div>

        {/* Components Preview (for groups) */}
        {card.type === 'group' && card.components && (
          <div className="mb-4">
            <div className="flex items-center space-x-2 mb-2">
              <span className={`text-xs ${theme.accent} font-medium`}>Components:</span>
            </div>
            <div className="flex space-x-2">
              {card.components.slice(0, 3).map((component, idx) => (
                <div
                  key={component.id}
                  className={`
                    w-8 h-8 rounded-lg ${theme.cardBg} ${theme.glow} flex items-center justify-center
                    text-xs border ${theme.accent}
                    ${isExpanded ? 'animate-bounce' : ''}
                  `}
                  style={{ animationDelay: `${idx * 0.1}s` }}
                >
                  {getTypeIcon(component.type)}
                </div>
              ))}
              {card.components.length > 3 && (
                <div className={`w-8 h-8 rounded-lg ${theme.cardBg} flex items-center justify-center text-xs ${theme.accent}`}>
                  +{card.components.length - 3}
                </div>
              )}
            </div>
          </div>
        )}

        {/* Reactions */}
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center space-x-3">
            {Object.entries(reactions).map(([type, count]) => {
              const icons = { heart: '❤️', fire: '🔥', star: '⭐', lightbulb: '💡' };
              return (
                <button
                  key={type}
                  onClick={(e) => {
                    e.stopPropagation();
                    onReaction?.(primary.id, type);
                  }}
                  className={`
                    flex items-center space-x-1 ${theme.accent} hover:scale-110 transition-transform
                    px-2 py-1 rounded-full ${theme.cardBg} hover:bg-white/20
                  `}
                >
                  <span className="text-xs">{icons[type]}</span>
                  <span className="text-xs">{count}</span>
                </button>
              );
            })}
          </div>
        </div>

        {/* Actions */}
        <div className="flex items-center justify-between">
          <button
            onClick={(e) => {
              e.stopPropagation();
              onPlayToggle?.(primary.id);
            }}
            className={`
              ${theme.button} p-3 rounded-xl hover:scale-110 transition-all duration-300
              ${theme.glow} shadow-lg hover:shadow-xl flex items-center space-x-2
            `}
          >
            {isPlaying ? <Pause size={16} className="text-white" /> : <Play size={16} className="text-white" />}
            {isExpanded && <span className="text-white text-sm">Play</span>}
          </button>

          <div className="flex items-center space-x-2">
            <button
              onClick={(e) => {
                e.stopPropagation();
                onFileSelect?.(primary.id);
              }}
              className={`
                p-2 rounded-lg transition-all duration-300 hover:scale-110
                ${selectedFiles.includes(primary.id) 
                  ? `${theme.button} text-white` 
                  : `${theme.cardBg} ${theme.text}`
                }
              `}
            >
              {selectedFiles.includes(primary.id) ? '✓' : '+'}
            </button>
            
            <button className={`p-2 rounded-lg ${theme.cardBg} ${theme.text} hover:scale-110 transition-transform`}>
              <MessageCircle size={16} />
            </button>
          </div>
        </div>
      </div>
    );
  };

  // Pinterest-style Grid Component
  const PinterestGrid = () => (
    <div className="columns-1 sm:columns-2 lg:columns-3 xl:columns-4 gap-6 space-y-6">
      {sampleCards.map((card) => (
        <div key={card.id} className="break-inside-avoid">
          <div className={`${theme.cardBg} ${theme.cardHover} rounded-2xl overflow-hidden ${theme.glow}`}>
            {/* Image/Visual Header */}
            <div className="aspect-w-16 aspect-h-10 bg-gradient-to-br from-gray-100 to-gray-300 relative">
              <div className="w-full h-48 flex items-center justify-center">
                <div className={`w-16 h-16 rounded-2xl ${theme.button} flex items-center justify-center text-2xl`}>
                  {card.primaryFile.thumbnail}
                </div>
              </div>
              <div className="absolute top-3 right-3">
                <button className={`p-2 rounded-lg ${theme.cardBg} ${theme.text} hover:scale-110 transition-transform`}>
                  <Heart size={16} />
                </button>
              </div>
            </div>
            
            {/* Content */}
            <div className="p-4">
              <h3 className={`${theme.text} font-semibold text-lg mb-2`}>
                {card.title}
              </h3>
              <p className={`${theme.accent} text-sm mb-3`}>
                {card.primaryFile.artist}
              </p>
              
              {/* Quick stats */}
              <div className="flex items-center justify-between text-xs">
                <span className={`${theme.text} opacity-60`}>
                  {card.metadata.views} views
                </span>
                <div className="flex items-center space-x-2">
                  {Object.entries(card.metadata.reactions).slice(0, 2).map(([type, count]) => (
                    <span key={type} className={theme.accent}>
                      {type === 'heart' ? '❤️' : '🔥'} {count}
                    </span>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </div>
      ))}
    </div>
  );

  // Professional List Component
  const ProfessionalList = () => (
    <div className={`${theme.cardBg} rounded-2xl overflow-hidden ${theme.glow}`}>
      {sampleCards.map((card, index) => (
        <div
          key={card.id}
          className={`
            flex items-center p-4 border-b border-white/10 last:border-b-0
            hover:bg-white/5 transition-colors cursor-pointer
          `}
        >
          {/* Thumbnail */}
          <div className={`w-12 h-12 rounded-xl ${theme.button} flex items-center justify-center mr-4 flex-shrink-0`}>
            {card.primaryFile.thumbnail}
          </div>
          
          {/* Content */}
          <div className="flex-1 min-w-0">
            <div className="flex items-center justify-between">
              <div>
                <h3 className={`${theme.text} font-semibold truncate`}>
                  {card.title}
                </h3>
                <p className={`${theme.accent} text-sm`}>
                  {card.primaryFile.artist} • {card.metadata.channel}
                </p>
              </div>
              
              <div className="flex items-center space-x-6 text-sm">
                <div className={`${theme.text} opacity-60`}>
                  <Eye size={14} className="inline mr-1" />
                  {card.metadata.views}
                </div>
                <div className={`${theme.accent}`}>
                  {card.primaryFile.duration || card.primaryFile.resolution}
                </div>
                <div className="flex items-center space-x-1">
                  {Object.entries(card.metadata.reactions).slice(0, 3).map(([type, count]) => (
                    <span key={type} className="text-xs">
                      {type === 'heart' ? '❤️' : type === 'fire' ? '🔥' : '⭐'} {count}
                    </span>
                  ))}
                </div>
                <button className={`p-2 rounded-lg ${theme.cardBg} ${theme.text} hover:scale-110 transition-transform`}>
                  <MoreHorizontal size={16} />
                </button>
              </div>
            </div>
          </div>
        </div>
      ))}
    </div>
  );

  return (
    <div
      ref={containerRef}
      className={`min-h-screen ${theme.background} ${theme.text} relative overflow-hidden transition-all duration-1000`}
      onTouchStart={handleTouchStart}
      onTouchEnd={handleTouchEnd}
    >
      {/* Theme Background Effects */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        {currentTheme === 'cosmic' && theme.particles && (
          <div className="absolute inset-0">
            {[...Array(30)].map((_, i) => (
              <div
                key={i}
                className="absolute w-1 h-1 bg-cyan-300 rounded-full opacity-40 animate-pulse"
                style={{
                  left: `${Math.random() * 100}%`,
                  top: `${Math.random() * 100}%`,
                  animationDelay: `${Math.random() * 3}s`,
                  animationDuration: `${2 + Math.random() * 4}s`
                }}
              />
            ))}
          </div>
        )}
        
        {currentTheme === 'cyberpunk' && theme.scanlines && (
          <div className="absolute inset-0 bg-[linear-gradient(90deg,transparent_50%,rgba(34,197,94,0.03)_50%)] bg-[length:20px_20px]" />
        )}
      </div>

      {/* Header */}
      <header className="relative z-20 p-4 sm:p-6">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-4">
            <h1 className={`text-2xl sm:text-3xl font-bold ${theme.glow}`}>
              Frestyl Discovery
            </h1>
            <div className={`px-3 py-1 rounded-full ${theme.cardBg}`}>
              <span className={`text-sm ${theme.accent}`}>
                {theme.icon} {theme.name}
              </span>
            </div>
          </div>

          <div className="flex items-center space-x-2">
            <button
              onClick={() => setShowFilters(!showFilters)}
              className={`p-3 rounded-xl ${theme.cardBg} ${theme.text} hover:scale-110 transition-all`}
            >
              <Filter size={20} />
            </button>
            <button
              onClick={() => setShowThemeSelector(!showThemeSelector)}
              className={`p-3 rounded-xl ${theme.button} hover:scale-110 transition-all ${theme.glow}`}
            >
              <Settings size={20} className="text-white" />
            </button>
          </div>
        </div>

        {/* Search Bar */}
        <div className={`mt-4 relative ${theme.glow}`}>
          <Search className={`absolute left-3 top-1/2 transform -translate-y-1/2 ${theme.accent}`} size={20} />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => {
              setSearchQuery(e.target.value);
              onSearch?.(e.target.value);
            }}
            placeholder="Search your media universe..."
            className={`
              w-full pl-12 pr-4 py-3 rounded-xl ${theme.cardBg} ${theme.text}
              placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-cyan-400
              transition-all duration-300
            `}
          />
        </div>

        {/* View Mode Selector */}
        <div className="flex items-center justify-center space-x-2 mt-4">
          {[
            { mode: 'discovery', icon: '🌌', label: 'Discovery' },
            { mode: 'grid', icon: '⚡', label: 'Grid' },
            { mode: 'list', icon: '📋', label: 'List' }
          ].map(({ mode, icon, label }) => (
            <button
              key={mode}
              onClick={() => switchView(mode)}
              className={`
                flex items-center space-x-2 px-4 py-2 rounded-xl transition-all duration-300
                ${viewMode === mode 
                  ? `${theme.button} ${theme.glow} text-white` 
                  : `${theme.cardBg} hover:scale-105 ${theme.text}`
                }
              `}
            >
              <span>{icon}</span>
              <span className="text-sm font-medium">{label}</span>
            </button>
          ))}
        </div>
      </header>

      {/* Theme Selector Modal */}
      {showThemeSelector && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className={`${theme.cardBg} rounded-2xl p-6 max-w-2xl w-full ${theme.glow}`}>
            <h3 className={`text-xl font-bold ${theme.text