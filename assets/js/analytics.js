/**
 * Frestyl Analytics Module
 * 
 * This module handles client-side analytics tracking for Frestyl.
 * It tracks various metrics including views, engagement, and streaming performance.
 */

const FrestylAnalytics = (function() {
  // Configuration
  const config = {
    apiEndpoint: '/api/analytics/metrics',
    apiKey: null,
    batchSize: 10,
    batchInterval: 30000, // 30 seconds
    debugMode: false
  };

  // Storage for metrics that are waiting to be sent
  let metricsQueue = [];
  let batchTimer = null;
  
  // Session data
  let sessionData = {
    sessionId: null,
    channelId: null,
    eventId: null,
    startTime: null,
    heartbeats: [],
    bufferEvents: 0,
    droppedFrames: 0,
    lastBitrate: 0,
    lastLatency: 0,
    lastResolution: null
  };

  // User data for demographics tracking
  let userData = {
    userId: null,
    demographicGroup: null,
    ageRange: null,
    gender: null,
    country: null,
    region: null,
    city: null,
    deviceType: detectDeviceType(),
    browser: detectBrowser(),
    os: detectOS(),
    referralSource: document.referrer
  };

  /**
   * Initialize the analytics module
   * @param {Object} options - Configuration options
   */
  function init(options = {}) {
    // Merge options with defaults
    Object.assign(config, options);
    
    log('Analytics initialized with options:', config);
    
    // Set up event listeners for global analytics
    window.addEventListener('beforeunload', handleUnload);
    
    // Start batch timer
    startBatchTimer();
    
    // Generate session ID if not provided
    if (!sessionData.sessionId) {
      sessionData.sessionId = generateId();
    }
    
    // Record initial page view
    if (options.autoTrackPageviews !== false) {
      trackPageView();
    }
    
    return {
      trackPageView,
      trackEvent,
      startWatchSession,
      recordStreamingMetrics,
      endWatchSession,
      trackPurchase
    };
  }

  /**
   * Start the batch timer for sending metrics
   */
  function startBatchTimer() {
    batchTimer = setInterval(() => {
      if (metricsQueue.length > 0) {
        sendMetricsBatch();
      }
    }, config.batchInterval);
  }

  /**
   * Track a page view event
   */
  function trackPageView() {
    const channelId = getChannelId();
    
    if (channelId) {
      queueMetric({
        type: 'channel_metric',
        channel_id: channelId,
        views: 1,
        unique_viewers: 1,
        recorded_at: new Date().toISOString()
      });
    }
  }

  /**
   * Track a custom event
   * @param {string} eventName - Name of the event
   * @param {Object} eventData - Additional data for the event
   */
  function trackEvent(eventName, eventData = {}) {
    const channelId = getChannelId();
    
    if (channelId) {
      const metric = {
        type: 'channel_metric',
        channel_id: channelId,
        recorded_at: new Date().toISOString()
      };
      
      // Add specific metrics based on event type
      switch (eventName) {
        case 'like':
          metric.likes_count = 1;
          break;
        case 'comment':
          metric.comments_count = 1;
          break;
        case 'share':
          metric.shares_count = 1;
          break;
        case 'engagement':
          metric.engagement_rate = eventData.value || 1.0;
          break;
        default:
          // For custom events, add data as-is
          Object.assign(metric, eventData);
      }
      
      queueMetric(metric);
    }
  }

  /**
   * Start tracking a watch session for streaming content
   * @param {Object} data - Session data including channel and event IDs
   */
  function startWatchSession(data) {
    // Set session data
    sessionData.channelId = data.channelId;
    sessionData.eventId = data.eventId;
    sessionData.startTime = new Date();
    sessionData.heartbeats = [Date.now()];
    
    // Reset streaming metrics
    sessionData.bufferEvents = 0;
    sessionData.droppedFrames = 0;
    
    // Track initial session metric
    queueMetric({
      type: 'session_metric',
      session_id: sessionData.sessionId,
      channel_id: sessionData.channelId,
      concurrent_viewers: 1,
      recorded_at: new Date().toISOString()
    });
    
    // Start heartbeat for watch time tracking
    startHeartbeat();
    
    // Track audience insights if available
    if (userData.demographicGroup || userData.country) {
      trackAudienceInsight();
    }
    
    log('Watch session started:', sessionData);
  }

  /**
   * Start heartbeat interval for tracking watch time
   */
  function startHeartbeat() {
    // Send heartbeat every 30 seconds
    sessionData.heartbeatInterval = setInterval(() => {
      sessionData.heartbeats.push(Date.now());
      
      // Calculate watch time up to now
      const watchTime = calculateWatchTime();
      
      // Track watch time
      queueMetric({
        type: 'session_metric',
        session_id: sessionData.sessionId,
        channel_id: sessionData.channelId,
        average_watch_time: watchTime,
        recorded_at: new Date().toISOString()
      });
    }, 30000); // 30 seconds
  }

  /**
   * Calculate total watch time from heartbeats
   * @returns {number} Watch time in seconds
   */
  function calculateWatchTime() {
    if (sessionData.heartbeats.length < 2) {
      return 0;
    }
    
    const now = Date.now();
    const totalTime = (now - sessionData.startTime) / 1000; // in seconds
    
    return totalTime;
  }

  /**
   * Record streaming performance metrics
   * @param {Object} metrics - Performance metrics for the stream
   */
  function recordStreamingMetrics(metrics) {
    // Update session data
    if (metrics.bufferEvent) {
      sessionData.bufferEvents++;
    }
    
    if (metrics.droppedFrames) {
      sessionData.droppedFrames += metrics.droppedFrames;
    }
    
    if (metrics.bitrate) {
      sessionData.lastBitrate = metrics.bitrate;
    }
    
    if (metrics.latency) {
      sessionData.lastLatency = metrics.latency;
    }
    
    if (metrics.resolution) {
      sessionData.lastResolution = metrics.resolution;
    }
    
    // Queue metric
    queueMetric({
      type: 'session_metric',
      session_id: sessionData.sessionId,
      channel_id: sessionData.channelId,
      buffer_count: sessionData.bufferEvents,
      average_bitrate: sessionData.lastBitrate,
      dropped_frames: sessionData.droppedFrames,
      latency: sessionData.lastLatency,
      resolution: sessionData.lastResolution,
      recorded_at: new Date().toISOString()
    });
  }

  /**
   * Track audience demographic insights
   */
  function trackAudienceInsight() {
    if (!sessionData.eventId) {
      return;
    }
    
    queueMetric({
      type: 'audience_insight',
      event_id: sessionData.eventId,
      channel_id: sessionData.channelId,
      session_id: sessionData.sessionId,
      demographic_group: userData.demographicGroup,
      age_range: userData.ageRange,
      gender: userData.gender,
      country: userData.country,
      region: userData.region,
      city: userData.city,
      device_type: userData.deviceType,
      browser: userData.browser,
      os: userData.os,
      referral_source: userData.referralSource,
      recorded_at: new Date().toISOString()
    });
  }

  /**
   * End a watch session and record final metrics
   */
  function endWatchSession() {
    // Stop heartbeat
    clearInterval(sessionData.heartbeatInterval);
    
    // Calculate final watch time
    const watchTime = calculateWatchTime();
    
    // Record final session metric
    queueMetric({
      type: 'session_metric',
      session_id: sessionData.sessionId,
      channel_id: sessionData.channelId,
      average_watch_time: watchTime,
      recorded_at: new Date().toISOString()
    });
    
    // Update audience insight with watch time
    if (sessionData.eventId) {
      queueMetric({
        type: 'audience_insight',
        event_id: sessionData.eventId,
        channel_id: sessionData.channelId,
        session_id: sessionData.sessionId,
        watch_time: watchTime,
        recorded_at: new Date().toISOString()
      });
    }
    
    log('Watch session ended. Total watch time:', watchTime);
    
    // Send metrics immediately
    sendMetricsBatch();
  }

  /**
   * Track a purchase event for revenue tracking
   * @param {Object} purchase - Purchase details
   */
  function trackPurchase(purchase) {
    const channelId = purchase.channelId || getChannelId();
    
    if (!channelId) {
      return;
    }
    
    // Determine purchase type
    let purchaseType = '';
    let countField = '';
    let amountField = '';
    
    switch (purchase.type) {
      case 'subscription':
        purchaseType = 'subscription';
        countField = 'subscription_count';
        amountField = 'subscription_amount';
        break;
      case 'donation':
        purchaseType = 'donation';
        countField = 'donation_count';
        amountField = 'donation_amount';
        break;
      case 'ticket':
        purchaseType = 'ticket';
        countField = 'ticket_count';
        amountField = 'ticket_amount';
        break;
      case 'merchandise':
        purchaseType = 'merchandise';
        countField = 'merchandise_count';
        amountField = 'merchandise_amount';
        break;
      default:
        purchaseType = 'other';
    }
    
    // Create metric object
    const metric = {
      type: 'revenue_metric',
      channel_id: channelId,
      event_id: purchase.eventId || null,
      total_amount: purchase.amount,
      currency: purchase.currency || 'USD',
      date: new Date().toISOString().split('T')[0]
    };
    
    // Add type-specific fields
    if (countField) {
      metric[countField] = 1;
    }
    
    if (amountField) {
      metric[amountField] = purchase.amount;
    }
    
    queueMetric(metric);
    
    // Send revenue metrics immediately
    sendMetricsBatch();
  }

  /**
   * Add a metric to the queue
   * @param {Object} metric - The metric to queue
   */
  function queueMetric(metric) {
    metricsQueue.push(metric);
    
    // Send immediately if we've reached batch size
    if (metricsQueue.length >= config.batchSize) {
      sendMetricsBatch();
    }
  }

  /**
   * Send a batch of metrics to the server
   */
  function sendMetricsBatch() {
    if (metricsQueue.length === 0) {
      return;
    }
    
    // Clone and clear the queue
    const batch = [...metricsQueue];
    metricsQueue = [];
    
    // Prepare headers
    const headers = {
      'Content-Type': 'application/json'
    };
    
    if (config.apiKey) {
      headers['X-API-Key'] = config.apiKey;
    }
    
    // Send the batch
    fetch(config.apiEndpoint, {
      method: 'POST',
      headers: headers,
      body: JSON.stringify({ metrics: batch })
    })
    .then(response => {
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      log('Metrics batch sent successfully:', batch.length);
      return response.json();
    })
    .catch(error => {
      log('Error sending metrics:', error);
      // Put the metrics back in the queue for retry
      metricsQueue = [...batch, ...metricsQueue];
    });
  }

  /**
   * Handle page unload event
   */
  function handleUnload() {
    // Send any queued metrics
    if (metricsQueue.length > 0) {
      // Use sendBeacon for reliable delivery during page unload
      if (navigator.sendBeacon) {
        const blob = new Blob([JSON.stringify({ metrics: metricsQueue })], { type: 'application/json' });
        navigator.sendBeacon(config.apiEndpoint, blob);
        log('Metrics sent via beacon on page unload');
      } else {
        // Fallback to synchronous XHR
        const xhr = new XMLHttpRequest();
        xhr.open('POST', config.apiEndpoint, false);
        xhr.setRequestHeader('Content-Type', 'application/json');
        if (config.apiKey) {
          xhr.setRequestHeader('X-API-Key', config.apiKey);
        }
        xhr.send(JSON.stringify({ metrics: metricsQueue }));
        log('Metrics sent via sync XHR on page unload');
      }
      metricsQueue = [];
    }
    
    // End watch session if active
    if (sessionData.heartbeatInterval) {
      clearInterval(sessionData.heartbeatInterval);
    }
  }

  // Utility functions

  /**
   * Get the current channel ID from the page
   */
  function getChannelId() {
    // Try to get from session data first
    if (sessionData.channelId) {
      return sessionData.channelId;
    }
    
    // Try to get from data attribute
    const channelElement = document.querySelector('[data-channel-id]');
    if (channelElement) {
      return channelElement.getAttribute('data-channel-id');
    }
    
    // Try to extract from URL
    const channelMatch = window.location.pathname.match(/\/channels\/([^\/]+)/);
    if (channelMatch) {
      return channelMatch[1];
    }
    
    return null;
  }

  /**
   * Generate a unique ID
   */
  function generateId() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
      const r = Math.random() * 16 | 0;
      const v = c === 'x' ? r : (r & 0x3 | 0x8);
      return v.toString(16);
    });
  }

  /**
   * Detect device type
   */
  function detectDeviceType() {
    const ua = navigator.userAgent;
    if (/tablet|ipad|playbook|silk/i.test(ua)) {
      return 'tablet';
    }
    if (/mobile|iphone|ipod|android|blackberry|opera mini|iemobile/i.test(ua)) {
      return 'mobile';
    }
    return 'desktop';
  }

  /**
   * Detect browser
   */
  function detectBrowser() {
    const ua = navigator.userAgent;
    
    if (ua.indexOf("Chrome") > -1) {
      return "Chrome";
    } else if (ua.indexOf("Safari") > -1) {
      return "Safari";
    } else if (ua.indexOf("Firefox") > -1) {
      return "Firefox";
    } else if (ua.indexOf("MSIE") > -1 || ua.indexOf("Trident") > -1) {
      return "Internet Explorer";
    } else if (ua.indexOf("Edge") > -1) {
      return "Edge";
    } else {
      return "Unknown";
    }
  }

  /**
   * Detect operating system
   */
  function detectOS() {
    const ua = navigator.userAgent;
    
    if (ua.indexOf("Win") > -1) {
      return "Windows";
    } else if (ua.indexOf("Mac") > -1) {
      return "Mac OS";
    } else if (ua.indexOf("Linux") > -1) {
      return "Linux";
    } else if (ua.indexOf("Android") > -1) {
      return "Android";
    } else if (ua.indexOf("iOS") > -1 || ua.indexOf("iPhone") > -1 || ua.indexOf("iPad") > -1) {
      return "iOS";
    } else {
      return "Unknown";
    }
  }

  /**
   * Log messages in debug mode
   */
  function log(...args) {
    if (config.debugMode) {
      console.log('[Frestyl Analytics]', ...args);
    }
  }

  // Public API
  return {
    init
  };
})();

// Make analytics available globally
window.FrestylAnalytics = FrestylAnalytics;

// Initialize analytics if the data attribute is present
document.addEventListener('DOMContentLoaded', () => {
  const analyticsConfig = document.querySelector('[data-analytics-config]');
  if (analyticsConfig) {
    try {
      const config = JSON.parse(analyticsConfig.getAttribute('data-analytics-config'));
      FrestylAnalytics.init(config);
    } catch (e) {
      console.error('Error initializing analytics:', e);
    }
  }
});