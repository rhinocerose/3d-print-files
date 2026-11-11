<#
.SYNOPSIS
  Generates a README.md in every top-level category folder of this repo, with a
  preview image, a link to the original model page, and a link to the repo folder
  for every build.

.DESCRIPTION
  Build detection:
    * Thingiverse  - folder has a README.txt "... on Thingiverse: <url>", or ends in a thing id
    * Printables   - folder ends in "-model_files" / contains "<id>-<slug>-<uuid>.pdf"
    * MakerWorld   - folder name contains "+" or ends in "_stls"
    * Anything else that holds model files is listed as a build with an unknown source
      (the script still tries an exact-title lookup on Printables and MakerWorld).

  Images:
    * Printables / MakerWorld cover images are downloaded into <category>/readme-images/
    * Thingiverse builds use the images/ folder that ships with the download
    * Otherwise the first image in the folder, or the thumbnail embedded in a .3mf, is used

  Resolved sources are cached in scripts/readme-sources.json. Edit an entry there and
  set "manual": true to override what the script found; manual entries are never refetched.

.PARAMETER Refresh
  Re-query the websites for every non-manual entry, ignoring cached results.

.PARAMETER Offline
  Don't contact any website; use only the cache and local files.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\Update-Readmes.ps1
#>
param([switch]$Refresh, [switch]$Offline, [switch]$ListOnly)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.IO.Compression.FileSystem

$Repo      = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$CachePath = Join-Path $PSScriptRoot 'readme-sources.json'
$ImgDir    = 'readme-images'
$UA        = 'Mozilla/5.0 (3d-print-files readme generator)'
$Utf8      = New-Object System.Text.UTF8Encoding $false

$ModelExt = @('.stl','.3mf','.step','.stp','.f3d','.f3z','.scad','.obj','.fcstd','.skp','.shapr',
              '.sldprt','.3dm','.ipt','.iges','.igs','.gcode','.dxf','.zip','.blend','.amf')
$ImageExt = @('.jpg','.jpeg','.png','.gif','.webp')
$SkipDirs = @('.git','scripts',$ImgDir,'__MACOSX')

