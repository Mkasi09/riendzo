# Riendzo Admin Dashboard Architecture

The active dashboard is bundled through webpack from `src/js/app.js`.

## Runtime Entry

- `index.html` loads `dist/bundle.js`.
- `src/js/app.js` owns app startup, navigation, and section rendering.
- Standalone/demo entry points have been removed; keep new work in the bundled module path.

## Data Access

- `src/js/modules/data-service.js` is the app-facing data layer.
- It reads from Firebase in deployed environments.
- It does not use demo or mock data in the active dashboard.
- If Firebase is unavailable, the UI shows a backend error state and exposes retry.
- Riendzo Partner transport operations read from the `transport_requests` Firestore collection used by `C:\dev\riendzo_partner`.

## Shared Display Helpers

- `src/js/modules/formatters.js` owns date, currency, avatar, and user-status formatting.
- Keep defensive formatting here instead of repeating guards in views.

## Styling

- `src/css/main.css` contains the active design system and dashboard layout.
- `src/css/components.css` and `src/css/dashboard.css` are intentionally lightweight compatibility files.

## Build And Preview

```bash
npm run build
npx serve . -l 3000
```

Local development uses the same Firebase-backed data path as production.
