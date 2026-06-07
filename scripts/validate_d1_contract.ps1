param(
  [string]$Root = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
)

$ErrorActionPreference = "Continue"
$failed = 0

function Read-Text([string]$Path) {
  $full = Join-Path $Root $Path
  if (-not (Test-Path $full)) {
    Write-Host "FAIL missing $Path"
    $script:failed += 1
    return ""
  }
  return Get-Content -Raw -Path $full
}

function Add-Check([string]$Name, [bool]$Ok, [string]$Detail = "") {
  if ($Ok) {
    Write-Host "PASS $Name"
  } else {
    if ($Detail -ne "") {
      Write-Host "FAIL $Name - $Detail"
    } else {
      Write-Host "FAIL $Name"
    }
    $script:failed += 1
  }
}

$worker = Read-Text "cloudflare\worker.js"
$schema = Read-Text "cloudflare\schema.sql"
$telemetry = Read-Text "autoload\Telemetry.gd"
$auth = Read-Text "autoload\Auth.gd"
$hub = Read-Text "scenes\ui\Hub.gd"
$hubReports = Read-Text "scenes\ui\HubReports.gd"
$liveD1 = Read-Text "scripts\verify_live_d1_flow.ps1"

Add-Check "worker stores telemetry in D1" ($worker.Contains("INSERT INTO telemetry_events") -and $worker.Contains("env.DB.batch(batch)"))
Add-Check "worker redacts telemetry before D1" ($worker.Contains("safeTelemetryEvent") -and $worker.Contains("TELEMETRY_STRING_FIELDS") -and -not $worker.Contains("JSON.stringify(e))"))
Add-Check "worker upserts competency in D1" ($worker.Contains("INSERT INTO competency") -and $worker.Contains("ON CONFLICT(user_id,skill)"))
Add-Check "worker exposes learner competency restore" ($worker.Contains("GET") -and $worker.Contains("/competency") -and $worker.Contains("competencyRead"))
Add-Check "worker exposes instructor class dashboard" ($worker.Contains("/class_dashboard") -and $worker.Contains("classDashboard"))
Add-Check "class dashboard requires instructor role" ($worker.Contains('p.role !== "instructor"') -and $worker.Contains("forbidden") -and $liveD1.Contains("learner dashboard access correctly denied"))
Add-Check "schema has telemetry table and indexes" ($schema.Contains("CREATE TABLE IF NOT EXISTS telemetry_events") -and $schema.Contains("tel_user_idx") -and $schema.Contains("tel_sess_idx"))
Add-Check "schema has competency primary key" ($schema.Contains("CREATE TABLE IF NOT EXISTS competency") -and $schema.Contains("PRIMARY KEY (user_id, skill)"))
Add-Check "telemetry uploads buffered events only when signed in" ($telemetry.Contains("Auth.signed_in()") -and $telemetry.Contains('/telemetry') -and $telemetry.Contains("_buffer"))
Add-Check "telemetry uploads competency estimates" ($telemetry.Contains("func upload_competency") -and $telemetry.Contains('/competency'))
Add-Check "auth restores cloud competency after login" ($auth.Contains("/competency") -and $auth.Contains("_load_competency_then_login"))
Add-Check "hub exposes cloud log verification surface" ($hub.Contains("CLOUD LOG CHECK") -and $hub.Contains("/class_dashboard") -and $hubReports.Contains("Local telemetry file:"))
Add-Check "live D1 smoke test is available and env-gated" ($liveD1.Contains("CHALK_API_BASE") -and $liveD1.Contains("/auth/login") -and $liveD1.Contains("/telemetry") -and $liveD1.Contains("/competency") -and $liveD1.Contains("LIVE D1 FLOW: PASS"))

if ($failed -gt 0) {
  Write-Host "D1 CONTRACT QA: FAIL ($failed gate(s))"
  exit 1
}

Write-Host "D1 CONTRACT QA: PASS"
