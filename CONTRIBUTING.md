# Contributing

Thank you for helping improve **Mister Rogers Renamer**. This project is open source; clear commits and PRs keep history readable for everyone.

## Development setup

- **Swift app:** See [BUILD_GUIDE.md](BUILD_GUIDE.md) and [QUICKSTART_SWIFT.md](QUICKSTART_SWIFT.md). Target **macOS 12+**.
- **Bundled episode JSON:** Built with Python in [`Scripts/build_episodes_json.py`](Scripts/build_episodes_json.py) (requires `TVDB_API_KEY` locally—never commit keys). The running app loads JSON from the Swift bundle, not Python.

## Pull requests

- Open a PR against the default branch (usually `main`). GitHub inserts [`.github/pull_request_template.md`](.github/pull_request_template.md)—fill bundled-data semver items when **`episodes.json`** / **`episodes.manifest.json`** change.
- CI runs on every PR: Swift debug/release build, `swift test`, and Python syntax check on `Scripts/*.py` (no network, no secrets).
- Keep changes focused; describe **what** and **why** in the PR body.

## Commit messages (recommended)

We recommend [Conventional Commits](https://www.conventionalcommits.org/) so future automation (changelog / version tools) can plug in cleanly.

**Format:** `type(scope): short description`

Common **types:** `feat`, `fix`, `docs`, `chore`, `test`, `ci`, `refactor`.

**Scopes (examples):** `app` (Swift UI/logic), `data` (bundled `episodes.json` or merge scripts), `scripts` (Python tooling), `ci` (GitHub Actions).

**Examples:**

- `fix(data): correct air date merge for production 1234`
- `feat(app): improve preview column layout`
- `ci: add macOS workflow for swift test`
- `docs: update RELEASING steps`

**Breaking changes:** Add a footer or use `feat(app)!:` and explain migration in the PR body (see [SemVer policy](RELEASING.md#semver-and-bundled-data-vs-code)).

## Merge strategy

Maintainers may **squash merge** with a single conventional subject so `main` stays easy to read. If you prefer merge commits, keep each commit conventional when possible.

## Code of conduct

Be respectful and assume good intent. For security-sensitive issues (e.g. exposed API keys), report privately to maintainers instead of a public issue.
