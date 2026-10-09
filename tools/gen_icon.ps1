# Draws the Math Jump app icon variants (1024x1024 PNG).
#   powershell -ExecutionPolicy Bypass -File .\tools\gen_icon.ps1 <outDir>
param([string]$OutDir = (Join-Path $PSScriptRoot '..\docs\icon-options'))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force $OutDir | Out-Null
$S = 1024

function C($h, $a = 255) { $c = [System.Drawing.ColorTranslator]::FromHtml($h); [System.Drawing.Color]::FromArgb($a, $c) }
function B($h, $a = 255) { New-Object System.Drawing.SolidBrush (C $h $a) }
function P($h, $w) { $p = New-Object System.Drawing.Pen (C $h), $w; $p.LineJoin = 'Round'; $p.StartCap = 'Round'; $p.EndCap = 'Round'; $p }
function RR($x, $y, $w, $h, $r) {
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath; $d = $r * 2
  $p.AddArc($x, $y, $d, $d, 180, 90); $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
  $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90); $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
  $p.CloseFigure(); $p
}
function Font($size) {
  foreach ($n in 'Arial Rounded MT Bold', 'Arial Black', 'Segoe UI Black', 'Arial') {
    $f = New-Object System.Drawing.Font $n, $size, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    if ($f.Name -eq $n) { return $f }
  }
  $f
}
function CenterText($g, $text, $font, $brush, $cx, $cy) {
  $sf = New-Object System.Drawing.StringFormat; $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'
  $g.DrawString($text, $font, $brush, (New-Object System.Drawing.RectangleF ($cx - 300), ($cy - 300), 600, 600), $sf)
}
function OutlinedText($g, $text, $font, $fill, $stroke, $strokeW, $cx, $cy) {
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $sf = New-Object System.Drawing.StringFormat; $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'
  $path.AddString($text, $font.FontFamily, [int]$font.Style, $font.Size, (New-Object System.Drawing.RectangleF ($cx - 500), ($cy - 200), 1000, 400), $sf)
  $g.DrawPath((P $stroke $strokeW), $path)
  $g.FillPath((B $fill), $path)
}

# Chú ếch (vẽ theo hệ tọa độ gốc ~ 580x590, tâm (512,585)), có thể xoay/thu nhỏ.
function Frog($g, $cx, $cy, $scale, $angle, [switch]$Jumping) {
  $state = $g.Save()
  $g.TranslateTransform($cx, $cy); $g.RotateTransform($angle); $g.ScaleTransform($scale, $scale); $g.TranslateTransform(-512, -585)
  $green = B '#5CC85A'; $dark = P '#2F8F3A' 16
  if ($Jumping) {
    # chân duỗi ra khi bật nhảy
    foreach ($s in -1, 1) {
      $leg = New-Object System.Drawing.Drawing2D.GraphicsPath
      $leg.AddBezier((512 + $s * 180), 820, (512 + $s * 260), 900, (512 + $s * 250), 980, (512 + $s * 200), 1010)
      $g.DrawPath((P '#2F8F3A' 70), $leg); $g.DrawPath((P '#5CC85A' 46), $leg)
      $g.FillEllipse($green, (512 + $s * 200 - 55), 985, 110, 50); $g.DrawEllipse((P '#2F8F3A' 10), (512 + $s * 200 - 55), 985, 110, 50)
    }
  }
  $g.FillEllipse($green, 222, 400, 580, 480); $g.DrawEllipse($dark, 222, 400, 580, 480)
  foreach ($x in 250, 554) { $g.FillEllipse($green, $x, 290, 220, 220); $g.DrawEllipse($dark, $x, 290, 220, 220) }
  $g.FillEllipse($green, 240, 420, 544, 200)
  foreach ($x in 285, 589) {
    $g.FillEllipse([System.Drawing.Brushes]::White, $x, 325, 150, 150)
    $g.FillEllipse((B '#3B3355'), ($x + 45), 345, 80, 80)
    $g.FillEllipse([System.Drawing.Brushes]::White, ($x + 80), 358, 24, 24)
  }
  $g.FillEllipse((B '#FF9EC4'), 280, 620, 110, 70); $g.FillEllipse((B '#FF9EC4'), 634, 620, 110, 70)
  $mouth = New-Object System.Drawing.Drawing2D.GraphicsPath
  $mouth.AddArc(372, 500, 280, 240, 15, 150); $mouth.CloseFigure()
  $g.FillPath((B '#E8505B'), $mouth); $g.DrawArc((P '#3B3355' 16), 372, 500, 280, 240, 15, 150)
  $g.Restore($state)
}

