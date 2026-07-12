[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$localAppData = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
$programsDirectory = [Environment]::GetFolderPath([Environment+SpecialFolder]::Programs)
$installDirectory = [IO.Path]::GetFullPath((Join-Path $localAppData "Programs\MyCapslox"))
$expectedInstallDirectory = [IO.Path]::GetFullPath("$localAppData\Programs\MyCapslox")
$installedExe = Join-Path $installDirectory "MyCapslox.exe"
$shortcutPath = Join-Path $programsDirectory "My Capslox.lnk"
$startupDirectory = [Environment]::GetFolderPath([Environment+SpecialFolder]::Startup)
$autostartShortcutPath = Join-Path $startupDirectory "My Capslox.lnk"
$dataDirectory = Join-Path $localAppData "MyCapslox"

if (-not [StringComparer]::OrdinalIgnoreCase.Equals($installDirectory, $expectedInstallDirectory)) {
    throw "Refusing to uninstall from an unexpected path: $installDirectory"
}

foreach ($process in @(Get-Process -Name "MyCapslox" -ErrorAction SilentlyContinue)) {
    try {
        $candidate = $process.Path
    }
    catch {
        throw "Detected MyCapslox but could not verify its path. Exit it from the tray first."
    }
    if ([string]::IsNullOrWhiteSpace($candidate)) {
        throw "Detected MyCapslox but could not verify its path. Exit it from the tray first."
    }
    if ([StringComparer]::OrdinalIgnoreCase.Equals([IO.Path]::GetFullPath($candidate), $installedExe)) {
        throw "My Capslox is running. Exit it from the tray before uninstalling."
    }
}

$knownFiles = @(
    $shortcutPath,
    $autostartShortcutPath,
    $installedExe,
    (Join-Path $installDirectory "README.md"),
    (Join-Path $installDirectory "MyCapslox.previous.exe")
)
foreach ($file in $knownFiles) {
    if (Test-Path -LiteralPath $file -PathType Leaf) {
        Remove-Item -LiteralPath $file -Force
    }
}

if (Test-Path -LiteralPath $installDirectory -PathType Container) {
    $remaining = @(Get-ChildItem -LiteralPath $installDirectory -Force)
    if ($remaining.Count -eq 0) {
        Remove-Item -LiteralPath $installDirectory
    }
    else {
        Write-Warning "Unknown files remain, so the install directory was preserved: $installDirectory"
    }
}

Write-Host "UNINSTALL OK"
Write-Host "Preserved data: $dataDirectory"
