# Patches the stock Godot web shell (dist_web/index.html) after every export:
#  1. drops user-scalable=no so browser zoom keeps working (accessibility)
#  2. adds a "Loading Chalk & Chance... NN%" line under the progress bar
#     (a 48MB wasm+pck download with a bare <progress> reads as a hang)
# Run after: godot --headless --export-release Web dist_web/index.html
param([string]$ShellPath = "$PSScriptRoot\..\dist_web\index.html")

$html = Get-Content -Raw -Encoding UTF8 $ShellPath
if ($html -match 'status-progress-text') {
    Write-Host 'patch_web_shell: already patched, skipping.'
    exit 0
}

$html = $html.Replace('content="width=device-width, user-scalable=no, initial-scale=1.0"',
    'content="width=device-width, initial-scale=1.0"')

# Anchor on selectors unique in the stock shell; a bare "#status-progress {"
# also matches the tail of the "#status, #status-splash, #status-progress {"
# selector list and corrupts it.
$html = $html.Replace("#status-progress, #status-notice {",
    "#status-progress, #status-progress-text, #status-notice {")

$css = @'
#status-progress {
	bottom: 10%;
'@
$cssNew = @'
#status-progress-text {
	position: absolute;
	left: 0;
	right: 0;
	bottom: calc(10% + 26px);
	text-align: center;
	color: #e0e0e0;
	font-family: 'Noto Sans', 'Droid Sans', Arial, sans-serif;
	font-size: 15px;
	text-shadow: 0 1px 3px rgba(0, 0, 0, 0.8);
}

#status-progress {
	bottom: 10%;
'@
$html = $html.Replace($css, $cssNew)

$html = $html.Replace('<progress id="status-progress"></progress>',
    "<progress id=`"status-progress`"></progress>`n`t`t`t<div id=`"status-progress-text`"></div>")

$html = $html.Replace("const statusProgress = document.getElementById('status-progress');",
    "const statusProgress = document.getElementById('status-progress');`n`tconst statusProgressText = document.getElementById('status-progress-text');")

$html = $html.Replace("statusProgress.style.display = mode === 'progress' ? 'block' : 'none';",
    "statusProgress.style.display = mode === 'progress' ? 'block' : 'none';`n`t`tstatusProgressText.style.display = mode === 'progress' ? 'block' : 'none';")

$html = $html.Replace("statusProgress.value = current;
					statusProgress.max = total;",
    "statusProgress.value = current;
					statusProgress.max = total;
					statusProgressText.textContent = 'Loading Chalk & Chance... ' + Math.round((current / total) * 100) + '%';")

$html = $html.Replace("statusProgress.removeAttribute('value');
					statusProgress.removeAttribute('max');",
    "statusProgress.removeAttribute('value');
					statusProgress.removeAttribute('max');
					statusProgressText.textContent = 'Loading Chalk & Chance...';")

[System.IO.File]::WriteAllText((Resolve-Path $ShellPath), $html, (New-Object System.Text.UTF8Encoding $false))
Write-Host 'patch_web_shell: patched.'
