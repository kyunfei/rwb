# Regenerate lib/services/source_engine/big5_table.dart from Windows CP950.
# Requires Windows (Encoding 950). Run from repo root:
#   powershell -File tools/gen_big5_table.ps1
$ErrorActionPreference = 'Stop'
$enc = [System.Text.Encoding]::GetEncoding(950)
$pairs = New-Object System.Collections.Generic.List[Object]
for ($lead = 0x81; $lead -le 0xFE; $lead++) {
  foreach ($trail in @((0x40..0x7E) + (0x80..0xFE))) {
    if ($trail -eq 0x7F) { continue }
    $bytes = [byte[]]@($lead, $trail)
    $s = $enc.GetString($bytes)
    if ($s.Length -ne 1) { continue }
    $cp = [int][char]$s[0]
    if ($cp -eq 0xFFFD -or $cp -lt 0x80) { continue }
    $code = ($lead -shl 8) -bor $trail
    $pairs.Add([Tuple]::Create([int]$code, [int]$cp))
  }
}
$buf = New-Object byte[] ($pairs.Count * 4)
$i = 0
foreach ($t in $pairs) {
  $code = $t.Item1; $uni = $t.Item2
  $buf[$i++] = $code -band 0xFF
  $buf[$i++] = ($code -shr 8) -band 0xFF
  $buf[$i++] = $uni -band 0xFF
  $buf[$i++] = ($uni -shr 8) -band 0xFF
}
$b64 = [Convert]::ToBase64String($buf)
$outPath = Join-Path $PSScriptRoot '..\lib\services\source_engine\big5_table.dart'
$sw = New-Object System.IO.StreamWriter($outPath, $false, [System.Text.UTF8Encoding]::new($false))
$sw.WriteLine('// GENERATED FILE — Big5/CP950 → Unicode (Windows code page 950).')
$sw.WriteLine('// Do not edit by hand. Regenerate via tools/gen_big5_table.ps1')
$sw.WriteLine('// Packed LE uint16 pairs: big5_code, unicode_cp.')
$sw.WriteLine('// ignore_for_file: lines_longer_than_80_chars')
$sw.WriteLine('')
$sw.WriteLine('const String kBig5PackedBase64 =')
$chunk = 80
for ($o = 0; $o -lt $b64.Length; $o += $chunk) {
  $len = [Math]::Min($chunk, $b64.Length - $o)
  $part = $b64.Substring($o, $len)
  if ($o + $chunk -lt $b64.Length) { $sw.WriteLine("    '$part'") }
  else { $sw.WriteLine("    '$part';") }
}
$sw.WriteLine('')
$sw.WriteLine('const int kBig5PairCount = ' + $pairs.Count + ';')
$sw.Close()
Write-Host "pairs=$($pairs.Count) -> $outPath ($((Get-Item $outPath).Length) bytes)"
