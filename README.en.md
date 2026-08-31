# BiliSpeakerAudioFixer

> Turn the `m4s` / `mp4` audio files you grabbed from Bilibili into MP3s that **actually play on Bluetooth speakers, TF cards, and car stereos**.

![改后缀 vs 真转码](docs/compare.jpg)


[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows-blue.svg)]()

[中文说明 / Chinese README](README.md)

---

## The problem this solves

Audio downloaded from Bilibili (via CatCatch / 猫抓 or similar tools) usually comes as `.m4s` or `.mp4`. A very common move is to **just rename it to `.mp3`**.

Then this happens:

| Where you play it | Result |
|---|---|
| Windows Media Player / PotPlayer | ✅ Works |
| Phone / PC music apps | ✅ Works |
| **Bluetooth speaker / TF card / car stereo** | ❌ **Nothing** |

**Why?** Renaming only changes the label. The file is still **AAC audio inside an MP4 container**. Phones and PCs decode in software and handle almost anything. Speakers use a **hardware decoder chip** — if AAC isn't burned into that chip, the file is silently skipped.

This tool does a **real transcode to standard MP3**, plus a list of compatibility tweaks aimed squarely at older decoder chips.

---

## Features

- **Check mode** — read-only scan. Reports the true codec, duration, and sample rate of every file, and writes a CSV report
- **Strip junk headers** — some cached files have junk bytes prepended, which makes even `ffprobe` fail. Detected and skipped automatically
- **Remux to M4A** — swaps the container without touching the audio stream. **Zero quality loss**
- **Transcode to MP3** — real re-encoding via the LAME encoder
- **Speaker-safe mode** — 192k CBR / 44.1 kHz / stereo / ID3v2.3 / Xing header. Maximum compatibility
- **Auto flatten & number** — outputs `001_title.mp3` into a single folder (old speakers can't scan nested directories)
- **Filename cleanup** — strips `BV` IDs, `av` IDs, `P01`, `audio` suffixes, and writes a clean title tag
- **Drop video tracks** — keeps audio only
- **Rebuild duration index** — fixes DASH fragments with missing duration or a broken seek bar

---

## Requirements

You need **FFmpeg + FFprobe** on your PATH (not bundled):

```powershell
winget install Gyan.FFmpeg
```

> ⚠️ **You must open a new terminal after installing**, or the PATH change won't apply.
> Verify with `ffmpeg -version` — if you get version output, you're good.

---

## Quick start

1. Download this repo and put the files **in the same folder as your music**
2. Double-click `1_check.bat` for a health scan (optional but recommended)
3. Double-click `4_to_speaker_mp3.bat` and wait
4. Copy the MP3s from the generated `音响专用` (`speaker`) folder to the **root** of your TF card

**What each .bat does:**

| File | Purpose | Use it for |
|---|---|---|
| `1_check.bat` | Scan only | See what you're dealing with |
| `2_to_m4a.bat` | Remux to `.m4a` | Phone / PC / music players, zero loss |
| `3_to_mp3.bat` | Transcode `.mp3` 320k | Video editing / legacy devices |
| `4_to_speaker_mp3.bat` | **Speaker-safe** `.mp3` | **Speakers / TF card / car ← most people want this** |

Output goes to a `已修复` (`fixed`) or `音响专用` (`speaker`) subfolder. **Your original files are never touched.**

---

## Advanced usage

Call the script directly for more control:

```powershell
# Speaker mode at 256k
.\BiliAudioFixer.ps1 -Mode SPK -Bitrate 256k

# Number-only filenames (when a speaker chokes on Chinese names)
.\BiliAudioFixer.ps1 -Mode SPK -ShortName

# Process a different folder
.\BiliAudioFixer.ps1 -Mode SPK -Dir "D:\MyMusic"

# Output in place, no subfolder
.\BiliAudioFixer.ps1 -Mode M4A -InPlace
```

**Parameters:**

| Param | Description |
|---|---|
| `-Mode` | `Check` / `M4A` / `MP3` / `SPK` |
| `-Dir` | Working directory. Defaults to the script's folder |
| `-Bitrate` | e.g. `192k` `256k` `320k`. Defaults: MP3=320k, SPK=192k |
| `-Flatten` | Flatten into one folder with numbered names (on by default in SPK) |
| `-ShortName` | Filenames become just `001.mp3` |
| `-InPlace` | Output in place, no subfolder |

---

## Still won't play on the speaker? Check in this order

1. **TF card filesystem** — cards over 64 GB ship as **exFAT**, but most cheap speakers only read **FAT32**. Reformat as FAT32 on your PC (32 GB cards are usually already FAT32)
2. **Put files in the root** — don't nest them in folders. Speakers often can't scan subdirectories
3. **Filenames** — if English titles play but Chinese ones don't, the speaker can't handle the encoding. Use `-ShortName` for pure numeric names
4. **Keep it under 999 tracks** — that's the index limit on many older speakers; anything beyond gets ignored
5. **Eject safely** — use "Safely Remove Hardware". Yanking the card can corrupt the FAT table

---

## Why a renamed "MP3" won't play

The short version:

- **Codec** — MP3 is MPEG-1/2 Layer III; AAC is an MPEG-4 codec. Totally different. A decoder chip only decodes what was burned into it
- **Sample rate** — Bilibili audio is often **48 kHz**, while many budget MP3 decoder chips only support **44.1 kHz**. Feed it 48k and you get silence or noise
- **Bitrate mode** — VBR confuses older chips. This tool always writes **CBR**
- **ID3 tags** — ID3v2.4 can hang some old firmware. This tool writes **v2.3**
- **Duration index** — DASH fragments often have an incomplete `moov` header, so duration shows wrong and seeking breaks

---

## FAQ

**Q: The .bat flashes and closes instantly.**
A: FFmpeg isn't installed, or you didn't open a new terminal. Check with `ffmpeg -version`.

**Q: It says "can't read file, corrupted."**
A: The download was incomplete. Grab it again.

**Q: Is it slow?**
A: M4A mode is a straight copy — hundreds of files in a minute. MP3 is real encoding, a few seconds per track, so a few hundred tracks may take 10+ minutes.

**Q: Will I lose quality?**
A: M4A mode: zero loss. MP3 mode: yes, some (AAC → MP3 is a lossy-to-lossy conversion). Prefer M4A unless you specifically need MP3.

**Q: Does it handle subfolders?**
A: Yes, it recurses. In SPK mode everything gets flattened and numbered.

---

## License & disclaimer

Code is **MIT** — use, modify, and distribute freely, including commercially, as long as you keep the attribution.

**A few notes:**

- This tool does **no downloading, no decryption, and no circumvention of any protection**. It only reorganizes files you already have
- Actual transcoding is done by [FFmpeg](https://ffmpeg.org/), which is licensed under LGPL/GPL. This project only calls it
- Only process content **you already own**. Don't redistribute copyrighted audio

---

## Contributing

Issues and PRs welcome. If you hit a speaker that still won't cooperate, paste in the CSV report from `1_check.bat` — it makes diagnosis much easier.
