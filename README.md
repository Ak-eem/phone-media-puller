Phone Media Puller — copies all media (images, videos, audio) from an Android phone over USB/MTP into a Desktop\w folder, mirroring the phone's folder structure (e.g. w\DCIM\Camera, w\WhatsApp\Media).

Steps:
1) plug phone in with USB mode = File transfer / MTP, keep it unlocked
2) run: powershell -ExecutionPolicy Bypass -File pull_media.ps1

Notes:
- only copies, never deletes from the phone
- re-runs skip existing files
- junk cache files (.exo, .crypted, .tmp, .part, .cache, .thumb) are skipped automatically
- URL-named files are auto-renamed (photo.jpeg%3Fwidth=300 -> photo.jpeg)
- up to 3 folders copy in parallel for speed
