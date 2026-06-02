param(
  [string]$Root = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
)

$ErrorActionPreference = "Stop"

function Read-ProjectFile {
  param([string]$RelPath)
  $path = Join-Path $Root $RelPath
  if (-not (Test-Path -LiteralPath $path)) {
    throw "missing file $RelPath"
  }
  return Get-Content -LiteralPath $path -Raw
}

function Add-Check {
  param([string]$Name, [bool]$Ok, [string]$Detail = "")
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

function ContainsText {
  param([string]$Haystack, [string]$Needle)
  return $Haystack.IndexOf($Needle, [StringComparison]::OrdinalIgnoreCase) -ge 0
}

$failed = 0

$demo = Read-ProjectFile "landing\demo.html"
$llm = Read-ProjectFile "autoload\LLMClient.gd"
$ttsClient = Read-ProjectFile "autoload\TTSClient.gd"
$worker = Read-ProjectFile "cloudflare\worker.js"
$ttsWorker = Read-ProjectFile "cloudflare\tts.js"
$authConfig = Read-ProjectFile "data\auth_config.json"
$groupScene = Read-ProjectFile "scenes\encounter\GroupCheckIn.gd"
$lectureScene = Read-ProjectFile "scenes\encounter\LectureScene.gd"
$gymScene = Read-ProjectFile "scenes\encounter\GymEncounter.gd"

Add-Check "demo opens taste build with public_demo flag" (ContainsText $demo "?public_demo=1")
Add-Check "demo explains API-safe/offline taste mode" ((ContainsText $demo "API-safe") -and (ContainsText $demo "offline"))
Add-Check "demo requests server voice token instead of local passcode check" ((ContainsText $demo "/voice_token") -and (-not [regex]::IsMatch($demo, "passcode\s*={2,3}|expectedPasscode|const\s+(PASSCODE|VOICE_PASSCODE)")))

Add-Check "web LLM client detects public_demo mode" ((ContainsText $llm "_web_public_demo_mode") -and (ContainsText $llm "public_demo"))
Add-Check "web public demo forces LLM stub" ([regex]::IsMatch($llm, "if\s+_web_public_demo_mode\(\):\s*\r?\n\s*use_stub\s*=\s*true", "IgnoreCase"))
Add-Check "TTS client disables voice in public demo" ((ContainsText $ttsClient "_web_public_demo_mode") -and (ContainsText $ttsClient "enabled = false") -and (ContainsText $ttsClient "public_demo"))
Add-Check "web TTS requires gate by config" ((ContainsText $authConfig '"tts_requires_gate": true') -and (ContainsText $ttsClient "voice_gate_required"))

Add-Check "group mode honors LLM stub before HTTP" ((ContainsText $groupScene "LLMClient.use_stub") -and (ContainsText $groupScene "_local_fallback(tag)"))
Add-Check "lecture mode honors LLM stub before HTTP" ((ContainsText $lectureScene "LLMClient.use_stub") -and (ContainsText $lectureScene "_http.request(ep"))
Add-Check "gym mode honors LLM stub before HTTP" ((ContainsText $gymScene "LLMClient.use_stub") -and (ContainsText $gymScene "_log_gym_turn"))

Add-Check "worker exposes voice token route" ((ContainsText $worker 'url.pathname === "/voice_token"') -and (ContainsText $worker "signVoiceToken"))
Add-Check "worker passcode comes from environment" ((ContainsText $worker "env.TTS_PASSCODE") -and (-not [regex]::IsMatch($worker, "TTS_PASSCODE\s*=\s*['""]", "IgnoreCase")))
Add-Check "voice token is short lived" ((ContainsText $worker "expiresIn") -and (ContainsText $worker "15 * 60"))
Add-Check "TTS accepts voice token header" (ContainsText $ttsWorker 'req.headers.get("X-Voice-Token")')
Add-Check "TTS rejects missing/invalid token silently" ((ContainsText $ttsWorker "verifyVoiceToken") -and (ContainsText $ttsWorker "status: 204"))

$verifyIdx = $ttsWorker.IndexOf("verifyVoiceToken", [StringComparison]::OrdinalIgnoreCase)
$fetchIdx = $ttsWorker.IndexOf("api.elevenlabs.io", [StringComparison]::OrdinalIgnoreCase)
Add-Check "TTS token verification precedes ElevenLabs fetch" ($verifyIdx -ge 0 -and $fetchIdx -gt $verifyIdx)

if ($failed -ne 0) {
  Write-Host "APICOST QA: FAIL ($failed gate(s))"
  exit 1
}

Write-Host "APICOST QA: PASS"
