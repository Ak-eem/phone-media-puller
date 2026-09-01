# pull_media.ps1 - copy ALL media (pics, vids, audio) from an Android phone over USB/MTP into a w folder
# v3 - parallel folder-by-folder copy, URL-name cleanup, junk auto-skip
# Phone: unlocked, plugged in, USB mode = File transfer / MTP
# Run:  powershell -ExecutionPolicy Bypass -File pull_media.ps1

$ErrorActionPreference = "Stop"

$destRoot = Join-Path $env:USERPROFILE "Desktop\w"
New-Item -ItemType Directory -Force -Path $destRoot | Out-Null

$imageExts = @(".jpg",".jpeg",".png",".gif",".webp",".bmp",".heic",".jfif")
$videoExts = @(".mp4",".mov",".mkv",".3gp",".avi",".webm",".m4v",".ts")
$audioExts = @(".mp3",".wav",".aac",".m4a",".opus",".ogg",".amr",".flac")
$skipExts  = @(".exo",".crypted",".tmp",".part",".cache",".thumb")
$mediaList = (($imageExts + $videoExts + $audioExts) -join ",")
$skipList  = ($skipExts -join ",")

$worker = {
    param($deviceName, $topName, $destRoot, $mediaList, $skipList)
    $mediaExts = $mediaList.Split(",")
    $skipExts  = $skipList.Split(",")
    $sh = New-Object -ComObject Shell.Application
    $dev = $sh.Namespace(17).Items() | Where-Object { $_.IsFolder -and $_.Name -eq $deviceName } | Select-Object -First 1
    if (-not $dev) { return @{ copied = 0; failed = 0 } }
    $top = $dev.GetFolder().Items() | Where-Object { $_.IsFolder -and $_.Name -eq $topName } | Select-Object -First 1
    if (-not $top) { return @{ copied = 0; failed = 0 } }
    $copied = 0; $failed = 0
    function Walk($folder, $rel) {
        foreach ($item in $folder.Items()) {
            $name = $item.Name
            if ($item.IsFolder) {
                try { Walk $item.GetFolder() (Join-Path $rel $name) } catch { }
                continue
            }
            $ext = [System.IO.Path]::GetExtension($name).ToLower()
            if ($skipExts -contains $ext) { continue }
            if ($mediaExts -notcontains $ext) { continue }
            $clean = $name -replace "%3F.*$", ""
            try { $clean = [System.Uri]::UnescapeDataString($clean) } catch { }
            $clean = $clean -replace "\.jpe?g$", ".jpeg"
            $destDir = Join-Path $destRoot $rel
            New-Item -ItemType Directory -Force -Path $destDir | Out-Null
            $destFile = Join-Path $destDir $clean
            $i = 1
            while (Test-Path $destFile) {
                $stem = [System.IO.Path]::GetFileNameWithoutExtension($clean)
                $ext2 = [System.IO.Path]::GetExtension($clean)
                $destFile = Join-Path $destDir ("{0}_{1}{2}" -f $stem, $i, $ext2)
                $i++
            }
            try {
                $folder.CopyHere($item, 16)
                $copied++
            } catch {
                $failed++
                Write-Host "  ! failed: $name" -ForegroundColor Yellow
            }
        }
    }
    Walk $top.GetFolder() $topName
    return @{ copied = $copied; failed = $failed }
}

$shell = New-Object -ComObject Shell.Application
$devices = $shell.Namespace(17).Items() | Where-Object { $_.IsFolder }
if (-not $devices) { Write-Host "No device found. Is the phone in File transfer mode?" -ForegroundColor Red; exit 1 }

$totalCopied = 0
$totalFailed = 0
$threadJobAvailable = [bool](Get-Command Start-ThreadJob -ErrorAction SilentlyContinue)

foreach ($device in $devices) {
    Write-Host "== Device: $($device.Name) ==" -ForegroundColor Cyan
    $root = $device.GetFolder()
    $jobs = @()
    foreach ($top in $root.Items()) {
        if (-not $top.IsFolder) { continue }
        if ($threadJobAvailable) {
            while ($jobs.Count -ge 3) {
                $done = Wait-Job -Job $jobs -Any
                if ($done) {
                    foreach ($j in ($jobs | Where-Object { $_.State -eq "Completed" -or $_.State -eq "Failed" })) {
                        $res = Receive-Job -Job $j
                        $totalCopied += $res.copied
                        $totalFailed += $res.failed
                        Remove-Job $j
                        $jobs = $jobs | Where-Object { $_ -ne $j }
                    }
                }
            }
            $jobs += Start-ThreadJob -ScriptBlock $worker -ArgumentList $device.Name, $top.Name, $destRoot, $mediaList, $skipList
        } else {
            $res = & $worker $device.Name $top.Name $destRoot $mediaList $skipList
            $totalCopied += $res.copied
            $totalFailed += $res.failed
        }
        Write-Host "  scanning+copying: $($top.Name)" -ForegroundColor Green
    }
    foreach ($j in $jobs) {
        Wait-Job $j | Out-Null
        $res = Receive-Job $j
        $totalCopied += $res.copied
        $totalFailed += $res.failed
        Remove-Job $j
    }
}

Write-Host ""
Write-Host "Done. $totalCopied media copied, $totalFailed failed -> $destRoot" -ForegroundColor Green
