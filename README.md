# Oh no, distractions

A tiny macOS app that blocks distracting websites (Reddit, YouTube, LinkedIn, …) in every browser, including Chrome and Safari.

- **Always blocked:** sites that stay blocked around the clock.
- **Blocked on a schedule:** sites that are blocked only during your time slots, e.g. 07:00–13:00 and 15:00–17:00, on the days you pick. Overnight slots (22:00–06:00) work too.

## How it works

The app writes your settings to `/Library/Application Support/SiteBlocker/config.txt`.
A small background helper (`siteblocker.sh`, run by launchd every minute and whenever the settings change) points the blocked sites to `127.0.0.1` in `/etc/hosts` while a block is active, and removes them afterwards.

## Build

Needs the Xcode command line tools (`xcode-select --install`).

```bash
./build.sh
```

This creates `Oh no, distractions.app`. Drag it into Applications, open it, and click **Install** (asks for your Mac password once to set up the helper).

To remove everything, click **Uninstall** in the app. It cleans up `/etc/hosts` and the helper.

## Files

| Path | What |
|---|---|
| `main.swift` | The SwiftUI app |
| `Resources/siteblocker.sh` | Helper script that edits `/etc/hosts` |
| `Resources/com.siteblocker.daemon.plist` | launchd job for the helper |
| `build.sh` | Compiles the app and bundles the icon and background |
| `art/` | Icon and background artwork; `render.swift` draws the generated icons |

## Credits

Comic artwork (app icon and window background) by [Catana Comics](https://catanacomics.com), with a reddit edit. All rights to the comic belong to its creator.
