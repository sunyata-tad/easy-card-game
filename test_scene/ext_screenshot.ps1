# 外部截图脚本：启动 Godot 主菜单窗口并 PrintWindow 截图
$godot = "D:\游戏开发\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64.exe"
$proj = "D:\游戏开发\项目文件\card"
$outDir = "$env:APPDATA\Godot\app_userdata\card"

Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Drawing;
public class WinCap {
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
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

$proc = Start-Process -FilePath $godot -ArgumentList "--path", "`"$proj`"" -PassThru
Start-Sleep -Seconds 7
$hwnd = $proc.MainWindowHandle
Write-Host "HWND=$hwnd"
if ($hwnd -ne [IntPtr]::Zero) {
    $bmp = [WinCap]::Capture($hwnd)
    if ($bmp -ne $null) {
        $bmp.Save("$outDir\ext_main.png")
        $bmp.Dispose()
        Write-Host "saved ext_main.png"
    } else {
        Write-Host "capture null"
    }
}
Start-Sleep -Seconds 1
if (-not $proc.HasExited) { $proc.Kill() }
Write-Host "done"