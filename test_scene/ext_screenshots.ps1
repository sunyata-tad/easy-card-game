# 外部截图：运行测试脚本，在各界面停留时截图
$godot = "D:\游戏开发\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64.exe"
$proj = "D:\游戏开发\项目文件\card"
$outDir = "$env:APPDATA\Godot\app_userdata\card"

Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Drawing;
public class WinCap2 {
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
    public struct RECT { public int Left, Top, Right, Bottom; }
    public static Bitmap Capture(IntPtr hwnd) {
        RECT r; GetWindowRect(hwnd, out r);
        int w = r.Right - r.Left, h = r.Bottom - r.Top;
        if (w <= 0 || h <= 0) return null;
        Bitmap bmp = new Bitmap(w, h);
        Graphics g = Graphics.FromImage(bmp);
        IntPtr hdc = g.GetHdc();
        PrintWindow(hwnd, hdc, 2);
        g.ReleaseHdc(hdc);
        g.Dispose();
        return bmp;
    }
}
"@ -ReferencedAssemblies System.Drawing

$proc = Start-Process -FilePath $godot -ArgumentList "--path", "`"$proj`"", "res://test_scene/test_screenshots.tscn" -PassThru
Start-Sleep -Seconds 4
$hwnd = $proc.MainWindowHandle
Write-Host "HWND=$hwnd"

function Shot($hwnd, $name, $waitSec) {
    Start-Sleep -Seconds $waitSec
    $bmp = [WinCap2]::Capture($hwnd)
    if ($bmp -ne $null) {
        $bmp.Save("$outDir\$name")
        $bmp.Dispose()
        Write-Host "saved $name"
    } else {
        Write-Host "capture null $name"
    }
}

Shot $hwnd "ext_01_main.png" 3
Shot $hwnd "ext_02_prebattle.png" 3
Shot $hwnd "ext_03_battle.png" 3

Start-Sleep -Seconds 2
if (-not $proc.HasExited) { $proc.Kill() }
Write-Host "done"