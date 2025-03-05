# Notestream

A simple markdown-based notetaking app.

Works on macOS and Linux.

__Disclaimer:__ *This is an ongoing personal project. I've experimented with many different notetaking apps in the past, so I figured I would build my own as a way to sharpen my Flutter skills. Expect bugs, but also progress!*

## Features:
- Write and view notes with markdown formatting.
- Organize notes using in-text tags.
- View notes in a scrollable timeline.
- Change the theme color and brightness (light, dark, or system).

## Installation:

**Build from source:**
 1. Clone this repository.
 2. cd into __../notestream_app__ and run in terminal:
    - For macOS: ```$ flutter build macos```
    - For Linux: ```$ flutter build linux```

### Notes:
- This *should* run on windows but I haven't tried it yet.
- Still working on supporting Android.
- Filesystem sandboxing on iOS creates a challenge for reading from, and saving to, the note folder external to the app's directory.
