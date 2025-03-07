# Notestream

A simple markdown-based notetaking app.

![Screenshot 2025-03-07 at 3 44 44 PM](https://github.com/user-attachments/assets/a9ae1da3-c03b-44f5-8c75-7b84b5b01cef)

Works on macOS and Linux.

__Disclaimer:__ *This is an ongoing personal project. I've experimented with many different notetaking apps in the past, so I figured I would build my own as a way to sharpen my Flutter skills. Expect bugs, but also progress!*

## Features:
- Write and view notes with markdown formatting.
- Organize notes using in-text tags.
- View notes in a scrollable timeline.
- Change the theme color and brightness (light, dark, or system).
 <img src="https://github.com/user-attachments/assets/122986a7-d189-4776-a0c9-22324fffc9b6" width="480">
 <img src="https://github.com/user-attachments/assets/cf2b137e-dc5a-44c9-83cc-131d61c185b7" width="480">
 
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
