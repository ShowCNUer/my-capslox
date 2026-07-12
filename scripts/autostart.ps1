[CmdletBinding()]
param(
    [switch]$Disable
)

$ErrorActionPreference = "Stop"
$localAppData = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
$startupDirectory = [Environment]::GetFolderPath([Environment+SpecialFolder]::Startup)
$installDirectory = Join-Path $localAppData "Programs\MyCapslox"
$installedExe = Join-Path $installDirectory "MyCapslox.exe"
$shortcutPath = Join-Path $startupDirectory "My Capslox.lnk"

if ($Disable) {
    if (Test-Path -LiteralPath $shortcutPath -PathType Leaf) {
        Remove-Item -LiteralPath $shortcutPath -Force
    }
    Write-Host "AUTOSTART DISABLED"
    Write-Host "Removed: $shortcutPath"
    exit 0
}

if (-not (Test-Path -LiteralPath $installedExe -PathType Leaf)) {
    throw "Installed executable not found: $installedExe"
}

New-Item -ItemType Directory -Path $startupDirectory -Force | Out-Null
$temporaryShortcut = Join-Path $startupDirectory ("My Capslox.installing." + [Guid]::NewGuid().ToString("N") + ".lnk")
$shortcutBackup = "$shortcutPath.previous"

try {
    $wsh = New-Object -ComObject WScript.Shell
    $shortcut = $null
    try {
        $shortcut = $wsh.CreateShortcut($temporaryShortcut)
        $shortcut.TargetPath = $installedExe
        $shortcut.Arguments = ""
        $shortcut.WorkingDirectory = $installDirectory
        $shortcut.Description = "Start My Capslox after sign-in"
        $shortcut.IconLocation = "$installedExe,0"
        $shortcut.Save()
    }
    finally {
        if ($null -ne $shortcut -and [Runtime.InteropServices.Marshal]::IsComObject($shortcut)) {
            [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($shortcut)
        }
        if ([Runtime.InteropServices.Marshal]::IsComObject($wsh)) {
            [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($wsh)
        }
    }

    $readerShell = New-Object -ComObject WScript.Shell
    $reader = $null
    try {
        $reader = $readerShell.CreateShortcut($temporaryShortcut)
        if (-not [StringComparer]::OrdinalIgnoreCase.Equals([IO.Path]::GetFullPath($reader.TargetPath), $installedExe)) {
            throw "Autostart shortcut target verification failed."
        }
        if ($reader.Arguments -ne "") {
            throw "Autostart shortcut unexpectedly contains arguments."
        }
        if (-not [StringComparer]::OrdinalIgnoreCase.Equals([IO.Path]::GetFullPath($reader.WorkingDirectory), $installDirectory)) {
            throw "Autostart shortcut working-directory verification failed."
        }
    }
    finally {
        if ($null -ne $reader -and [Runtime.InteropServices.Marshal]::IsComObject($reader)) {
            [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($reader)
        }
        if ([Runtime.InteropServices.Marshal]::IsComObject($readerShell)) {
            [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($readerShell)
        }
    }

    if (Test-Path -LiteralPath $shortcutPath -PathType Leaf) {
        [IO.File]::Replace($temporaryShortcut, $shortcutPath, $shortcutBackup, $true)
        if (Test-Path -LiteralPath $shortcutBackup -PathType Leaf) {
            Remove-Item -LiteralPath $shortcutBackup -Force
        }
    }
    else {
        Move-Item -LiteralPath $temporaryShortcut -Destination $shortcutPath
    }
}
finally {
    if (Test-Path -LiteralPath $temporaryShortcut -PathType Leaf) {
        Remove-Item -LiteralPath $temporaryShortcut -Force
    }
}

Write-Host "AUTOSTART ENABLED"
Write-Host "Shortcut: $shortcutPath"
Write-Host "Target:   $installedExe"
