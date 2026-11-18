<#
.SYNOPSIS
  Downloads a model from Printables or MakerWorld into a folder of this repo, unzips it,
  deletes the zip, records the source in scripts/readme-sources.json and regenerates the READMEs.

.DESCRIPTION
  Printables: downloaded directly (no account needed). By default only the "model files"
  pack is fetched, into "<slug>-model_files" - the same layout as the existing folders.
  -AllFiles also fetches the print files (gcode/3mf) and other files packs.

  MakerWorld requires a logged-in account to download. The first time a MakerWorld link comes
  up, the script asks for your Bambu Lab / MakerWorld email and password (and the emailed or
  2FA code if your account uses one), saves the token in scripts/.makerworld-token
  (git-ignored) and reuses it for every MakerWorld link after that. It then downloads into
  "<Model+Name>\":
    STL-CAD\                 the STL/CAD model files, if the designer uploaded them
    3MF\<profile name>.3mf   every print profile
  $env:MAKERWORLD_TOKEN overrides the saved token. Other options:
    -File <path>   use a zip/3mf you already downloaded (no login needed)
    skip login     press Enter at the email prompt; the model page then opens in your
                   browser and the file you download is picked up from your Downloads folder

  scripts/add_model.py is the Linux/macOS version of this script.

.PARAMETER Url
  One or more Printables / MakerWorld model URLs.
.PARAMETER List
  A text file with one URL per line. A line can name its own folder after the URL
  ("<url>  storage/8020"); otherwise -Folder is used. Blank lines and lines starting with #
  are ignored. A failed model is reported and the rest of the list still runs.
.PARAMETER Folder
  Repo folder to put the model in (created if missing). Defaults to the current directory.
  A relative path is relative to the current directory, also for folders named in -List.
.PARAMETER Name
  Override the name of the model's folder (only with a single URL).
.PARAMETER NoPage
  Don't save model-page.html (an offline copy of the model's page). Attachments such as PDF
  manuals and assembly guides are still downloaded into Instructions\.
.PARAMETER NoPdf
  Save the page as HTML only. By default a PDF copy (model-page.pdf) is printed with Edge.
.PARAMETER NoComments
  Leave user comments and ratings out of the saved page.
.PARAMETER NoReadme
  Don't regenerate the READMEs afterwards (run Update-Readmes.ps1 yourself later).
.PARAMETER FillPages
  Add model-page.html and Instructions\ to models that are already in the repo (listed in
  readme-sources.json as Printables / MakerWorld) but don't have a saved page yet. Only models
  under the folders given in place of URLs (or -Folder, or the current directory) are done.
  No model files are downloaded and no login is needed. -Force redoes models that have a page.
.PARAMETER Match
  Find the Printables / MakerWorld page for models in readme-sources.json that have no link
  yet (under the folders given in place of URLs, or -Folder, or the current directory).
  When a model's 3MF says which MakerWorld model it came from, the match is saved
  automatically. For the rest it shows search results: type a number to pick one, paste the
  model's URL, type other words to search again, press Enter to skip, x for "not online"
  (never asked again; -Force asks again), or q to stop.
.PARAMETER AutoOnly
  With -Match: only save the automatic (exact) matches and ask nothing.

.EXAMPLE
  scripts\Add-Model.ps1 https://www.printables.com/model/359285-klamma-locking-cable-clip -Folder cable-management
.EXAMPLE
  cd storage\8020; ..\..\scripts\Add-Model.ps1 https://makerworld.com/en/models/2133463-cable-organizer
.EXAMPLE
  scripts\Add-Model.ps1 -List new-models.txt -Folder unsorted
.EXAMPLE
  scripts\Add-Model.ps1 -FillPages tools\woodworking
.EXAMPLE
  scripts\Add-Model.ps1 -Match bub
