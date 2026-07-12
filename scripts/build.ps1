[CmdletBinding()]
param(
    [string]$AutoHotkeyPath = "",
    [string]$CompilerPath = "",
    [switch]$Integration
)

$ErrorActionPreference = "Stop"
$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$toolsDir = Join-Path $root ".tools"
$defaultRuntimePath = Join-Path $root ".tools\AutoHotkey_2.0.26\AutoHotkey64.exe"
$defaultRuntimeSha256 = "A2A54B8ABC476D7671D4DE0771BB54BF5F2373D79FF6871D0BA6A62C3B88AE00"
$compilerVersion = "1.1.37.02a2"
$compilerDirectory = Join-Path $toolsDir "Ahk2Exe_$compilerVersion"
$compilerZip = Join-Path $toolsDir "Ahk2Exe_$compilerVersion.zip"
$compilerUrl = "https://github.com/AutoHotkey/Ahk2Exe/releases/download/Ahk2Exe$compilerVersion/Ahk2Exe$compilerVersion.zip"
$compilerZipSha256 = "C29B8C3A5124850D79FC9E66E2CA79677C377D7F31631AD3022BA159C5D9E3BE"
$compilerExeSha256 = "E54A599B19BAA5C1688849BBAE7A9CF049EEFCCD4F704C67941B40DA13A625B2"

function Assert-Sha256 {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Expected,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    if (-not [StringComparer]::OrdinalIgnoreCase.Equals($actual, $Expected)) {
        throw "$Label SHA-256 mismatch. Expected $Expected, got $actual."
    }
}

function Get-PeMachine {
    param([Parameter(Mandatory = $true)][string]$Path)

    $stream = [IO.File]::OpenRead($Path)
    $reader = $null
    try {
        $reader = [IO.BinaryReader]::new($stream)
        if ($reader.ReadUInt16() -ne 0x5A4D) {
            throw "Not a Windows PE file: $Path"
        }
        $stream.Position = 0x3C
        $peOffset = $reader.ReadInt32()
        $stream.Position = $peOffset
        if ($reader.ReadUInt32() -ne 0x00004550) {
            throw "Invalid PE signature: $Path"
        }
        return $reader.ReadUInt16()
    }
    finally {
        if ($null -ne $reader) {
            $reader.Dispose()
        }
        else {
            $stream.Dispose()
        }
    }
}

function Resolve-AutoHotkeyRuntime {
    param([string]$RequestedPath)

    if ($RequestedPath) {
        $resolved = [IO.Path]::GetFullPath($RequestedPath)
        if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
            throw "AutoHotkey runtime not found: $resolved"
        }
        return $resolved
    }

    $candidates = @(
        $defaultRuntimePath,
        (Join-Path $env:ProgramFiles "AutoHotkey\v2\AutoHotkey64.exe"),
        (Join-Path $env:ProgramFiles "AutoHotkey\AutoHotkey.exe")
    )
    $candidate = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    if (-not $candidate) {
        throw "AutoHotkey v2 runtime not found. Pass -AutoHotkeyPath or install AutoHotkey v2."
    }
    return [IO.Path]::GetFullPath($candidate)
}

function Resolve-Ahk2ExeCompiler {
    param([string]$RequestedPath)

    if ($RequestedPath) {
        $resolved = [IO.Path]::GetFullPath($RequestedPath)
        if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
            throw "Ahk2Exe compiler not found: $resolved"
        }
        return $resolved
    }

    $defaultCompiler = Join-Path $compilerDirectory "Ahk2Exe.exe"
    if (-not (Test-Path -LiteralPath $defaultCompiler -PathType Leaf)) {
        New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null
        if (-not (Test-Path -LiteralPath $compilerZip -PathType Leaf)) {
            $partialZip = "$compilerZip.partial"
            Invoke-WebRequest `
                -UseBasicParsing `
                -Headers @{ "User-Agent" = "MyCapslox-Build" } `
                -Uri $compilerUrl `
                -OutFile $partialZip
            Assert-Sha256 -Path $partialZip -Expected $compilerZipSha256 -Label "Ahk2Exe archive"
            Move-Item -LiteralPath $partialZip -Destination $compilerZip
        }
        Assert-Sha256 -Path $compilerZip -Expected $compilerZipSha256 -Label "Ahk2Exe archive"
        Expand-Archive -LiteralPath $compilerZip -DestinationPath $compilerDirectory
    }

    Assert-Sha256 -Path $defaultCompiler -Expected $compilerExeSha256 -Label "Ahk2Exe executable"
    return [IO.Path]::GetFullPath($defaultCompiler)
}

$runtime = Resolve-AutoHotkeyRuntime -RequestedPath $AutoHotkeyPath
$compiler = Resolve-Ahk2ExeCompiler -RequestedPath $CompilerPath

