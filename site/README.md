# Landing Page

This directory contains the static bilingual landing page deployed with GitHub Pages.

## Structure

- `site/index.html` — English landing page
- `site/zh-CN/index.html` — Chinese landing page
- `site/styles.css` — shared styling
- `site/config.js` — editable analytics settings
- `site/analytics.js` — optional Plausible and GA4 bootstrap plus CTA click tracking
- `site/assets/` — images and favicon used by the site
- `.github/workflows/deploy-pages.yml` — deploys `site/` to GitHub Pages

## Analytics

Edit `site/config.js` to turn on one or both analytics providers.

```js
window.TERMITE_SITE_CONFIG = {
  analytics: {
    enableLocalAnalytics: false,
    plausible: {
      domain: '',
      scriptSrc: 'https://plausible.io/js/script.js'
    },
    ga4: {
      measurementId: '',
      config: {
        allow_google_signals: false,
        allow_ad_personalization_signals: false
      }
    }
  }
};
```

- Set `analytics.plausible.domain` to the site you created in Plausible.
- Set `analytics.ga4.measurementId` to your `G-...` web stream ID.
- Leave either value empty to disable that provider.
- Keep `enableLocalAnalytics` as `false` unless you intentionally want local preview traffic in your reports.
- CTA clicks are wired through `data-analytics-event`, `data-analytics-label`, and `data-analytics-location` attributes.

## Local preview

```bash
python3 -m http.server 4173 --directory site
```

Then open:

- `http://127.0.0.1:4173/`
- `http://127.0.0.1:4173/zh-CN/`

## Publishing

Push to `main` after editing files under `site/` or the deploy workflow.
The `Deploy Landing Page` workflow uploads the `site/` directory and publishes it to GitHub Pages.
