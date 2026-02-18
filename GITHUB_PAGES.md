# Publishing a static version on GitHub Pages

This app can be exported as a **static site** (HTML, CSS, JS, images) and published on GitHub Pages so you can browse it without a server or database.

## One-time setup

1. **Precompile assets** (so CSS/JS have stable filenames):
   ```bash
   rake assets:precompile
   ```

2. **Export the static site** into the `docs/` folder. You can do this in either of two ways.

### Option A – Export using a running server (recommended)

1. Start the Rails server (production so asset URLs match the precompiled files):
   ```bash
   # Windows (PowerShell)
   $env:SECRET_KEY_BASE="your-secret-key-or-any-dummy-string-for-export"; $env:RAILS_ENV="production"; bundle exec rails s -p 3000

   # macOS/Linux
   SECRET_KEY_BASE=static_export_dummy rails s -e production -p 3000
   ```

2. In another terminal, run the export (it will fetch each page from the server):
   ```bash
   rake static:export
   ```

3. Stop the server (Ctrl+C in the first terminal).

### Option B – Export without a server (in-process)

If you prefer not to run a server, you can try in-process export. It may hit CSRF/403 in some setups; if so, use Option A.

```bash
# Windows (PowerShell)
$env:STATIC_EXPORT="1"; $env:IN_PROCESS="1"; bundle exec rake static:export

# macOS/Linux
STATIC_EXPORT=1 IN_PROCESS=1 rake static:export
```

## Preview locally

The export uses **relative paths** and **Turbolinks is disabled** in the static build so that links do a normal full-page load (nothing intercepts them). You can open the site by double‑clicking **`docs/index.html`** (or opening it from your file manager). CSS, JS, and navigation should work.

If **images or icons** don’t show when opening the file directly, some browsers restrict loading local resources from `file://`. Use a local HTTP server instead: from the project root run `cd docs; python -m http.server 4000` (or `ruby -run -e httpd docs -p 4000`), then open http://127.0.0.1:4000/.

## Publish on GitHub Pages

1. Commit and push the `docs/` folder and the rest of the repo:
   ```bash
   git add docs/
   git commit -m "Add static export for GitHub Pages"
   git push
   ```

2. In your GitHub repo: **Settings → Pages**:
   - **Source**: Deploy from a branch
   - **Branch**: e.g. `main` or `master`
   - **Folder**: `/docs`
   - Save.

3. After a short wait, the site will be at:
   - **Project site**: `https://<username>.github.io/<repo-name>/`
   - Example: `https://myuser.github.io/finservdemo/`

The export uses base path **`/finservdemo`** by default so links and assets work under that URL. If your repo has a different name, run:

```bash
rake static:export BASE=/your-repo-name
```

## Customization

| Env var | Default | Purpose |
|--------|--------|--------|
| `BASE` | `/finservdemo` | Base path (usually your repo name with a leading slash) |
| `OUT` | `docs` | Output directory for the static site |
| `STATIC_EXPORT_URL` | `http://127.0.0.1:3000` | Server URL when using Option A |
| `IN_PROCESS` | (unset) | Set to `1` to use Option B |

Example: export for a repo named `my-demo` into a folder `build`:

```bash
rake static:export BASE=/my-demo OUT=build
```

Then configure GitHub Pages to publish from the `build` folder (or copy `build/` to `docs/` and publish from `docs`).
