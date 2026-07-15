# Touch Bar Lyrics

A small macOS menu-bar utility that shows the current line of synchronized
Spotify lyrics on the MacBook Pro Touch Bar.

It does not require Spicetify or a Spotify developer token. The app reads the
current track and playback position through Spotify's macOS automation support,
then retrieves community-provided synchronized lyrics from
[LRCLIB](https://lrclib.net).

## Requirements

- A MacBook Pro with a physical Touch Bar
- macOS 13 or newer (initially tested on macOS 26)
- Spotify for macOS
- Xcode command-line tools
- Internet access for LRCLIB lookups

## Build and run

```sh
./scripts/build-app.sh
open "build/Touch Bar Lyrics.app"
```

Or build, copy to `~/Applications`, and launch it:

```sh
./scripts/install.sh
```

On first use, macOS asks for permission to automate Spotify. The app only reads
the current track, playback state, and playback position. Track title, artist,
album, and duration are sent to LRCLIB to find lyrics.

The app has no Dock icon or main window. Use its quote-bubble menu-bar item to
enable or disable lyrics, configure Launch at Login, or quit.

## Development

Run the test suite with:

```sh
swift test
```

Core synchronization and parsing code lives in `TouchBarLyricsCore`. The native
app target contains Spotify automation, menu-bar lifecycle, and Touch Bar
presentation.

## Important limitations

- LRCLIB data is community-maintained. Some songs have no synchronized lyrics,
  and timestamps can differ from Spotify's built-in lyric display.
- The app displays line-synchronized lyrics, not word-by-word karaoke.
- System-wide Touch Bar presentation uses private AppKit/DFRFoundation APIs.
  Apple can change these APIs, and apps using them are not suitable for the Mac
  App Store.
- Public distribution should use Developer ID signing and notarization. The
  included build script uses ad-hoc signing for local development only.

The private Touch Bar approach is based on the technique used by open-source
projects such as [MTMR](https://github.com/Toxblh/MTMR).
