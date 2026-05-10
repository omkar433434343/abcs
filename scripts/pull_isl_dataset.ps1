param(
  [string]$Package = "com.swasthyasetu.swasthya_setu_flutter",
  [string]$RemoteDir = "app_flutter/isl_dataset",
  [string]$OutDir = "exports/isl_dataset"
)

$ErrorActionPreference = "Stop"

function Find-Adb {
  $cmd = Get-Command adb -ErrorAction SilentlyContinue
  if ($cmd) {
    return $cmd.Source
  }

  $candidates = @(
    "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
    "$env:ANDROID_HOME\platform-tools\adb.exe",
    "$env:ANDROID_SDK_ROOT\platform-tools\adb.exe"
  )

  foreach ($candidate in $candidates) {
    if ($candidate -and (Test-Path $candidate)) {
      return $candidate
    }
  }

  throw "adb.exe not found. Install Android SDK platform-tools or add adb to PATH."
}

function Invoke-AdbText {
  param([string[]]$AdbArgs)

  $output = & $script:Adb @AdbArgs 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw ($output -join "`n")
  }
  return $output
}

function Save-AdbExecOut {
  param(
    [string[]]$AdbArgs,
    [string]$OutputPath
  )

  function Quote-ProcessArgument {
    param([string]$Value)

    if ($Value -notmatch '[\s"]') {
      return $Value
    }

    return '"' + ($Value -replace '\\(?=\\*")', '$0$0' -replace '"', '\"') + '"'
  }

  $psi = [System.Diagnostics.ProcessStartInfo]::new()
  $psi.FileName = $script:Adb
  $psi.Arguments = ($AdbArgs | ForEach-Object { Quote-ProcessArgument $_ }) -join " "
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true

  $process = [System.Diagnostics.Process]::Start($psi)
  try {
    $file = [System.IO.File]::Open(
      (Resolve-Path -LiteralPath (Split-Path -Parent $OutputPath)).Path +
        [System.IO.Path]::DirectorySeparatorChar +
        (Split-Path -Leaf $OutputPath),
      [System.IO.FileMode]::Create,
      [System.IO.FileAccess]::Write
    )
    try {
      $process.StandardOutput.BaseStream.CopyTo($file)
    } finally {
      $file.Dispose()
    }

    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) {
      Remove-Item -LiteralPath $OutputPath -Force -ErrorAction SilentlyContinue
      throw $stderr
    }
  } finally {
    $process.Dispose()
  }
}

$script:Adb = Find-Adb
$root = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")
$dest = Join-Path $root $OutDir
New-Item -ItemType Directory -Force -Path $dest | Out-Null

$devices = Invoke-AdbText @("devices")
$connected = $devices | Where-Object { $_ -match "\tdevice$" }
if (-not $connected) {
  throw "No authorized Android device found. Connect phone, enable USB debugging, and accept the prompt."
}

Write-Host "Pulling ISL dataset from $Package/$RemoteDir"
Write-Host "Output folder: $dest"

$files = Invoke-AdbText @(
  "shell",
  "run-as",
  $Package,
  "sh",
  "-c",
  "find '$RemoteDir' -maxdepth 1 -type f -name '*.json' -printf '%f\n' 2>/dev/null"
)

$files = @($files | Where-Object { $_ -and $_.Trim().EndsWith(".json") })
if ($files.Count -eq 0) {
  Write-Host "No JSON samples found on device."
  exit 0
}

$pulled = 0
foreach ($name in $files) {
  $safeName = Split-Path -Leaf $name.Trim()
  $localPath = Join-Path $dest $safeName
  $remotePath = "$RemoteDir/$safeName"

  Save-AdbExecOut `
    @("exec-out", "run-as", $Package, "cat", $remotePath) `
    $localPath
  $pulled++
}

$summaryPath = Join-Path $dest "pull_manifest.json"
$summary = [ordered]@{
  package = $Package
  remote_dir = $RemoteDir
  output_dir = $dest
  pulled_at = (Get-Date).ToString("o")
  file_count = $pulled
  files = $files
}
$summary | ConvertTo-Json -Depth 4 | Set-Content -Encoding UTF8 $summaryPath

Write-Host "Pulled $pulled JSON files."
Write-Host "Manifest: $summaryPath"
