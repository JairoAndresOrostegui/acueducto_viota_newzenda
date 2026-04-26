param(
  [string]$Target = ".",
  [int]$TimeoutSec = 120,
  [switch]$NoPub = $true,
  [switch]$SkipGlobalCleanup
)

$ErrorActionPreference = "Stop"

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

Write-Host "Cleaning Flutter/Dart state..."
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
$process = Start-Process -FilePath "C:\flutter\bin\flutter.bat" `
  -ArgumentList $args `
  -WorkingDirectory $workspace `
  -NoNewWindow `
  -PassThru

if (-not $process.WaitForExit($TimeoutSec * 1000)) {
  Write-Warning "flutter analyze exceeded ${TimeoutSec}s. Stopping analyzer processes."
  Stop-FlutterProcesses
  if (-not $process.HasExited) {
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
  }
  exit 124
}

exit $process.ExitCode
