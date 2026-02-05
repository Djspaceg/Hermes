# Releasing Hermes

Quick reference for creating releases. See [Documentation/ReleaseEngineering.md](Documentation/ReleaseEngineering.md) for detailed instructions.

## Prerequisites

- GitHub access token ([generate here](https://github.com/settings/tokens/))
- DSA private key (`hermes.key`) for Sparkle signatures
- Local clone of `hermes-pages` repository

## Quick Release

```bash
# 1. Bump versions
agvtool bump -all
agvtool new-marketing-version X.Y.Z

# 2. Update CHANGELOG.md with release date and changes

# 3. Test
make CONFIGURATION=Release
make test

# 4. Create and upload release
make upload-release GITHUB_ACCESS_TOKEN=<token>

# 5. Commit, push, and publish
git commit -am "vX.Y.Z"
git push

# 6. Publish the draft release on GitHub

# 7. Update website
cd ../hermes-pages
git add .
git commit -m "vX.Y.Z"
git push
```

## Version Commands

```bash
agvtool mvers -terse1              # Show current marketing version
agvtool bump -all                  # Increment build number
agvtool new-marketing-version X.Y.Z  # Set marketing version
```
