param(
  [string]$GodotPath = "C:\Users\jewoo\godot\godot.exe",
  [switch]$SkipScreenshots
)

$ErrorActionPreference = "Continue"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$report = Join-Path $root "tools\product_qa_report.txt"
$scenes = @(
  @{ Name = "Project load"; Args = @("--headless", "--path", ".", "--quit"); Expect = "" },
  @{ Name = "Login to playable completion"; Args = @("--headless", "--path", ".", "--scene", "res://scenes/dev/Playtest.tscn"); Expect = "PLAYTEST | ALL PASS" },
  @{ Name = "UI layout audit"; Args = @("--headless", "--path", ".", "--scene", "res://scenes/dev/UILayoutAudit.tscn"); Expect = "UIAUDIT PASS" },
  @{ Name = "Visual asset audit"; Args = @("--headless", "--path", ".", "--scene", "res://scenes/dev/VisualAssetAudit.tscn"); Expect = "VISUALASSET PASS" },
  @{ Name = "Learning surface content"; Args = @("--headless", "--path", ".", "--scene", "res://scenes/dev/ProductContentAudit.tscn"); Expect = "PRODUCTCONTENT PASS" },
  @{ Name = "Scenario/data integrity"; Args = @("--headless", "--path", ".", "--scene", "res://scenes/dev/ScenarioIntegrityAudit.tscn"); Expect = "SCENARIOINTEGRITY PASS" },
  @{ Name = "Encounter smoke + differentiation"; Args = @("--headless", "--path", ".", "--scene", "res://scenes/dev/SmokeTest.tscn"); Expect = "SMOKE TEST: PASS" },
  @{ Name = "Lecture mode"; Args = @("--headless", "--path", ".", "--scene", "res://scenes/dev/LectureTest.tscn"); Expect = "LECTURE TEST: PASS" },
  @{ Name = "Gym capstone"; Args = @("--headless", "--path", ".", "--scene", "res://scenes/dev/GymTest.tscn"); Expect = "GYM TEST: PASS" },
  @{ Name = "Lesson import"; Args = @("--headless", "--path", ".", "--scene", "res://scenes/dev/ImportTest.tscn"); Expect = "IMPORT TEST: PASS" },
  @{ Name = "Telemetry/xAPI"; Args = @("--headless", "--path", ".", "--scene", "res://scenes/dev/TelemetryTest.tscn"); Expect = "TELEMETRY TEST: PASS" },
  @{ Name = "Overworld ecology"; Args = @("--headless", "--path", ".", "--scene", "res://scenes/dev/OverworldTest.tscn"); Expect = "OVERWORLD OK" }
)

if (-not (Test-Path $GodotPath)) {
  throw "Godot executable not found: $GodotPath"
}

function Invoke-GodotChecked {
  param(
    [string[]]$ArgsList,
    [int]$TimeoutSeconds = 90
  )

  $psi = [System.Diagnostics.ProcessStartInfo]::new()
  $psi.FileName = $GodotPath
  $psi.Arguments = ($ArgsList | ForEach-Object {
    if ($_ -match '[\s"]') {
      '"' + ($_.Replace('"', '\"')) + '"'
    } else {
      $_
    }
  }) -join " "
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  $proc = [System.Diagnostics.Process]::new()
  $proc.StartInfo = $psi
  [void]$proc.Start()
  $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
  $stderrTask = $proc.StandardError.ReadToEndAsync()
  if (-not $proc.WaitForExit($TimeoutSeconds * 1000)) {
    try {
      $proc.Kill($true)
    } catch {
      $proc.Kill()
    }
    $output = @(
      $stdoutTask.GetAwaiter().GetResult()
      $stderrTask.GetAwaiter().GetResult()
      "PROCESS TIMEOUT after ${TimeoutSeconds}s"
    ) -join [Environment]::NewLine
    return [pscustomobject]@{ ExitCode = 124; Output = $output }
  }
  $output = @(
    $stdoutTask.GetAwaiter().GetResult()
    $stderrTask.GetAwaiter().GetResult()
  ) -join [Environment]::NewLine
  return [pscustomobject]@{ ExitCode = $proc.ExitCode; Output = $output }
}

$lines = @()
$lines += "Chalk & Chance Product QA"
$lines += "Run: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$lines += "Root: $root"
$lines += ""

