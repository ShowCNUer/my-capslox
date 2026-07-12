param(
    [string]$AutoHotkeyPath = "",
    [switch]$Integration
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

if (-not $AutoHotkeyPath) {
    $candidates = @(
        (Join-Path $root ".tools\AutoHotkey_2.0.26\AutoHotkey64.exe"),
        (Join-Path $env:ProgramFiles "AutoHotkey\v2\AutoHotkey64.exe"),
        (Join-Path $env:ProgramFiles "AutoHotkey\AutoHotkey.exe")
    )
    $AutoHotkeyPath = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}

if (-not $AutoHotkeyPath -or -not (Test-Path -LiteralPath $AutoHotkeyPath)) {
    throw "AutoHotkey v2 runtime not found. Pass -AutoHotkeyPath or download the portable runtime."
}

function Invoke-Ahk {
    param(
        [Parameter(Mandatory = $true)][string]$Arguments,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $AutoHotkeyPath
    $startInfo.Arguments = $Arguments
    $startInfo.WorkingDirectory = $root
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    if (-not $process.Start()) {
        throw "$Label failed to start."
    }

    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(10000)) {
        $process.Kill()
        throw "$Label timed out."
    }

    $stdout = $stdoutTask.Result
    $stderr = $stderrTask.Result
    if ($stdout) { Write-Host $stdout.TrimEnd() }
    if ($stderr) { Write-Host $stderr.TrimEnd() }
    if ($stdout -match "==> Warning:" -or $stderr -match "==> Warning:") {
        throw "$Label emitted an AutoHotkey warning."
    }
    if ($process.ExitCode -ne 0) {
        throw "$Label failed with exit code $($process.ExitCode)."
    }
    Write-Host "PASS $Label"
    $process.Dispose()
}

$main = Join-Path $root "main.ahk"
$tests = Join-Path $root "tests\run.ahk"
Invoke-Ahk -Label "main syntax" -Arguments "/ErrorStdOut=UTF-8 /Validate `"$main`""
Invoke-Ahk -Label "unit tests" -Arguments "/ErrorStdOut=UTF-8 `"$tests`""
if ($Integration) {
    $integrationScript = Join-Path $root "tests\integration.ahk"
    Invoke-Ahk -Label "window integration tests" -Arguments "/ErrorStdOut=UTF-8 `"$integrationScript`""
}
