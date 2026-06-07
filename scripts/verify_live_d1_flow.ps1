param(
  [string]$ApiBase = $env:CHALK_API_BASE,
  [string]$ClassCode = $env:CHALK_CLASS_CODE,
  [string]$LoginName = $env:CHALK_LOGIN_NAME,
  [string]$Password = $env:CHALK_PASSWORD,
  [string]$InstructorName = $env:CHALK_INSTRUCTOR_NAME,
  [string]$InstructorPassword = $env:CHALK_INSTRUCTOR_PASSWORD
)

$ErrorActionPreference = "Stop"

function Need([string]$Name, [string]$Value) {
  if ([string]::IsNullOrWhiteSpace($Value)) {
    throw "$Name is required. Set CHALK_API_BASE, CHALK_CLASS_CODE, CHALK_LOGIN_NAME, and CHALK_PASSWORD."
  }
}

Need "ApiBase" $ApiBase
Need "ClassCode" $ClassCode
Need "LoginName" $LoginName
Need "Password" $Password

$ApiBase = $ApiBase.TrimEnd("/")
$loginBody = @{
  class_code = $ClassCode
  name = $LoginName
  password = $Password
} | ConvertTo-Json

$login = Invoke-RestMethod -Method Post -Uri "$ApiBase/auth/login" -ContentType "application/json" -Body $loginBody
if ([string]::IsNullOrWhiteSpace($login.token)) {
  throw "Login did not return a token."
}

$headers = @{ Authorization = "Bearer $($login.token)" }
try {
  Invoke-RestMethod -Method Get -Uri "$ApiBase/class_dashboard" -Headers $headers | Out-Null
  throw "Learner token unexpectedly accessed /class_dashboard."
} catch {
  $status = [int]($_.Exception.Response.StatusCode)
  if ($status -ne 403) {
    throw "Learner dashboard check expected 403, got $status."
  }
  Write-Host "learner dashboard access correctly denied"
}

$sessionId = "live_d1_verify_$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"
$telemetryBody = @{
  events = @(
    @{
      event = "live_d1_verify"
      session_id = $sessionId
      construct_id = "formative_check"
      scenario_id = "qa_live_d1"
      source = "scripts/verify_live_d1_flow.ps1"
    }
  )
} | ConvertTo-Json -Depth 8
$telemetry = Invoke-RestMethod -Method Post -Uri "$ApiBase/telemetry" -Headers $headers -ContentType "application/json" -Body $telemetryBody
if ([int]($telemetry.stored) -lt 1) {
  throw "Telemetry POST did not store an event."
}

$competencyBody = @{
  skills = @(
    @{
      skill = "formative_check"
      theta = 0.42
      prob = 0.61
      n = 3
    }
  )
} | ConvertTo-Json -Depth 8
$competency = Invoke-RestMethod -Method Post -Uri "$ApiBase/competency" -Headers $headers -ContentType "application/json" -Body $competencyBody
if ([int]($competency.upserted) -lt 1) {
  throw "Competency POST did not upsert a skill."
}

$own = Invoke-RestMethod -Method Get -Uri "$ApiBase/competency" -Headers $headers
$hasOwnSkill = $false
foreach ($skill in $own.skills) {
  if ($skill.skill -eq "formative_check" -and [int]($skill.n) -ge 3) {
    $hasOwnSkill = $true
  }
}
if (-not $hasOwnSkill) {
  throw "Learner competency restore did not expose the posted formative_check skill."
}

if ([string]::IsNullOrWhiteSpace($InstructorName) -or [string]::IsNullOrWhiteSpace($InstructorPassword)) {
  Write-Host "LIVE D1 FLOW: PASS telemetry stored; learner competency restored; learner dashboard denied; instructor dashboard skipped (set CHALK_INSTRUCTOR_NAME/PASSWORD to verify aggregates)"
  exit 0
}

$instructorBody = @{
  class_code = $ClassCode
  name = $InstructorName
  password = $InstructorPassword
} | ConvertTo-Json
$instructorLogin = Invoke-RestMethod -Method Post -Uri "$ApiBase/auth/login" -ContentType "application/json" -Body $instructorBody
if ([string]::IsNullOrWhiteSpace($instructorLogin.token)) {
  throw "Instructor login did not return a token."
}
$instructorHeaders = @{ Authorization = "Bearer $($instructorLogin.token)" }
$after = Invoke-RestMethod -Method Get -Uri "$ApiBase/class_dashboard" -Headers $instructorHeaders
$afterCount = [int]($after.telemetry_events)
$hasSkill = $false
foreach ($skill in $after.skills) {
  if ($skill.skill -eq "formative_check" -and [int]($skill.evidence) -ge 3) {
    $hasSkill = $true
  }
}

if (-not $hasSkill) {
  throw "Class dashboard did not expose the posted formative_check competency."
}

Write-Host "LIVE D1 FLOW: PASS learner telemetry stored; learner dashboard denied; instructor dashboard telemetry=$afterCount; competency formative_check visible"
