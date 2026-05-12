# Releasing

This document describes how maintainers cut releases and how **Semantic Versioning** applies to this repo. Official spec: [SemVer 2.0.0](https://semver.org/).

## Artifacts

- **Current default:** Unsigned **`MisterRogersRenamer`** executable from `swift build -c release` (see [BUILD_GUIDE.md](BUILD_GUIDE.md)). The release workflow uploads `MisterRogersRenamer-macos-<arch>` (runner architecture, e.g. `arm64` or `x86_64`) to [GitHub Releases](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases).
- **Signed `.app` bundles** are out of scope for the automated workflow; add a separate pipeline later if needed.

## Artifact boundary: bundled catalog vs downloadable data (**Project decision**)

- **Shipped inside the tagged binary:** The bundled **`episodes.json`** and sidecar **`episodes.manifest.json`** (see [`Sources/MisterRogersRenamerCore/Resources/`](Sources/MisterRogersRenamerCore/Resources/)). Any revision to bundled episode rows or the manifest’s `contentSha256` requires **at least one SemVer bump** (almost always PATCH) **and** a new `v*` tag before users can pick up that data—not a silent re-upload under the same version.
- **Runtime / not versioned by this repo:** TheTVDB cache files under Application Support (`tvdb-{seriesId}-{lang}.json`); refreshing them does **not** require an app release. Users delete those files to force a refetch; see README.
- **Future (Option C — “no SemVer bump for data-only”)** is viable only after episode data is **outside** the SemVer‑tagged artifact—for example downloadable sidecar manifests, CDN-hosted packages, or a separate release channel—and the team documents how users pin or roll back that stream. Until then, bundled data rides every app release alongside code.

## Bundled-data manifest (`episodes.manifest.json`)

Regeneration via [`Scripts/build_episodes_json.py`](Scripts/build_episodes_json.py) updates:

- **`contentSha256`** — SHA‑256 of the written `episodes.json` bytes (canonical check for CI and releases).
- **`dataRevision`** — Opaque revision string (default `mrn-YYYY-MM-DD` when merged content changes; unchanged if regenerated output is bitwise identical unless you pass `--data-revision`).
- **`generatedAt`**, **`dataset`**, **`tvdbSeriesId`** — Attribution and tooling.

Expose **`dataRevision`** in GitHub Release notes when cutting a tag so support can correlate “two numbers”: app SemVer (`vX.Y.Z`) vs bundled catalog identity.

### Changelog and release-note categories

Use headings or bullets that distinguish intent (maps well to [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)):

| Category | Typical meaning |
|---------|----------------|
| **Code — Fix** | App bug fixes, renaming behavior corrections |
| **Code — Feature** | New UX, catalog modes, file patterns |
| **Data — Episode refresh** | Regenerated bundled JSON from Archive + TVDB (broader sweep) |
| **Data — Correction** | Small targeted bundled metadata fixes |
| **Build / CI** | Workflows, packaging, reproducibility |

When the manifest’s `contentSha256` changed, mention **`dataRevision`** explicitly in **Unreleased** / the version section before tagging.

## How to publish a release

1. Ensure `main` is green (CI passing).
2. Update [CHANGELOG.md](CHANGELOG.md) on `main` for the version you are about to tag (see sections below).
3. Create an annotated tag (example `v1.2.3`):
   ```bash
   git tag -a v1.2.3 -m "v1.2.3"
   git push origin v1.2.3
   ```
4. **GitHub Actions** [Release workflow](.github/workflows/release.yml) runs on push of `v*`, verifies the bundled catalog fingerprint, builds the binary, and creates or updates the GitHub **Release** (composed notes prepend **dataRevision / SHA‑256**, then GitHub‑generated changelog when available).

**Manual dispatch** (e.g. re-upload asset for an existing tag):

- Actions → **Release** → **Run workflow** → enter the existing tag (e.g. `v1.2.3`). The workflow checks out that tag, builds, and uploads the binary (creates the Release if missing, otherwise replaces the asset).

## SemVer and bundled data vs. code

This project is an application, not a library; we still use SemVer for **communicating impact** to users and contributors.

| Change | Typical level | Examples |
|--------|---------------|----------|
| **PATCH** | Fixes, data-only corrections | Typos in app UI; corrections to bundled `episodes.json` (metadata fixes) that don’t change how the app **interprets** files; CI/docs-only |
| **MINOR** | Additive behavior | New catalog mode, new file patterns, new options; larger `episodes.json` refreshes that only add/fix episode rows users expect |
| **MAJOR** | Breaking or high-impact | Documented rename rules change; removal of a mode; JSON shape change that breaks older app versions if they ever shared the file |

Team judgment applies: if a “data” change materially changes user-visible episode titles for many files, you may choose **MINOR** instead of **PATCH**—**document the call** in the changelog.

**Pre-releases:** Use SemVer pre-release labels when needed, e.g. `v2.0.0-rc.1` ([SemVer item 9](https://semver.org/#spec-item-9)).

## Branch protection (manual, GitHub UI)

To require CI before merge:

1. Repo **Settings** → **Branches** → **Add branch protection rule** (or edit existing) for `main` (and `master` if used).
2. Enable **Require a pull request before merging** (optional: required reviewers).
3. Enable **Require status checks** and select the **`build-test`** job from the **CI** workflow (optionally **`classify`** / **`label-pr`** if you want path classification or labels enforced — forks skip labeling when `GITHUB_TOKEN` is read‑only).

4. Save the rule.

This cannot be committed as code; repeat for new default branches if you rename them.

## Release automation tooling (manual tags today)

Tag-driven publishing remains the source of truth. If manual tagging becomes the bottleneck **after** the team adopts consistent [Conventional Commits](https://www.conventionalcommits.org/), pick **one**:

| Tool | Fits when… | Caveats |
|------|---------------|---------|
| **[release-please](https://github.com/googleapis/release-please)** | You want **`CHANGELOG.md` + merged “release PRs”**, simple `simple`/`rust`/custom manifest versioning, minimal JS stack | Tune `release-type` / config for SPM; artifacts still attach via Actions after tag or via extra job |
| **[semantic-release](https://github.com/semantic-release/semantic-release)** | Every commit message truly follows Conventions and you want **fully automated publish** driven by analyzes | Requires plugin setup for SPM/Swift binaries and tighter branch rules; brittle if commit discipline slips |

Recommendation: Prefer **release-please** until Conventional Commit compliance is measurable on `main`; only invest in semantic-release once messages are reliably machine-classifiable **and** the team budgets time for semantic-release plugins and recovery workflows.

Related (already wired): [.github/workflows/bundled-data-regen.yml](.github/workflows/bundled-data-regen.yml) can open data PRs with `TVDB_API_KEY`; it **never auto-tags**.
