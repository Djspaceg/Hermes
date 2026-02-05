# Release Engineering

## Requirements

- Xcode with macOS Tahoe (26.0) SDK
- DSA private key for Sparkle signatures (`~/Documents/hermes.key`)
- GitHub access token for releases
- Local clones:
  - `Hermes/` — the app repository
  - `hermes-pages/` — the GitHub Pages site

## Version Numbers

Hermes uses Apple Generic Versioning (`agvtool`):

- **Project version** (`CFBundleVersion`) — incrementing build number
- **Marketing version** (`CFBundleShortVersionString`) — user-facing version like `2.0.0`

## Release Process

### 1. Bump Version

```bash
cd Hermes/
agvtool bump -all                    # Increment build number
agvtool new-marketing-version 2.0.0  # Set marketing version
```

### 2. Update Changelog

Edit `CHANGELOG.md`:

- Add release date
- Update the comparison link to point to the new tag
- Document all significant changes

### 3. Test

```bash
make CONFIGURATION=Release
make test
```

Build and test the archive manually before releasing.

### 4. Create Release

```bash
make upload-release GITHUB_ACCESS_TOKEN=<token>
```

This will:

- Build the release archive
- Sign for Sparkle distribution
- Create a GitHub release draft
- Update the Sparkle appcast

### 5. Publish

1. Test the download from the GitHub draft release
2. Commit and push the version bump
3. Publish the release on GitHub (creates the git tag)
4. Update and push `hermes-pages` for the website

```bash
git commit -am "v2.0.0"
git push
git pull -t  # Pull the new tag

cd ../hermes-pages
git add .
git commit -m "v2.0.0"
git push
```

## Build Commands

```bash
make                        # Debug build
make CONFIGURATION=Release  # Release build
make archive                # Create distributable .zip
make test                   # Run unit tests
make clean                  # Remove build artifacts
```

## Sparkle Updates

- Public key: `Resources/dsa_pub.pem`
- Private key: `hermes.key` (obtain from project admin)
- Appcast: `hermes-pages/versions.xml`
