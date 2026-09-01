# phone-media-puller

Copies all media from an Android phone via USB/MTP into a `w` folder on the laptop split into `Pictures/` and `Videos/`.

## Windows 10 run steps

1. Plug the phone in and select File transfer/MTP mode.
2. Open PowerShell in the folder containing the script.
3. Run `powershell -ExecutionPolicy Bypass -File pull_media.ps1`.

This script only copies files and never deletes anything from the phone.
Re-runs skip files that already exist (same name + same size), so it is safe to run multiple times.
