# Flextensions Documentation

This directory contains the source files for the Flextensions documentation site, served at [docs.flextensions.berkeley.edu](https://docs.flextensions.berkeley.edu).

The site is built with [Jekyll](https://jekyllrb.com/) and deployed automatically via GitHub Pages from the `docs/` directory on `main`. The custom domain is set by the `CNAME` file, so the site is served from the domain root (`baseurl` is empty).

## Local Development

```bash
cd docs
bundle install
bundle exec jekyll serve
```

Then visit http://localhost:4000/.

## Directory Structure

- `*.md` — Documentation pages (each has YAML front matter with `title` and `permalink`)
- `_config.yml` — Jekyll configuration
- `api/` — Swagger/OpenAPI reference (static HTML, not processed by Jekyll)
- `img/` — Images used in documentation
- `CNAME` — Custom domain for GitHub Pages (`docs.flextensions.berkeley.edu`)
- `_site/` — Generated output (gitignored)

## Adding a Page

Create a new `.md` file with front matter:

```markdown
---
title: Your Page Title
permalink: /your-page/
---

Content here...
```

Internal links should use absolute paths from the domain root, with a trailing slash, e.g. `[Developers](/developers/)`. Images work the same way: `![Home](/img/1-home.png)`.

## CI

The `Docs Build` workflow (`.github/workflows/docs.yml`) validates the Jekyll build and checks for broken internal links on PRs that touch `docs/`.
