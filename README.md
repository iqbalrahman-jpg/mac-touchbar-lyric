# Touch Bar Lyrics

Touch Bar Lyrics is a lightweight macOS menu-bar utility that displays the
current line of synchronized Spotify lyrics on a MacBook Pro Touch Bar.

It does not require Spicetify, a Spotify developer account, or a Spotify API
token. It reads the current track and playback position through Spotify's macOS
automation support and retrieves community-provided synchronized lyrics from
[LRCLIB](https://lrclib.net).

## Example

While Spotify is playing, the current lyric is shown left-aligned on the Touch
Bar and updates as the song progresses:

```text
┌──────────────────────────────────────────────────────────────┬─────────────┐
│  And you're right here by my side                            │ Control Strip│
└──────────────────────────────────────────────────────────────┴─────────────┘
```

Pausing Spotify keeps the current line visible but dims it. Seeking or changing
tracks automatically selects the corresponding lyric line.

LRCLIB provides timestamps for complete lines rather than individual words, so
karaoke progress is estimated from the number of words and shown as a smooth
left-to-right color fill.

## Features

- Line-synchronized Spotify lyrics
- Smooth estimated karaoke highlighting across each lyric line
- Spotify album artwork and song title with tap-to-play/pause,
  swipe-to-change-track, and pinch artwork focus gestures
- Persistent display while using other applications
- Left-aligned, automatically resized lyric text
- Pause, resume, seek, and track-change synchronization
- Menu-bar controls with no Dock icon or main window
- Optional Launch at Login
- No Spotify credentials or API tokens

## Requirements

- A MacBook Pro with a physical Touch Bar
- macOS 13 or newer (initially tested on Apple silicon with macOS 26)
- Spotify for macOS
- Internet access for LRCLIB lookups
- Xcode command-line tools only when building from source

## Install a prebuilt release (recommended)

Prebuilt releases do not require Xcode, Homebrew, Git, or Terminal.

1. Open the [latest GitHub release](https://github.com/iqbalrahman-jpg/mac-touchbar-lyric/releases/latest).
2. Download and extract `TouchBarLyrics-v<version>-arm64.zip`.
3. Move **Touch Bar Lyrics.app** into `/Applications`.
4. Try opening the app once.
5. If Gatekeeper blocks the free, non-notarized build, open **System Settings →
   Privacy & Security**, scroll to Security, choose **Open Anyway**, and confirm
   **Open**.

Only bypass Gatekeeper when the download came from this repository and you
trust its contents. Public releases are currently ad-hoc signed, not notarized
by Apple.

## Install from source

1. Install Apple's command-line tools if they are not already available:

   ```sh
   xcode-select --install
   ```

2. Clone and enter the repository:

   ```sh
   git clone https://github.com/iqbalrahman-jpg/mac-touchbar-lyric.git
   cd mac-touchbar-lyric
   ```

3. Build, install into `~/Applications`, and launch the app:

   ```sh
   ./scripts/install.sh
   ```

The app runs in the background. Look for the quote-bubble icon in the macOS menu
bar at the top-right of the screen.

### Run without installing

To create a local development build and run it directly:

```sh
./scripts/build-app.sh
open "build/Touch Bar Lyrics.app"
```

## First-run permission

macOS asks whether Touch Bar Lyrics may automate Spotify. Choose **Allow**. The
app only reads the current track, playback state, and playback position.

If permission was denied:

1. Open **System Settings → Privacy & Security → Automation**.
2. Find **Touch Bar Lyrics**.
3. Enable access to **Spotify**.
4. Quit and reopen Touch Bar Lyrics.

## Usage

1. Open Spotify and play a song.
2. Wait briefly while synchronized lyrics are retrieved.
3. The current line appears on the Touch Bar and follows Spotify's position.
   Tap the album cover/title group to play or pause, swipe it left for the next
   track, or swipe it right for the previous track. Pinch outward on the group to
   hide the lyrics and center the album cover and title. Pinch inward on the
   centered group to restore the normal lyrics view.
4. Use the quote-bubble menu-bar item to:
   - Enable or disable **Show Lyrics on Touch Bar**.
   - Choose any lyric color with **Text Color…**, or restore the default color.
   - Enable **Launch at Login**.
   - View the current status.
   - Quit the app.

If you close the lyric view on the Touch Bar, it stays hidden across lyric and
track changes. Tap the quote-bubble Touch Bar button or re-enable **Show Lyrics
on Touch Bar** from the menu-bar item to show it again.

Typical status messages include:

- `Waiting for Spotify…`
- `Loading lyrics for <song>…`
- `Showing lyrics for <song>`
- `Synced lyrics unavailable`

## Troubleshooting

### The menu-bar icon is missing

Move the pointer to the top of the screen if the macOS menu bar is hidden. The
icon resembles a speech bubble containing quotation marks.

### Spotify access failed

Enable Spotify under **System Settings → Privacy & Security → Automation →
Touch Bar Lyrics** and restart the app.

### No lyrics appear

- Confirm Spotify is playing a normal music track rather than an advertisement
  or podcast.
- Confirm **Show Lyrics on Touch Bar** is enabled.
- Some LRCLIB tracks have plain lyrics but no synchronized timestamps. These
  tracks cannot be displayed by the current version.

### Lyrics are early or late

LRCLIB timestamps are community-maintained and may differ from Spotify's own
lyrics. Seeking in Spotify forces the app to resynchronize within about one
second.

## Uninstall

From the repository directory:

```sh
./scripts/uninstall.sh
```

You can also quit the app and delete `~/Applications/Touch Bar Lyrics.app`
manually.

## Development

Run all tests:

```sh
swift test
```

Create a release-mode app bundle:

```sh
./scripts/build-app.sh
```

Create a validated release ZIP and SHA-256 checksum using the version from
`Resources/Info.plist`:

```sh
./scripts/package-release.sh
```

For version `0.1.0`, publish the generated files after committing and pushing
the release source:

```sh
gh release create v0.1.0 \
  "build/releases/TouchBarLyrics-v0.1.0-arm64.zip" \
  "build/releases/TouchBarLyrics-v0.1.0-arm64.zip.sha256" \
  --repo iqbalrahman-jpg/mac-touchbar-lyric \
  --title "Touch Bar Lyrics v0.1.0" \
  --generate-notes
```

The project is divided into:

- `TouchBarLyricsCore`: lyric parsing, metadata matching, and playback timing
- `TouchBarLyricsApp`: Spotify automation and menu-bar lifecycle
- `TouchBarPrivateBridge`: the unsupported system-wide Touch Bar integration

## Privacy and limitations

- Track title, artist, album, and duration are sent to LRCLIB to locate lyrics.
- Album artwork is downloaded from the URL supplied by Spotify and cached in
  memory while the app is running.
  Spotify credentials and listening history are not collected.
- LRCLIB data is community-maintained. Some songs have no synchronized lyrics,
  and timestamps can differ from Spotify's built-in lyric display.
- Lyrics are line-synchronized, not word-by-word karaoke.
- System-wide Touch Bar presentation uses private AppKit and DFRFoundation APIs.
  Apple may change these APIs, and the app is not suitable for the Mac App
  Store.
- The included build script uses ad-hoc signing for local development. Polished
  public distribution requires Developer ID signing and Apple notarization.

The private Touch Bar technique is based on the approach used by open-source
projects such as [MTMR](https://github.com/Toxblh/MTMR).
