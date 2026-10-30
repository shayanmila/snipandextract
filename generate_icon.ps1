# Generate a custom 256px Windows icon without external image dependencies.
Add-Type -AssemblyName System.Drawing
$bmp = [System.Drawing.Bitmap]::new(256,256)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::Transparent)
$background = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(8,126,131))
$white = [System.Drawing.Pen]::new([System.Drawing.Color]::White,13)
$white.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$white.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$accent = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(191,245,231))
# Rounded rectangle drawn using a graphics path for compatibility with .NET Framework.
$p = [System.Drawing.Drawing2D.GraphicsPath]::new()
$p.AddArc(12,12,56,56,180,90); $p.AddArc(188,12,56,56,270,90)
$p.AddArc(188,188,56,56,0,90); $p.AddArc(12,188,56,56,90,90); $p.CloseFigure()
$g.FillPath($background,$p)
$g.DrawLine($white,63,111,63,65); $g.DrawLine($white,63,65,111,65)
$g.DrawLine($white,145,65,193,65); $g.DrawLine($white,193,65,193,111)
$g.DrawLine($white,63,145,63,193); $g.DrawLine($white,63,193,111,193)
$g.DrawLine($white,145,193,193,193); $g.DrawLine($white,193,193,193,145)
$g.FillEllipse($accent,104,104,48,48)
$g.DrawLine($white,113,145,151,107)
$png=[System.IO.MemoryStream]::new()
$bmp.Save($png,[System.Drawing.Imaging.ImageFormat]::Png)
$pngBytes=$png.ToArray()
$dest=Join-Path $PSScriptRoot 'windows/runner/resources/app_icon.ico'
$stream=[System.IO.File]::Create($dest)
$writer=[System.IO.BinaryWriter]::new($stream)
$writer.Write([uint16]0);$writer.Write([uint16]1);$writer.Write([uint16]1)
$writer.Write([byte]0);$writer.Write([byte]0);$writer.Write([byte]0);$writer.Write([byte]0)
$writer.Write([uint16]1);$writer.Write([uint16]32)
$writer.Write([uint32]$pngBytes.Length);$writer.Write([uint32]22)
$writer.Write($pngBytes)
$writer.Dispose();$png.Dispose();$p.Dispose();$accent.Dispose();$white.Dispose();$background.Dispose();$g.Dispose();$bmp.Dispose()
Write-Host "Custom app icon generated: $dest"