# Khối bậc thang 3D có dấu phép tính.
function Block($g, $x, $y, $w, $h, $color, $shade, $symbol, $font) {
  $g.FillPath((B $shade), (RR $x ($y + 22) $w $h 34))
  $g.FillPath((B $color), (RR $x $y $w $h 34))
  $g.DrawPath((P '#FFFFFF' 8), (RR ($x + 4) ($y + 4) ($w - 8) ($h - 8) 30))
  CenterText $g $symbol $font ([System.Drawing.Brushes]::White) ($x + $w / 2) ($y + $h / 2 + 6)
}

function Sky($g, $clouds = @(@(150, 170, 1.0), @(560, 470, 0.6))) {
  $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush ((New-Object System.Drawing.Point 0, 0)), ((New-Object System.Drawing.Point 0, $S)), (C '#6EC3F7'), (C '#D9F2FF')
  $g.FillRectangle($bg, 0, 0, $S, $S)
  $cloud = B '#FFFFFF' 200
  foreach ($c in $clouds) {
    $x = $c[0]; $y = $c[1]; $k = $c[2]
    $g.FillEllipse($cloud, ($x - 70 * $k), ($y - 30 * $k), 140 * $k, 80 * $k)
    $g.FillEllipse($cloud, ($x - 10 * $k), ($y - 60 * $k), 120 * $k, 110 * $k)
    $g.FillEllipse($cloud, ($x + 50 * $k), ($y - 25 * $k), 110 * $k, 75 * $k)
  }
}

function Arc($g, $pts) {
  $pen = P '#FFFFFF' 16; $pen.DashStyle = 'Dot'
  $g.DrawCurve($pen, [System.Drawing.PointF[]]$pts, 0.6)
}

