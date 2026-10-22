Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinTest {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint c, IntPtr e);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, int n);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L; public int T; public int R; public int B; }
}
"@
Add-Type -AssemblyName System.Drawing

$godot = "D:\游戏开发\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64.exe"
$project = "D:\游戏开发\项目文件\card"
$outDir = "D:\游戏开发\项目文件\card\test_scene"

# Start game
$proc = Start-Process -FilePath $godot -ArgumentList "--path", $project -PassThru
Write-Output "Started PID: $($proc.Id)"
Start-Sleep -Seconds 6

function TakeScreenshot($procId, $name) {
    $p = Get-Process -Id $procId -ErrorAction SilentlyContinue
    if (-not $p) { Write-Output "  Process dead for $name"; return $false }
    $h = $p.MainWindowHandle
    $r = New-Object WinTest+RECT
    [WinTest]::GetWindowRect($h, [ref]$r) | Out-Null
    $w = $r.R - $r.L
    $hgt = $r.B - $r.T
    if ($w -le 0 -or $hgt -le 0) { Write-Output "  Bad window size for $name"; return $false }
    $bmp = New-Object System.Drawing.Bitmap($w, $hgt)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $hdc = $g.GetHdc()
    [WinTest]::PrintWindow($h, $hdc, 3) | Out-Null
    $g.ReleaseHdc($hdc)
    $g.Dispose()
    $path = "$outDir\$name"
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Output "  Screenshot: $name ($w x $hgt)"
    return $true
}

function ClickAt($procId, $offX, $offY) {
    $p = Get-Process -Id $procId -ErrorAction SilentlyContinue
    if (-not $p) { return $false }
    $h = $p.MainWindowHandle
    $r = New-Object WinTest+RECT
    [WinTest]::GetWindowRect($h, [ref]$r) | Out-Null
    $cx = [int](($r.L + $r.R) / 2) + $offX
    $cy = [int](($r.T + $r.B) / 2) + $offY
    [WinTest]::SetForegroundWindow($h) | Out-Null
    Start-Sleep -Milliseconds 300
    [WinTest]::SetCursorPos($cx, $cy) | Out-Null
    Start-Sleep -Milliseconds 100
    [WinTest]::mouse_event(2, 0, 0, 0, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 50
    [WinTest]::mouse_event(4, 0, 0, 0, [IntPtr]::Zero)
    return $true
}

$gamePid = $proc.Id

# Screenshot main menu
TakeScreenshot $gamePid "auto_01_menu.png" | Out-Null

# Click "开始游戏" (first button, ~118px above center)
Write-Output "Clicking 开始游戏..."
ClickAt $gamePid 0 -118 | Out-Null
Start-Sleep -Seconds 4
TakeScreenshot $gamePid "auto_02_map.png" | Out-Null

# Click north node (第1层, ~64px above center)
Write-Output "Clicking 第1层 node..."
ClickAt $gamePid 0 -64 | Out-Null
Start-Sleep -Seconds 5
TakeScreenshot $gamePid "auto_03_battle.png" | Out-Null

# Check if still alive
$p = Get-Process -Id $gamePid -ErrorAction SilentlyContinue
if ($p) {
    Write-Output "Game still running: $($p.MainWindowTitle)"
} else {
    Write-Output "Game process died!"
}