(function () {
  const siteConfig = window.TERMITE_SITE_CONFIG || {};
  const analyticsConfig = siteConfig.analytics || {};
  const enableLocalAnalytics = Boolean(analyticsConfig.enableLocalAnalytics);
  const isLocalHost = ['localhost', '127.0.0.1', '[::1]'].includes(window.location.hostname);

  if (isLocalHost && !enableLocalAnalytics) {
    return;
  }

  const plausibleConfig = analyticsConfig.plausible || {};
  const plausibleDomain = String(plausibleConfig.domain || '').trim();
  const plausibleScriptSrc = String(plausibleConfig.scriptSrc || 'https://plausible.io/js/script.js').trim();
  const ga4Config = analyticsConfig.ga4 || {};
  const ga4MeasurementId = String(ga4Config.measurementId || '').trim();
  const ga4Options = Object.assign(
    {
      allow_google_signals: false,
      allow_ad_personalization_signals: false
    },
    ga4Config.config || {}
  );

  const hasPlausible = plausibleDomain.length > 0;
  const hasGa4 = ga4MeasurementId.length > 0;

  if (!hasPlausible && !hasGa4) {
    return;
  }

  if (hasPlausible) {
    window.plausible = window.plausible || function () {
      (window.plausible.q = window.plausible.q || []).push(arguments);
    };

    const plausibleScript = document.createElement('script');
    plausibleScript.defer = true;
    plausibleScript.dataset.domain = plausibleDomain;
    plausibleScript.src = plausibleScriptSrc;
    document.head.appendChild(plausibleScript);
  }

  if (hasGa4) {
    const ga4Script = document.createElement('script');
    ga4Script.async = true;
    ga4Script.src = `https://www.googletagmanager.com/gtag/js?id=${encodeURIComponent(ga4MeasurementId)}`;
    document.head.appendChild(ga4Script);

    window.dataLayer = window.dataLayer || [];
    window.gtag = window.gtag || function () {
      window.dataLayer.push(arguments);
    };

    window.gtag('js', new Date());
    window.gtag('config', ga4MeasurementId, ga4Options);
  }

  const trackedElements = document.querySelectorAll('[data-analytics-event]');

  function trackEvent(eventName, params) {
    if (!eventName) {
      return;
    }

    if (hasPlausible && typeof window.plausible === 'function') {
      window.plausible(eventName, { props: params });
    }

    if (hasGa4 && typeof window.gtag === 'function') {
      window.gtag('event', eventName, params);
    }
  }

  trackedElements.forEach((element) => {
    element.addEventListener('click', () => {
      const eventName = element.getAttribute('data-analytics-event');
      const params = {
        cta_label: element.getAttribute('data-analytics-label') || element.textContent.trim().slice(0, 80),
        cta_location: element.getAttribute('data-analytics-location') || 'unknown',
        page_locale: document.documentElement.lang || 'en',
        page_pathname: window.location.pathname
      };

      trackEvent(eventName, params);
    });
  });
})();
