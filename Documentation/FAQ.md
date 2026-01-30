# Frequently Asked Questions

## Help! Hermes crashes on startup or behaves badly

If you're experiencing crashes or unexpected behavior, try resetting Hermes to its default state:

### Manual Reset Steps

1. Quit Hermes completely
2. Remove application support files: `~/Library/Application Support/Hermes/`
3. Remove preferences: `~/Library/Preferences/com.alexcrichton.Hermes.plist`
4. Remove caches: `~/Library/Caches/com.alexcrichton.Hermes/`
5. Remove Hermes credentials from Keychain:
   - Open Keychain Access
   - Search for "Hermes"
   - Select all items named "Hermes"
   - Press Delete or choose Edit → Delete

### Quick Reset Script

Run this shell script to reset everything at once:

```bash
# Exit Hermes if running
killall Hermes 2>/dev/null

# Remove application data
rm -rf ~/Library/Application\ Support/Hermes
rm -f ~/Library/Preferences/com.alexcrichton.Hermes.plist
rm -rf ~/Library/Caches/com.alexcrichton.Hermes

# Remove keychain entries
while security delete-generic-password -l Hermes >/dev/null 2>&1; do :; done

echo "Hermes has been reset. You can now launch it fresh."
```

**Note:** If you needed to reset Hermes, there may be a bug. Please [report it on GitHub](https://github.com/HermesApp/Hermes/issues) so we can fix it!

## How do I enable debug logging?

Hermes includes comprehensive logging for troubleshooting:

### Enable Logging

Hold down the **⌥ (Option)** key while launching Hermes. You'll see a 🐞 (ladybug emoji) indicator when logging is active.

### View Logs

#### Option 1: Console.app

1. Open Console.app (`/Applications/Utilities/Console.app`)
2. In the sidebar under "FILES", expand `~/Library/Logs`
3. Expand the `Hermes` folder
4. Click on the latest log file

#### Option 2: Terminal

```bash
# View the most recent log
cat ~/Library/Logs/Hermes/hermes-*.log | tail -n 100

# Follow logs in real-time
tail -f ~/Library/Logs/Hermes/hermes-*.log
```

When reporting bugs, please include relevant log excerpts to help us diagnose the issue.

## Does Hermes work with Pandora One/Premium?

Yes! Hermes fully supports both free Pandora accounts and Pandora One/Premium subscriptions. Premium users automatically get higher quality audio streams.

## Can I use Hermes outside the United States?

Pandora's service is geographically restricted to the United States. If you're outside the US, you'll need to use a VPN or proxy service. Hermes includes proxy configuration in Preferences → Network.

## How do I control Hermes with keyboard shortcuts?

Hermes supports extensive keyboard control. See [KeyboardShortcuts.md](KeyboardShortcuts.md) for a complete list.

Common shortcuts:

- **Space** - Play/Pause
- **⌘E** - Next song
- **⌘L** - Like song
- **⌘D** - Dislike song
- **⌘T** - Tired of song

## Can I scrobble to Last.fm?

Yes! Go to Preferences → Playback and enable "Scrobble tracks to Last.fm". You can also configure whether to scrobble only liked tracks.

## How do I control media keys with Hermes?

Media keys (play/pause, next track) work automatically through macOS's built-in media control system (MPRemoteCommandCenter).

To enable or disable media key support, go to **Preferences → General → "Control playback with media keys"**. This setting is enabled by default.

When enabled, you can control Hermes playback using:

- The play/pause and next track keys on your keyboard
- Touch Bar media controls (if available)
- Control Center media controls
- Lock screen media controls

## The album artwork isn't loading

Hermes caches album artwork for better performance. If artwork isn't appearing:

1. Check your internet connection
2. Try selecting a different station and coming back
3. Clear the artwork cache: `rm -rf ~/Library/Application\ Support/Hermes/station_artwork_cache.json`
4. Restart Hermes

## Can I run Hermes as a menu bar app only?

Yes! In Preferences → General, enable "Run as menu bar accessory (hide Dock icon)". Hermes will only appear in the menu bar.

## How do I report a bug or request a feature?

We actively monitor GitHub issues:

1. Check [existing issues](https://github.com/HermesApp/Hermes/issues) to see if it's already reported
2. [Open a new issue](https://github.com/HermesApp/Hermes/issues/new) with:
   - Clear description of the problem or feature
   - Steps to reproduce (for bugs)
   - macOS version and Hermes version
   - Relevant log excerpts if applicable

## Is Hermes open source?

Yes! Hermes is open source under the MIT License. Contributions are welcome! See the [Contributing section](../README.md#contributing) in the README for details.
