# Concert lobby video generator

Creates the original SYNK concert-light background at `assets/lobby/lobby_loop.ogv` and its matching fallback `assets/lobby/concert_background.png`.

The direction takes inspiration from the music-focused staging and atmospheric lighting of the SuperStar series. References researched:

- [SuperStar SMTOWN lobby update screenshots](https://www.4gamer.net/games/430/G043092/20210422186/screenshot.html)
- [DalcomSoft Japan's SuperStar SMTOWN anniversary announcement](https://prtimes.jp/main/html/rd/p/000000037.000070838.html)

All visuals here are original shader-generated motion graphics. The loop uses midnight blue, rose and champagne washes, six slowly sweeping spotlights, a defocused LED wall, lens bokeh, dust, and curved stage reflections. It contains no borrowed footage, logos, performers or text.

Every motion follows whole cycles of a twelve-second phase, so the end joins the start smoothly. It is rendered at 1280 × 720, 30 fps, 360 frames, with no audible soundtrack. Only the encoded Ogg Theora video plays in the game; the generator shader does not run on the phone.

This directory is a separate Godot project and is excluded from game exports.

Run from the repository root in PowerShell:

```powershell
& .tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe --path tools/lobby_video --resolution 1280x720 --write-movie "$PWD/assets/lobby/lobby_loop.ogv" --fixed-fps 30 --quit-after 360
& .tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe --path tools/lobby_video --resolution 1280x720 -- --phase=0.2 "--still=$PWD/assets/lobby/concert_background.png"
```

Reimport the main project after generation. `--phase` can be any position from 0 to 1 to inspect a still. The fallback uses the same frame styling as the video, so it does not return to the old city look while video initializes.
