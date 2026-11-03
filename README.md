# Spectrum Studio — 3D Music Visualizer

Create professional music visualizer videos on your phone, the way the big
visualizer apps do it — but fully offline after install.

## What it does

1. **Pick a song** from your device (MP3, M4A, WAV, FLAC, OGG).
2. **Add a background picture** (optional — a dark studio gradient is built in).
3. **Enter the song title and artist name.**
4. **Pick one of six 3D visualizer templates:**
   - Circular Spectrum, Rotating 3D Bars, Neon Rings,
   - Glowing Sphere, Particle Field, Waveform Tunnel.
5. **Preview and tap Export Video.**

The visualizer reacts to the song's **real frequencies and beats** — a pure-Dart
FFT analyzes the actual audio, and a spectral-flux beat tracker drives the
pulses. Nothing is random.

## Export

Real MP4 videos (H.264 + AAC) with the **complete original audio**, in sync
with the visuals for the whole song:

- 9:16 vertical (Shorts / Reels), 16:9 landscape (YouTube), 1:1 square
- 720p or 1080p, 30 or 60 FPS

Customize color, size, position, glow, background blur and title placement,
or just use the professional defaults.

## Install (Android)

Download the latest APK from the **Releases** page of this repo and install it
on your phone. No account needed.

## Build it yourself

```sh
flutter pub get
flutter analyze
flutter build apk --release   # Android
flutter build ios --release   # iOS (macOS + Xcode required)
```

## Tech

Flutter + Dart. Audio decoding and video encoding via FFmpeg, playback via
just_audio, 3D visuals via real perspective-projected geometry rendered on
Flutter's canvas. Projects are stored locally on-device (SharedPreferences);
everything works offline.
