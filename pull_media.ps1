# pull_media.ps1 - copy ALL media from an Android phone (USB, MTP mode) into a w folder
# Phone must be: unlocked, plugged in, USB mode set to File transfer / MTP

$ErrorActionPreference = "Stop"

$destRoot = Join-Path $env:USERPROFILE "Desktop\w"
$pics = Join-Path $destRoot "Pictures"
$vids = Join-Path $destRoot "Videos"
New-Item -ItemType Directory -Force -Path $pics, $vids | Out-Null

$imageExts = @(".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp", ".heic")
$videoExts = @(".mp4", ".mov", ".mkv", ".3gp", ".avi", ".webm")
$mediaExts = $imageExts + $videoExts

$shell = New-Object -ComObject Shell.Application
$devices = $shell.Namespace(17).Items() | Where-Object { $_.IsFolder }

if (-not $devices) { Write-Host "No device found. Is the phone in File transfer mode?" -ForegroundColor Red; exit 1 }

$copied = 0

function Copy-MediaFolder($folder) {
    foreach ($item in $folder.Items()) {
        $name = $item.Name
        if ($item.IsFolder) {
            try { Copy-MediaFolder $item.GetFolder() } catch { }
        } else {
            $ext = [System.IO.Path]::GetExtension($name).ToLower()
            if ($mediaExts -contains $ext) {
                $target = if ($imageExts -contains $ext) { $pics } else { $vids }
                $destFile = Join-Path $target $name
                $i = 1
                while (Test-Path $destFile) {
                    $base = [System.IO.Path]::GetFileNameWithoutExtension($name)
                    $destFile = Join-Path $target ("{0}_{1}{2}" -f $base, $i, $ext)
                    $i++
                }
                try {
                    $folder.CopyHere($item, 16)
                    $script:copied++
                    Write-Host "  + $name -> $($target | Split-Path -Leaf)" -ForegroundColor Green
                } catch { Write-Host "  ! failed: $name" -ForegroundColor Yellow }
            }
        }
    }
}

foreach ($device in $devices) {
    Write-Host "== Device: $($device.Name) ==" -ForegroundColor Cyan
    try { Copy-MediaFolder $device.GetFolder() } catch { Write-Host "  can't open device, skipping" -ForegroundColor Yellow }
}

Write-Host "Done. $copied files copied to $destRoot" -ForegroundColor Green
