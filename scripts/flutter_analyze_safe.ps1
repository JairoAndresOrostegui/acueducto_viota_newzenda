<#
Safe Flutter analyzer runner for this project.

Codex note:
- In the Codex sandbox, `flutter analyze` can hang even when the project is OK.
- Run this script outside the sandbox/escalated when validating changes.
- Keep `--no-pub` enabled unless dependencies were intentionally changed.

Known-good command from Codex:
  powershell -ExecutionPolicy Bypass -File scripts\flutter_analyze_safe.ps1 -Target . -TimeoutSec 240 -SkipGlobalCleanup
#>

param(
  [string]$Target = ".",
  [int]$TimeoutSec = 240,
  [switch]$NoPub = $true,
  [switch]$SkipGlobalCleanup
)

$ErrorActionPreference = "Stop"
$env:DART_SUPPRESS_ANALYTICS = "true"
$env:FLUTTER_SUPPRESS_ANALYTICS = "true"
$env:PUB_ENVIRONMENT = "codex:flutter_analyze_safe"

$flutterBat = "C:\flutter\bin\flutter.bat"

function Remove-PathIfExists {
  param(
    [Parameter(Mandatory = $true)]
    [string]$LiteralPath
  )

  if (Test-Path -LiteralPath $LiteralPath) {
    Remove-Item -LiteralPath $LiteralPath -Recurse -Force -ErrorAction SilentlyContinue
  }
}

function Stop-FlutterProcesses {
  $names = @("dart", "dartvm", "dartaotruntime", "java")
  Get-Process -ErrorAction SilentlyContinue |
    Where-Object { $names -contains $_.ProcessName } |
    Stop-Process -Force -ErrorAction SilentlyContinue
}

$workspace = (Resolve-Path $PWD).Path
$targetPath = $Target

if (-not (Test-Path -LiteralPath $flutterBat)) {
  Write-Error "Flutter was not found at $flutterBat"
  exit 127
}

Write-Host "Cleaning Flutter/Dart state..."
Write-Host "If this command hangs inside Codex, re-run it outside the sandbox/escalated."
Stop-FlutterProcesses
Remove-PathIfExists -LiteralPath (Join-Path $workspace ".dart_tool\chrome-device")

if (-not $SkipGlobalCleanup) {
  Remove-PathIfExists -LiteralPath "C:\flutter\bin\cache\lockfile"
  Remove-PathIfExists -LiteralPath "C:\flutter\bin\cache\flutter.bat.lock"
  Remove-PathIfExists -LiteralPath (Join-Path $env:LOCALAPPDATA ".dartServer")

  Get-ChildItem $env:TEMP -Directory -Filter "flutter_tools.*" -ErrorAction SilentlyContinue |
    ForEach-Object {
      Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$args = @("analyze")
if ($NoPub) {
  $args += "--no-pub"
}
$args += $targetPath

Write-Host "Running: flutter $($args -join ' ')"
$process = Start-Process -FilePath $flutterBat `
  -ArgumentList $args `
  -WorkingDirectory $workspace `
  -NoNewWindow `
  -PassThru

if (-not $process.WaitForExit($TimeoutSec * 1000)) {
  Write-Warning "flutter analyze exceeded ${TimeoutSec}s. Stopping analyzer processes."
  Write-Warning "In this workspace that usually means sandbox/process-lock trouble, not necessarily Dart errors."
  Write-Warning "Known-good Codex pattern: request escalation and run this script with -SkipGlobalCleanup."
  Stop-FlutterProcesses
  if (-not $process.HasExited) {
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
  }
  exit 124
}

exit $process.ExitCode
