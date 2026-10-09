$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;

public static class MutcoIconBuilder {
  public static void Resize(string input, string output, int size, double fraction, bool removeCream) {
    using (var source = new Bitmap(input))
    using (var cleaned = new Bitmap(source.Width, source.Height, PixelFormat.Format32bppArgb)) {
      for (int y = 0; y < source.Height; y++) {
        for (int x = 0; x < source.Width; x++) {
          var color = source.GetPixel(x, y);
          if (removeCream && color.R > 224 && color.G > 206 && color.B > 174 && color.R > color.G && color.G > color.B) {
            cleaned.SetPixel(x, y, Color.Transparent);
          } else {
            cleaned.SetPixel(x, y, color);
          }
        }
      }
      using (var target = new Bitmap(size, size, PixelFormat.Format32bppArgb))
      using (var graphics = Graphics.FromImage(target)) {
        graphics.Clear(Color.Transparent);
        graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;
        graphics.SmoothingMode = SmoothingMode.HighQuality;
        int drawn = (int)Math.Round(size * fraction);
        int offset = (size - drawn) / 2;
        graphics.DrawImage(cleaned, new Rectangle(offset, offset, drawn, drawn),
          new Rectangle(0, 0, source.Width, source.Height), GraphicsUnit.Pixel);
        target.Save(output, ImageFormat.Png);
      }
    }
  }
}
'@

$project = (Get-Location).Path
$launcher = Join-Path $project 'FileApp/icon.png'
$loading = Join-Path $project 'FileApp/uiscreen/iconloadingscreen.png'
$res = Join-Path $project 'android/app/src/main/res'
$densities = @{
  'mdpi' = @(48, 108, 220, 288)
  'hdpi' = @(72, 162, 330, 432)
  'xhdpi' = @(96, 216, 440, 576)
  'xxhdpi' = @(144, 324, 660, 864)
  'xxxhdpi' = @(192, 432, 880, 1152)
}
foreach ($density in $densities.Keys) {
  $sizes = $densities[$density]
  $mipmap = Join-Path $res "mipmap-$density"
  $drawable = Join-Path $res "drawable-$density"
  New-Item -ItemType Directory -Force -Path $mipmap, $drawable | Out-Null
  [MutcoIconBuilder]::Resize($launcher, (Join-Path $mipmap 'ic_launcher.png'), $sizes[0], 1.0, $false)
  [MutcoIconBuilder]::Resize($launcher, (Join-Path $mipmap 'ic_launcher_foreground.png'), $sizes[1], 1.0, $false)
  [MutcoIconBuilder]::Resize($loading, (Join-Path $drawable 'loading_icon.png'), $sizes[2], 1.0, $false)
  [MutcoIconBuilder]::Resize($loading, (Join-Path $drawable 'splash_icon.png'), $sizes[3], 0.60, $false)
}
