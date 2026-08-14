<#
.SYNOPSIS
    Builds a ChannelSieve extension package on Windows.

.DESCRIPTION
    A Windows-native equivalent of tools/build.sh. Windows has no `zip` binary and this
    repo needs no Node toolchain, so this script does the whole build with built-ins:
    copy the sources, substitute the {EXT_VERSION} placeholder, and produce a .xpi.

    Unlike the shell script it never deletes anything unless you explicitly pass -Force,
    and it refuses to write outside <repo>\dist.

.EXAMPLE
    .\tools\build.ps1 -Browser firefox_selfhosted

.EXAMPLE
    .\tools\build.ps1 -Browser firefox -Force
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('firefox', 'firefox_selfhosted', 'chrome')]
    [string]$Browser,

    [string]$Version,

    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$BaseDir  = Split-Path -Parent $PSScriptRoot
$DistRoot = Join-Path $BaseDir 'dist'
$Dest     = Join-Path $DistRoot $Browser

if (-not $Version) {
    $Version = (Get-Content (Join-Path $BaseDir 'VERSION') -Raw).Trim()
}

# Never operate outside <repo>\dist, whatever the inputs were.
$resolvedDistRoot = [System.IO.Path]::GetFullPath($DistRoot)
$resolvedDest     = [System.IO.Path]::GetFullPath($Dest)
if (-not $resolvedDest.StartsWith($resolvedDistRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to build: '$resolvedDest' is outside '$resolvedDistRoot'."
}

if (Test-Path $Dest) {
    if (-not $Force) {
        throw "'$Dest' already exists. Inspect it, then re-run with -Force to replace it."
    }
    Write-Host "Replacing existing $Dest"
    Remove-Item -LiteralPath $Dest -Recurse -Force
}

New-Item -ItemType Directory -Path $Dest -Force | Out-Null

Write-Host "Building $Browser v$Version to $Dest"

Copy-Item (Join-Path $BaseDir 'src')     $Dest -Recurse
Copy-Item (Join-Path $BaseDir 'assets')  $Dest -Recurse
Copy-Item (Join-Path $BaseDir 'LICENSE') $Dest
Copy-Item (Join-Path $BaseDir 'VERSION') $Dest
Copy-Item (Join-Path $BaseDir "platform\$Browser\manifest.json") $Dest

# Substitute {EXT_VERSION}. Written as UTF-8 *without* a BOM -- Windows PowerShell's
# -Encoding utf8 emits a BOM, and a BOM in manifest.json makes Firefox reject the JSON.
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
foreach ($rel in @('manifest.json', 'src\ui\options.html')) {
    $file = Join-Path $Dest $rel
    $text = [System.IO.File]::ReadAllText($file)
    $text = $text.Replace('{EXT_VERSION}', $Version)
    [System.IO.File]::WriteAllText($file, $text, $utf8NoBom)
}

$remaining = Select-String -Path (Join-Path $Dest 'manifest.json') -Pattern 'EXT_VERSION' -ErrorAction SilentlyContinue
if ($remaining) {
    throw "manifest.json still contains the {EXT_VERSION} placeholder -- Firefox would reject it."
}

# Package. Entries are added one at a time rather than with
# [ZipFile]::CreateFromDirectory or Compress-Archive: on Windows PowerShell 5.1 both write
# the OS separator into entry names, producing "src\scripts\background.js". The ZIP format
# requires forward slashes, and Firefox cannot resolve the manifest's paths without them.
$xpi = Join-Path $DistRoot "channelsieve_${Browser}_v${Version}.xpi"
if (Test-Path $xpi) { Remove-Item -LiteralPath $xpi -Force }

# Both assemblies are needed: ZipFile lives in .FileSystem, ZipArchive/ZipArchiveMode in
# System.IO.Compression itself.
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression
$destFull   = [System.IO.Path]::GetFullPath($Dest)
$zipStream  = [System.IO.File]::Open($xpi, [System.IO.FileMode]::CreateNew)
try {
    $archive = New-Object System.IO.Compression.ZipArchive(
        $zipStream, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($file in Get-ChildItem -LiteralPath $Dest -Recurse -File) {
            $relative = $file.FullName.Substring($destFull.Length).TrimStart('\', '/')
            $entryName = $relative -replace '\\', '/'
            $entry = $archive.CreateEntry($entryName, [System.IO.Compression.CompressionLevel]::Optimal)
            $entryStream = $entry.Open()
            try {
                $fileStream = [System.IO.File]::OpenRead($file.FullName)
                try { $fileStream.CopyTo($entryStream) } finally { $fileStream.Dispose() }
            } finally { $entryStream.Dispose() }
        }
    } finally { $archive.Dispose() }
} finally { $zipStream.Dispose() }

Write-Host ""
Write-Host "Unpacked : $Dest"
Write-Host "Package  : $xpi"
Write-Host ""
Write-Host "To load in Firefox: about:debugging#/runtime/this-firefox -> Load Temporary Add-on"
Write-Host "then pick either the .xpi above or $Dest\manifest.json"
