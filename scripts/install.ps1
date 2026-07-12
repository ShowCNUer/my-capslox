[CmdletBinding()]
param(
    [string]$ExePath = "",
    [switch]$Launch
)

$ErrorActionPreference = "Stop"
$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$localAppData = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
$programsDirectory = [Environment]::GetFolderPath([Environment+SpecialFolder]::Programs)
$installDirectory = Join-Path $localAppData "Programs\MyCapslox"
$installedExe = Join-Path $installDirectory "MyCapslox.exe"
$dataDirectory = Join-Path $localAppData "MyCapslox\data"
$slotFile = Join-Path $dataDirectory "window-slots.ini"
$shortcutPath = Join-Path $programsDirectory "My Capslox.lnk"

if (-not $ExePath) {
    $ExePath = Join-Path $root "dist\MyCapslox.exe"
}
$sourceExe = [IO.Path]::GetFullPath($ExePath)

function Assert-InstalledAppStopped {
    param([Parameter(Mandatory = $true)][string]$ExecutablePath)

    $target = [IO.Path]::GetFullPath($ExecutablePath)
    $processName = [IO.Path]::GetFileNameWithoutExtension($target)
    foreach ($process in @(Get-Process -Name $processName -ErrorAction SilentlyContinue)) {
        try {
            $candidate = $process.Path
        }
        catch {
            throw "Detected $processName but could not verify its path. Exit My Capslox from the tray first."
        }
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            throw "Detected $processName but could not verify its path. Exit My Capslox from the tray first."
        }
        if ([StringComparer]::OrdinalIgnoreCase.Equals([IO.Path]::GetFullPath($candidate), $target)) {
            throw "The installed My Capslox is running. Exit it from the tray and retry."
        }
    }
}

