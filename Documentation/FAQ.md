# Frequently Asked Questions

## Help! Hermes crashes on startup or behaves badly

Try resetting Hermes to its default state:

### Quick Reset

```bash
# Quit Hermes
killall Hermes 2>/dev/null

# Remove application data
rm -rf ~/Library/Application\ Support/Hermes
rm -f ~/Library/Preferences/com.alexcrichton.Hermes.plist
rm -rf ~/Library/Caches/com.alexcrichton.Hermes

# Remove keychain entries
while security delete-generic-password -l Hermes >/dev/null 2>&1; do :; done

echo "Hermes has been reset."
```

If you needed to reset, please [report the issue](https://github.com/HermesApp/Hermes/issues) so we can fix it!

## Does Hermes work with Pandora Premium?

Yes! Hermes supports both free Pandora accounts and Pandora Premium subscriptions. Premium users automatically get higher quality audio streams.

## Can I use Hermes outside the United States?

Pandora's service is geographically restricted to the US. You'll need a VPN or proxy. Hermes includes proxy configuration in Preferences → Network.

## How do I control Hermes with keyboard shortcuts?

See [KeyboardShortcuts.md](KeyboardShortcuts.md) for the complete list.

Common shortcuts:

- **Space** — Play/Pause
- **⌘E** — Next song
- **⌘L** — Like song
- **⌘D** — Dislike song (skips to next)
- **⌘T** — Tired of song (skips to next)

## Can I scrobble to Last.fm?

Yes! Go to Preferences → Playback and enable Last.fm scrobbling.

## How do media keys work?

Media keys work automatically through macOS's MPRemoteCommandCenter. Toggle in Preferences → General → "Control playback with media keys".

## The album artwork isn't loading

1. Check your internet connection
2. Try selecting a different station
3. Clear the cache: `rm -rf ~/Library/Application\ Support/Hermes/station_artwork_cache.json`
4. Restart Hermes

## Can I run Hermes as a menu bar app only?

Yes! In Preferences → General, enable "Run as menu bar accessory (hide Dock icon)".

## How do I view the album art fullscreen?

Click on the album artwork in the player to open the Album Art window, then click the green fullscreen button (or press ⌃⌘F).

## How do I report a bug?

[Open an issue on GitHub](https://github.com/HermesApp/Hermes/issues/new) with:

- Description of the problem
- Steps to reproduce
- macOS version and Hermes version

## Is Hermes open source?

Yes! MIT License. Contributions welcome — see [Contributing.md](Contributing.md).
