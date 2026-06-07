param(
  [string]$Root = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$checks = @(
  @{ Path = "tools\ui_login.png"; Width = 960; Height = 540; MinBytes = 12000; MinColors = 24; MinLumaRange = 35 },
  @{ Path = "tools\ui_hub.png"; Width = 960; Height = 540; MinBytes = 12000; MinColors = 24; MinLumaRange = 35 },
  @{ Path = "tools\ui_import.png"; Width = 960; Height = 540; MinBytes = 12000; MinColors = 12; MinLumaRange = 35 },
  @{ Path = "tools\ui_preview.png"; Width = 960; Height = 540; MinBytes = 12000; MinColors = 24; MinLumaRange = 35 },
  @{ Path = "tools\ui_briefing.png"; Width = 960; Height = 540; MinBytes = 12000; MinColors = 24; MinLumaRange = 35 },
  @{ Path = "tools\ui_notice_upgrade.png"; Width = 960; Height = 540; MinBytes = 12000; MinColors = 24; MinLumaRange = 35 },
  @{ Path = "tools\ui_notice_locked.png"; Width = 960; Height = 540; MinBytes = 12000; MinColors = 24; MinLumaRange = 35 },
  @{ Path = "tools\ui_evidence.png"; Width = 960; Height = 540; MinBytes = 12000; MinColors = 24; MinLumaRange = 35 },
  @{ Path = "tools\ui_leaderboard.png"; Width = 960; Height = 540; MinBytes = 12000; MinColors = 24; MinLumaRange = 35 },
  @{ Path = "tools\ui_trace_detail.png"; Width = 960; Height = 540; MinBytes = 12000; MinColors = 24; MinLumaRange = 35 },
  @{ Path = "tools\ui_quality_report.png"; Width = 960; Height = 540; MinBytes = 12000; MinColors = 24; MinLumaRange = 35 },
  @{ Path = "tools\ui_teachersim_delta.png"; Width = 960; Height = 540; MinBytes = 12000; MinColors = 24; MinLumaRange = 35 },
  @{ Path = "tools\ui_cloud_log.png"; Width = 960; Height = 540; MinBytes = 12000; MinColors = 24; MinLumaRange = 35 },
  @{ Path = "tools\ui_class_dashboard.png"; Width = 960; Height = 540; MinBytes = 12000; MinColors = 24; MinLumaRange = 35 },
  @{ Path = "tools\ui_settings.png"; Width = 960; Height = 540; MinBytes = 12000; MinColors = 24; MinLumaRange = 35 },
  @{ Path = "tools\ui_upgrades.png"; Width = 960; Height = 540; MinBytes = 12000; MinColors = 24; MinLumaRange = 35 },
  @{ Path = "tools\ui_items.png"; Width = 960; Height = 540; MinBytes = 12000; MinColors = 24; MinLumaRange = 35 },
  @{ Path = "tools\ui_encounter_menu.png"; Width = 960; Height = 540; MinBytes = 12000; MinColors = 24; MinLumaRange = 35 },
  @{ Path = "tools\ui_encounter_type.png"; Width = 960; Height = 540; MinBytes = 12000; MinColors = 24; MinLumaRange = 35 },
  @{ Path = "tools\ui_lecture_menu.png"; Width = 960; Height = 540; MinBytes = 12000; MinColors = 24; MinLumaRange = 35 },
  @{ Path = "tools\ui_lecture_type.png"; Width = 960; Height = 540; MinBytes = 12000; MinColors = 24; MinLumaRange = 35 },
  @{ Path = "tools\ui_lecture_complete.png"; Width = 960; Height = 540; MinBytes = 12000; MinColors = 24; MinLumaRange = 35 },
  @{ Path = "tools\ui_gym_menu.png"; Width = 960; Height = 540; MinBytes = 12000; MinColors = 24; MinLumaRange = 35 },
  @{ Path = "tools\ui_gym_type.png"; Width = 960; Height = 540; MinBytes = 12000; MinColors = 24; MinLumaRange = 35 },
  @{ Path = "tools\ui_gym_complete.png"; Width = 960; Height = 540; MinBytes = 12000; MinColors = 24; MinLumaRange = 35 },
  @{ Path = "tools\ui_group.png"; Width = 960; Height = 540; MinBytes = 12000; MinColors = 24; MinLumaRange = 35 },
  @{ Path = "tools\ui_group_complete.png"; Width = 960; Height = 540; MinBytes = 12000; MinColors = 24; MinLumaRange = 35 },
  @{ Path = "tools\ui_overworld_independent.png"; Width = 960; Height = 540; MinBytes = 12000; MinColors = 24; MinLumaRange = 35 },
  @{ Path = "tools\ui_overworld_reflect.png"; Width = 960; Height = 540; MinBytes = 12000; MinColors = 24; MinLumaRange = 35 },
  @{ Path = "tools\ui_overworld_debrief.png"; Width = 960; Height = 540; MinBytes = 12000; MinColors = 24; MinLumaRange = 35 },
  @{ Path = "tmp\shot_enc_competency.png"; Width = 1920; Height = 1080; MinBytes = 12000; MinColors = 24; MinLumaRange = 35 }
)

function Test-ScreenshotSurface {
  param(
    [hashtable]$Check
  )

  $path = Join-Path $Root $Check.Path
  if (-not (Test-Path -LiteralPath $path)) {
    return "FAIL missing $($Check.Path)"
  }

  $item = Get-Item -LiteralPath $path
  if ($item.Length -lt [int64]$Check.MinBytes) {
    return "FAIL tiny $($Check.Path) bytes=$($item.Length) min=$($Check.MinBytes)"
  }

  $bitmap = $null
  try {
    $bitmap = [System.Drawing.Bitmap]::new($path)

    if ($bitmap.Width -ne [int]$Check.Width -or $bitmap.Height -ne [int]$Check.Height) {
      return "FAIL size $($Check.Path) got=$($bitmap.Width)x$($bitmap.Height) expected=$($Check.Width)x$($Check.Height)"
    }

    $colors = [System.Collections.Generic.HashSet[string]]::new()
    $minLuma = 999.0
    $maxLuma = -1.0
    $samplesX = 32
    $samplesY = 18

    for ($yi = 0; $yi -lt $samplesY; $yi += 1) {
      $y = [Math]::Min($bitmap.Height - 1, [int][Math]::Round(($yi + 0.5) * $bitmap.Height / $samplesY))
      for ($xi = 0; $xi -lt $samplesX; $xi += 1) {
        $x = [Math]::Min($bitmap.Width - 1, [int][Math]::Round(($xi + 0.5) * $bitmap.Width / $samplesX))
        $pixel = $bitmap.GetPixel($x, $y)
        $bucket = "{0:X1}{1:X1}{2:X1}" -f [int]($pixel.R / 16), [int]($pixel.G / 16), [int]($pixel.B / 16)
        [void]$colors.Add($bucket)
        $luma = (0.2126 * $pixel.R) + (0.7152 * $pixel.G) + (0.0722 * $pixel.B)
        if ($luma -lt $minLuma) { $minLuma = $luma }
        if ($luma -gt $maxLuma) { $maxLuma = $luma }
      }
    }

    $range = $maxLuma - $minLuma
    if ($colors.Count -lt [int]$Check.MinColors) {
      return "FAIL low-color $($Check.Path) colors=$($colors.Count) min=$($Check.MinColors)"
    }
    if ($range -lt [double]$Check.MinLumaRange) {
      return "FAIL flat-luma $($Check.Path) range=$([Math]::Round($range, 1)) min=$($Check.MinLumaRange)"
    }

    return "PASS $($Check.Path) $($bitmap.Width)x$($bitmap.Height) bytes=$($item.Length) colors=$($colors.Count) lumaRange=$([Math]::Round($range, 1))"
  }
  finally {
    if ($bitmap -ne $null) {
      $bitmap.Dispose()
    }
  }
}

$failed = 0
$results = @()
foreach ($check in $checks) {
  $result = Test-ScreenshotSurface -Check $check
  $results += $result
  if ($result.StartsWith("FAIL")) {
    $failed += 1
  }
}

$results | ForEach-Object { Write-Host $_ }
if ($failed -ne 0) {
  Write-Host "SCREENSHOT QA: FAIL ($failed gate(s))"
  exit 1
}

Write-Host "SCREENSHOT QA: PASS"
