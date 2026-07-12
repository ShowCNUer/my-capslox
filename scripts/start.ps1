param(
    [string]$AutoHotkeyPath = "",
    [switch]$AllowCapsloxConflict
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

if (-not $AllowCapsloxConflict -and (Get-Process -Name Capslox -ErrorAction SilentlyContinue)) {
    throw "Capslox is still running. Exit it first, or pass -AllowCapsloxConflict intentionally."
}

if (-not $AutoHotkeyPath) {
    $candidates = @(
        (Join-Path $root ".tools\AutoHotkey_2.0.26\AutoHotkey64.exe"),
        (Join-Path $env:ProgramFiles "AutoHotkey\v2\AutoHotkey64.exe"),
        (Join-Path $env:ProgramFiles "AutoHotkey\AutoHotkey.exe")
    )
    $AutoHotkeyPath = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}

if (-not $AutoHotkeyPath -or -not (Test-Path -LiteralPath $AutoHotkeyPath)) {
    throw "AutoHotkey v2 runtime not found. Install it or pass -AutoHotkeyPath."
}

$script = Join-Path $root "main.ahk"
$process = Start-Process `
    -FilePath $AutoHotkeyPath `
    -ArgumentList @("`"$script`"") `
    -WorkingDirectory $root `
    -WindowStyle Hidden `
    -PassThru

Write-Host "My Capslox started. PID=$($process.Id)"