#>
param(
  [Parameter(Position = 0, ValueFromRemainingArguments = $true)][string[]]$Url,
  [string]$List,
  [string]$Folder = '.',
  [string]$Name,
  [string]$File,
  [switch]$AllFiles,
  [switch]$Force,
  [switch]$NoReadme,
  [switch]$NoPage,
  [switch]$NoPdf,
  [switch]$NoComments,
  [switch]$FillPages,
  [switch]$Match,
  [switch]$AutoOnly
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.IO.Compression.FileSystem
. (Join-Path $PSScriptRoot 'ReadmeCommon.ps1')

$Repo      = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$CachePath = Join-Path $PSScriptRoot 'readme-sources.json'
$TokenFile = Join-Path $PSScriptRoot '.makerworld-token'
$UA        = 'Mozilla/5.0 (3d-print-files readme generator)'
$ModelExts = '^\.(zip|3mf|stl|step|stp|f3d|f3z|obj|scad|amf)$'

function LongPath([string]$p) { if ($p.StartsWith('\\?\')) { $p } else { "\\?\$p" } }
function SafeName([string]$s) { (($s -replace '[<>:"/\\|?*\x00-\x1f]', '_').Trim()).TrimEnd('.', ' ') }

# ---------------------------------------------------------------- what to download, and where
function Resolve-Dest([string]$folder) {
  $d = if ([IO.Path]::IsPathRooted($folder)) { $folder } else { Join-Path (Get-Location).Path $folder }
  $d = [IO.Path]::GetFullPath($d).TrimEnd('\')
  if (-not $d.StartsWith("$Repo\", [StringComparison]::OrdinalIgnoreCase)) {
    throw "Folder '$d' must be a category folder inside the repo ($Repo)."
  }
  $d
}
# Reads a URL list: "<url>" or "<url> <folder>" per line; blank lines and # comments are skipped.
function Read-UrlList([string]$path) {
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "URL list '$path' not found (looked in $((Get-Location).Path))." }
  $found = 0
  foreach ($line in [IO.File]::ReadAllLines((Resolve-Path -LiteralPath $path).Path)) {   # handles UTF-8 and UTF-16
    $t = ($line -replace '(^|\s)#.*$', '').Trim()
    if (-not $t) { continue }
    $parts = $t -split '\s+', 2
    $found++
    @{ Url = $parts[0]; Folder = $(if ($parts.Count -gt 1) { $parts[1].Trim() } else { $Folder }) }
  }
  if (-not $found) { throw "URL list '$path' has no URLs in it (blank lines and # comments are skipped)." }
}

if ($FillPages -or $Match) {   # the arguments are folders to look in, not URLs
  $scopes = @(foreach ($f in $(if (@($Url | Where-Object { $_ }).Count) { @($Url | Where-Object { $_ }) } else { @($Folder) })) {
    $d = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($f)) { $f } else { Join-Path (Get-Location).Path $f })).TrimEnd('\')
    if ($d -ne $Repo -and -not $d.StartsWith("$Repo\", [StringComparison]::OrdinalIgnoreCase)) { throw "Folder '$d' is not inside the repo ($Repo)." }
    $d
  })
} else {
# A file name instead of a URL is read as a URL list, same as -List.
$jobs = @(foreach ($u in @($Url)) {
  if (-not $u) { continue }
  if ($u -notmatch '^https?://' -and (Test-Path -LiteralPath $u -PathType Leaf)) { Read-UrlList $u }
  else { @{ Url = $u; Folder = $Folder } }
})
if ($List) { $jobs += @(Read-UrlList $List) }
if (-not $jobs.Count) { throw 'Give one or more model URLs, or -List <file with one URL per line>.' }
if ($Name -and $jobs.Count -gt 1) { throw '-Name can only be used with a single URL.' }
if ($File -and $jobs.Count -gt 1) { throw '-File can only be used with a single URL.' }
foreach ($j in $jobs) { $j.Dest = Resolve-Dest $j.Folder }   # fail early on a bad folder
}

# ---------------------------------------------------------------- web helpers
function Gql([string]$query, [hashtable]$vars = @{}) {
  $body = @{ query = $query; variables = $vars } | ConvertTo-Json -Compress -Depth 6
  $r = Invoke-RestMethod -Uri 'https://api.printables.com/graphql/' -Method Post -Body $body -ContentType 'application/json' -UserAgent $UA -TimeoutSec 60
  if ($r.errors) { throw "Printables API: $($r.errors[0].message)" }
  $r.data
}
function Save-Url([string]$url, [string]$out, [hashtable]$headers = @{}) {
  Write-Host "  downloading $([IO.Path]::GetFileName($out))"
  # Invoke-WebRequest -OutFile can't write to \\?\ long paths, so download next to the temp folder and move it.
  $part = Join-Path ([IO.Path]::GetTempPath()) ("add-model-" + [guid]::NewGuid().ToString('N') + '.part')
  try {
    Invoke-WebRequest -Uri $url -OutFile $part -UserAgent $UA -Headers $headers -UseBasicParsing -TimeoutSec 600
    if ([IO.File]::Exists($out)) { [IO.File]::Delete($out) }
    [IO.File]::Move($part, $out)
  } finally { if (Test-Path -LiteralPath $part) { Remove-Item -LiteralPath $part -Force } }
}

# Extracts a zip into $dest. A single top-level folder inside the zip is flattened, and
# __MACOSX / .DS_Store junk is skipped.
function Expand-ModelZip([string]$zip, [string]$dest) {
  $z = [IO.Compression.ZipFile]::OpenRead((LongPath $zip))
  try {
    $entries = @($z.Entries | Where-Object { $_.Name -and $_.FullName -notmatch '(^|/)__MACOSX/' -and $_.Name -ne '.DS_Store' })
    $names = @($entries | ForEach-Object { $_.FullName -replace '\\', '/' })
    $strip = ''
    if ($names.Count -and @($names | Where-Object { $_ -notmatch '/' }).Count -eq 0) {
      $tops = @($names | ForEach-Object { ($_ -split '/')[0] } | Select-Object -Unique)
      if ($tops.Count -eq 1) { $strip = "$($tops[0])/" }
    }
    foreach ($e in $entries) {
      $n = ($e.FullName -replace '\\', '/')
      if ($strip) { $n = $n.Substring($strip.Length) }
      $parts = @($n -split '/' | Where-Object { $_ })
      if ($parts -contains '..' -or $n.StartsWith('/') -or $n -match '^[A-Za-z]:') { Write-Warning "skipping unsafe zip entry $n"; continue }
      $target = LongPath ([IO.Path]::Combine($dest, ($parts | ForEach-Object { SafeName $_ }) -join '\'))
      [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))
      [IO.Compression.ZipFileExtensions]::ExtractToFile($e, $target, $true)
    }
    $entries.Count
  } finally { $z.Dispose() }
}

function Get-DownloadsFolder {
  try {
    $p = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders' -ErrorAction Stop).'{374DE290-123F-4565-9164-39C4925E467B}'
    if ($p -and (Test-Path $p)) { return $p }
  } catch { }
  Join-Path $env:USERPROFILE 'Downloads'
}
# Waits for a new model file to finish downloading into $dir.
function Wait-ForDownload([string]$dir, [datetime]$since, [int]$timeoutSec = 900) {
  Write-Host "  waiting for the download to appear in $dir (Ctrl+C to cancel) ..."
  $deadline = (Get-Date).AddSeconds($timeoutSec); $last = $null; $lastSize = -1
  while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 2
    $files = @(Get-ChildItem -LiteralPath $dir -File -ErrorAction SilentlyContinue |
      Where-Object { $_.LastWriteTime -gt $since -or $_.CreationTime -gt $since })
    $partial = @($files | Where-Object { $_.Extension -match '^\.(crdownload|part|partial|tmp|download)$' })
    $cand = $files | Where-Object { $_.Extension -match $ModelExts } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($cand -and -not $partial.Count) {
      if ($cand.FullName -eq $last -and $cand.Length -eq $lastSize -and $cand.Length -gt 0) { return $cand.FullName }
      $last = $cand.FullName; $lastSize = $cand.Length
    }
  }
  throw "No download showed up in $dir within $([int]($timeoutSec / 60)) minutes. Re-run with -File <path to the zip>."
}

# ---------------------------------------------------------------- MakerWorld login
# MakerWorld accounts are Bambu Lab accounts. The script logs in once through the Bambu Lab
# account API (the one Bambu Studio uses), saves the token in scripts/.makerworld-token
# (git-ignored) and reuses it for every MakerWorld link - in this run and later ones - until
# MakerWorld rejects it, at which point it asks you to log in again.
$script:MwToken = $null
$script:MwSkip = $false
function Read-Plain([string]$prompt, [switch]$Secret) {
  if (-not $Secret) { return (Read-Host $prompt) }
  $s = Read-Host $prompt -AsSecureString
  $b = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($s)
  try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($b) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b) }
}
function Invoke-BambuPost([string]$url, [hashtable]$body) {
  try { Invoke-RestMethod -Uri $url -Method Post -Body ($body | ConvertTo-Json -Compress) -ContentType 'application/json' -UserAgent $UA -TimeoutSec 60 }
  catch {
    $ex = $_; $err = $null
    try { $err = ($ex.ErrorDetails.Message | ConvertFrom-Json).error } catch { }
    throw $(if ($err) { $err } else { $ex.Exception.Message })
  }
}
# Returns an access token, asking for an emailed or 2FA code when the account needs one.
function Invoke-BambuLogin([string]$account, [string]$password) {
  $api = 'https://api.bambulab.com/v1/user-service/user'
  $r = Invoke-BambuPost "$api/login" @{ account = $account; password = $password; apiError = '' }
  if ($r.accessToken) { return $r.accessToken }
  if ($r.loginType -eq 'verifyCode') {
    [void](Invoke-BambuPost "$api/sendemail/code" @{ email = $account; type = 'codeLogin' })
    $code = Read-Plain "  Bambu Lab emailed a verification code to $account. Code"
    return (Invoke-BambuPost "$api/login" @{ account = $account; code = $code.Trim() }).accessToken
  }
  if ($r.loginType -eq 'tfa') {
    $code = Read-Plain '  Two-factor code from your authenticator app'
    $resp = Invoke-WebRequest -Uri 'https://bambulab.com/api/sign-in/tfa' -Method Post -UseBasicParsing -UserAgent $UA -TimeoutSec 60 `
      -Body (@{ tfaKey = $r.tfaKey; tfaCode = $code.Trim() } | ConvertTo-Json -Compress) -ContentType 'application/json' -SessionVariable sv
    $tok = ($sv.Cookies.GetCookies('https://bambulab.com') | Where-Object { $_.Name -eq 'token' } | Select-Object -First 1).Value
    if (-not $tok) { try { $tok = ($resp.Content | ConvertFrom-Json).accessToken } catch { } }
    return $tok
  }
  throw "unexpected login response: $($r | ConvertTo-Json -Compress)"
}
function Get-MakerWorldToken([switch]$Renew) {
  if ($Renew) {
    $script:MwToken = $null   # the current one was rejected
    if ($script:MwSkip) { return $null }
  } else {
    if ($script:MwToken) { return $script:MwToken }
    if ($script:MwSkip) { return $null }
    if ($env:MAKERWORLD_TOKEN) { return ($script:MwToken = $env:MAKERWORLD_TOKEN.Trim()) }
    if (Test-Path -LiteralPath $TokenFile) {
      $t = ([IO.File]::ReadAllText($TokenFile)).Trim()
      if ($t) { return ($script:MwToken = $t) }
    }
  }
  Write-Host ''
  Write-Host 'MakerWorld login - your Bambu Lab / MakerWorld account. Needed once; the token is saved in'
  Write-Host 'scripts/.makerworld-token for next time. Press Enter without an email to skip (you then'
  Write-Host 'download each MakerWorld model yourself in the browser).'
  for ($attempt = 1; $attempt -le 3; $attempt++) {
    $acct = (Read-Plain '  Email').Trim()
    if (-not $acct) { $script:MwSkip = $true; return $null }
    $pw = Read-Plain '  Password' -Secret
    try {
      $tok = Invoke-BambuLogin $acct $pw
      if (-not $tok) { throw 'the login did not return a token' }
      [IO.File]::WriteAllText($TokenFile, $tok)
      Write-Host '  logged in, token saved.'
      Write-Host ''
      return ($script:MwToken = $tok)
    } catch { Write-Warning "Login failed: $($_.Exception.Message)" }
    finally { $pw = $null }
  }
  throw 'MakerWorld login failed 3 times.'
}
# Calls a logged-in MakerWorld API; logs in again once if the saved token was rejected.
function Invoke-MwApi([string]$path) {
  for ($try = 0; $try -lt 2; $try++) {
    $tok = Get-MakerWorldToken -Renew:($try -gt 0)
    if (-not $tok) { throw 'not logged in to MakerWorld' }
    try {
      return Invoke-RestMethod -Uri "https://makerworld.com$path" -Headers @{ Authorization = "Bearer $tok"; Cookie = "token=$tok" } -UserAgent $UA -TimeoutSec 60
    } catch {
      $status = 0; if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
      $msg = if ($_.ErrorDetails.Message) { $_.ErrorDetails.Message } else { $_.Exception.Message }
      if ($try -eq 0 -and ($status -eq 401 -or ($status -eq 403 -and $msg -match 'log ?in'))) {
        Write-Host '  the saved MakerWorld token was rejected (expired?) - please log in again'
        continue
      }
      throw "MakerWorld: $msg"
    }
  }
}
function Get-MwLink($r) {
  foreach ($c in @($r, $r.data)) { if ($c -and $c.url) { return @{ Url = $c.url; Name = $c.name } } }
  throw "MakerWorld didn't return a download link: $($r | ConvertTo-Json -Compress -Depth 4)"
}

# ---------------------------------------------------------------- saved model page + instructions
# Both sites build their pages with JavaScript (and block automated browsers), so a "saved page"
# is rebuilt from the same data the site shows: one self-contained HTML file with every image
# embedded, so it works offline. Attachments (PDF manuals, assembly guides, BOMs...) go in
# <model folder>\Instructions\. Mirrors the same section of add_model.py.
$PageName = 'model-page.html'
$InstrDir = 'Instructions'
$Mime = @{ '.jpg' = 'image/jpeg'; '.jpeg' = 'image/jpeg'; '.png' = 'image/png'; '.gif' = 'image/gif'; '.webp' = 'image/webp'; '.svg' = 'image/svg+xml'; '.bmp' = 'image/bmp' }
$PageCss = @'
:root { --bg:#ffffff; --fg:#1f2328; --muted:#59636e; --line:#d1d9e0; --card:#f6f8fa; --link:#0969da; }
@media (prefers-color-scheme: dark) { :root { --bg:#0d1117; --fg:#e6edf3; --muted:#9198a1; --line:#3d444d; --card:#151b23; --link:#4493f8; } }
* { box-sizing: border-box; }
body { margin:0; background:var(--bg); color:var(--fg); font:16px/1.55 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif; }
main { max-width:960px; margin:0 auto; padding:24px 16px 64px; }
a { color:var(--link); }
h1 { font-size:1.9rem; line-height:1.25; margin:0 0 8px; }
h2 { font-size:1.3rem; margin:40px 0 12px; padding-bottom:6px; border-bottom:1px solid var(--line); }
.meta, .saved, .muted { color:var(--muted); }
.saved { font-size:.85rem; }
.gallery { display:grid; grid-template-columns:repeat(auto-fill,minmax(220px,1fr)); gap:10px; margin-top:20px; }
.gallery img { width:100%; aspect-ratio:4/3; object-fit:cover; border-radius:8px; background:var(--card); cursor:zoom-in; }
.gallery img.big { grid-column:1/-1; aspect-ratio:auto; object-fit:contain; cursor:zoom-out; }
article img, .guide img { max-width:100%; height:auto; border-radius:6px; }
.profiles { display:grid; grid-template-columns:repeat(auto-fill,minmax(260px,1fr)); gap:12px; }
.profile { background:var(--card); border:1px solid var(--line); border-radius:8px; padding:12px; }
.profile img { width:100%; aspect-ratio:4/3; object-fit:cover; border-radius:6px; }
.profile b { display:block; margin-top:6px; }
.tags span { display:inline-block; background:var(--card); border:1px solid var(--line); border-radius:999px; padding:1px 10px; margin:2px; font-size:.85rem; }
.comment { border-top:1px solid var(--line); padding:12px 0 4px; }
.comment .who { font-weight:600; }
.comment .when, .comment .likes { color:var(--muted); font-size:.85rem; margin-left:8px; }
.comment .stars { color:#bf8700; margin-left:8px; }
.comment p { margin:6px 0; white-space:pre-wrap; overflow-wrap:anywhere; }
.comment .pics img { height:140px; max-width:100%; object-fit:cover; border-radius:6px; margin:4px 6px 0 0; }
.replies { margin-left:20px; padding-left:14px; border-left:3px solid var(--line); }
.replies .comment:first-child { border-top:0; }
@media print { :root { --bg:#fff; --fg:#000; --card:#f6f8fa; --line:#d1d9e0; --muted:#59636e; --link:#0969da; }
  .gallery img, .profile, .guide img, .comment .pics { break-inside:avoid; } h2 { break-after:avoid; } }
'@
$PageJs = "document.querySelectorAll('.gallery img').forEach(function(i){i.onclick=function(){i.classList.toggle('big')}})"
$script:ImgCache = @{}

function HtmlEnc([string]$s) { [System.Net.WebUtility]::HtmlEncode($s) }   # (not "H": that's the Get-History alias)
function DataUri([byte[]]$data, [string]$nameOrUrl, [string]$ctype) {
  if (-not $ctype -or -not $ctype.StartsWith('image/')) {
    $ext = if (($nameOrUrl -replace '[?#].*$', '') -match '(\.[A-Za-z0-9]+)$') { $Matches[1].ToLowerInvariant() } else { '' }
    $ctype = if ($Mime[$ext]) { $Mime[$ext] } else { 'image/jpeg' }
  }
  "data:$ctype;base64,$([Convert]::ToBase64String($data))"
}
function MwResize([string]$u, [int]$w) { if ($u -match '\?' -or $u -notmatch 'bblmw\.com') { $u } else { "${u}?x-oss-process=image/resize,w_${w}/format,webp" } }
# Downloads an image once and returns it as a data: URI ($null if the download fails).
function Embed([string]$url, [int]$mwWidth = 0) {
  if (-not $url) { return $null }
  $key = "$mwWidth|$url"
  if (-not $script:ImgCache.ContainsKey($key)) {
    $fetch = if ($mwWidth) { MwResize $url $mwWidth } else { $url }
    try {
      $wc = New-Object System.Net.WebClient
      $wc.Headers['User-Agent'] = $UA
      $bytes = $wc.DownloadData($fetch)
      $ct = "$($wc.ResponseHeaders['Content-Type'])" -replace ';.*$', ''
      $script:ImgCache[$key] = DataUri $bytes $url $ct.Trim()
    } catch { Write-Warning "  image ${url}: $($_.Exception.Message)"; $script:ImgCache[$key] = $null }
  }
  $script:ImgCache[$key]
}
# Site description HTML -> offline HTML: no scripts, iframes become links, images embedded.
function Clean-Html([string]$h, [int]$mwWidth = 0) {
  if (-not $h) { return '' }
  $h = [regex]::Replace($h, '(?is)<script\b.*?</script>', '')
  $h = [regex]::Replace($h, '(?is)<iframe\b[^>]*?\bsrc="([^"]*)"[^>]*>.*?</iframe>', { param($m) "<p><a href=`"$($m.Groups[1].Value)`">$($m.Groups[1].Value)</a></p>" })
  $h = [regex]::Replace($h, '(?i)\s(?:on\w+|srcset|loading)="[^"]*"', '')
  [regex]::Replace($h, '(?i)(<img\b[^>]*?\bsrc=")([^"]+)(")', {
    param($m)
    $u = Embed ([System.Net.WebUtility]::HtmlDecode($m.Groups[2].Value)) $mwWidth
    $m.Groups[1].Value + $(if ($u) { $u } else { $m.Groups[2].Value }) + $m.Groups[3].Value
  })
}
# $items: @{ Name; Url } -> saved in <target>\Instructions\. Returns @{ Name; Rel } for each saved file.
function Save-Attachments($items, [string]$target) {
  $used = @{}
  foreach ($it in @($items)) {
    if (-not $it.Url) { continue }
    $fn = SafeName $(if ($it.Name) { $it.Name } else { [Uri]::UnescapeDataString(([Uri]$it.Url).Segments[-1]) })
    if (-not $fn) { $fn = 'attachment' }
    $base = $fn; $n = 2
    while ($used.ContainsKey($fn.ToLowerInvariant())) { $fn = "$([IO.Path]::GetFileNameWithoutExtension($base)) ($n)$([IO.Path]::GetExtension($base))"; $n++ }
    try {
      $sub = Join-Path $target $InstrDir
      [void][IO.Directory]::CreateDirectory((LongPath $sub))
      Save-Url $it.Url (LongPath (Join-Path $sub $fn))
      $used[$fn.ToLowerInvariant()] = $true
      @{ Name = $fn; Rel = "$InstrDir/$fn" }
    } catch { Write-Warning "  attachment ${fn}: $($_.Exception.Message)" }
  }
}
# $p: Title Author AuthorUrl Site Url License Published Tags Summary Description Images
#     Profiles(@{Title;Details;Cover}) Guide(@{Name;Uri}) Attachments(@{Name;Rel})
function Write-Page([string]$target, [hashtable]$p) {
  # drop $null entries: in PowerShell @($null).Count is 1, which would render empty sections
  foreach ($k in 'Tags', 'Attachments', 'Guide', 'Profiles', 'Images') { $p[$k] = @($p[$k] | Where-Object { $_ }) }
  $o = New-Object System.Collections.Generic.List[string]
  foreach ($l in '<!doctype html>', '<html lang="en">', '<head>', '<meta charset="utf-8">', '<meta name="viewport" content="width=device-width, initial-scale=1">') { $o.Add($l) }
  $o.Add("<title>$(HtmlEnc $p.Title)</title>"); $o.Add("<style>$PageCss</style>"); $o.Add('</head>'); $o.Add('<body>'); $o.Add('<main>')
  $o.Add("<h1>$(HtmlEnc $p.Title)</h1>")
  $meta = @()
  if ($p.Author) { $meta += 'by ' + $(if ($p.AuthorUrl) { "<a href=`"$(HtmlEnc $p.AuthorUrl)`">$(HtmlEnc $p.Author)</a>" } else { HtmlEnc $p.Author }) }
  $meta += "<a href=`"$(HtmlEnc $p.Url)`">$(HtmlEnc $p.Site)</a>"
  if ($p.License) { $meta += HtmlEnc $p.License }
  if ($p.Published) { $meta += "published $(HtmlEnc $p.Published)" }
  $o.Add("<p class=`"meta`">$($meta -join ' &middot; ')</p>")
  $o.Add("<p class=`"saved`">Saved $((Get-Date).ToString('yyyy-MM-dd')) from <a href=`"$(HtmlEnc $p.Url)`">$(HtmlEnc $p.Url)</a></p>")
  $imgs = @($p.Images | Where-Object { $_ })
  if ($imgs.Count) { $o.Add('<section class="gallery">' + (($imgs | ForEach-Object { "<img src=`"$_`" alt=`"`">" }) -join '') + '</section>') }
  if ($p.Summary) { $o.Add("<p>$(HtmlEnc $p.Summary)</p>") }
  if (@($p.Tags).Count) { $o.Add('<p class="tags">' + ((@($p.Tags) | ForEach-Object { "<span>$(HtmlEnc $_)</span>" }) -join '') + '</p>') }
  if (@($p.Attachments).Count) {
    $o.Add('<h2>Instructions &amp; attachments</h2><ul>')
    foreach ($a in $p.Attachments) { $o.Add("<li><a href=`"$(HtmlEnc ((($a.Rel -split '/') | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/'))`">$(HtmlEnc $a.Name)</a></li>") }
    $o.Add('</ul>')
  }
  if ($p.Description) { $o.Add('<h2>Description</h2>'); $o.Add('<article>'); $o.Add($p.Description); $o.Add('</article>') }
  if (@($p.Guide).Count) {
    $o.Add('<h2>Assembly guide</h2><div class="guide">')
    foreach ($g in $p.Guide) { $o.Add("<p><img src=`"$($g.Uri)`" alt=`"$(HtmlEnc $g.Name)`"></p>") }
    $o.Add('</div>')
  }
  if (@($p.Profiles).Count) {
    $o.Add("<h2>Print profiles ($(@($p.Profiles).Count))</h2><div class=`"profiles`">")
    foreach ($pr in $p.Profiles) {
      $img = if ($pr.Cover) { "<img src=`"$($pr.Cover)`" alt=`"`">" } else { '' }
      $o.Add("<div class=`"profile`">$img<b>$(HtmlEnc $pr.Title)</b><span class=`"muted`">$(HtmlEnc $pr.Details)</span></div>")
    }
    $o.Add('</div>')
  }
  $comments = @($p.Comments | Where-Object { $_ })
  $total = 0
  if ($comments.Count) {
    foreach ($c in $comments) { $total += 1 + @($c.Replies | Where-Object { $_ }).Count }
    $o.Add("<h2>Comments ($total)</h2><section class=`"comments`">")
    if ($comments.Count -ge $MaxComments) {
      $o.Add("<p class=`"muted`">The top $MaxComments comments, with their replies. The rest are on <a href=`"$(HtmlEnc $p.Url)`">$(HtmlEnc $p.Site)</a>.</p>")
    }
    foreach ($c in $comments) { $o.Add((CommentHtml $c)) }
    $o.Add('</section>')
  }
  $o.Add('</main>'); $o.Add("<script>$PageJs</script>"); $o.Add('</body>'); $o.Add('</html>'); $o.Add('')
  $path = Join-Path $target $PageName
  [IO.File]::WriteAllText((LongPath $path), ($o -join "`n"), (New-Object System.Text.UTF8Encoding $false))
  Write-Host ("  saved page: {0} ({1:N1} MB{2})" -f $PageName, ((Get-Item -LiteralPath (LongPath $path)).Length / 1e6), $(if ($comments.Count) { ", $total comments" }))
  if (-not $NoPdf) { Html-ToPdf $path (Join-Path $target $PdfName) }
}
# $c: Author Date Text Likes Stars Images(data uris) Replies(@($c...))
function CommentHtml($c) {
  $head = "<span class=`"who`">$(HtmlEnc $(if ($c.Author) { $c.Author } else { '?' }))</span>"
  if ($c.Stars) { $head += '<span class="stars">' + ('&#9733;' * [int]$c.Stars) + ('&#9734;' * (5 - [int]$c.Stars)) + '</span>' }
  if ($c.Date) { $head += "<span class=`"when`">$(HtmlEnc $c.Date)</span>" }
  if ($c.Likes) { $head += "<span class=`"likes`">&#9829; $($c.Likes)</span>" }
  $body = if ($c.Text) { "<p>$(HtmlEnc $c.Text)</p>" } else { '' }
  $pics = @($c.Images | Where-Object { $_ })
  if ($pics.Count) { $body += '<div class="pics">' + (($pics | ForEach-Object { "<img src=`"$_`" alt=`"`">" }) -join '') + '</div>' }
  $reps = @($c.Replies | Where-Object { $_ })
  $r = if ($reps.Count) { '<div class="replies">' + (($reps | ForEach-Object { CommentHtml $_ }) -join '') + '</div>' } else { '' }
  "<div class=`"comment`">$head$body$r</div>"
}

# ---------------------------------------------------------------- PDF copy of the saved page
# Printed by Edge (always on Windows) or Chrome in headless mode.
$PdfName = 'model-page.pdf'
# PDF can't hold WebP, so the browser would store every photo losslessly (several times bigger).
# The copy that gets printed first redraws each image as a JPEG, which goes into the PDF as is.
# Synchronous on purpose: Chromium loads data: images immediately, so this finishes before printing starts.
$PrintJs = "<script>(function(){var c=document.createElement('canvas'),x=c.getContext('2d');" +
           "Array.prototype.forEach.call(document.images,function(i){try{var w=i.naturalWidth,h=i.naturalHeight;" +
           "if(!w||/^data:image\/jpeg/.test(i.src))return;c.width=w;c.height=h;x.fillStyle='#fff';" +
           "x.fillRect(0,0,w,h);x.drawImage(i,0,0);i.src=c.toDataURL('image/jpeg',0.85);}catch(e){}});})();</script>"
$script:PdfBrowser = $null; $script:PdfChecked = $false
function Get-PdfBrowser {
  if (-not $script:PdfChecked) {
    $script:PdfChecked = $true
    $script:PdfBrowser = @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
                           "$env:ProgramFiles\Google\Chrome\Application\chrome.exe", "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe") |
                         Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
    if (-not $script:PdfBrowser) { Write-Warning "No Edge or Chrome found, so no PDF is made ($PdfName)." }
  }
  $script:PdfBrowser
}
function Html-ToPdf([string]$page, [string]$out) {
  $exe = Get-PdfBrowser
  if (-not $exe) { return }
  $src = Join-Path (Split-Path $page) ".print-$(Split-Path $page -Leaf)"
  $text = [IO.File]::ReadAllText((LongPath $page))
  $i = $text.IndexOf('</body>')
  [IO.File]::WriteAllText((LongPath $src), $text.Insert($i, $PrintJs), (New-Object System.Text.UTF8Encoding $false))
  try {
    if (Test-Path -LiteralPath (LongPath $out)) { Remove-Item -LiteralPath (LongPath $out) }
    $url = ([Uri]$src).AbsoluteUri
    $argList = @('--headless', '--disable-gpu', '--no-pdf-header-footer', '--no-first-run', '--virtual-time-budget=120000', "`"--print-to-pdf=$out`"", "`"$url`"")
    $proc = Start-Process -FilePath $exe -ArgumentList $argList -Wait -PassThru -WindowStyle Hidden
    if (Test-Path -LiteralPath (LongPath $out)) { Write-Host ("  saved PDF: {0} ({1:N1} MB)" -f $PdfName, ((Get-Item -LiteralPath (LongPath $out)).Length / 1e6)) }
    else { Write-Warning "  PDF: the browser did not write $PdfName (exit code $($proc.ExitCode))" }
  } catch { Write-Warning "  PDF: $($_.Exception.Message)" }
  finally { Remove-Item -LiteralPath (LongPath $src) -ErrorAction SilentlyContinue }
}

# ---------------------------------------------------------------- user comments
# Only the top comments are kept (top-level ones; each keeps all its replies): MakerWorld's own
# "Top" order (comments and ratings), Printables' most-liked first.
$MaxComments = 50
function Printables-Comments([string]$id) {
  $f = 'id text created likesCount author { publicUsername } images { filePath }'
  $out = New-Object System.Collections.Generic.List[object]; $seen = @{}; $offset = 0
  $conv = {
    param($c)
    @{ Author = $c.author.publicUsername; Date = "$($c.created)".Substring(0, [Math]::Min(10, "$($c.created)".Length)); Text = "$($c.text)".Trim()
       Likes = $c.likesCount; Images = @(@($c.images) | Where-Object { $_ } | ForEach-Object { Embed (Printables-Thumb $_.filePath '320x240') }) }
  }
  while ($out.Count -lt $MaxComments) {
    $batch = @((Gql "query { comments(targetObjectId: `"$id`", targetType: print, limit: $MaxComments, offset: $offset, ordering: { orderBy: likes_count, sortOrder: descending }) { $f replies { $f replies { $f } } } }").comments | Where-Object { $_ })
    $new = @($batch | Where-Object { -not $seen.ContainsKey("$($_.id)") } | Select-Object -First ($MaxComments - $out.Count))
    if (-not $new.Count) { break }
    foreach ($c in $new) {
      $seen["$($c.id)"] = $true
      $item = & $conv $c
      # flatten deeper reply levels into one list under the comment
      $item.Replies = @(foreach ($r in @($c.replies)) { if ($r) { & $conv $r; foreach ($r2 in @($r.replies)) { if ($r2) { & $conv $r2 } } } })
      $out.Add($item)
    }
    $offset += $batch.Count
  }
  , $out.ToArray()
}
function MakerWorld-Comments([string]$id) {
  $base = 'https://makerworld.com/api/v1/comment-service/'
  $conv = {
    param($c, $who)
    $at = $c.atUser.name
    @{ Author = $who.name; Date = "$($c.createTime)".Substring(0, [Math]::Min(10, "$($c.createTime)".Length))
       Text = $(if ($at) { "@$at " } else { '' }) + "$($c.content)".Trim(); Likes = $c.likeCount
       Images = @(@($c.images) | Where-Object { $_ } | ForEach-Object { Embed $(if ($_ -is [string]) { $_ } else { $_.url }) 320 }) }
  }
  $out = New-Object System.Collections.Generic.List[object]; $offset = 0
  while ($out.Count -lt $MaxComments) {
    $r = Invoke-RestMethod -Uri "${base}commentandrating?designId=$id&limit=20&offset=$offset&msgId=0&msgType=0" -UserAgent $UA -TimeoutSec 60
    $hits = @($r.hits | Where-Object { $_ })
    if (-not $hits.Count) { break }
    foreach ($h in @($hits | Select-Object -First ($MaxComments - $out.Count))) {
      if ($h.comment) {
        $c = $h.comment
        $item = & $conv $c $c.user
        $replies = @($c.commentReply | Where-Object { $_ })
        if ([int]$c.replyCount -gt $replies.Count) {   # only the first few replies come with the comment
          $replies = @(); $after = 0
          while ($true) {
            $rr = @((Invoke-RestMethod -Uri "${base}comment/$($c.id)/reply?limit=20&after=$after&msgCommentReplyId=0" -UserAgent $UA -TimeoutSec 60).replies | Where-Object { $_ })
            $replies += $rr
            if ($rr.Count -lt 20) { break }
            $after = $rr[-1].id
          }
        }
        $item.Replies = @($replies | ForEach-Object { & $conv $_ $_.user })
        $out.Add($item)
      } elseif ($h.ratingItem) {
        $ri = $h.ratingItem
        $item = & $conv $ri $ri.creator
        $item.Stars = $ri.score
        $out.Add($item)
      }
    }
    $offset += $hits.Count
    if ($offset -ge [int]$r.total) { break }
  }
  , $out.ToArray()
}

# Instructions\ (guide, BOM and other attachments) + the saved page for a MakerWorld design.
function MakerWorld-Extras($d, [string]$target) {
  $x = $d.designExtension
  $files = foreach ($k in 'design_guide', 'design_bom', 'design_other') { foreach ($f in @($x.$k)) { if ($f -and $f.url) { @{ Name = $f.name; Url = $f.url } } } }
  $att = @(Save-Attachments $files $target)
  if ($NoPage) { return }
  try {
    $guide = foreach ($a in $att) {   # guide images are shown on the page too
      if ($Mime[[IO.Path]::GetExtension($a.Name).ToLowerInvariant()]) {
        @{ Name = $a.Name; Uri = (DataUri ([IO.File]::ReadAllBytes((LongPath (Join-Path $target ($a.Rel -replace '/', '\'))))) $a.Name $null) }
      }
    }
    $profiles = foreach ($i in @($d.instances)) {
      $bits = @()
      if ($i.prediction) { $bits += ('{0}h {1:00}m' -f [math]::Floor($i.prediction / 3600), [math]::Floor(($i.prediction % 3600) / 60)) }
      if ($i.weight) { $bits += "$($i.weight) g" }
      if ($i.materialCnt) { $bits += "$($i.materialCnt) colour$(if ($i.materialCnt -ne 1) { 's' })" }
      if ($i.needAms) { $bits += 'AMS' }
      @{ Title = $(if ($i.title) { $i.title } else { "Profile $($i.id)" }); Details = ($bits -join " $([char]0xB7) "); Cover = (Embed $i.cover 480) }
    }
    # the cover is usually also the first gallery photo (under another URL), so only use it as a fallback
    $pics = @(@($x.design_pictures) | Where-Object { $_.url } | ForEach-Object { $_.url } | Select-Object -Unique)
    if (-not $pics.Count -and $d.coverUrl) { $pics = @($d.coverUrl) }
    $comments = @()
    if (-not $NoComments) { try { $comments = MakerWorld-Comments $d.id } catch { Write-Warning "  comments: $($_.Exception.Message)" } }
    Write-Page $target @{
      Title = $d.title; Author = $d.designCreator.name
      AuthorUrl = $(if ($d.designCreator.handle) { "https://makerworld.com/en/@$($d.designCreator.handle)" })
      Site = 'MakerWorld'; Url = "https://makerworld.com/en/models/$($d.id)-$($d.slug)"; License = $d.license
      Published = "$($d.createTime)".Substring(0, [Math]::Min(10, "$($d.createTime)".Length)); Tags = @($d.tags)
      Images = @($pics | ForEach-Object { Embed $_ 1200 }); Description = (Clean-Html $d.summary 1200)
      Guide = @($guide); Profiles = @($profiles); Attachments = $att; Comments = $comments
    }
  } catch { Write-Warning "  saved page: $($_.Exception.Message)" }
}

function Printables-Thumb([string]$fp, [string]$size = '1280x960') {
  if ($fp -match '^(.*)/([^/]+)\.(\w+)$') { "https://media.printables.com/$($Matches[1])/thumbs/inside/$size/$($Matches[3])/$($Matches[2]).webp" }
}
# Instructions\ (the model's "other files": manuals, guides...) + the saved page for a Printables model.
$PrintablesFields = 'id name slug user { publicUsername handle } image { filePath } downloadPacks { id fileType } stls { id name } ' +
                    'summary description datePublished license { name } images { filePath } otherFiles { id name }'
$DownloadLink = 'mutation GetDownloadLink($id: ID!, $printId: ID!, $fileType: DownloadFileTypeEnum!, $source: DownloadSourceEnum!) { getDownloadLink(id: $id, printId: $printId, fileType: $fileType, source: $source) { ok errors { field messages } output { link } } }'
# A download link for one of model $script:PrintId's files ($type: pack, stl or other).
function Link($fileId, $type) {
  $r = (Gql $DownloadLink @{ id = "$fileId"; printId = "$script:PrintId"; fileType = $type; source = 'model_detail' }).getDownloadLink
  if (-not $r.ok) { throw "Printables refused the download: $(($r.errors | ForEach-Object { $_.messages }) -join ', ')" }
  $r.output.link
}
function Printables-Extras($p, [string]$target) {
  $script:PrintId = $p.id
  $files = foreach ($f in @($p.otherFiles)) {
    if (-not $f) { continue }
    try { @{ Name = $f.name; Url = (Link $f.id 'other') } } catch { Write-Warning "  attachment $($f.name): $($_.Exception.Message)" }
  }
  $att = @(Save-Attachments $files $target)
  if ($NoPage) { return }
  try {
    $comments = @()
    if (-not $NoComments) { try { $comments = Printables-Comments $p.id } catch { Write-Warning "  comments: $($_.Exception.Message)" } }
    Write-Page $target @{
      Title = $p.name; Author = $p.user.publicUsername
      AuthorUrl = $(if ($p.user.handle) { "https://www.printables.com/@$($p.user.handle)" })
      Site = 'Printables'; Url = "https://www.printables.com/model/$($p.id)-$($p.slug)"; License = $p.license.name
      Published = "$($p.datePublished)".Substring(0, [Math]::Min(10, "$($p.datePublished)".Length))
      Images = @(@($p.images) | ForEach-Object { Embed (Printables-Thumb $_.filePath) })
      Summary = $p.summary; Description = (Clean-Html $p.description); Attachments = $att; Comments = $comments
    }
  } catch { Write-Warning "  saved page: $($_.Exception.Message)" }
}

# ---------------------------------------------------------------- Cults3D (official API) and Thangs
# Cults3D's API needs your username and an API key (cults3d.com > your account > API). It gives
# the model's details, pictures and comments but not its files, so those you download in the
# browser (or pass with -File). Thangs has no public API: only the link is recorded and the
# file is picked up from your browser's downloads.
$CultsKeyFile = Join-Path $PSScriptRoot '.cults3d-key'
$CultsUrl = 'cults3d\.com/(?:[a-z]{2}/)?3d-model/(?:[^/?#]+/)?([^/?#]+)'
$CultsFields = 'slug name(locale: EN) url(locale: EN) description(locale: EN) details(locale: EN) tags(locale: EN) ' +
               'publishedAt license { name } price(currency: USD) { cents } creator { nick url(locale: EN) } ' +
               'illustrationImageUrl illustrations { imageUrl(version: LARGE) } blueprints { fileName } ' +
               'comments { text publishedAt creator { nick } answers { text publishedAt creator { nick } } }'
$script:CultsAuth = $null; $script:CultsAsked = $false
# 'Basic ...' header value from $env:CULTS3D_KEY / scripts\.cults3d-key ("username:apikey"), or $null.
function Get-CultsAuth([switch]$NoPrompt) {
  if ($script:CultsAuth -or $script:CultsAsked) { return $script:CultsAuth }
  $key = "$env:CULTS3D_KEY".Trim()
  if (-not $key -and (Test-Path -LiteralPath $CultsKeyFile)) { $key = "$(@([IO.File]::ReadAllLines($CultsKeyFile))[0])".Trim() }
  if (-not $key -and -not $NoPrompt -and -not [Console]::IsInputRedirected) {   # ask once per run
    $script:CultsAsked = $true
    Write-Host ''
    Write-Host 'Cults3D API key - create one at cults3d.com (your account > API). Saved in'
    Write-Host 'scripts\.cults3d-key for next time. Press Enter to skip (the model is then recorded without details).'
    $user = "$(Read-Host '  Cults3D username')".Trim()
    if ($user) {
      $key = "${user}:$((Read-Plain '  API key' -Secret).Trim())"
      [IO.File]::WriteAllText($CultsKeyFile, "$key`n", (New-Object System.Text.UTF8Encoding $false))
    }
  }
  if ($key) { $script:CultsAuth = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($key)) }
  $script:CultsAuth
}
function Invoke-CultsGql([string]$query) {
  $auth = Get-CultsAuth
  if (-not $auth) { throw 'no Cults3D API key (scripts\.cults3d-key)' }
  try {
    $r = Invoke-RestMethod -Uri 'https://cults3d.com/graphql' -Method Post -Body (@{ query = $query } | ConvertTo-Json -Compress) `
         -ContentType 'application/json; charset=utf-8' -Headers @{ Authorization = $auth } -UserAgent $UA -TimeoutSec 60
  } catch {
    $code = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
    throw "Cults3D API: $(if ($code) { $code } else { $_.Exception.Message })$(if ($code -eq 401) { ' (check the username:key in scripts\.cults3d-key)' })"
  }
  if ($r.errors) { throw "Cults3D API: $($r.errors[0].message)" }
  $r.data
}
function Get-CultsCreation([string]$slug) {
  $c = (Invoke-CultsGql "{ creation(slug: $(ConvertTo-Json $slug)) { $CultsFields } }").creation
  if (-not $c) { throw "Cults3D model $slug was not found" }
  $c
}
function CultsInfo($c) {
  # README cover: the first still picture (the main one is sometimes an animated GIF)
  $still = @(@($c.illustrations) | Where-Object { $_ -and $_.imageUrl -and $_.imageUrl -notmatch '\.gif$' } | ForEach-Object { $_.imageUrl }) | Select-Object -First 1
  @{ source = 'cults3d'; id = $c.slug; name = $c.name; author = $c.creator.nick
     url = $(if ($c.url) { $c.url } else { "https://cults3d.com/:$($c.slug)" })
     imageUrl = $(if ($still) { $still } else { $c.illustrationImageUrl }); manual = $true }
}
function CultsHits([string]$query, [int]$limit = 5) {
  if (-not (Get-CultsAuth -NoPrompt)) { return @() }
  @((Invoke-CultsGql "{ creationsSearchBatch(query: $(ConvertTo-Json $query), limit: $limit) { results { slug name(locale: EN) url(locale: EN) creator { nick } illustrationImageUrl } } }").creationsSearchBatch.results | Where-Object { $_ })
}
# Saved page for a Cults3D model (the API has no attachments or file links).
function Cults-Extras($c, [string]$target) {
  if ($NoPage) { return }
  try {
    $text = (@($c.description, $c.details) | Where-Object { "$_".Trim() } | ForEach-Object { "<p style=`"white-space:pre-wrap`">$(HtmlEnc "$_".Trim())</p>" }) -join ''
    $files = @(@($c.blueprints) | Where-Object { $_ -and $_.fileName } | ForEach-Object { $_.fileName })
    if ($files.Count) { $text += '<h3>Files on Cults3D</h3><ul>' + (($files | ForEach-Object { "<li>$(HtmlEnc $_)</li>" }) -join '') + '</ul>' }
    $cents = [int]$c.price.cents
    $comments = @()
    if (-not $NoComments) {
      $conv = { param($x) @{ Author = $x.creator.nick; Date = "$($x.publishedAt)".Substring(0, [Math]::Min(10, "$($x.publishedAt)".Length)); Text = "$($x.text)".Trim() } }
      $comments = @(@($c.comments) | Where-Object { $_ } | Select-Object -First $MaxComments | ForEach-Object {
        $item = & $conv $_
        $item.Replies = @(@($_.answers) | Where-Object { $_ } | ForEach-Object { & $conv $_ })
        $item
      })
    }
    $imgs = @(@($c.illustrations) | Where-Object { $_ } | ForEach-Object { Embed $_.imageUrl })
    if (-not $imgs.Count) { $imgs = @(Embed $c.illustrationImageUrl) }
    Write-Page $target @{
      Title = $c.name; Author = $c.creator.nick; AuthorUrl = $c.creator.url
      Site = 'Cults3D'; Url = $c.url; License = $c.license.name
      Published = "$($c.publishedAt)".Substring(0, [Math]::Min(10, "$($c.publishedAt)".Length)); Tags = @($c.tags)
      Summary = $(if ($cents) { 'Paid model ($' + ('{0:N2}' -f ($cents / 100.0)) + ')' })
      Images = $imgs; Description = $text; Comments = $comments
    }
  } catch { Write-Warning "  saved page: $($_.Exception.Message)" }
}
# The file from -File, or the one you download in the browser (picked up from Downloads).
function Get-BrowserDownload([string]$pageUrl, [string]$site) {
  if ($File) { return (Resolve-Path -LiteralPath $File).Path }
  $since = Get-Date
  Write-Host "  $site files can only be downloaded in your browser. Opening the model page -"
  Write-Host '  download the files (zip or single file) and the script will pick them up.'
  Start-Process $pageUrl
  Wait-ForDownload (Get-DownloadsFolder) $since
}
function Expand-Download([string]$src, [string]$target) {
  [void][IO.Directory]::CreateDirectory((LongPath $target))
  if ([IO.Path]::GetExtension($src) -eq '.zip') {
    $n = Expand-ModelZip $src $target
    Remove-Item -LiteralPath $src
    Write-Host "  extracted $n files"
  } else {
    Move-Item -LiteralPath $src -Destination (LongPath (Join-Path $target (SafeName ([IO.Path]::GetFileName($src) -replace '\s*\(\d+\)(?=\.\w+$)', '')))) -Force
  }
}
function Add-Cults([string]$slug, [string]$pageUrl) {
  $c = $null
  try { $c = Get-CultsCreation $slug } catch { Write-Warning "  $($_.Exception.Message) - recording the link without details." }
  $info = if ($c) { CultsInfo $c } else { @{ source = 'cults3d'; id = $slug; name = (Pretty $slug); url = ($pageUrl -replace '\?.*$', ''); manual = $true } }
  Write-Host "Cults3D: $($info.name) by $(if ($info.author) { $info.author } else { '?' })"
  $target = Join-Path $destRoot $(if ($Name) { SafeName $Name } else { SafeName $slug })
  if ((Test-Path -LiteralPath $target) -and -not $Force) { throw "'$target' already exists. Use -Force to download into it anyway." }
  Expand-Download (Get-BrowserDownload $info.url 'Cults3D') $target
  if ($c) { Cults-Extras $c $target }
  @{ Info = $info; Folder = $target }
}
# @{ Id; Name; Designer } from a Thangs model URL, or $null.
function Parse-Thangs([string]$u) {
  if ($u -match 'thangs\.com/designer/([^/]+)/3d-model/([^/?#]+)') {
    $designer = [Uri]::UnescapeDataString($Matches[1]); $slug = [Uri]::UnescapeDataString($Matches[2])
    $id = if ($slug -match '-(\d+)$') { $Matches[1] } else { $slug }
    return @{ Id = $id; Name = (Pretty (($slug -replace '-\d+$', '') -replace '-', ' ')); Designer = $designer }
  }
  if ($u -match 'thangs\.com/(?:m|model)/(\d+)') { return @{ Id = $Matches[1]; Name = "Thangs model $($Matches[1])"; Designer = $null } }
  $null
}
function Add-Thangs([string]$u) {
  $t = Parse-Thangs $u
  $info = @{ source = 'thangs'; id = $t.Id; name = $t.Name; author = $t.Designer; url = ($u -replace '\?.*$', ''); manual = $true }
  Write-Host "Thangs: $($t.Name)$(if ($t.Designer) { " by $($t.Designer)" }) (Thangs has no API, so no saved page)"
  $src = Get-BrowserDownload $info.url 'Thangs'
  $folder = if ($Name) { SafeName $Name } elseif ([IO.Path]::GetExtension($src) -eq '.zip') { SafeName ([IO.Path]::GetFileNameWithoutExtension($src) -replace '\s*\(\d+\)$', '') } else { SafeName $t.Name }
  $target = Join-Path $destRoot $folder
  if ((Test-Path -LiteralPath $target) -and -not $Force) { throw "'$target' already exists. Use -Force to download into it anyway (the downloaded file was left at $src)." }
  Expand-Download $src $target
  @{ Info = $info; Folder = $target }
}

# ---------------------------------------------------------------- per-site handlers
# Each returns @{ Info = <cache entry>; Folder = <full path of the model folder> }
function Add-Printables([string]$id, [string]$tmp) {
  $p = (Gql "query { print(id: `"$id`") { $PrintablesFields } }").print
  if (-not $p) { throw "Printables model $id was not found (removed or private?)." }
  $script:PrintId = $id
  $img = $null
  if ($p.image -and $p.image.filePath -match '^(.*)/([^/]+)\.(\w+)$') { $img = "https://media.printables.com/$($Matches[1])/thumbs/inside/640x480/$($Matches[3])/$($Matches[2]).webp" }
  $info = @{ source = 'printables'; id = "$($p.id)"; name = $p.name; author = $p.user.publicUsername
             url = "https://www.printables.com/model/$($p.id)-$($p.slug)"; imageUrl = $img; manual = $true }
  Write-Host "Printables: $($p.name) by $($p.user.publicUsername)"

  $target = Join-Path $destRoot $(if ($Name) { SafeName $Name } else { "$($p.slug)-model_files" })
  if ((Test-Path -LiteralPath $target) -and -not $Force) { throw "'$target' already exists. Use -Force to download into it anyway." }
  [void][IO.Directory]::CreateDirectory((LongPath $target))

  $types = if ($AllFiles) { @('MODEL_FILES', 'PRINT_FILES', 'OTHER_FILES') } else { @('MODEL_FILES') }
  $packs = @(foreach ($t in $types) { $p.downloadPacks | Where-Object { $_.fileType -eq $t } })
  if ($packs.Count) {
    foreach ($pack in $packs) {
      $link = Link $pack.id 'pack'
      $zip = Join-Path $tmp ([Uri]::UnescapeDataString(([Uri]$link).Segments[-1]))
      Save-Url $link $zip
      $n = Expand-ModelZip $zip $target
      Remove-Item -LiteralPath $zip
      Write-Host "  extracted $n files"
    }
  } elseif (@($p.stls).Count) {   # no packs: fetch the model files one by one
    foreach ($s in $p.stls) { Save-Url (Link $s.id 'stl') (LongPath (Join-Path $target (SafeName $s.name))) }
  } else { throw "Printables model $id has no downloadable files." }
  Printables-Extras $p $target
  @{ Info = $info; Folder = $target }
}

function Add-MakerWorld([string]$id, [string]$tmp, [string]$pageUrl) {
  $d = Invoke-RestMethod -Uri "https://makerworld.com/api/v1/design-service/design/$id" -UserAgent $UA -TimeoutSec 60
  if (-not $d.title) { throw "MakerWorld model $id was not found." }
  $info = @{ source = 'makerworld'; id = "$id"; name = $d.title; author = $d.designCreator.name
             url = "https://makerworld.com/en/models/$id-$($d.slug)"
             imageUrl = $(if ($d.coverUrl) { "$($d.coverUrl)?x-oss-process=image/resize,w_640/format,webp" }); manual = $true }
  Write-Host "MakerWorld: $($d.title) by $($d.designCreator.name)"

  $src = $null
  if ($File) {
    $src = (Resolve-Path -LiteralPath $File).Path
  } elseif (Get-MakerWorldToken) {
    # Logged in: <Model+Name>\STL-CAD\ (the model files, when the designer uploaded them)
    # and <Model+Name>\3MF\<profile name>.3mf for every print profile.
    $target = Join-Path $destRoot $(if ($Name) { SafeName $Name } else { SafeName ($d.title -replace '\s+', '+') })
    if ((Test-Path -LiteralPath $target) -and -not $Force) { throw "'$target' already exists. Use -Force to download into it anyway." }
    $got = 0; $problems = @()

    if (@($d.designExtension.model_files).Count) {
      try {
        $l = Get-MwLink (Invoke-MwApi "/api/v1/design-service/design/$id/model")
        $fname = if ($l.Name) { $l.Name } else { [Uri]::UnescapeDataString(([Uri]$l.Url).Segments[-1]) }
        $f = Join-Path $tmp (SafeName $fname)
        Save-Url $l.Url $f
        $sub = Join-Path $target 'STL-CAD'
        [void][IO.Directory]::CreateDirectory((LongPath $sub))
        if ([IO.Path]::GetExtension($f) -eq '.zip') { $n = Expand-ModelZip $f $sub; Remove-Item -LiteralPath $f; Write-Host "  STL-CAD: extracted $n files" }
        else { Move-Item -LiteralPath $f -Destination (LongPath (Join-Path $sub (SafeName $fname))) -Force }
        $got++
      } catch { $problems += "STL/CAD files: $($_.Exception.Message)" }
    } else { Write-Host '  this model has no STL/CAD files, only print profiles' }

    $used = @{}
    foreach ($inst in @($d.instances)) {
      $pname = if ($inst.title) { $inst.title } else { "Profile $($inst.id)" }
      try {
        $l = Get-MwLink (Invoke-MwApi "/api/v1/design-service/instance/$($inst.id)/f3mf?type=download")
        $fn = SafeName "$pname.3mf"
        if ($used.ContainsKey($fn.ToLowerInvariant())) { $fn = SafeName "$pname ($($inst.id)).3mf" }
        $sub = Join-Path $target '3MF'
        [void][IO.Directory]::CreateDirectory((LongPath $sub))
        Save-Url $l.Url (LongPath (Join-Path $sub $fn))
        $used[$fn.ToLowerInvariant()] = $true
        $got++
      } catch { $problems += "profile '$pname': $($_.Exception.Message)" }
    }
    foreach ($p in $problems) { Write-Warning "  $p" }
    if (-not $got) {
      if ((Test-Path -LiteralPath $target) -and -not @(Get-ChildItem -LiteralPath $target -Force).Count) { Remove-Item -LiteralPath $target }
      throw "nothing could be downloaded from MakerWorld model $id"
    }
    Write-Host "  downloaded $(@($used.Keys).Count) of $(@($d.instances).Count) print profiles"
    MakerWorld-Extras $d $target
    return @{ Info = $info; Folder = $target }
  } else {
    $dl = Get-DownloadsFolder
    $since = Get-Date
    Write-Host "  MakerWorld needs you to be logged in to download. Opening the model page -"
    Write-Host "  click Download > 'STL/CAD files' (or the 3MF) and the script will pick it up."
    Start-Process $pageUrl
    $src = Wait-ForDownload $dl $since
  }

  $base = [IO.Path]::GetFileNameWithoutExtension($src) -replace '\s*\(\d+\)$', ''
  $folderName = if ($Name) { SafeName $Name } elseif ([IO.Path]::GetExtension($src) -eq '.zip') { SafeName $base } else { SafeName ($d.title -replace '\s+', '+') }
  $target = Join-Path $destRoot $folderName
  if ((Test-Path -LiteralPath $target) -and -not $Force) { throw "'$target' already exists. Use -Force to download into it anyway (the downloaded file was left at $src)." }
  [void][IO.Directory]::CreateDirectory((LongPath $target))
  if ([IO.Path]::GetExtension($src) -eq '.zip') {
    $n = Expand-ModelZip $src $target
    Remove-Item -LiteralPath $src
    Write-Host "  extracted $n files"
  } else {
    Move-Item -LiteralPath $src -Destination (Join-Path $target (SafeName ([IO.Path]::GetFileName($src) -replace '\s*\(\d+\)(?=\.\w+$)', ''))) -Force
  }
  MakerWorld-Extras $d $target
  @{ Info = $info; Folder = $target }
}

# Saved page + Instructions\ for models already in readme-sources.json (no model files are downloaded).
function Fill-Pages([string[]]$scopes) {
  $cache = Read-Cache $CachePath
  $todo = @(); $skippedFiles = 0; $doneAlready = 0
  # a model is done when it has the last file this run would make (pages made before the PDF existed get redone)
  $marker = if ($NoPage) { $InstrDir } elseif (-not $NoPdf -and (Get-PdfBrowser)) { $PdfName } else { $PageName }
  foreach ($key in (OSort @($cache.Keys) { $_ })) {
    $info = $cache[$key]
    if ($info.source -notin 'printables', 'makerworld', 'cults3d' -or -not $info.id) { continue }
    $full = Join-Path $Repo ($key -replace '/', '\')
    if (-not @($scopes | Where-Object { $full -eq $_ -or $full.StartsWith("$_\", [StringComparison]::OrdinalIgnoreCase) }).Count) { continue }
    if (-not (Test-Path -LiteralPath (LongPath $full))) { continue }
    if (-not (Test-Path -LiteralPath (LongPath $full) -PathType Container)) { $skippedFiles++; continue }   # a lone .zip/.3mf: no folder for the page
    if ((Test-Path -LiteralPath (LongPath (Join-Path $full $marker))) -and -not $Force) { $doneAlready++; continue }
    $todo += , @($key, $info, $full)
  }
  $msg = "$($todo.Count) model folder(s) to fill in"
  if ($doneAlready) { $msg += ", $doneAlready already have $marker (-Force redoes them)" }
  if ($skippedFiles) { $msg += ", $skippedFiles single-file models skipped" }
  Write-Host "$msg."
  $failed = @(); $n = 0
  foreach ($t in $todo) {
    $key, $info, $full = $t; $n++
    Write-Host "[$n/$($todo.Count)] $key"
    try {
      if ($info.source -eq 'printables') {
        $p = (Gql "query { print(id: `"$($info.id)`") { $PrintablesFields } }").print
        if (-not $p) { throw "Printables model $($info.id) was not found (removed or private?)" }
        Printables-Extras $p $full
      } elseif ($info.source -eq 'cults3d') {
        Cults-Extras (Get-CultsCreation $info.id) $full
      } else {
        $d = Invoke-RestMethod -Uri "https://makerworld.com/api/v1/design-service/design/$($info.id)" -UserAgent $UA -TimeoutSec 60
        if (-not $d.title) { throw "MakerWorld model $($info.id) was not found" }
        MakerWorld-Extras $d $full
      }
    } catch {
      Write-Warning "  $($_.Exception.Message)"
      $failed += "$key - $($_.Exception.Message)"
    }
  }
  Write-Host "Filled in $($todo.Count - $failed.Count) of $($todo.Count) model folders."
  if ($failed.Count) { Write-Host 'Failed:'; $failed | ForEach-Object { Write-Host "  $_" } }
}

# ---------------------------------------------------------------- -Match: find the web page for models with no id
# Title / Designer / DesignModelId etc. from the first .3mf of a model (MakerWorld and Bambu Studio write these).
function Read-3mfMeta([string]$full) {
  $files = if (Test-Path -LiteralPath (LongPath $full) -PathType Leaf) { @($full) } else { @(OSort @(Get-ChildItem -LiteralPath (LongPath $full) -Recurse -File -Filter *.3mf | ForEach-Object { $_.FullName }) { $_ }) }
  foreach ($f in $files) {
    if ([IO.Path]::GetExtension($f) -ne '.3mf') { continue }
    try {
      $z = [IO.Compression.ZipFile]::OpenRead((LongPath $f))
      try {
        $e = $z.Entries | Where-Object { $_.FullName -eq '3D/3dmodel.model' } | Select-Object -First 1
        if (-not $e) { continue }
        $r = New-Object IO.StreamReader($e.Open())
        $buf = New-Object char[] 200000; $n = $r.Read($buf, 0, $buf.Length); $r.Dispose()
        $head = New-Object string($buf, 0, $n)
      } finally { $z.Dispose() }
      $md = @{}
      foreach ($m in [regex]::Matches($head, '<metadata name="([^"]+)">([^<]*)</metadata>')) {
        $md[$m.Groups[1].Value] = [System.Net.WebUtility]::HtmlDecode([System.Net.WebUtility]::HtmlDecode($m.Groups[2].Value)).Trim()
      }
      if ($md.Title -or $md.DesignModelId) { return $md }
    } catch { continue }
  }
  @{}
}
function MwInfo($h) {   # cache entry from a MakerWorld search hit or design
  $cover = if ($h.cover) { $h.cover } else { $h.coverUrl }
  @{ source = 'makerworld'; id = "$($h.id)"; name = $h.title; author = $h.designCreator.name
     url = "https://makerworld.com/en/models/$($h.id)-$($h.slug)"
     imageUrl = $(if ($cover) { "${cover}?x-oss-process=image/resize,w_640/format,webp" }); manual = $true }
}
function PrintablesInfo($p) {
  $img = $null
  if ($p.image -and $p.image.filePath -match '^(.*)/([^/]+)\.(\w+)$') { $img = "https://media.printables.com/$($Matches[1])/thumbs/inside/640x480/$($Matches[3])/$($Matches[2]).webp" }
  @{ source = 'printables'; id = "$($p.id)"; name = $p.name; author = $p.user.publicUsername
     url = "https://www.printables.com/model/$($p.id)-$($p.slug)"; imageUrl = $img; manual = $true }
}
function MwHits([string]$query) {
  Start-Sleep -Milliseconds 400
  @((Invoke-RestMethod -Uri "https://makerworld.com/api/v1/search-service/select/design2?keyword=$([Uri]::EscapeDataString($query))&limit=20" -UserAgent $UA -TimeoutSec 60).hits | Where-Object { $_ })
}
# Printables needs every word to match, so retry with the first few words when a long title finds nothing.
function PrintablesHits([string]$query) {
  $words = @(($query -replace '["\\]', ' ') -split '\s+' | Where-Object { $_ })
  foreach ($q in @(($words -join ' '), (@($words | Select-Object -First 3) -join ' ')) | Select-Object -Unique) {
    if (-not $q) { continue }
    $items = @((Gql "query { searchPrints2(query: `"$q`", limit: 5) { items { id name slug user { publicUsername } image { filePath } } } }").searchPrints2.items | Where-Object { $_ })
    if ($items.Count) { return $items }
  }
  @()
}
function Info-FromUrl([string]$u, [string]$key) {
  if ($u -match 'printables\.com/(?:[a-z]{2}/)?model/(\d+)') {
    $p = (Gql "query { print(id: `"$($Matches[1])`") { id name slug user { publicUsername } image { filePath } } }").print
    if (-not $p) { throw "Printables model $($Matches[1]) was not found" }
    return (PrintablesInfo $p)
  }
  if ($u -match 'makerworld\.com/(?:[a-z]{2}/)?models/(\d+)') {
    $d = Invoke-RestMethod -Uri "https://makerworld.com/api/v1/design-service/design/$($Matches[1])" -UserAgent $UA -TimeoutSec 60
    if (-not $d.title) { throw "MakerWorld model $($Matches[1]) was not found" }
    return (MwInfo $d)
  }
  if ($u -match 'thingiverse\.com/thing:(\d+)') {
    return @{ source = 'thingiverse'; id = $Matches[1]; name = (Pretty ([IO.Path]::GetFileNameWithoutExtension(($key -split '/')[-1])))
              url = "https://www.thingiverse.com/thing:$($Matches[1])"; manual = $true }
  }
  if ($u -match $CultsUrl) {
    $slug = $Matches[1]
    try { return (CultsInfo (Get-CultsCreation $slug)) }
    catch {
      Write-Host "  ($($_.Exception.Message) - saving the link only)"
      return @{ source = 'cults3d'; id = $slug; name = (Pretty $slug); url = ($u -replace '\?.*$', ''); manual = $true }
    }
  }
  $t = Parse-Thangs $u
  if ($t) { return @{ source = 'thangs'; id = $t.Id; name = $t.Name; author = $t.Designer; url = ($u -replace '\?.*$', ''); manual = $true } }
  throw 'not a Printables, MakerWorld, Thingiverse, Cults3D or Thangs model URL'
}

function Match-Models([string[]]$scopes) {
  $cache = Read-Cache $CachePath
  $todo = @(foreach ($key in (OSort @($cache.Keys) { $_ })) {
    $info = $cache[$key]
    if ($info.id -or $info.source -notin 'makerworld', 'printables', 'unknown') { continue }
    if ($info.noMatch -and -not $Force) { continue }
    $full = Join-Path $Repo ($key -replace '/', '\')
    if (@($scopes | Where-Object { $full -eq $_ -or $full.StartsWith("$_\", [StringComparison]::OrdinalIgnoreCase) }).Count -and (Test-Path -LiteralPath (LongPath $full))) { $key }
  })
  $interactive = -not [Console]::IsInputRedirected -and -not $AutoOnly
  Write-Host ("$($todo.Count) model(s) without a web page to match." + $(if (-not $interactive) { ' Only exact matches (from 3MF files) are saved in this mode.' }))
  if ($interactive) {
    Write-Host "For each one: type a number to pick it, paste the model URL, type other words to search again,"
    Write-Host "Enter to skip, x if it is not online (never asked again), or q to stop."
  }
  $matched = 0; $n = 0
  foreach ($key in $todo) {
    $n++
    $full = Join-Path $Repo ($key -replace '/', '\')
    $isFile = Test-Path -LiteralPath (LongPath $full) -PathType Leaf
    $md = Read-3mfMeta $full
    Write-Host ''
    Write-Host "[$n/$($todo.Count)] $key"
    try {
      $leaf = ($key -split '/')[-1]
      $query = if ($md.Title) { $md.Title } else { Pretty $(if ($isFile) { [IO.Path]::GetFileNameWithoutExtension($leaf) } else { $leaf }) }
      if ($md.Count) { Write-Host "  3MF says: `"$(if ($md.Title) { $md.Title } else { '?' })`"$(if ($md.Designer) { " by $($md.Designer)" })" }
      $mw = if ($query) { @(MwHits $query) } else { @() }
      $mid = $md.DesignModelId
      $exact = if ($mid) { $mw | Where-Object { $_.modelId -eq $mid -or "$($_.cover)".Contains("/model/$mid/") } | Select-Object -First 1 }
      if ($exact) {
        $info = MwInfo $exact
        $cache[$key] = $info; Save-Cache $cache $CachePath; $matched++
        Write-Host "  matched (exact, from the 3MF): $($info.name) by $($info.author)  $($info.url)"
        continue
      }
      if (-not $interactive) { Write-Host '  no exact match'; continue }
      $stop = $false
      while ($true) {
        $uid = $md.DesignerUserId
        $same = @(if ($uid) { $mw | Where-Object { "$($_.designCreator.uid)" -eq $uid } })
        $cands = @($same | Select-Object -First 5 | ForEach-Object { @{ Info = (MwInfo $_); Note = ' (same designer)' } })
        $cands += @($mw | Where-Object { $same -notcontains $_ } | Select-Object -First ([Math]::Max(0, 5 - $cands.Count)) | ForEach-Object { @{ Info = (MwInfo $_); Note = '' } })
        try { $cands += @(PrintablesHits $query | ForEach-Object { @{ Info = (PrintablesInfo $_); Note = '' } }) }
        catch { Write-Host "  (Printables search failed: $($_.Exception.Message))" }
        try { $cands += @(CultsHits $query 3 | ForEach-Object { @{ Info = (CultsInfo $_); Note = '' } }) }
        catch { Write-Host "  (Cults3D search failed: $($_.Exception.Message))" }
        if (-not $md.Count) {   # a Bambu 3MF almost always comes from MakerWorld; otherwise show Printables first
          $cands = @($cands | Where-Object { $_.Info.source -eq 'printables' }) + @($cands | Where-Object { $_.Info.source -eq 'makerworld' })
        }
        if (-not $cands.Count) { Write-Host "  no search results for `"$query`"" }
        for ($i = 0; $i -lt $cands.Count; $i++) {
          $c = $cands[$i].Info
          $site = @{ printables = 'Printables'; makerworld = 'MakerWorld'; cults3d = 'Cults3D'; thangs = 'Thangs' }[$c.source]
          Write-Host "  $($i + 1)) $($c.name) - by $(if ($c.author) { $c.author } else { '?' }) [$site]$($cands[$i].Note)"
          Write-Host "     $($c.url)"
        }
        $a = "$(Read-Host '  >')".Trim()
        if (-not $a) { break }
        if ($a -eq 'q') { $stop = $true; break }
        if ($a -eq 'x') {
          $cache[$key] = @{ source = 'unknown'; manual = $true; noMatch = $true }; Save-Cache $cache $CachePath
          Write-Host '  marked as not online'; break
        }
        if ($a -match '^\d+$' -and [int]$a -ge 1 -and [int]$a -le $cands.Count) {
          $cache[$key] = $cands[[int]$a - 1].Info; Save-Cache $cache $CachePath; $matched++
          Write-Host "  saved: $($cands[[int]$a - 1].Info.url)"; break
        }
        if ($a -match '^https?://') {
          try {
            $info = Info-FromUrl $a $key
            $cache[$key] = $info; Save-Cache $cache $CachePath; $matched++
            Write-Host "  saved: $($info.name) - $($info.url)"; break
          } catch { Write-Host "  $($_.Exception.Message)"; continue }
        }
        $query = $a
        $mw = @(MwHits $query)
      }
      if ($stop) { Write-Host ''; Write-Host 'Stopped.'; break }
    } catch { Write-Warning "  $($_.Exception.Message)" }
  }
  Write-Host ''
  Write-Host "Matched $matched model(s)."
  if ($matched) {
    $rels = @($scopes | ForEach-Object { $r = $_.Substring($Repo.Length).TrimStart('\'); if ($r) { $r } else { '.' } })
    Write-Host "Add their saved pages with:  Add-Model.ps1 -FillPages $($rels -join ' ')"
    if (-not $NoReadme) { Write-Host 'Updating READMEs ...'; & (Join-Path $PSScriptRoot 'Update-Readmes.ps1') }
  }
}

# ---------------------------------------------------------------- main
if ($FillPages) { Fill-Pages $scopes; return }
if ($Match) { Match-Models $scopes; return }
$tmp =Join-Path ([IO.Path]::GetTempPath()) ("add-model-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
[void][IO.Directory]::CreateDirectory($tmp)
$added = @(); $failed = @()
# Log in to MakerWorld up front (once) when the list has MakerWorld links, so the run can go unattended.
if (-not $File -and @($jobs | Where-Object { $_.Url -match 'makerworld\.com/' }).Count) {
  try { [void](Get-MakerWorldToken) } catch { Write-Warning "$($_.Exception.Message) MakerWorld models will open in the browser instead."; $script:MwSkip = $true }
}
if (@($jobs | Where-Object { $_.Url -match $CultsUrl }).Count) { [void](Get-CultsAuth) }   # ask for the API key up front too
try {
  $n = 0
  foreach ($j in $jobs) {
    $u = $j.Url; $destRoot = $j.Dest; $n++
    if ($jobs.Count -gt 1) { Write-Host "[$n/$($jobs.Count)] $u" }
    try {
      if ($u -match 'printables\.com/(?:[a-z]{2}/)?model/(\d+)') { $res = Add-Printables $Matches[1] $tmp }
      elseif ($u -match 'makerworld\.com/(?:[a-z]{2}/)?models/(\d+)') { $res = Add-MakerWorld $Matches[1] $tmp $u }
      elseif ($u -match $CultsUrl) { $res = Add-Cults $Matches[1] $u }
      elseif (Parse-Thangs $u) { $res = Add-Thangs $u }
      else { throw 'not a Printables, MakerWorld, Cults3D or Thangs model URL' }

      $key = ($res.Folder.Substring($Repo.Length).TrimStart('\')) -replace '\\', '/'
      $cache = Read-Cache $CachePath
      $cache[$key] = $res.Info
      Save-Cache $cache $CachePath
      $added += $key
      Write-Host "  added $key"
    } catch {
      if ($jobs.Count -eq 1) { throw }
      Write-Warning "$u failed: $($_.Exception.Message)"
      $failed += "$u - $($_.Exception.Message)"
    }
  }
} finally {
  Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

if ($jobs.Count -gt 1) {
  Write-Host "Added $($added.Count) of $($jobs.Count) models."
  if ($failed.Count) { Write-Host "Failed:"; $failed | ForEach-Object { Write-Host "  $_" } }
}

if ($added.Count -and -not $NoReadme) {
  Write-Host "Updating READMEs ..."
  & (Join-Path $PSScriptRoot 'Update-Readmes.ps1')
}
