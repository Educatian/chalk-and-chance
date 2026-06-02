param(
  [string]$GodotPath = "C:\Users\jewoo\godot\godot.exe",
  [switch]$SkipScreenshots
)

$ErrorActionPreference = "Continue"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$report = Join-Path $root "tools\product_qa_report.txt"
$scenes = @(
  @{ Name = "Project load"; Args = @("--headless", "--path", ".", "--quit"); Expect = "" },
  @{ Name = "UI layout audit"; Args = @("--headless", "--path", ".", "--scene", "res://scenes/dev/UILayoutAudit.tscn"); Expect = "UIAUDIT PASS" },
  @{ Name = "Visual asset audit"; Args = @("--headless", "--path", ".", "--scene", "res://scenes/dev/VisualAssetAudit.tscn"); Expect = "VISUALASSET PASS" },
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
    $output = (& $GodotPath @argsList 2>&1 | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    $fatal = $output.Contains("SCRIPT ERROR") -or
      $output.Contains("Parse Error") -or
      $output.Contains("Invalid call") -or
      $output.Contains("Cannot call")
    $ok = $LASTEXITCODE -eq 0
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

  if (-not $SkipScreenshots) {
    $lines += "== UI screenshot refresh =="
    $shotOutput = (& $GodotPath --path . --scene "res://scenes/dev/UILayoutShots.tscn" 2>&1 | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    $shotOk = $LASTEXITCODE -eq 0 -and
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
    $encOutput = (& $GodotPath --path . --scene "res://scenes/dev/ShotEnc.tscn" 2>&1 | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    $encOk = $LASTEXITCODE -eq 0 -and (Test-Path (Join-Path $root "tmp\shot_enc_competency.png"))
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
