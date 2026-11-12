<#
.SYNOPSIS
  Downloads a model from Printables or MakerWorld into a folder of this repo, unzips it,
  deletes the zip, records the source in scripts/readme-sources.json and regenerates the READMEs.

.DESCRIPTION
  Printables: downloaded directly (no account needed). By default only the "model files"
  pack is fetched, into "<slug>-model_files" - the same layout as the existing folders.
  -AllFiles also fetches the print files (gcode/3mf) and other files packs.

  MakerWorld requires a logged-in account to download, so one of these is used:
    1. -File <path>   a zip/3mf you already downloaded from the model page
    2. a token        your MakerWorld "token" cookie in $env:MAKERWORLD_TOKEN or in
                      scripts/.makerworld-token (git-ignored); downloads directly
    3. otherwise      the model page opens in your browser; click Download and the script
                      picks the file up from your Downloads folder automatically
  The folder is named after the downloaded zip (e.g. "Cable+Organizer"), like the existing ones.

  scripts/add_model.py is the Linux/macOS version of this script.

.PARAMETER Url
  One or more Printables / MakerWorld model URLs.
.PARAMETER Folder
  Repo folder to put the model in (created if missing). Defaults to the current directory.
.PARAMETER Name
  Override the name of the model's folder (only with a single URL).
.PARAMETER NoReadme
  Don't regenerate the READMEs afterwards (run Update-Readmes.ps1 yourself later).

.EXAMPLE
  scripts\Add-Model.ps1 https://www.printables.com/model/359285-klamma-locking-cable-clip -Folder cable-management
.EXAMPLE
  cd storage\8020; ..\..\scripts\Add-Model.ps1 https://makerworld.com/en/models/2133463-cable-organizer