Push-Location $root
try {
  $failed = 0
  foreach ($scene in $scenes) {
    $name = $scene.Name
    $argsList = $scene.Args
    $expect = $scene.Expect
    $lines += "== $name =="
    $result = Invoke-GodotChecked -ArgsList $argsList
    $output = $result.Output
    $fatal = $output.Contains("SCRIPT ERROR") -or
      $output.Contains("Parse Error") -or
      $output.Contains("Invalid call") -or
      $output.Contains("Cannot call")
    $ok = $result.ExitCode -eq 0
    if ($expect -ne "") {
      $ok = $output.Contains($expect) -and (-not $fatal)
    }
    $lines += if ($ok) { "PASS" } else { "FAIL" }
    $lines += $output.Trim()
    $lines += ""
    if (-not $ok) {
      $failed += 1
    }
  }

  $lines += "== Landing/social metadata =="
  $landingOutput = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "scripts\validate_landing_meta.ps1") -Root $root 2>&1 | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
  $landingOk = $LASTEXITCODE -eq 0 -and $landingOutput.Contains("LANDING QA: PASS")
  $lines += if ($landingOk) { "PASS" } else { "FAIL" }
  $lines += $landingOutput.Trim()
  $lines += ""
  if (-not $landingOk) {
    $failed += 1
  }

  $lines += "== API cost gate =="
  $apiCostOutput = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "scripts\validate_api_cost_gate.ps1") -Root $root 2>&1 | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
  $apiCostOk = $LASTEXITCODE -eq 0 -and $apiCostOutput.Contains("APICOST QA: PASS")
  $lines += if ($apiCostOk) { "PASS" } else { "FAIL" }
  $lines += $apiCostOutput.Trim()
  $lines += ""
  if (-not $apiCostOk) {
    $failed += 1
  }

  $lines += "== D1 telemetry contract =="
  $d1Output = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "scripts\validate_d1_contract.ps1") -Root $root 2>&1 | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
  $d1Ok = $LASTEXITCODE -eq 0 -and $d1Output.Contains("D1 CONTRACT QA: PASS")
  $lines += if ($d1Ok) { "PASS" } else { "FAIL" }
  $lines += $d1Output.Trim()
  $lines += ""
  if (-not $d1Ok) {
    $failed += 1
  }

  if (-not $SkipScreenshots) {
    $lines += "== UI screenshot refresh =="
    $shotResult = Invoke-GodotChecked -ArgsList @("--path", ".", "--scene", "res://scenes/dev/UILayoutShots.tscn")
    $shotOutput = $shotResult.Output
    $shotOk = $shotResult.ExitCode -eq 0 -and
      (Test-Path (Join-Path $root "tools\ui_briefing.png")) -and
      (Test-Path (Join-Path $root "tools\ui_evidence.png")) -and
      (Test-Path (Join-Path $root "tools\ui_leaderboard.png")) -and
      (Test-Path (Join-Path $root "tools\ui_notice_upgrade.png")) -and
      (Test-Path (Join-Path $root "tools\ui_notice_locked.png")) -and
      (Test-Path (Join-Path $root "tools\ui_settings.png")) -and
      (Test-Path (Join-Path $root "tools\ui_upgrades.png")) -and
      (Test-Path (Join-Path $root "tools\ui_items.png")) -and
      (Test-Path (Join-Path $root "tools\ui_lecture_complete.png")) -and
      (Test-Path (Join-Path $root "tools\ui_gym_complete.png")) -and
      (Test-Path (Join-Path $root "tools\ui_group_complete.png")) -and
      (Test-Path (Join-Path $root "tools\ui_overworld_reflect.png")) -and
      (Test-Path (Join-Path $root "tools\ui_overworld_debrief.png"))
    $lines += if ($shotOk) { "PASS" } else { "FAIL" }
    $lines += $shotOutput.Trim()
    $lines += ""
    if (-not $shotOk) {
      $failed += 1
    }

    $lines += "== Encounter completion screenshot =="
    $encResult = Invoke-GodotChecked -ArgsList @("--path", ".", "--scene", "res://scenes/dev/ShotEnc.tscn")
    $encOutput = $encResult.Output
    $encOk = $encResult.ExitCode -eq 0 -and (Test-Path (Join-Path $root "tmp\shot_enc_competency.png"))
    $lines += if ($encOk) { "PASS" } else { "FAIL" }
    $lines += $encOutput.Trim()
    $lines += ""
    if (-not $encOk) {
      $failed += 1
    }

    $lines += "== Screenshot quality gate =="
    $qualityOutput = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "scripts\validate_screenshots.ps1") -Root $root 2>&1 | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    $qualityOk = $LASTEXITCODE -eq 0 -and $qualityOutput.Contains("SCREENSHOT QA: PASS")
    $lines += if ($qualityOk) { "PASS" } else { "FAIL" }
    $lines += $qualityOutput.Trim()
    $lines += ""
    if (-not $qualityOk) {
      $failed += 1
    }
  }

  $lines += "SUMMARY: " + ($(if ($failed -eq 0) { "PASS" } else { "FAIL ($failed gate(s))" }))
  $lines | Set-Content -Path $report -Encoding UTF8
  Write-Host "Product QA report: $report"
  if ($failed -ne 0) {
    exit 1
  }
}
finally {
  Pop-Location
}
