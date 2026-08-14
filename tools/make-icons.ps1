<#
.SYNOPSIS
    Generates the ChannelSieve extension icons.

.DESCRIPTION
    Draws a sieve/funnel glyph on a rounded teal tile and writes 16/48/128px PNGs into
    assets/icons/. Kept in the repo so the icons are reproducible and tweakable rather
    than being opaque binaries.

    The artwork is drawn once at high resolution and downsampled, which antialiases far
    better than drawing the small sizes directly. 16px is the real constraint -- it is the
    toolbar size -- so the glyph is deliberately chunky, with no thin strokes or detail
    that would turn to mud.

.EXAMPLE
    .\tools\make-icons.ps1
#>
[CmdletBinding()]
param(
    [string]$OutDir,
    [int[]]$Sizes = @(16, 48, 128)
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

if (-not $OutDir) {
    $OutDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'assets\icons'
}
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

$MasterSize     = 512
$TILE       = [System.Drawing.ColorTranslator]::FromHtml('#0F766E')  # deep teal
$TILE_EDGE  = [System.Drawing.ColorTranslator]::FromHtml('#0B5D56')  # subtle darker rim
$GLYPH      = [System.Drawing.ColorTranslator]::FromHtml('#FFFFFF')

function New-RoundedRectPath {
    param([float]$x, [float]$y, [float]$w, [float]$h, [float]$r)
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $path.AddArc($x,             $y,             $d, $d, 180, 90)
    $path.AddArc($x + $w - $d,   $y,             $d, $d, 270, 90)
    $path.AddArc($x + $w - $d,   $y + $h - $d,   $d, $d,   0, 90)
    $path.AddArc($x,             $y + $h - $d,   $d, $d,  90, 90)
    $path.CloseFigure()
    return $path
}

# ---- draw the master ----
$masterBmp = New-Object System.Drawing.Bitmap($MasterSize, $MasterSize, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($masterBmp)
$g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.Clear([System.Drawing.Color]::Transparent)

$m = $MasterSize

# Rounded tile
$tilePath = New-RoundedRectPath -x ($m * 0.03) -y ($m * 0.03) -w ($m * 0.94) -h ($m * 0.94) -r ($m * 0.22)
$tileBrush = New-Object System.Drawing.SolidBrush($TILE)
$g.FillPath($tileBrush, $tilePath)
$rimPen = New-Object System.Drawing.Pen($TILE_EDGE, ($m * 0.02))
$g.DrawPath($rimPen, $tilePath)

# Funnel glyph: wide mouth tapering to a spout. A filter, not a slash -- deliberately
# nothing like upstream's red circle-and-bar mark.
$glyphBrush = New-Object System.Drawing.SolidBrush($GLYPH)
$funnel = New-Object System.Drawing.Drawing2D.GraphicsPath
$pts = @(
    (New-Object System.Drawing.PointF(($m * 0.17), ($m * 0.235))),
    (New-Object System.Drawing.PointF(($m * 0.83), ($m * 0.235))),
    (New-Object System.Drawing.PointF(($m * 0.585), ($m * 0.525))),
    (New-Object System.Drawing.PointF(($m * 0.585), ($m * 0.775))),
    (New-Object System.Drawing.PointF(($m * 0.415), ($m * 0.775))),
    (New-Object System.Drawing.PointF(($m * 0.415), ($m * 0.525)))
)
$funnel.AddPolygon($pts)
$g.FillPath($glyphBrush, $funnel)

# Two grains dropping out of the spout -- what the sieve rejects. Large enough to survive
# the downsample to 16px as visible dots rather than grey smudges.
$g.FillEllipse($glyphBrush, ($m * 0.455), ($m * 0.835), ($m * 0.09), ($m * 0.09))
$g.FillEllipse($glyphBrush, ($m * 0.665), ($m * 0.66),  ($m * 0.075), ($m * 0.075))

$g.Dispose()

# ---- downsample and save ----
foreach ($size in $Sizes) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $gs = [System.Drawing.Graphics]::FromImage($bmp)
    $gs.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $gs.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $gs.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $gs.Clear([System.Drawing.Color]::Transparent)
    $gs.DrawImage($masterBmp, (New-Object System.Drawing.Rectangle(0, 0, $size, $size)))
    $gs.Dispose()

    $out = Join-Path $OutDir "$size.png"
    $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host ("wrote {0} ({1}x{1})" -f $out, $size)
}

$masterBmp.Dispose()
