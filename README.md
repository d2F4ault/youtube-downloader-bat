# YouTube Downloader – Safety First

**A carefully engineered, standalone Windows batch application** for downloading YouTube audio and video.

No installers. No PATH changes. No “latest” downloads.  
Everything lives next to the `.bat` file and is designed to be as safe and predictable as possible.

**Current version:** 3.0.0 (2026-08-17)

---

## Why this exists

Most YouTube download scripts are either:
- Too minimal (and dangerous with playlists)
- Or full of silent updates, PATH pollution, and weak safety

This project takes the opposite approach:

- **Pinned, immutable tool versions** with exact size + SHA-256 verification
- **Transactional tool installation** (with automatic rollback if anything fails)
- **Strong playlist / channel protection** (you must deliberately allow multi-item downloads)
- **Isolated job directories** and private config files for every download
- **Archive locking** so concurrent jobs cannot race or corrupt the same archive
- Completely self-contained — never touches your system PATH

It is deliberately conservative by default.

---

## Features

### Core Safety
- x64-only (refuses 32-bit and ARM64)
- Never follows `/latest` — versions and hashes are baked into the batch file
- First-run trust model: you trust *this* batch file, not a mutable upstream release
- Playlist/channel safety gates + item limits
- Double confirmation required for unrestricted collection mode
- Separate audio and video download archives
- `--no-overwrites` always enabled
- Sync-folder warnings (OneDrive / Dropbox / Google Drive)

### Download Quality
- Default Audio → Best compatibility M4A
- Default Video → Strict compatible MP4 (H.264 + AAC preferred), up to 1080p
- Custom audio: M4A / MP3 / Opus / FLAC / WAV / keep original
- Custom video: MP4 / MKV / WebM or pure original container mode
- SponsorBlock removal (configurable)
- Optional subtitles (manual + auto) with language preference
- Thumbnail embedding + metadata + chapters

### Tooling & Reliability
- Local copies of yt-dlp, FFmpeg, and aria2c
- Concurrent fragment downloads + optional aria2c acceleration for direct HTTP
- Bandwidth limiting
- Diagnostic verbose logging mode
- Built-in YouTube extraction self-test
- Repair / reinstall verified toolset
- Active job markers + clean stale-lock cleanup tools

---

## Requirements

- 64-bit Windows (x64)
- Internet connection (only needed for the first tool download)
- No administrator rights required

Recommended: keep the folder on a **local non-synced drive** (not OneDrive).

---

## Quick Start

1. Download `YouTube_Downloader.bat`
2. Place it in a clean local folder
3. Double-click it
4. On first run it will download and verify the pinned tools
5. Use the menu

That’s it.

---

## Important Notes

- This tool uses [yt-dlp](https://github.com/yt-dlp/yt-dlp).  
  **Respect YouTube’s Terms of Service and copyright law.**  
  Download only content you have the right to download.
- The script is intentionally strict about playlists and channels.  
  This is a feature, not a bug.
- Cookies-from-browser support is available but comes with a clear privacy warning.

---

## Folder Structure (created automatically)
YouTube_Downloader.bat
├── bin/                  ← local tools (yt-dlp, FFmpeg, aria2)
├── Downloads/
│   ├── Audio/
│   └── Video/
├── temp/                 ← isolated session & job directories
├── logs/
├── locks/
├── settings.ini
├── archive-audio.txt
├── archive-video.txt
└── advanced-yt-dlp.conf  ← optional extra safe options
text---

## Philosophy

> Prefer predictability and safety over convenience.

Every multi-item download is stopped for confirmation.  
Every tool is verified by size and SHA-256 before it is allowed to replace the previous one.  
Every job runs in its own private directory with its own private config file.

If something goes wrong, the previous working tools are restored whenever possible.

---

## License

MIT

---

**Made for people who want a YouTube downloader that behaves like a careful tool, not a reckless script.**
