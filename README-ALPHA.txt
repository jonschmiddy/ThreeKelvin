THREE KELVIN -- ALPHA BUILD
===========================

Thanks for playing. This is an early build: things will break, and when they do,
that is useful.


WINDOWS
-------
1. Right-click the zip and choose "Extract All...", then open the folder it made.
2. Double-click ThreeKelvin.exe.
3. Windows may say "Windows protected your PC". The game is not signed, which is
   why. Click "More info", then "Run anyway". You only have to do this once.

ThreeKelvin.console.exe is the same game with a text window beside it showing
what the game is doing. If ThreeKelvin.exe will not start at all, run the
console one and send a photo or a copy of that window.


MAC
---
1. Double-click the zip. You get "Three Kelvin.app" (if you get another zip,
   double-click that one too).
2. Drag "Three Kelvin.app" into Applications (or anywhere you like).
3. The app is not notarised by Apple, so the first open is blocked. Either:

   a) Open Terminal and paste this line (it removes the "downloaded from the
      internet" flag from the app), then open the app normally:

        xattr -dr com.apple.quarantine "/Applications/Three Kelvin.app"

      (change the path if you put the app somewhere else -- you can type
      xattr -dr com.apple.quarantine and a space, then drag the app onto the
      Terminal window to fill in its path)

   or b) Double-click the app, click "Done" on the warning, then open
      System Settings > Privacy & Security, scroll down to the line about
      "Three Kelvin" and click "Open Anyway", then confirm.

   On older macOS (before 15), right-click the app, choose Open, then Open again.

It runs on both Apple Silicon and Intel Macs.


WHEN SOMETHING GOES WRONG
-------------------------
Open the menu (Escape) > Settings > PLAYTEST > SAVE MY LOGS. It puts one zip on
your Desktop. Send that zip along with what you were doing. The same button is
on the game-over screen.

Nothing is ever sent anywhere by the game itself.

Your saves, settings and logs live in their own folder:
  Windows: %APPDATA%\ThreeKelvinAlpha
  Mac:     ~/Library/Application Support/ThreeKelvinAlpha
Deleting that folder resets the game to a first launch.

The build's version is in the corner of the title screen and at the bottom of
the pause menu. Mention it when you report something.
