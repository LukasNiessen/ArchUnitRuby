# GitHub Pages

ArchUnitRuby publishes its guide and API reference at
<https://lukasniessen.github.io/ArchUnitRuby/>.

The site is generated from `README.md` and the public Ruby source with YARD. Its custom stylesheet
lives in `docs-assets/`; `scripts/prepare_docs.rb` adds shared navigation and the static files that
GitHub Pages needs. `scripts/check_docs.rb` then checks the complete generated site for missing
artifacts, missing theme injection, and broken internal links. The generated `docs/` directory is
intentionally ignored.

Build the exact deployment artifact locally with:

```bash
bundle exec rake docs
```

To inspect it in a browser, serve it as static files instead of opening pages directly:

```bash
ruby -run -e httpd docs -p 8000
```

Every push and pull request validates the build in `ci.yml`. A push to `main` also uploads and
deploys the result through `docs.yml` using GitHub's official Pages actions.