function New-Canvas { $bmp = New-Object System.Drawing.Bitmap $S, $S; $g = [System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBicubic'; @($bmp, $g) }
function Save($bmp, $g, $name) { $bmp.Save((Join-Path $OutDir $name), [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose() }

$sym = Font 150
$colors = @(@('#FF9F43', '#D9760C', '+'), @('#4DABF7', '#1C7ED6', [string][char]0x2212), @('#FF7EB3', '#D6528B', [string][char]0x00D7), @('#9775FA', '#6741D9', [string][char]0x00F7))

# ---- A: bậc thang phép tính + ếch bật nhảy (không chữ) ----
$bmp, $g = New-Canvas; Sky $g
$bw = 200; $bh = 200
for ($i = 0; $i -lt 4; $i++) {
  $x = 70 + $i * 225; $y = 790 - $i * 150
  $g.FillRectangle((B '#FFFFFF' 70), $x, ($y + $bh), $bw, ($S - $y - $bh))
  Block $g $x $y $bw $bh $colors[$i][0] $colors[$i][1] $colors[$i][2] $sym
}
# ếch bay phía trên khối ÷, đường nhảy nét đứt từ khối − lên
Arc $g @((New-Object System.Drawing.PointF 395, 625), (New-Object System.Drawing.PointF 500, 260), (New-Object System.Drawing.PointF 690, 150))
Frog $g 845 175 0.38 6 -Jumping
Save $bmp $g 'icon_A.png'

# ---- B: chữ MATH JUMP ở trên, bậc thang + ếch ở dưới ----
$bmp, $g = New-Canvas; Sky $g @(@(150, 170, 1.0), @(170, 560, 0.7))
for ($i = 0; $i -lt 4; $i++) {
  $x = 70 + $i * 225; $y = 860 - $i * 95
  $g.FillRectangle((B '#FFFFFF' 70), $x, ($y + 150), 200, ($S - $y - 150))
  Block $g $x $y 200 150 $colors[$i][0] $colors[$i][1] $colors[$i][2] (Font 120)
}
Arc $g @((New-Object System.Drawing.PointF 395, 755), (New-Object System.Drawing.PointF 500, 520), (New-Object System.Drawing.PointF 690, 470))
Frog $g 845 480 0.3 6 -Jumping
OutlinedText $g 'MATH' (Font 165) '#FFFFFF' '#6741D9' 32 512 125
OutlinedText $g 'JUMP' (Font 165) '#FFD43B' '#D9480F' 32 512 285
Save $bmp $g 'icon_B.png'

function Gradient($g, $c1, $c2, [switch]$Diagonal) {
  $end = if ($Diagonal) { New-Object System.Drawing.Point $S, $S } else { New-Object System.Drawing.Point 0, $S }
  $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Point 0, 0), $end, (C $c1), (C $c2)
  $g.FillRectangle($brush, 0, 0, $S, $S)
}
function MotionLines($g, $cx, $y) {
  $pen = P '#FFFFFF' 18
  foreach ($dx in -90, 0, 90) { $g.DrawLine($pen, ($cx + $dx), $y, ($cx + $dx * 1.25), ($y + 90)) }
}
function Star($g, $cx, $cy, $r, $fill) {
  $pts = for ($i = 0; $i -lt 10; $i++) {
    $a = -[Math]::PI / 2 + $i * [Math]::PI / 5; $rr = if ($i % 2 -eq 0) { $r } else { $r * 0.45 }
    New-Object System.Drawing.PointF ($cx + $rr * [Math]::Cos($a)), ($cy + $rr * [Math]::Sin($a))
  }
  $g.FillPolygon((B $fill), [System.Drawing.PointF[]]$pts)
  $g.DrawPolygon((P '#E67700' 14), [System.Drawing.PointF[]]$pts)
}

# ---- C: dấu + khổng lồ làm bạt nhún ----
$bmp, $g = New-Canvas; Gradient $g '#9775FA' '#4DABF7' -Diagonal
$soft = B '#FFFFFF' 70; $f2 = Font 170
CenterText $g ([string][char]0x2212) $f2 $soft 150 210; CenterText $g ([string][char]0x00D7) $f2 $soft 880 250; CenterText $g ([string][char]0x00F7) $f2 $soft 150 560; CenterText $g '=' $f2 $soft 880 600
$t = 170; $L = 500; $cx = 512; $cy = 700
foreach ($layer in @(@('#D9760C', 28), @('#FF9F43', 0))) {
  $br = B $layer[0]; $dy = $layer[1]
  $g.FillPath($br, (RR ($cx - $L / 2) ($cy - $t / 2 + $dy) $L $t 60))
  $g.FillPath($br, (RR ($cx - $t / 2) ($cy - $L / 2 + $dy) $t $L 60))
}
$g.DrawPath((P '#FFFFFF' 10), (RR ($cx - $L / 2 + 8) ($cy - $t / 2 + 8) ($L - 16) ($t - 16) 52))
MotionLines $g 512 330
Frog $g 512 175 0.34 0 -Jumping
Save $bmp $g 'icon_C.png'

# ---- D: ếch nhảy ra từ máy tính bỏ túi ----
$bmp, $g = New-Canvas; Gradient $g '#FFE066' '#FF922B'
$g.FillPath((B '#3B3355' 60), (RR 212 482 600 600 70))
$g.FillPath((B '#FFFFFF'), (RR 200 460 624 620 70))
$g.FillPath((B '#D0EBFF'), (RR 250 505 524 120 30))
$g.DrawString('1+2=3', (Font 95), (B '#1C7ED6'), 330, 512)
$keys = @(@('7', '#ADB5BD'), @('8', '#ADB5BD'), @('+', '#FF9F43'), @('4', '#ADB5BD'), @('5', '#ADB5BD'), @([string][char]0x00D7, '#FF7EB3'))
for ($i = 0; $i -lt 6; $i++) {
  $kx = 250 + ($i % 3) * 180; $ky = 660 + [Math]::Floor($i / 3) * 170
  $g.FillPath((B $keys[$i][1]), (RR $kx $ky 155 145 34))
  CenterText $g $keys[$i][0] (Font 100) ([System.Drawing.Brushes]::White) ($kx + 78) ($ky + 76)
}
Arc $g @((New-Object System.Drawing.PointF 300, 500), (New-Object System.Drawing.PointF 340, 250), (New-Object System.Drawing.PointF 460, 170))
Frog $g 620 215 0.36 8 -Jumping
Save $bmp $g 'icon_D.png'

# ---- E: phép tính 2 + ? = 5, ếch nhảy lên ô ? ----
$bmp, $g = New-Canvas; Sky $g @(@(170, 150, 0.9), @(860, 200, 0.6))
$g.FillPath((B '#3B3355' 50), (RR 60 640 904 250 60))
$g.FillPath((B '#FFFFFF'), (RR 60 620 904 250 60))
$fe = Font 190; $ink = B '#3B3355'
CenterText $g '2' $fe $ink 165 750; CenterText $g '+' $fe $ink 315 750
$g.FillPath((B '#FFD43B'), (RR 405 650 190 200 40)); $g.DrawPath((P '#F59F00' 12), (RR 405 650 190 200 40))
CenterText $g '?' $fe $ink 500 752; CenterText $g '=' $fe $ink 690 750; CenterText $g '5' $fe $ink 850 750
# bóng của ếch in trên thẻ phép tính → ếch đang ở trên không
$g.FillEllipse((B '#3B3355' 40), 422, 626, 180, 22)
Frog $g 512 300 0.42 0 -Jumping
Save $bmp $g 'icon_E.png'

# ---- F: cầu thang số 1-2-3, ếch nhảy với ngôi sao ----
$bmp, $g = New-Canvas; Gradient $g '#63E6BE' '#4DABF7'
$steps = @(@('1', '#FF9F43', '#D9760C'), @('2', '#FF7EB3', '#D6528B'), @('3', '#9775FA', '#6741D9'))
for ($i = 0; $i -lt 3; $i++) {
  $x = 80 + $i * 290; $y = 760 - $i * 200; $w = 280
  $g.FillRectangle((B $steps[$i][2]), $x, ($y + 30), $w, ($S - $y))
  $g.FillPath((B $steps[$i][1]), (RR $x $y $w ($S - $y + 60) 40))
  CenterText $g $steps[$i][0] (Font 200) ([System.Drawing.Brushes]::White) ($x + $w / 2) ($y + 130)
}
Star $g 880 130 90 '#FFD43B'
Arc $g @((New-Object System.Drawing.PointF 500, 540), (New-Object System.Drawing.PointF 540, 320), (New-Object System.Drawing.PointF 610, 270))
Frog $g 680 320 0.32 10 -Jumping
Save $bmp $g 'icon_F.png'

# Bản xem nhỏ từng phương án (cỡ biểu tượng thật trên điện thoại)
$names = Get-ChildItem $OutDir -Filter 'icon_?.png' | Sort-Object Name | ForEach-Object { $_.BaseName }
foreach ($n in $names) {
  $src = [System.Drawing.Image]::FromFile((Join-Path $OutDir "$n.png"))
  $sheet = New-Object System.Drawing.Bitmap 360, 130
  $g = [System.Drawing.Graphics]::FromImage($sheet); $g.InterpolationMode = 'HighQualityBicubic'; $g.Clear((C '#F1F3F5'))
  $x = 10
  foreach ($sz in 48, 72, 96) { $g.DrawImage($src, $x, (120 - $sz), $sz, $sz); $x += $sz + 20 }
  $sheet.Save((Join-Path $OutDir "${n}_small.png"), [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $sheet.Dispose(); $src.Dispose()
}

# Bảng so sánh tất cả phương án: hình lớn + cỡ thật bên dưới
$cell = 300; $gap = 30; $cols = $names.Count
$sheet = New-Object System.Drawing.Bitmap ($cols * ($cell + $gap) + $gap), 480
$g = [System.Drawing.Graphics]::FromImage($sheet); $g.InterpolationMode = 'HighQualityBicubic'; $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAlias'
$g.Clear((C '#FFFFFF'))
$lbl = Font 34
for ($i = 0; $i -lt $cols; $i++) {
  $src = [System.Drawing.Image]::FromFile((Join-Path $OutDir "$($names[$i]).png"))
  $x = $gap + $i * ($cell + $gap)
  $clip = RR $x 20 $cell $cell 66
  $g.SetClip($clip); $g.DrawImage($src, $x, 20, $cell, $cell); $g.ResetClip()
  CenterText $g ($names[$i] -replace 'icon_', '') $lbl (B '#3B3355') ($x + $cell / 2) 360
  $g.DrawImage($src, ($x + $cell / 2 - 80), 400, 56, 56); $g.DrawImage($src, ($x + $cell / 2 + 10), 410, 44, 44)
  $src.Dispose()
}
$sheet.Save((Join-Path $OutDir 'compare.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $sheet.Dispose()

Get-ChildItem $OutDir | Select-Object Name, Length
