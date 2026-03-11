# Landing Page

This directory contains the static bilingual landing page deployed with GitHub Pages.

## Structure

- `site/index.html` — English landing page
- `site/zh-CN/index.html` — Chinese landing page
- `site/styles.css` — shared styling
- `site/assets/` — images and favicon used by the site
- `.github/workflows/deploy-pages.yml` — deploys `site/` to GitHub Pages

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
