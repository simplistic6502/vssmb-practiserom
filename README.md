VS. Super Mario Bros. Practise ROM
==================================

This patch adds a stage select with configuration options, practice information during gameplay, and keybinds for restarting the current stage or returning to the stage select.

Forked from [threecreepio's VS SMB practise ROM](https://github.com/threecreepio/smb1-practiserom-vssmb).

Included is a Python script to help with calculating RNG seeds. To use the script, run the script in a terminal.

Patching
--------

The easiest way to apply this patch is to use [ROM Patcher JS](https://www.marcrobledo.com/RomPatcher.js/).

This patch is intended to be applied to `VS Super Mario Bros (VS) [a1].nes`, which has an expected MD5 hash of `e448025d8d332d431b6177b006441d65`. While this dump has incorrect timer speeds, the patch will restore the correct speeds.
