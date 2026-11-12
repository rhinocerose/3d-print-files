# Helpers shared by Update-Readmes.ps1 and Add-Model.ps1 (dot-sourced).
# The Python scripts (update_readmes.py / add_model.py) reproduce these exactly.

# Stable, ordinal, case-insensitive sort (culture-aware Sort-Object can't be reproduced on Linux).
function OSort($items, [scriptblock]$key) {
  $arr = @($items)
  if ($arr.Count -lt 2) { return $arr }
  OSortKeys $arr ([string[]]@(foreach ($x in $arr) { [string]($key.InvokeWithContext($null, [psvariable[]]@([psvariable]::new('_', $x)), $null) | Select-Object -First 1) }))
}
function OSortKeys([object[]]$arr, [string[]]$keys) {
  if ($arr.Count -lt 2) { return $arr }
  $cmp = [StringComparer]::OrdinalIgnoreCase
  $idx = [int[]](0..($arr.Count - 1))
  [Array]::Sort($idx, [Comparison[int]]{ param($a, $b) $c = $cmp.Compare($keys[$a], $keys[$b]); if ($c) { $c } else { $a.CompareTo($b) } })
  foreach ($i in $idx) { $arr[$i] }
}

function JsonStr([string]$s) {
  $sb = New-Object System.Text.StringBuilder '"'
  foreach ($ch in $s.ToCharArray()) {
    switch ([int]$ch) {
      34 { [void]$sb.Append('\"') } 92 { [void]$sb.Append('\\') } 10 { [void]$sb.Append('\n') } 13 { [void]$sb.Append('\r') }
      9 { [void]$sb.Append('\t') } 8 { [void]$sb.Append('\b') } 12 { [void]$sb.Append('\f') }
      default { if ([int]$ch -lt 32) { [void]$sb.Append(('\u{0:x4}' -f [int]$ch)) } else { [void]$sb.Append($ch) } }
    }
  }
  [void]$sb.Append('"'); $sb.ToString()
}
function JsonVal($v) {
  if ($v -is [bool]) { if ($v) { 'true' } else { 'false' } }
  elseif ($v -is [int] -or $v -is [long] -or $v -is [double]) { [string]::Format([Globalization.CultureInfo]::InvariantCulture, '{0}', $v) }
  else { JsonStr ([string]$v) }
}

# readme-sources.json <-> @{ "repo/relative/path" = @{ field = value } }
function Read-Cache([string]$path) {
  $cache = @{}
  if (Test-Path -LiteralPath $path) {
    $raw = [IO.File]::ReadAllText($path) | ConvertFrom-Json
    foreach ($p in $raw.PSObject.Properties) {
      $h = @{}; foreach ($q in $p.Value.PSObject.Properties) { $h[$q.Name] = $q.Value }; $cache[$p.Name] = $h
    }
  }
  $cache
}
# Writes the cache in the same layout as Python's json.dumps(indent=2, ensure_ascii=False).
function Save-Cache([hashtable]$c, [string]$path) {
  $lines = New-Object System.Collections.Generic.List[string]
  $keys = @(OSort $c.Keys { $_ })
  for ($i = 0; $i -lt $keys.Count; $i++) {
    $e = $c[$keys[$i]]
    $fields = @(OSort @($e.Keys | Where-Object { $null -ne $e[$_] }) { $_ })
    $sep = if ($i -lt $keys.Count - 1) { ',' } else { '' }
    if (-not $fields.Count) { $lines.Add("  $(JsonStr $keys[$i]): {}$sep"); continue }
    $lines.Add("  $(JsonStr $keys[$i]): {")
    for ($j = 0; $j -lt $fields.Count; $j++) {
      $lines.Add("    $(JsonStr $fields[$j]): $(JsonVal $e[$fields[$j]])$(if ($j -lt $fields.Count - 1) { ',' })")
    }
    $lines.Add("  }$sep")
  }
  $text = if ($keys.Count) { "{`n" + ($lines -join "`n") + "`n}`n" } else { "{}`n" }
  [IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding $false))
}