function Copy-AndVerify {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    [IO.File]::Copy($Source, $Destination, $false)
    $sourceHash = (Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash
    $destinationHash = (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash
    if (-not [StringComparer]::OrdinalIgnoreCase.Equals($sourceHash, $destinationHash)) {
        throw "Copied file hash mismatch: $Destination"
    }
}

function Install-ExecutableAtomically {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    $temporary = Join-Path $installDirectory ("MyCapslox.installing." + [Guid]::NewGuid().ToString("N") + ".exe")
    $backup = Join-Path $installDirectory "MyCapslox.previous.exe"
    try {
        Copy-AndVerify -Source $Source -Destination $temporary
        Assert-InstalledAppStopped -ExecutablePath $Destination
        if (Test-Path -LiteralPath $Destination -PathType Leaf) {
            [IO.File]::Replace($temporary, $Destination, $backup, $true)
            if (Test-Path -LiteralPath $backup -PathType Leaf) {
                Remove-Item -LiteralPath $backup -Force
            }
        }
        else {
            Move-Item -LiteralPath $temporary -Destination $Destination
        }
    }
    finally {
        if (Test-Path -LiteralPath $temporary -PathType Leaf) {
            Remove-Item -LiteralPath $temporary -Force
        }
    }

    $sourceHash = (Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash
    $installedHash = (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash
    if (-not [StringComparer]::OrdinalIgnoreCase.Equals($sourceHash, $installedHash)) {
        throw "Installed executable hash mismatch."
    }
}

function Migrate-WindowSlots {
    if (Test-Path -LiteralPath $slotFile -PathType Leaf) {
        return
    }

    $legacyCandidates = @(
        (Join-Path $installDirectory "data\window-slots.ini"),
        (Join-Path $root "data\window-slots.ini")
    ) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }
    if (-not $legacyCandidates) {
        return
    }

    $primary = $legacyCandidates | Select-Object -First 1
    Copy-AndVerify -Source $primary -Destination $slotFile

    $primaryHash = (Get-FileHash -LiteralPath $primary -Algorithm SHA256).Hash
    $backupIndex = 0
    foreach ($candidate in @($legacyCandidates | Select-Object -Skip 1)) {
        $candidateHash = (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash
        if ([StringComparer]::OrdinalIgnoreCase.Equals($candidateHash, $primaryHash)) {
            continue
        }
        $backupIndex += 1
        $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $backupPath = Join-Path $dataDirectory "window-slots.legacy-$stamp-$backupIndex.ini"
        Copy-AndVerify -Source $candidate -Destination $backupPath
    }
}

function Install-StartMenuShortcut {
    $temporaryShortcut = Join-Path $programsDirectory ("My Capslox.installing." + [Guid]::NewGuid().ToString("N") + ".lnk")
    $wsh = New-Object -ComObject WScript.Shell
    $shortcut = $null
    try {
        $shortcut = $wsh.CreateShortcut($temporaryShortcut)
        $shortcut.TargetPath = $installedExe
        $shortcut.Arguments = ""
        $shortcut.WorkingDirectory = $installDirectory
        $shortcut.Description = "My Capslox"
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
            throw "Start Menu shortcut target verification failed."
        }
        if ($reader.Arguments -ne "") {
            throw "Start Menu shortcut unexpectedly contains arguments."
        }
        if (-not [StringComparer]::OrdinalIgnoreCase.Equals([IO.Path]::GetFullPath($reader.WorkingDirectory), $installDirectory)) {
            throw "Start Menu shortcut working-directory verification failed."
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
        $shortcutBackup = "$shortcutPath.previous"
        [IO.File]::Replace($temporaryShortcut, $shortcutPath, $shortcutBackup, $true)
        if (Test-Path -LiteralPath $shortcutBackup -PathType Leaf) {
            Remove-Item -LiteralPath $shortcutBackup -Force
        }
    }
    else {
        Move-Item -LiteralPath $temporaryShortcut -Destination $shortcutPath
    }
}

if (-not (Test-Path -LiteralPath $sourceExe -PathType Leaf)) {
    throw "Compiled executable not found: $sourceExe. Run scripts\build.ps1 first."
}
if ((Get-Item -LiteralPath $sourceExe).Length -lt 1MB) {
    throw "Compiled executable is unexpectedly small: $sourceExe"
}

$sourceSelfTest = Start-Process `
    -FilePath $sourceExe `
    -ArgumentList "--self-test" `
    -WorkingDirectory (Split-Path -Parent $sourceExe) `
    -WindowStyle Hidden `
    -Wait `
    -PassThru
if ($sourceSelfTest.ExitCode -ne 0) {
    throw "Compiled executable self-test failed with exit code $($sourceSelfTest.ExitCode)."
}

Assert-InstalledAppStopped -ExecutablePath $installedExe
New-Item -ItemType Directory -Path $installDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $dataDirectory -Force | Out-Null
Migrate-WindowSlots
Install-ExecutableAtomically -Source $sourceExe -Destination $installedExe

$readme = Join-Path $root "README.md"
if (Test-Path -LiteralPath $readme -PathType Leaf) {
    Copy-Item -LiteralPath $readme -Destination (Join-Path $installDirectory "README.md") -Force
}
Install-StartMenuShortcut

$sourceInstance = Get-CimInstance Win32_Process | Where-Object {
    $_.Name -in @("AutoHotkey64.exe", "AutoHotkey.exe") -and
    $_.CommandLine -like "*my-capslox*main.ahk*"
}
if ($sourceInstance) {
    Write-Warning "The source-script instance is still running. Exit it from the tray before starting the installed app."
}

Write-Host "INSTALL OK"
Write-Host "Executable: $installedExe"
Write-Host "Start Menu: $shortcutPath"
Write-Host "Data:       $dataDirectory"

if ($Launch) {
    if ($sourceInstance) {
        throw "Installation completed, but the source-script instance is still running. Exit it from the tray, then start My Capslox from the Start menu."
    }
    Start-Process -FilePath $installedExe -WorkingDirectory $installDirectory -WindowStyle Hidden
}
