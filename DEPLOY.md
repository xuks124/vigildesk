# Deploying the VigilDesk docs site

The site is pure static (HTML/CSS/SVG, **zero external resources**), so any
static host works. Source: this directory (`docs-site/`).

Local preview first:

```bat
python docs-site\serve.py --port 8080
:: open http://127.0.0.1:8080/
```

---

## Option A — Cloudflare Pages

1. Push the repository to GitHub/GitLab (site root: `product/docs-site`).
2. Cloudflare dashboard → **Workers & Pages → Create → Pages → Connect to Git**,
   pick the repo.
3. Build settings:
   - **Framework preset:** `None`
   - **Build command:** *(leave empty — nothing to build)*
   - **Build output directory:** `docs-site` (relative to repo root)
4. **Save and Deploy.** Pages publishes to
   `https://<project>.pages.dev`; custom domains can be attached in the
   project's *Custom domains* tab.
5. Every push to the production branch redeploys automatically; PRs get
   preview URLs.

CLI alternative (optional):

```bat
npm install -g wrangler
wrangler pages deploy docs-site --project-name=vigildesk-docs
```

---

## Option B — GitHub Pages

1. Push the repo to GitHub.
2. Repo → **Settings → Pages → Build and deployment → Source: Deploy from a branch**.
3. Choose branch `main` and folder. Two choices:
   - **`/ (root)`** if the repo root *is* the site, or
   - `/docs` after moving/renaming `docs-site/` to `docs/` (GitHub Pages
     only recognizes the `docs/` folder name for branch deploys — or use
     the GitHub Actions workflow below to keep the folder name).
4. **Actions workflow alternative** (keeps `docs-site/` name) — add
   `.github/workflows/pages.yml`:

   ```yaml
   name: pages
   on:
     push:
       branches: [main]
   permissions:
     contents: read
     pages: write
     id-token: write
   jobs:
     deploy:
       runs-on: ubuntu-latest
       environment:
         name: github-pages
         url: ${{ steps.deployment.outputs.page_url }}
       steps:
         - uses: actions/checkout@v4
         - uses: actions/upload-pages-artifact@v3
           with:
             path: product/docs-site
         - uses: actions/deploy-pages@v4
           id: deployment
   ```
5. Site goes live at `https://<user>.github.io/<repo>/`.

---

## Post-deploy checklist

- [ ] `index.html`, `faq.html`, `faq-zh.html` all return 200.
- [ ] `assets/logo.svg` and `style.css` load (no 404s in the browser console).
- [ ] No external requests appear in DevTools → Network (site must be fully self-contained).
- [ ] Risk disclaimer visible on the landing page and both FAQ pages.
