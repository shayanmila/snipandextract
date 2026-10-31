param([ValidateSet('capture','ocr','copyImage')][string]$Action,[string]$Payload,[string]$PayloadFile)
$ErrorActionPreference='Stop'
# Use physical pixels for both the selection overlay and screen capture.
# DPI awareness must be enabled before Windows Forms creates a window.
if ($Action -eq 'capture') {
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class CaptureDpi {
 [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr context);
 [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
'@
try {
  if (-not [CaptureDpi]::SetProcessDpiAwarenessContext([IntPtr](-4))) {
    [void][CaptureDpi]::SetProcessDPIAware()
  }
} catch { [void][CaptureDpi]::SetProcessDPIAware() }
}
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
function OutJson($obj){[Console]::Out.WriteLine(($obj|ConvertTo-Json -Compress -Depth 5))}
if($Action -eq 'capture'){
Add-Type -ReferencedAssemblies System.Windows.Forms,System.Drawing -TypeDefinition @'
using System;using System.Drawing;using System.Windows.Forms;
public class ScreenSelect : Form {
 public Rectangle Selection=Rectangle.Empty; Point start; bool dragging=false;
 public ScreenSelect(){FormBorderStyle=FormBorderStyle.None;ShowInTaskbar=false;TopMost=true;Cursor=Cursors.Cross;DoubleBuffered=true;KeyPreview=true;BackColor=Color.Black;Opacity=.20;var bounds=SystemInformation.VirtualScreen;StartPosition=FormStartPosition.Manual;Location=bounds.Location;Size=bounds.Size;
 MouseDown+=(s,e)=>{if(e.Button==MouseButtons.Left){start=Cursor.Position;dragging=true;}};
 MouseMove+=(s,e)=>{if(dragging)Invalidate();};
 MouseUp+=(s,e)=>{if(dragging){dragging=false;var end=Cursor.Position;int x=Math.Min(start.X,end.X),y=Math.Min(start.Y,end.Y),w=Math.Abs(start.X-end.X),h=Math.Abs(start.Y-end.Y);if(w>1&&h>1){Selection=new Rectangle(x,y,w,h);DialogResult=DialogResult.OK;}else DialogResult=DialogResult.Cancel;Close();}};
 KeyDown+=(s,e)=>{if(e.KeyCode==Keys.Escape){DialogResult=DialogResult.Cancel;Close();}};}
 protected override void OnPaint(PaintEventArgs e){base.OnPaint(e);if(dragging){var a=PointToClient(start);var m=PointToClient(Cursor.Position);var r=Rectangle.FromLTRB(Math.Min(a.X,m.X),Math.Min(a.Y,m.Y),Math.Max(a.X,m.X),Math.Max(a.Y,m.Y));using(var p=new Pen(Color.White,2))e.Graphics.DrawRectangle(p,r);}}
}
'@
$form=[ScreenSelect]::new();try{if($form.ShowDialog() -ne [Windows.Forms.DialogResult]::OK){OutJson @{cancelled=$true};exit 0};$rect=$form.Selection}finally{$form.Dispose()}
Start-Sleep -Milliseconds 200
$bmp=[Drawing.Bitmap]::new($rect.Width,$rect.Height);try{$gfx=[Drawing.Graphics]::FromImage($bmp);try{$gfx.CopyFromScreen($rect.Location,[Drawing.Point]::Empty,$rect.Size)}finally{$gfx.Dispose()};$ms=[IO.MemoryStream]::new();try{$bmp.Save($ms,[Drawing.Imaging.ImageFormat]::Png);OutJson @{image=[Convert]::ToBase64String($ms.ToArray());width=$rect.Width;height=$rect.Height}}finally{$ms.Dispose()}}finally{$bmp.Dispose()};exit 0
}
if ($PayloadFile) {
  if (-not [IO.File]::Exists($PayloadFile)) { throw "Payload file not found" }
  $data = ConvertFrom-Json ([IO.File]::ReadAllText($PayloadFile, [Text.Encoding]::UTF8))
} elseif ($Payload) {
  $data = ConvertFrom-Json ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Payload)))
} else {
  throw 'No payload supplied'
}
if($Action -eq 'copyImage'){$bytes=[Convert]::FromBase64String($data.image);$stream=[IO.MemoryStream]::new($bytes);$bmp=[Drawing.Bitmap]::new($stream);try{[Windows.Forms.Clipboard]::SetImage($bmp);OutJson @{ok=$true}}finally{$bmp.Dispose();$stream.Dispose()};exit 0}
if($Action -eq 'ocr'){
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null=[Windows.Media.Ocr.OcrEngine,Windows.Foundation,ContentType=WindowsRuntime]
$null=[Windows.Graphics.Imaging.BitmapDecoder,Windows.Foundation,ContentType=WindowsRuntime]
$null=[Windows.Storage.Streams.DataWriter,Windows.Foundation,ContentType=WindowsRuntime]
function Await($op,$t){$m=[System.WindowsRuntimeSystemExtensions].GetMethods()|Where-Object{$_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1}|Select-Object -First 1;$task=$m.MakeGenericMethod($t).Invoke($null,@($op));$task.Wait();return $task.Result}
$bytes=[Convert]::FromBase64String($data.image);$stream=[Windows.Storage.Streams.InMemoryRandomAccessStream]::new();$writer=[Windows.Storage.Streams.DataWriter]::new($stream);$writer.WriteBytes($bytes);$null=Await ($writer.StoreAsync()) ([uint32]);$writer.DetachStream()|Out-Null;$stream.Seek(0);$decoder=Await ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder]);$bitmap=Await ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap]);$engine=[Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages();if($null -eq $engine){throw 'Windows OCR language not installed'};$result=Await ($engine.RecognizeAsync($bitmap)) ([Windows.Media.Ocr.OcrResult]);OutJson @{text=$result.Text};exit 0
}
