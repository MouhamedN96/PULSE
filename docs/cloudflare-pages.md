# Cloudflare Pages Frontend + Railway Backend

This repo can be deployed as:

- `Railway`: Rust API backend
- `Cloudflare Pages`: Flutter web frontend plus a `/api/*` Pages Function proxy

## Why this split

The Flutter web build uses same-origin `/api` on web by default. The Pages Function in
`flutter_app/functions/api/[[path]].js` proxies those requests to Railway, so the frontend
does not need a hardcoded backend URL baked into the build artifact.

## Files

- `flutter_app/wrangler.jsonc`: Pages project config
- `flutter_app/functions/api/[[path]].js`: catch-all proxy to Railway
- `flutter_app/build/web`: static Flutter web artifact deployed to Pages

## Deploy

From `flutter_app/`:

```powershell
npm install
npm run cf:project:create
npm run cf:deploy
```

If the project already exists:

```powershell
npm run cf:deploy
```

## Railway origin

The proxy reads `RAILWAY_API_ORIGIN` from Wrangler config, and defaults to:

`https://pulse-production-62b2.up.railway.app`

If Railway changes, update:

- `flutter_app/wrangler.jsonc`

If you prefer dashboard-managed variables instead, remove `RAILWAY_API_ORIGIN` from Wrangler config first so Pages can own that value.

## Authentication

In this environment, Wrangler expects a token-based login:

```powershell
$env:CLOUDFLARE_API_TOKEN="..."
npm run cf:whoami
```