#>
param(
  [Parameter(Mandatory = $true, Position = 0, ValueFromRemainingArguments = $true)][string[]]$Url,
  [string]$Folder = '.',
  [string]$Name,
  [string]$File,
  [switch]$AllFiles,
  [switch]$Force,
  [switch]$NoReadme
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

# ---------------------------------------------------------------- destination folder
$destRoot = if ([IO.Path]::IsPathRooted($Folder)) { $Folder } else { Join-Path (Get-Location).Path $Folder }
$destRoot = [IO.Path]::GetFullPath($destRoot).TrimEnd('\')
if (-not $destRoot.StartsWith("$Repo\", [StringComparison]::OrdinalIgnoreCase)) {
  throw "Folder '$destRoot' must be a category folder inside the repo ($Repo)."
}
if ($Name -and $Url.Count -gt 1) { throw '-Name can only be used with a single URL.' }
if ($File -and $Url.Count -gt 1) { throw '-File can only be used with a single URL.' }

# ---------------------------------------------------------------- web helpers
function Gql([string]$query, [hashtable]$vars = @{}) {
  $body = @{ query = $query; variables = $vars } | ConvertTo-Json -Compress -Depth 6
  $r = Invoke-RestMethod -Uri 'https://api.printables.com/graphql/' -Method Post -Body $body -ContentType 'application/json' -UserAgent $UA -TimeoutSec 60
  if ($r.errors) { throw "Printables API: $($r.errors[0].message)" }
  $r.data
}
function Save-Url([string]$url, [string]$out, [hashtable]$headers = @{}) {
  Write-Host "  downloading $([IO.Path]::GetFileName($out))"
  Invoke-WebRequest -Uri $url -OutFile $out -UserAgent $UA -Headers $headers -UseBasicParsing -TimeoutSec 600
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

function Get-MakerWorldToken {
  if ($env:MAKERWORLD_TOKEN) { return $env:MAKERWORLD_TOKEN.Trim() }
  if (Test-Path -LiteralPath $TokenFile) { return ([IO.File]::ReadAllText($TokenFile)).Trim() }
  $null
}

# ---------------------------------------------------------------- per-site handlers
# Each returns @{ Info = <cache entry>; Folder = <full path of the model folder> }
function Add-Printables([string]$id, [string]$tmp) {
  $fields = 'id name slug user { publicUsername } image { filePath } downloadPacks { id fileType } stls { id name }'
  $p = (Gql "query { print(id: `"$id`") { $fields } }").print
  if (-not $p) { throw "Printables model $id was not found (removed or private?)." }
  $img = $null
  if ($p.image -and $p.image.filePath -match '^(.*)/([^/]+)\.(\w+)$') { $img = "https://media.printables.com/$($Matches[1])/thumbs/inside/640x480/$($Matches[3])/$($Matches[2]).webp" }
  $info = @{ source = 'printables'; id = "$($p.id)"; name = $p.name; author = $p.user.publicUsername
             url = "https://www.printables.com/model/$($p.id)-$($p.slug)"; imageUrl = $img; manual = $true }
  Write-Host "Printables: $($p.name) by $($p.user.publicUsername)"

  $target = Join-Path $destRoot $(if ($Name) { SafeName $Name } else { "$($p.slug)-model_files" })
  if ((Test-Path -LiteralPath $target) -and -not $Force) { throw "'$target' already exists. Use -Force to download into it anyway." }
  [void][IO.Directory]::CreateDirectory((LongPath $target))

  $mutation = 'mutation GetDownloadLink($id: ID!, $printId: ID!, $fileType: DownloadFileTypeEnum!, $source: DownloadSourceEnum!) { getDownloadLink(id: $id, printId: $printId, fileType: $fileType, source: $source) { ok errors { field messages } output { link } } }'
  function Link($fileId, $type) {
    $r = (Gql $mutation @{ id = "$fileId"; printId = "$id"; fileType = $type; source = 'model_detail' }).getDownloadLink
    if (-not $r.ok) { throw "Printables refused the download: $(($r.errors | ForEach-Object { $_.messages }) -join ', ')" }
    $r.output.link
  }

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
  } elseif ($tok = Get-MakerWorldToken) {
    $h = @{ Authorization = "Bearer $tok"; Cookie = "token=$tok" }
    try { $r = Invoke-RestMethod -Uri "https://makerworld.com/api/v1/design-service/design/$id/model" -Headers $h -UserAgent $UA -TimeoutSec 60 }
    catch { throw "MakerWorld download request failed (is the token still valid?): $($_.ErrorDetails.Message) $($_.Exception.Message)" }
    if (-not $r.url) { throw "MakerWorld didn't return a download link: $($r | ConvertTo-Json -Compress)" }
    $fname = if ($r.name) { $r.name } else { [Uri]::UnescapeDataString(([Uri]$r.url).Segments[-1]) }
    $src = Join-Path $tmp (SafeName $fname)
    Save-Url $r.url $src
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
  @{ Info = $info; Folder = $target }
}

# ---------------------------------------------------------------- main
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("add-model-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
[void][IO.Directory]::CreateDirectory($tmp)
$added = @()
try {
  foreach ($u in $Url) {
    if ($u -match 'printables\.com/(?:[a-z]{2}/)?model/(\d+)') { $res = Add-Printables $Matches[1] $tmp }
    elseif ($u -match 'makerworld\.com/(?:[a-z]{2}/)?models/(\d+)') { $res = Add-MakerWorld $Matches[1] $tmp $u }
    else { Write-Warning "Not a Printables or MakerWorld model URL, skipped: $u"; continue }

    $key = ($res.Folder.Substring($Repo.Length).TrimStart('\')) -replace '\\', '/'
    $cache = Read-Cache $CachePath
    $cache[$key] = $res.Info
    Save-Cache $cache $CachePath
    $added += $key
    Write-Host "  added $key"
  }
} finally {
  Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

if ($added.Count -and -not $NoReadme) {
  Write-Host "Updating READMEs ..."
  & (Join-Path $PSScriptRoot 'Update-Readmes.ps1')
}