if ([StringComparer]::OrdinalIgnoreCase.Equals($runtime, [IO.Path]::GetFullPath($defaultRuntimePath))) {
    Assert-Sha256 -Path $runtime -Expected $defaultRuntimeSha256 -Label "AutoHotkey runtime"
}
$runtimeVersionText = (Get-Item -LiteralPath $runtime).VersionInfo.FileVersion
try {
    $runtimeVersion = [Version]$runtimeVersionText
}
catch {
    throw "Could not parse the AutoHotkey runtime version: $runtimeVersionText"
}
if ($runtimeVersion -lt [Version]"2.0.26") {
    throw "AutoHotkey 2.0.26 or newer is required; found $runtimeVersionText."
}
if ((Get-PeMachine -Path $runtime) -ne 0x8664) {
    throw "A 64-bit AutoHotkey runtime is required."
}

$verifyArguments = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $PSScriptRoot "verify.ps1"),
    "-AutoHotkeyPath", $runtime
)
if ($Integration) {
    $verifyArguments += "-Integration"
}
& powershell @verifyArguments
if ($LASTEXITCODE -ne 0) {
    throw "Source verification failed with exit code $LASTEXITCODE."
}

$distDirectory = Join-Path $root "dist"
$output = Join-Path $distDirectory "MyCapslox.exe"
$hashFile = Join-Path $distDirectory "MyCapslox.sha256"
$stagingDirectory = Join-Path $distDirectory (".build-" + [Guid]::NewGuid().ToString("N"))
$stagedOutput = Join-Path $stagingDirectory "MyCapslox.exe"
$outputBackup = Join-Path $distDirectory "MyCapslox.previous.exe"
$hashTemporary = Join-Path $distDirectory ("MyCapslox.sha256.building." + [Guid]::NewGuid().ToString("N"))
$hashBackup = Join-Path $distDirectory "MyCapslox.sha256.previous"
New-Item -ItemType Directory -Path $distDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $stagingDirectory | Out-Null

$mainScript = Join-Path $root "main.ahk"
$compilerArguments = @(
    "/in", "`"$mainScript`"",
    "/out", "`"$stagedOutput`"",
    "/base", "`"$runtime`"",
    "/compress", "0",
    "/silent", "verbose"
)
try {
    $compilerProcess = Start-Process `
        -FilePath $compiler `
        -ArgumentList $compilerArguments `
        -WorkingDirectory $root `
        -WindowStyle Hidden `
        -Wait `
        -PassThru
    if ($compilerProcess.ExitCode -ne 0) {
        throw "Ahk2Exe failed with exit code $($compilerProcess.ExitCode)."
    }
    if (-not (Test-Path -LiteralPath $stagedOutput -PathType Leaf)) {
        throw "Ahk2Exe reported success but did not create the staged executable."
    }
    if ((Get-PeMachine -Path $stagedOutput) -ne 0x8664) {
        throw "Compiled output is not a 64-bit Windows executable."
    }

    $hash = (Get-FileHash -LiteralPath $stagedOutput -Algorithm SHA256).Hash
    $version = (Get-Item -LiteralPath $stagedOutput).VersionInfo
    $selfTest = Start-Process `
        -FilePath $stagedOutput `
        -ArgumentList "--self-test" `
        -WorkingDirectory $stagingDirectory `
        -WindowStyle Hidden `
        -Wait `
        -PassThru
    if ($selfTest.ExitCode -ne 0) {
        throw "Compiled executable self-test failed with exit code $($selfTest.ExitCode)."
    }

    if (Test-Path -LiteralPath $output -PathType Leaf) {
        [IO.File]::Replace($stagedOutput, $output, $outputBackup, $true)
        if (Test-Path -LiteralPath $outputBackup -PathType Leaf) {
            Remove-Item -LiteralPath $outputBackup -Force
        }
    }
    else {
        Move-Item -LiteralPath $stagedOutput -Destination $output
    }
    Assert-Sha256 -Path $output -Expected $hash -Label "Published executable"

    Set-Content -LiteralPath $hashTemporary -Encoding ASCII -Value "$hash *MyCapslox.exe"
    if (Test-Path -LiteralPath $hashFile -PathType Leaf) {
        [IO.File]::Replace($hashTemporary, $hashFile, $hashBackup, $true)
        if (Test-Path -LiteralPath $hashBackup -PathType Leaf) {
            Remove-Item -LiteralPath $hashBackup -Force
        }
    }
    else {
        Move-Item -LiteralPath $hashTemporary -Destination $hashFile
    }
}
finally {
    if (Test-Path -LiteralPath $stagedOutput -PathType Leaf) {
        Remove-Item -LiteralPath $stagedOutput -Force
    }
    if (Test-Path -LiteralPath $hashTemporary -PathType Leaf) {
        Remove-Item -LiteralPath $hashTemporary -Force
    }
    if (Test-Path -LiteralPath $stagingDirectory -PathType Container) {
        $remainingStagingFiles = @(Get-ChildItem -LiteralPath $stagingDirectory -Force)
        if ($remainingStagingFiles.Count -eq 0) {
            Remove-Item -LiteralPath $stagingDirectory
        }
        else {
            Write-Warning "Build staging directory was preserved because it contains unexpected files: $stagingDirectory"
        }
    }
}

Write-Host "BUILD OK"
Write-Host "Executable: $output"
Write-Host "SHA-256:   $hash"
Write-Host "Version:   $($version.FileVersion)"
