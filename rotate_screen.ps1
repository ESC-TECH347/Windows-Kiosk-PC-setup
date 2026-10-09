# Rotate Screen - rotates the primary display 90 degrees clockwise each time it runs.
# Writes what it did (and any error) to rotate.log next to this script.
$log = Join-Path $PSScriptRoot "rotate.log"
function Log($m) { "$(Get-Date -Format s)  $m" | Out-File -FilePath $log -Append -Encoding ascii }

try {
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class DisplayRotation {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
    public struct DEVMODE {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmDeviceName;
        public short dmSpecVersion;
        public short dmDriverVersion;
        public short dmSize;
        public short dmDriverExtra;
        public int dmFields;
        public int dmPositionX;
        public int dmPositionY;
        public int dmDisplayOrientation;
        public int dmDisplayFixedOutput;
        public short dmColor;
        public short dmDuplex;
        public short dmYResolution;
        public short dmTTOption;
        public short dmCollate;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmFormName;
        public short dmLogPixels;
        public int dmBitsPerPel;
        public int dmPelsWidth;
        public int dmPelsHeight;
        public int dmDisplayFlags;
        public int dmDisplayFrequency;
        public int dmICMMethod;
        public int dmICMIntent;
        public int dmMediaType;
        public int dmDitherType;
        public int dmReserved1;
        public int dmReserved2;
        public int dmPanningWidth;
        public int dmPanningHeight;
    }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
    public struct DISPLAY_DEVICE {
        public int cb;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string DeviceName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceString;
        public int StateFlags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceID;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceKey;
    }
    [DllImport("user32.dll")] public static extern int EnumDisplaySettings(string deviceName, int modeNum, ref DEVMODE devMode);
    [DllImport("user32.dll")] public static extern int ChangeDisplaySettingsEx(string deviceName, ref DEVMODE devMode, IntPtr hwnd, int flags, IntPtr param);
    [DllImport("user32.dll")] public static extern bool EnumDisplayDevices(string device, uint devNum, ref DISPLAY_DEVICE dd, uint flags);
}
"@

# Find the primary display's device name (e.g. \\.\DISPLAY1)
$primary = $null
for ($i = 0; $i -lt 16; $i++) {
    $dd = New-Object DisplayRotation+DISPLAY_DEVICE
    $dd.cb = [System.Runtime.InteropServices.Marshal]::SizeOf($dd)
    if (-not [DisplayRotation]::EnumDisplayDevices($null, $i, [ref]$dd, 0)) { break }
    Log "Display $i : $($dd.DeviceName) flags=$($dd.StateFlags) $($dd.DeviceString)"
    if (($dd.StateFlags -band 4) -and -not $primary) { $primary = $dd.DeviceName }
}
Log "Primary display: $primary"

function Try-Rotate($dev, $flags, $label) {
    $dm = New-Object DisplayRotation+DEVMODE
    $dm.dmSize = [System.Runtime.InteropServices.Marshal]::SizeOf($dm)
    $ok = [DisplayRotation]::EnumDisplaySettings($dev, -1, [ref]$dm)
    if ($ok -eq 0) { Log "$label : EnumDisplaySettings failed"; return -99 }
    Log ("$label : current orientation=$($dm.dmDisplayOrientation) size=$($dm.dmPelsWidth)x$($dm.dmPelsHeight) fields=0x{0:X} dmSize=$($dm.dmSize)" -f $dm.dmFields)
    $dm.dmDisplayOrientation = ($dm.dmDisplayOrientation + 1) % 4
    $w = $dm.dmPelsWidth
    $dm.dmPelsWidth = $dm.dmPelsHeight
    $dm.dmPelsHeight = $w
    # DM_DISPLAYORIENTATION (0x80) | DM_PELSWIDTH (0x80000) | DM_PELSHEIGHT (0x100000)
    $dm.dmFields = $dm.dmFields -bor 0x80 -bor 0x80000 -bor 0x100000
    $r = [DisplayRotation]::ChangeDisplaySettingsEx($dev, [ref]$dm, [IntPtr]::Zero, $flags, [IntPtr]::Zero)
    Log "$label : applied orientation=$($dm.dmDisplayOrientation) size=$($dm.dmPelsWidth)x$($dm.dmPelsHeight) flags=$flags result=$r (0=OK -1=failed -2=bad mode -4=bad flags -5=bad param)"
    return $r
}

# Try the most specific call first, then fall back.
$attempts = @()
if ($primary) {
    $attempts += ,@($primary, 1, "named display, save to registry")
    $attempts += ,@($primary, 0, "named display, this session only")
}
$attempts += ,@($null, 1, "default display, save to registry")
$attempts += ,@($null, 0, "default display, this session only")

foreach ($a in $attempts) {
    $res = Try-Rotate $a[0] $a[1] $a[2]
    if ($res -eq 0) { Log "SUCCESS"; break }
}
} catch { Log "ERROR: $_" }
