/**
 * BroyhillGOP Visitor Deanonymization Pixel
 * E56 - Visitor Tracking & Intent Scoring
 * 
 * Usage: Add to candidate website <head>:
 * <script src="https://cdn.broyhillgop.com/pixel.js" data-candidate="CANDIDATE_UUID"></script>
 */
(function() {
  'use strict';
  
  // Configuration
  const API_ENDPOINT = 'https://api.broyhillgop.com/v1/pixel';
  const COOKIE_NAME = 'bgop_vid';
  const COOKIE_DAYS = 365;
  const HEARTBEAT_INTERVAL = 30000; // 30 seconds
  
  // Get candidate ID from script tag
  const scriptTag = document.currentScript || document.querySelector('script[data-candidate]');
  const CANDIDATE_ID = scriptTag?.getAttribute('data-candidate');
  
  if (!CANDIDATE_ID) {
    console.warn('BroyhillGOP Pixel: Missing data-candidate attribute');
    return;
  }
  
  // Session state
  const session = {
    visitorId: null,
    sessionId: null,
    startTime: Date.now(),
    pageViews: 0,
    maxScroll: 0,
    formInteractions: 0,
    events: []
  };
  
  // ============================================
  // UTILITY FUNCTIONS
  // ============================================
  
  function generateId() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
      const r = Math.random() * 16 | 0;
      return (c === 'x' ? r : (r & 0x3 | 0x8)).toString(16);
    });
  }
  
  function getCookie(name) {
    const match = document.cookie.match(new RegExp('(^| )' + name + '=([^;]+)'));
    return match ? match[2] : null;
  }
  
  function setCookie(name, value, days) {
    const expires = new Date(Date.now() + days * 864e5).toUTCString();
    document.cookie = name + '=' + value + '; expires=' + expires + '; path=/; SameSite=Lax';
  }
  
  function getVisitorId() {
    let vid = getCookie(COOKIE_NAME);
    if (!vid) {
      vid = generateId();
      setCookie(COOKIE_NAME, vid, COOKIE_DAYS);
    }
    return vid;
  }
  
  // ============================================
  // FINGERPRINTING (Privacy-Respecting)
  // ============================================
  
  function getFingerprint() {
    const components = {
      userAgent: navigator.userAgent,
      language: navigator.language,
      platform: navigator.platform,
      screenRes: screen.width + 'x' + screen.height,
      colorDepth: screen.colorDepth,
      timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
      touchSupport: 'ontouchstart' in window
    };
    
    // Simple hash
    const str = JSON.stringify(components);
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      hash = ((hash << 5) - hash) + str.charCodeAt(i);
      hash |= 0;
    }
    return Math.abs(hash).toString(16);
  }
  
  // ============================================
  // DATA COLLECTION
  // ============================================
  
  function getPageType() {
    const path = window.location.pathname.toLowerCase();
    if (path.includes('donate') || path.includes('contribution')) return 'donate';
    if (path.includes('volunteer') || path.includes('signup')) return 'volunteer';
    if (path.includes('event')) return 'event';
    if (path.includes('about') || path.includes('bio')) return 'about';
    if (path.includes('issue') || path.includes('policy')) return 'issues';
    if (path.includes('contact')) return 'contact';
    if (path === '/' || path === '/index.html') return 'home';
    return 'other';
  }
  
  function getUTMParams() {
    const params = new URLSearchParams(window.location.search);
    return {
      utm_source: params.get('utm_source'),
      utm_medium: params.get('utm_medium'),
      utm_campaign: params.get('utm_campaign'),
      utm_content: params.get('utm_content'),
      utm_term: params.get('utm_term')
    };
  }
  
  function getDeviceType() {
    const ua = navigator.userAgent;
    if (/tablet|ipad|playbook|silk/i.test(ua)) return 'tablet';
    if (/mobile|iphone|ipod|android|blackberry|opera mini|iemobile/i.test(ua)) return 'mobile';
    return 'desktop';
  }
  
  // ============================================
  // EVENT TRACKING
  // ============================================
  
  function trackScroll() {
    const scrollHeight = document.documentElement.scrollHeight - window.innerHeight;
    const scrollPercent = scrollHeight > 0 ? Math.round((window.scrollY / scrollHeight) * 100) : 100;
    if (scrollPercent > session.maxScroll) {
      session.maxScroll = scrollPercent;
    }
  }
  
  function trackFormInteraction(e) {
    const target = e.target;
    if (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA' || target.tagName === 'SELECT') {
      session.formInteractions++;
      trackEvent('form_interaction', {
        fieldType: target.type || target.tagName.toLowerCase(),
        fieldName: target.name || target.id
      });
    }
  }
  
  function trackClick(e) {
    const target = e.target.closest('a, button');
    if (!target) return;
    
    const href = target.href || '';
    const text = target.innerText?.substring(0, 50) || '';
    
    // High-value click detection
    if (href.includes('donate') || href.includes('winred') || href.includes('anedot') ||
        text.toLowerCase().includes('donate') || text.toLowerCase().includes('contribute')) {
      trackEvent('donate_click', { href, text });
    } else if (href.includes('volunteer') || text.toLowerCase().includes('volunteer')) {
      trackEvent('volunteer_click', { href, text });
    }
  }
  
  function trackEvent(eventType, eventData) {
    session.events.push({
      type: eventType,
      data: eventData,
      timestamp: Date.now()
    });
    
    // Send high-value events immediately
    if (['donate_click', 'volunteer_click', 'form_submit'].includes(eventType)) {
      sendEvent(eventType, eventData);
    }
  }
  
  // ============================================
  // API COMMUNICATION
  // ============================================
  
  function sendBeacon(endpoint, data) {
    const payload = JSON.stringify(data);
    
    if (navigator.sendBeacon) {
      navigator.sendBeacon(endpoint, payload);
    } else {
      fetch(endpoint, {
        method: 'POST',
        body: payload,
        headers: { 'Content-Type': 'application/json' },
        keepalive: true
      }).catch(() => {});
    }
  }
  
  function sendPageView() {
    session.pageViews++;
    
    const data = {
      candidate_id: CANDIDATE_ID,
      visitor_id: session.visitorId,
      session_id: session.sessionId,
      fingerprint: getFingerprint(),
      
      page_url: window.location.href,
      page_path: window.location.pathname,
      page_title: document.title,
      page_type: getPageType(),
      referrer: document.referrer,
      
      device_type: getDeviceType(),
      user_agent: navigator.userAgent,
      
      ...getUTMParams(),
      
      event_type: 'page_view',
      timestamp: Date.now()
    };
    
    sendBeacon(API_ENDPOINT + '/pageview', data);
  }
  
  function sendHeartbeat() {
    const data = {
      candidate_id: CANDIDATE_ID,
      visitor_id: session.visitorId,
      session_id: session.sessionId,
      
      time_on_page: Math.round((Date.now() - session.startTime) / 1000),
      scroll_depth: session.maxScroll,
      form_interactions: session.formInteractions,
      
      event_type: 'heartbeat',
      timestamp: Date.now()
    };
    
    sendBeacon(API_ENDPOINT + '/heartbeat', data);
  }
  
  function sendEvent(eventType, eventData) {
    const data = {
      candidate_id: CANDIDATE_ID,
      visitor_id: session.visitorId,
      session_id: session.sessionId,
      
      event_type: eventType,
      event_data: eventData,
      page_url: window.location.href,
      
      timestamp: Date.now()
    };
    
    sendBeacon(API_ENDPOINT + '/event', data);
  }
  
  function sendSessionEnd() {
    const data = {
      candidate_id: CANDIDATE_ID,
      visitor_id: session.visitorId,
      session_id: session.sessionId,
      
      total_time: Math.round((Date.now() - session.startTime) / 1000),
      page_views: session.pageViews,
      max_scroll: session.maxScroll,
      form_interactions: session.formInteractions,
      events_count: session.events.length,
      
      event_type: 'session_end',
      timestamp: Date.now()
    };
    
    sendBeacon(API_ENDPOINT + '/session', data);
  }
  
  // ============================================
  // INITIALIZATION
  // ============================================
  
  function init() {
    // Initialize session
    session.visitorId = getVisitorId();
    session.sessionId = generateId();
    
    // Track initial page view
    sendPageView();
    
    // Event listeners
    window.addEventListener('scroll', trackScroll, { passive: true });
    document.addEventListener('focusin', trackFormInteraction);
    document.addEventListener('click', trackClick);
    
    // Heartbeat
    setInterval(sendHeartbeat, HEARTBEAT_INTERVAL);
    
    // Session end on page unload
    window.addEventListener('beforeunload', sendSessionEnd);
    document.addEventListener('visibilitychange', function() {
      if (document.visibilityState === 'hidden') {
        sendSessionEnd();
      }
    });
    
    // Expose for custom events
    window.bgopTrack = trackEvent;
  }
  
  // Start when DOM ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