# ---------------------------------------------------------------- helpers
function LongPath([string]$p) { if ($p.StartsWith('\\?\')) { $p } else { "\\?\$p" } }
function Rel([string]$full) { $f = $full -replace '^\\\\\?\\',''; $f.Substring($Repo.Length).TrimStart('\') -replace '\\','/' }
function Norm([string]$s) { if (-not $s) { return '' }; ($s.ToLowerInvariant() -replace '[^\p{L}\p{N}]','') }
function Enc([string]$relPath) { (($relPath -split '/') | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/' }
function Html([string]$s) { [System.Net.WebUtility]::HtmlEncode($s) }

function Pretty([string]$s) {
  $t = $s -replace '-model_files$','' -replace '_stls$','' -replace '\+',' ' -replace '_',' '
  $t = $t -replace '\s+-\s+\d{5,}.*$','' -replace '\s+\d{5,}$',''
  if ($t -cmatch '^[a-z0-9 \-]+$') {   # slug-style -> Title Case
    $t = (($t -replace '-',' ') -split '\s+' | Where-Object { $_ } | ForEach-Object { $_.Substring(0,1).ToUpper() + $_.Substring(1) }) -join ' '
  }
  ($t -replace '\s+',' ').Trim()
}

$childCache = @{}
function Kids([string]$full) {
  if (-not $childCache.ContainsKey($full)) {
    $items = @(Get-ChildItem -LiteralPath (LongPath $full) -Force -ErrorAction SilentlyContinue)
    $childCache[$full] = @{
      Dirs  = @($items | Where-Object { $_.PSIsContainer -and $SkipDirs -notcontains $_.Name })
      Files = @($items | Where-Object { -not $_.PSIsContainer })
    }
  }
  $childCache[$full]
}
function AllFiles([string]$full) {
  @(Get-ChildItem -LiteralPath (LongPath $full) -Recurse -File -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '\\__MACOSX\\' })
}
function IsModel($f) { $ModelExt -contains $f.Extension.ToLowerInvariant() }
function IsImage($f) { $ImageExt -contains $f.Extension.ToLowerInvariant() }

function TvReadme([string]$full) {
  $rd = (Kids $full).Files | Where-Object { $_.Name -eq 'README.txt' } | Select-Object -First 1
  if (-not $rd) { return $null }
  $lines = [IO.File]::ReadAllLines($rd.FullName)
  foreach ($line in $lines) {   # current format: "<title> by <author> on Thingiverse: <url>"
    if ($line -match '^\s*(.+?)\s+by\s+(.+?)\s+on Thingiverse:\s*(https?://\S*thingiverse\.com/thing:(\d+))') {
      return @{ Name = $Matches[1].Trim(); Author = $Matches[2].Trim(); Url = ($Matches[3] -replace '^http:','https:'); Id = $Matches[4] }
    }
  }
  $id = $null; $name = $null; $author = $null
  foreach ($line in $lines) {   # older format: "<url>" then "<title> by <author> is licensed under ..."
    if (-not $id -and $line -match 'thingiverse\.com/thing:(\d+)') { $id = $Matches[1] }
    if (-not $name -and $line -match '^\s*(.+?)\s+by\s+(.+?)\s+is licensed under') { $name = $Matches[1].Trim(); $author = $Matches[2].Trim() }
  }
  if ($id) { return @{ Name = $name; Author = $author; Url = "https://www.thingiverse.com/thing:$id"; Id = $id } }
  $null
}
function PrintablesPdfId([string]$full) {
  foreach ($f in (Kids $full).Files) {
    if ($f.Name -match '^(\d+)-.+-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.pdf$') { return $Matches[1] }
  }
  $null
}
function SourceHint($dir) {
  $n = $dir.Name
  if (TvReadme $dir.FullName) { return 'thingiverse' }
  if ($n -match '(?:_|\s-\s)(\d{5,8})(?:\s|$)' -or $n -match '_(\d{5,8})$') { return 'thingiverse' }
  if ($n -match '-model_files$' -or $n -match '-mo$' -or (PrintablesPdfId $dir.FullName)) { return 'printables' }
  if ($n -match '\+' -or ($n -match '_stls$' -and $n -notmatch '^(legacy|old|new|v?\d+)_stls$')) { return 'makerworld' }
  $null
}

$markerMemo = @{}
function HasMarkerBelow($dir) {
  if ($markerMemo.ContainsKey($dir.FullName)) { return $markerMemo[$dir.FullName] }
  $res = $false
  foreach ($c in (Kids $dir.FullName).Dirs) { if ((SourceHint $c) -or (HasMarkerBelow $c)) { $res = $true; break } }
  $markerMemo[$dir.FullName] = $res
  $res
}

# ---------------------------------------------------------------- discovery
$builds = New-Object System.Collections.ArrayList
$loose  = New-Object System.Collections.ArrayList

function Walk($dir, [string]$category) {
  $k = Kids $dir.FullName
  $subNames = $k.Dirs | ForEach-Object { $_.Name }
  foreach ($c in $k.Dirs) {
    $hint = SourceHint $c
    if ($hint) { [void]$builds.Add(@{ Dir = $c; Category = $category; Hint = $hint }) }
    elseif (HasMarkerBelow $c) { Walk $c $category }
    elseif (@(AllFiles $c.FullName | Where-Object { IsModel $_ }).Count -gt 0) {
      [void]$builds.Add(@{ Dir = $c; Category = $category; Hint = $null })
    }
  }
  foreach ($f in $k.Files) {
    if (-not (IsModel $f)) { continue }
    $base = [IO.Path]::GetFileNameWithoutExtension($f.Name)
    if ($f.Extension -eq '.zip' -and ($subNames -contains $base -or $subNames -contains ($base -replace '\(\d+\)$',''))) { continue }  # already extracted
    [void]$loose.Add(@{ File = $f; Category = $category })
  }
}

$categories = Get-ChildItem -LiteralPath $Repo -Directory | Where-Object { $SkipDirs -notcontains $_.Name } | Sort-Object Name
foreach ($cat in $categories) { Walk $cat $cat.Name }
Write-Host ("Found {0} builds and {1} loose files in {2} categories" -f $builds.Count, $loose.Count, $categories.Count)
if ($ListOnly) {
  $builds | ForEach-Object { "{0,-12} {1}" -f $(if ($_.Hint) { $_.Hint } else { '?' }), (Rel $_.Dir.FullName) }
  $loose  | ForEach-Object { "{0,-12} {1}" -f 'file', (Rel $_.File.FullName) }
  return
}

# ---------------------------------------------------------------- cache
$cache = @{}
if (Test-Path $CachePath) {
  $raw = Get-Content -LiteralPath $CachePath -Raw -Encoding UTF8 | ConvertFrom-Json
  foreach ($p in $raw.PSObject.Properties) {
    $h = @{}; foreach ($q in $p.Value.PSObject.Properties) { $h[$q.Name] = $q.Value }; $cache[$p.Name] = $h
  }
}

# ---------------------------------------------------------------- web lookups
function Gql([string]$query) {
  Start-Sleep -Milliseconds 250
  $body = @{ query = $query } | ConvertTo-Json -Compress
  (Invoke-RestMethod -Uri 'https://api.printables.com/graphql/' -Method Post -Body $body -ContentType 'application/json' -UserAgent $UA -TimeoutSec 30).data
}
$PrintFields = 'id name slug user { publicUsername } image { filePath }'
function PrintablesInfo($p) {
  $img = $null
  if ($p.image -and $p.image.filePath) {
    $fp = $p.image.filePath
    if ($fp -match '^(.*)/([^/]+)\.(\w+)$') { $img = "https://media.printables.com/$($Matches[1])/thumbs/inside/640x480/$($Matches[3])/$($Matches[2]).webp" }
  }
  @{ source = 'printables'; id = "$($p.id)"; name = $p.name; author = $p.user.publicUsername
     url = "https://www.printables.com/model/$($p.id)-$($p.slug)"; imageUrl = $img }
}
function PrintablesById([string]$id) {
  $d = Gql "query { print(id: `"$id`") { $PrintFields } }"
  if ($d.print) { PrintablesInfo $d.print } else { $null }
}
function PrintablesSearch([string]$title, [string]$slug) {
  $q = ($title -replace '["\\]',' ')
  $d = Gql "query { searchPrints2(query: `"$q`", limit: 20) { items { $PrintFields } } }"
  foreach ($p in @($d.searchPrints2.items)) {
    if (($slug -and $p.slug -eq $slug) -or ((Norm $p.name) -eq (Norm $title))) { return PrintablesInfo $p }
  }
  $null
}
function MakerWorldSearch([string]$title) {
  Start-Sleep -Milliseconds 400
  $kw = [Uri]::EscapeDataString(($title -replace '_',' ').Trim())
  $r = Invoke-RestMethod -Uri "https://makerworld.com/api/v1/search-service/select/design2?keyword=$kw&limit=20" -UserAgent $UA -TimeoutSec 30
  $want = Norm ($title -replace '_','')
  foreach ($h in @($r.hits)) {
    if ((Norm $h.title) -eq $want) {
      $img = if ($h.cover) { "$($h.cover)?x-oss-process=image/resize,w_640/format,webp" } else { $null }
      return @{ source = 'makerworld'; id = "$($h.id)"; name = $h.title; author = $h.designCreator.name
                url = "https://makerworld.com/en/models/$($h.id)-$($h.slug)"; imageUrl = $img }
    }
  }
  $null
}
function Safe([scriptblock]$sb) { if ($Offline) { return $null }; try { & $sb } catch { Write-Warning $_.Exception.Message; $null } }

function Resolve-Build($b) {
  $dir = $b.Dir; $n = $dir.Name; $hint = $b.Hint
  $info = $null
  switch ($hint) {
    'thingiverse' {
      $tv = TvReadme $dir.FullName
      if ($tv) { $info = @{ source='thingiverse'; id=$tv.Id; name=$tv.Name; author=$tv.Author; url=$tv.Url } }
      elseif ($n -match '(\d{5,8})') { $info = @{ source='thingiverse'; id=$Matches[1]; name=(Pretty $n); url="https://www.thingiverse.com/thing:$($Matches[1])" } }
    }
    'printables' {
      $id = PrintablesPdfId $dir.FullName
      if ($id) { $info = Safe { PrintablesById $id }
                 if (-not $info) { $info = @{ source='printables'; id=$id; url="https://www.printables.com/model/$id" } } }
      else {
        $slug = $n -replace '-model_files$','' -replace '-mo$',''
        $info = Safe { PrintablesSearch ($slug -replace '-',' ') $slug }
      }
      if (-not $info) { $info = @{ source='printables' } }
    }
    'makerworld' {
      $title = ($n -replace '_stls$','') -replace '\+',' '
      $info = Safe { MakerWorldSearch $title }
      if (-not $info) { $info = @{ source='makerworld' } }
    }
    default {
      $title = Pretty $n
      $info = Safe { PrintablesSearch $title $null }
      if (-not $info) { $info = Safe { MakerWorldSearch $title } }
      if (-not $info) { $info = @{ source='unknown' } }
    }
  }
  $info
}

$i = 0
foreach ($b in $builds) {
  $i++
  $key = Rel $b.Dir.FullName
  $c = $cache[$key]
  if ($c -and ($c.manual -or -not $Refresh)) { $b.Info = $c; continue }
  if ($i % 20 -eq 0) { Write-Host "  resolving $i / $($builds.Count)" }
  $info = Resolve-Build $b
  $cache[$key] = $info
  $b.Info = $info
}
foreach ($l in $loose) {
  $key = Rel $l.File.FullName
  $c = $cache[$key]
  if ($c -and ($c.manual -or -not $Refresh)) { $l.Info = $c; continue }
  $info = $null
  if ($l.File.Name -match '\+') { $info = Safe { MakerWorldSearch (([IO.Path]::GetFileNameWithoutExtension($l.File.Name) -replace '\(\d+\)$','') -replace '\+',' ') } }
  if (-not $info) { $info = @{ source = $(if ($l.File.Name -match '\+') { 'makerworld' } else { 'unknown' }) } }
  $cache[$key] = $info
  $l.Info = $info
}

# save cache (sorted, stable)
$ordered = [ordered]@{}
foreach ($k in ($cache.Keys | Sort-Object)) {
  $o = [ordered]@{}; foreach ($f in ($cache[$k].Keys | Sort-Object)) { if ($null -ne $cache[$k][$f]) { $o[$f] = $cache[$k][$f] } }; $ordered[$k] = $o
}
[IO.File]::WriteAllText($CachePath, ($ordered | ConvertTo-Json -Depth 5), $Utf8)

# ---------------------------------------------------------------- images
function ImgName([string]$relUnderCat, [string]$ext) {
  $slug = ($relUnderCat.ToLowerInvariant() -replace '[^a-z0-9]+','-').Trim('-')
  if ($slug.Length -gt 70) { $slug = $slug.Substring(0,70).Trim('-') }
  $md5 = [Security.Cryptography.MD5]::Create()
  $hash = -join ($md5.ComputeHash([Text.Encoding]::UTF8.GetBytes($relUnderCat))[0..3] | ForEach-Object { $_.ToString('x2') })
  if ($slug) { "$slug-$hash$ext" } else { "$hash$ext" }
}
function Extract3mfThumb([string]$file, [string]$dest) {
  try {
    $z = [IO.Compression.ZipFile]::OpenRead((LongPath $file))
    try {
      $e = $z.Entries | Where-Object { $_.FullName -like 'Auxiliaries/Model Pictures/*' -and $_.Length -gt 0 -and $_.Name -match '\.(png|jpe?g|webp)$' } | Select-Object -First 1
      if (-not $e) { $e = $z.Entries | Where-Object { $_.FullName -match '^Metadata/(plate_1|thumbnail)\.png$' } | Select-Object -First 1 }
      if (-not $e) { $e = $z.Entries | Where-Object { $_.FullName -match '^Metadata/.*\.png$' -and $_.Name -notmatch '^(top|pick)_|_small' } | Select-Object -First 1 }
      if (-not $e) { return $null }
      $ext = [IO.Path]::GetExtension($e.Name).ToLowerInvariant()
      $out = [IO.Path]::ChangeExtension($dest, $ext)
      [IO.Compression.ZipFileExtensions]::ExtractToFile($e, $out, $true)
      return $out
    } finally { $z.Dispose() }
  } catch { return $null }
}
function PickLocalImage([string]$full) {
  $imgs = @(AllFiles $full | Where-Object { (IsImage $_) -and $_.Length -gt 2000 })
  if (-not $imgs) { return $null }
  $named = @($imgs | Where-Object { [IO.Path]::GetFileNameWithoutExtension($_.Name) -notmatch '^[0-9a-f]{32}$' })
  if ($named) { $named[0] } else { $imgs[0] }
}

function Get-Preview($entry, [string]$catFull, [string]$targetFull, [bool]$isDir) {
  $relUnderCat = (Rel $targetFull).Substring($entry.Category.Length).TrimStart('/')
  $destBase = Join-Path (Join-Path $catFull $ImgDir) (ImgName $relUnderCat '')
  $existing = @(Get-ChildItem -Path "$destBase.*" -ErrorAction SilentlyContinue)
  if ($existing) { return $existing[0].FullName }

  $info = $entry.Info
  if ($info.imageUrl -and -not $Offline) {
    New-Item -ItemType Directory -Force (Join-Path $catFull $ImgDir) | Out-Null
    $out = "$destBase.webp"
    try { Invoke-WebRequest -Uri $info.imageUrl -OutFile $out -UserAgent $UA -UseBasicParsing -TimeoutSec 60; return $out }
    catch { Write-Warning "image download failed for $($info.url): $($_.Exception.Message)"; Remove-Item $out -ErrorAction SilentlyContinue }
  }
  if ($isDir) {
    $local = PickLocalImage $targetFull
    if ($local) { return ($local.FullName -replace '^\\\\\?\\','') }
    $tmf = AllFiles $targetFull | Where-Object { $_.Extension -eq '.3mf' } | Select-Object -First 1
    if ($tmf) { New-Item -ItemType Directory -Force (Join-Path $catFull $ImgDir) | Out-Null; return (Extract3mfThumb $tmf.FullName "$destBase.png") }
  } elseif ($entry.File.Extension -eq '.3mf') {
    New-Item -ItemType Directory -Force (Join-Path $catFull $ImgDir) | Out-Null
    return (Extract3mfThumb $entry.File.FullName "$destBase.png")
  }
  $null
}

# ---------------------------------------------------------------- README rendering
$SiteName = @{ thingiverse = 'Thingiverse'; printables = 'Printables'; makerworld = 'MakerWorld' }
function SourceLink($info, [string]$fallbackTitle) {
  if ($info.url) { return "<a href=`"$(Html $info.url)`">$($SiteName[$info.source])</a>" }
  $q = [Uri]::EscapeDataString($fallbackTitle)
  switch ($info.source) {
    'makerworld' { "<a href=`"https://makerworld.com/en/search/models?keyword=$q`">Search MakerWorld</a>" }
    'printables' { "<a href=`"https://www.printables.com/search/models?q=$q`">Search Printables</a>" }
    default      { 'Source unknown' }
  }
}
function RelFromCat([string]$catFull, [string]$path) {
  $p = $path -replace '^\\\\\?\\',''
  ($p.Substring($catFull.Length).TrimStart('\')) -replace '\\','/'
}

$total = 0
foreach ($cat in $categories) {
  $catFull = $cat.FullName
  $cb = @($builds | Where-Object { $_.Category -eq $cat.Name })
  $cl = @($loose  | Where-Object { $_.Category -eq $cat.Name })
  if (-not $cb -and -not $cl) { continue }

  $cards = @()
  foreach ($b in $cb) {
    $info = $b.Info
    $relDir = RelFromCat $catFull $b.Dir.FullName
    $name = if ($info.name) { $info.name } elseif ($b.Dir.Name -match '^(files|stls?|stl files)$') { Pretty (Split-Path $relDir -Parent | Split-Path -Leaf) } else { Pretty $b.Dir.Name }
    $img = Get-Preview $b $catFull $b.Dir.FullName $true
    $group = Split-Path $relDir -Parent
    $cards += @{ Name = $name; Group = ($group -replace '\\','/'); Link = (Enc $relDir); Img = $(if ($img) { Enc (RelFromCat $catFull $img) }); Info = $info; Fallback = (Pretty $b.Dir.Name) }
  }
  foreach ($l in $cl) {
    $info = $l.Info
    $relFile = RelFromCat $catFull $l.File.FullName
    $img = Get-Preview $l $catFull $l.File.FullName $false
    $name = if ($info.name) { $info.name } else { [IO.Path]::GetFileNameWithoutExtension($l.File.Name) -replace '\+',' ' }
    $group = Split-Path $relFile -Parent
    $cards += @{ Name = $name; Group = ($group -replace '\\','/'); Link = (Enc $relFile); Img = $(if ($img) { Enc (RelFromCat $catFull $img) }); Info = $info; Fallback = $name; IsFile = $true; FileName = $l.File.Name }
  }

  $sb = New-Object System.Text.StringBuilder
  $title = Pretty $cat.Name
  [void]$sb.AppendLine("# $title").AppendLine()
  [void]$sb.AppendLine('<!-- Generated by scripts/Update-Readmes.ps1 - edit scripts/readme-sources.json and rerun instead of editing by hand. -->').AppendLine()
  $counts = $cards | Group-Object { $_.Info.source } | Sort-Object Name | ForEach-Object { "$($_.Count) $(if ($SiteName[$_.Name]) { $SiteName[$_.Name] } else { 'unknown source' })" }
  [void]$sb.AppendLine("$($cards.Count) builds &middot; $($counts -join ' &middot; ')").AppendLine()

  $groups = $cards | Group-Object { $_.Group } | Sort-Object @{ Expression = { if ($_.Name) { 1 } else { 0 } } }, Name
  if (@($groups).Count -gt 1) {
    [void]$sb.AppendLine('## Contents').AppendLine()
    foreach ($g in $groups) {
      $gt = if ($g.Name) { (($g.Name -split '/') | ForEach-Object { Pretty $_ }) -join ' / ' } else { $title }
      $anchor = ($gt.ToLowerInvariant() -replace '[^\p{L}\p{N} \-]','' -replace ' ','-')
      [void]$sb.AppendLine("- [$gt](#$anchor) ($($g.Count))")
    }
    [void]$sb.AppendLine()
  }

  foreach ($g in $groups) {
    $gt = if ($g.Name) { (($g.Name -split '/') | ForEach-Object { Pretty $_ }) -join ' / ' } else { $title }
    [void]$sb.AppendLine("## $gt").AppendLine()
    $all   = @($g.Group | Sort-Object { $_.Name })
    $items = @($all | Where-Object { -not ($_.IsFile -and -not $_.Img -and -not $_.Info.url) })
    $plain = @($all | Where-Object { $_.IsFile -and -not $_.Img -and -not $_.Info.url })
    if ($items.Count) { [void]$sb.AppendLine('<table>') }
    for ($r = 0; $r -lt $items.Count; $r += 3) {
      [void]$sb.AppendLine('<tr>')
      for ($cI = $r; $cI -lt [Math]::Min($r + 3, $items.Count); $cI++) {
        $it = $items[$cI]
        [void]$sb.AppendLine('<td width="33%" align="center" valign="top">')
        if ($it.Img) { [void]$sb.AppendLine("<a href=`"$($it.Link)`"><img src=`"$($it.Img)`" width=`"240`" alt=`"$(Html $it.Name)`"></a><br>") }
        else { [void]$sb.AppendLine('<i>no preview</i><br>') }
        [void]$sb.AppendLine("<b>$(Html $it.Name)</b><br>")
        if ($it.Info.author) { [void]$sb.AppendLine("<sub>by $(Html $it.Info.author)</sub><br>") }
        $repoLabel = if ($it.IsFile) { Html $it.FileName } else { 'Repo folder' }
        [void]$sb.AppendLine("$(SourceLink $it.Info $it.Fallback) &middot; <a href=`"$($it.Link)`">$repoLabel</a>")
        [void]$sb.AppendLine('</td>')
      }
      [void]$sb.AppendLine('</tr>')
    }
    if ($items.Count) { [void]$sb.AppendLine('</table>').AppendLine() }
    if ($plain.Count) {
      [void]$sb.AppendLine("<details><summary>Other files in this folder ($($plain.Count))</summary>").AppendLine()
      foreach ($p in ($plain | Sort-Object { $_.FileName })) { [void]$sb.AppendLine("- [$($p.FileName -replace '([\[\]])','\$1')]($($p.Link))") }
      [void]$sb.AppendLine().AppendLine('</details>').AppendLine()
    }
  }

  [IO.File]::WriteAllText((Join-Path $catFull 'README.md'), $sb.ToString(), $Utf8)
  $total += $cards.Count
  Write-Host ("  {0,-22} {1,4} entries" -f $cat.Name, $cards.Count)
}
Write-Host "Wrote READMEs for $total entries."

# ---------------------------------------------------------------- root index (between markers)
$rootReadme = Join-Path $Repo 'README.md'
$rootText = if (Test-Path $rootReadme) { [IO.File]::ReadAllText($rootReadme) } else { "# 3d-print-files`n" }
$idx = New-Object System.Text.StringBuilder
[void]$idx.AppendLine('<!-- categories:start -->').AppendLine('## Categories').AppendLine()
foreach ($cat in $categories) {
  if (-not (Test-Path (Join-Path $cat.FullName 'README.md'))) { continue }
  $cnt = @($builds | Where-Object { $_.Category -eq $cat.Name }).Count
  [void]$idx.AppendLine("- [$(Pretty $cat.Name)]($(Enc $cat.Name)/README.md) - $cnt builds")
}
[void]$idx.Append('<!-- categories:end -->')
if ($rootText -match '(?s)<!-- categories:start -->.*<!-- categories:end -->') {
  $rootText = [regex]::Replace($rootText, '(?s)<!-- categories:start -->.*<!-- categories:end -->', { param($m) $idx.ToString() })
} else { $rootText = $rootText.TrimEnd() + "`n`n" + $idx.ToString() + "`n" }
[IO.File]::WriteAllText($rootReadme, $rootText, $Utf8)
