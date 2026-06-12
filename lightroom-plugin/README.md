# Lightroom Classic → Portfolio Plugin

Publish photos straight from Lightroom Classic to griffinfrankel.com — no
exporting to disk, no dragging files into the admin page.

The plugin shows up as an export destination inside Lightroom. Pick a gallery,
hit Export, and each photo is rendered to the site's standard (2400px long
edge, JPEG quality 82, sRGB), uploaded to the repo, and added to
`photos.json`. GitHub Pages redeploys and the photos are live about a minute
later.

## Install (one time)

1. Get this folder onto your computer — either clone the repo or download it
   (green **Code** button → **Download ZIP**) and unzip.
2. Open Lightroom Classic → **File → Plug-in Manager…**
3. Click **Add**, then select the `GriffinFrankelPortfolio.lrplugin` folder
   (inside `lightroom-plugin/`).
4. Click **Done**.

## Connect (one time)

1. Select any photo and choose **File → Export…**
2. At the top, set **Export To: Griffin Frankel Portfolio**.
3. Paste your GitHub personal access token — the same kind the admin page
   uses. Create one at
   [github.com/settings/tokens/new](https://github.com/settings/tokens/new?scopes=repo&description=GFP+Lightroom)
   with the **repo** scope.
4. Click **Test connection**. On success the token is saved in Lightroom's
   password store (not in plain text, and never in export presets).

## Everyday use

1. Select the photos you want on the site (edited, cropped — what you see is
   what gets published).
2. **File → Export…** (or use a saved preset — see below).
3. Choose the gallery: **People**, **City & Nature**, or **Events**.
4. Click **Export**. A progress bar tracks the uploads; you'll get a
   confirmation when everything is live.

Tip: after setting the gallery once, click **Add** in the export dialog's
preset panel to save it (e.g. "Portfolio — People"). From then on it's
right-click → **Export → Portfolio — People** on any selection.

## Good to know

- **Sizing is automatic.** The plugin forces 2400px / quality 82 / sRGB with
  copyright-only metadata (location stripped), matching what the admin page
  does to uploads. There's nothing to configure per export.
- **Re-exports update, not duplicate.** Exporting a photo with the same
  filename replaces the image and its gallery entry.
- **Aspect ratios are recorded** from the cropped dimensions, so the masonry
  layout is correct immediately.
- **The admin page still works** for deletes and reordering — the plugin and
  the admin page edit the same `photos.json`.
- Avoid publishing from the admin page at the same moment an export is
  running; both write `photos.json` and the second writer would get a
  conflict error and need to retry.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| "Connection failed" / HTTP 401 | Token is wrong or expired — create a new one with the **repo** scope. |
| "GitHub returned HTTP 409" on photos.json | Someone else (likely the admin page) published at the same time. Export again — images already uploaded are skipped over by sha and just re-linked. |
| Photos uploaded but not on the site | GitHub Pages takes ~1 minute to deploy. Hard-refresh after that. |
| Plugin missing from the Export To menu | Plug-in Manager → check it's listed and enabled; re-add the `.lrplugin` folder if not. |
