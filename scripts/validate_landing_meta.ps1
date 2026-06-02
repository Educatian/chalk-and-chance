param(
  [string]$Root = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$pages = @(
  @{ Path = "landing\index.html"; Url = "https://chalk-and-chance.pages.dev/"; Type = "website" },
  @{ Path = "landing\demo.html"; Url = "https://chalk-and-chance.pages.dev/demo.html"; Type = "website" },
  @{ Path = "landing\guidebook.html"; Url = "https://chalk-and-chance.pages.dev/guidebook.html"; Type = "article" }
)

$assets = @(
  @{ Path = "landing\img\social-card.png"; Width = 1200; Height = 630; MinBytes = 50000; MinColors = 24; MinLumaRange = 35 },
  @{ Path = "landing\favicon.ico"; Width = 32; Height = 32; MinBytes = 500; MinColors = 4; MinLumaRange = 10 },
  @{ Path = "landing\img\favicon-32.png"; Width = 32; Height = 32; MinBytes = 300; MinColors = 4; MinLumaRange = 10 },
  @{ Path = "landing\img\site-icon-192.png"; Width = 192; Height = 192; MinBytes = 800; MinColors = 4; MinLumaRange = 10 },
  @{ Path = "landing\img\site-icon-512.png"; Width = 512; Height = 512; MinBytes = 1200; MinColors = 4; MinLumaRange = 10 },
  @{ Path = "landing\apple-touch-icon.png"; Width = 180; Height = 180; MinBytes = 800; MinColors = 4; MinLumaRange = 10 }
)

function Get-MetaContent {
  param([string]$Html, [string]$Key)
  $tags = [regex]::Matches($Html, '<meta\s+[^>]+>', "IgnoreCase")
  foreach ($tagMatch in $tags) {
    $tag = $tagMatch.Value
    $keyPattern = '(?:property|name)\s*=\s*"' + [regex]::Escape($Key) + '"'
    if ([regex]::IsMatch($tag, $keyPattern, "IgnoreCase")) {
      $contentMatch = [regex]::Match($tag, 'content\s*=\s*"([^"]*)"', "IgnoreCase")
      if ($contentMatch.Success) {
        return [System.Net.WebUtility]::HtmlDecode($contentMatch.Groups[1].Value)
      }
    }
  }
  return ""
}

function Test-PageMeta {
  param([hashtable]$Page)
  $path = Join-Path $Root $Page.Path
  if (-not (Test-Path -LiteralPath $path)) {
    return @("FAIL missing page $($Page.Path)")
  }
  $html = Get-Content -LiteralPath $path -Raw
  $fails = @()

  $titleMatch = [regex]::Match($html, '<title>([^<]+)</title>', "IgnoreCase")
  $title = if ($titleMatch.Success) { [System.Net.WebUtility]::HtmlDecode($titleMatch.Groups[1].Value).Trim() } else { "" }
  if ($title.Length -lt 12) { $fails += "FAIL $($Page.Path) title missing/short" }

  $requirements = @{
    "description" = "";
    "og:type" = $Page.Type;
    "og:url" = $Page.Url;
    "og:title" = "";
    "og:description" = "";
    "og:image" = "https://chalk-and-chance.pages.dev/img/social-card.png";
    "og:image:width" = "1200";
    "og:image:height" = "630";
    "og:image:alt" = "";
    "twitter:card" = "summary_large_image";
    "twitter:title" = "";
    "twitter:description" = "";
    "twitter:image" = "https://chalk-and-chance.pages.dev/img/social-card.png";
  }
  foreach ($key in $requirements.Keys) {
    $actual = Get-MetaContent -Html $html -Key $key
    $expected = [string]$requirements[$key]
    if ($actual.Trim() -eq "") {
      $fails += "FAIL $($Page.Path) missing meta $key"
    } elseif ($expected -ne "" -and $actual.Trim() -ne $expected) {
      $fails += "FAIL $($Page.Path) meta $key got='$actual' expected='$expected'"
    }
  }

  foreach ($href in @('favicon.ico', 'img/favicon-32.png', 'apple-touch-icon.png')) {
    if ($html.IndexOf($href, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
      $fails += "FAIL $($Page.Path) missing icon link $href"
    }
  }

  if ($fails.Count -eq 0) {
    return @("PASS $($Page.Path) share metadata")
  }
  return $fails
}

function Test-ImageAsset {
  param([hashtable]$Asset)
  $path = Join-Path $Root $Asset.Path
  if (-not (Test-Path -LiteralPath $path)) {
    return "FAIL missing asset $($Asset.Path)"
  }
  $item = Get-Item -LiteralPath $path
  if ($item.Length -lt [int64]$Asset.MinBytes) {
    return "FAIL tiny asset $($Asset.Path) bytes=$($item.Length) min=$($Asset.MinBytes)"
  }

  $image = $null
  try {
    $image = [System.Drawing.Bitmap]::new($path)
    if ($image.Width -ne [int]$Asset.Width -or $image.Height -ne [int]$Asset.Height) {
      return "FAIL asset size $($Asset.Path) got=$($image.Width)x$($image.Height) expected=$($Asset.Width)x$($Asset.Height)"
    }
    $colors = [System.Collections.Generic.HashSet[string]]::new()
    $minLuma = 999.0
    $maxLuma = -1.0
    $samplesX = [Math]::Min(32, $image.Width)
    $samplesY = [Math]::Min(18, $image.Height)
    for ($yi = 0; $yi -lt $samplesY; $yi += 1) {
      $y = [Math]::Min($image.Height - 1, [int][Math]::Round(($yi + 0.5) * $image.Height / $samplesY))
      for ($xi = 0; $xi -lt $samplesX; $xi += 1) {
        $x = [Math]::Min($image.Width - 1, [int][Math]::Round(($xi + 0.5) * $image.Width / $samplesX))
        $pixel = $image.GetPixel($x, $y)
        $bucket = "{0:X1}{1:X1}{2:X1}" -f [int]($pixel.R / 16), [int]($pixel.G / 16), [int]($pixel.B / 16)
        [void]$colors.Add($bucket)
        $luma = (0.2126 * $pixel.R) + (0.7152 * $pixel.G) + (0.0722 * $pixel.B)
        if ($luma -lt $minLuma) { $minLuma = $luma }
        if ($luma -gt $maxLuma) { $maxLuma = $luma }
      }
    }
    $range = $maxLuma - $minLuma
    if ($colors.Count -lt [int]$Asset.MinColors) {
      return "FAIL low-color asset $($Asset.Path) colors=$($colors.Count) min=$($Asset.MinColors)"
    }
    if ($range -lt [double]$Asset.MinLumaRange) {
      return "FAIL flat-luma asset $($Asset.Path) range=$([Math]::Round($range, 1)) min=$($Asset.MinLumaRange)"
    }
    return "PASS $($Asset.Path) $($image.Width)x$($image.Height) bytes=$($item.Length) colors=$($colors.Count) lumaRange=$([Math]::Round($range, 1))"
  }
  finally {
    if ($image -ne $null) {
      $image.Dispose()
    }
  }
}

$results = @()
$failed = 0
foreach ($page in $pages) {
  foreach ($result in (Test-PageMeta -Page $page)) {
    $results += $result
    if ($result.StartsWith("FAIL")) { $failed += 1 }
  }
}
foreach ($asset in $assets) {
  $result = Test-ImageAsset -Asset $asset
  $results += $result
  if ($result.StartsWith("FAIL")) { $failed += 1 }
}

$results | ForEach-Object { Write-Host $_ }
if ($failed -ne 0) {
  Write-Host "LANDING QA: FAIL ($failed gate(s))"
  exit 1
}

Write-Host "LANDING QA: PASS"
