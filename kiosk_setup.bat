@echo off
setlocal EnableDelayedExpansion

:: ==================================================================
::  Kiosk / Always-On PC Setup Script
:: ==================================================================
::  What this does:
::   1. Windows Update: instead of blocking it, restricts it to a
::      1 AM - 9 AM install window (Active Hours 9 AM-1 AM), with a
::      forced unattended reboot and update deferral so it's never
::      first-in-line for a bad patch
::   2. Power plan: display never turns off, PC never sleeps,
::      hibernate off, screensaver disabled
::   3. Power button and sleep button set to "Do nothing"
::   4. Fast Startup disabled
::   5. Sets DevicePasswordLessBuildVersion to 0 (re-enables normal
::      password sign-in / auto-logon support)
::   6. Turns off Notifications + the two "suggestions/tips" toggles
::   7. Turns on automatic time zone detection (locations span
::      multiple zones, so this is location-based, not hardcoded)
::   8. Opens netplwiz for the one step that still needs a click
::      (Windows won't let a script silently uncheck that box or
::      type an account password for you)
::   9. Drops an "Update PC Kiosk Settings" desktop icon that re-runs
::      the latest version of this script straight from SCRIPT_URL -
::      future changes just mean editing that file on GitHub and
::      having someone click the icon, nothing to redistribute
::  10. Drops a "Rotate Screen" desktop icon - each click rotates the
::      display 90 degrees clockwise, no admin prompt needed
::
::  IMPORTANT: Run this WHILE LOGGED INTO the actual kiosk/game
::  station user account, using "Run as administrator" (right-click
::  > Run as administrator). Several settings below (screensaver,
::  notifications) live in HKEY_CURRENT_USER, so they apply to
::  whichever account is logged in when the script runs.
:: ==================================================================

:: --- EDIT ME: tune these for this PC's site/schedule ---
set INSTALL_HOUR=4
set ACTIVE_HOURS_START=9
set ACTIVE_HOURS_END=1
set DEFER_FEATURE_DAYS=60
set DEFER_QUALITY_DAYS=4

:: --- EDIT ME: raw GitHub URL to this same file, once it's hosted there.
::     This is what the "Update PC Kiosk Settings" icon re-downloads and
::     re-runs every time someone clicks it, so pushing an update just
::     means editing the file at this URL - no need to touch each PC again.
set SCRIPT_URL=https://raw.githubusercontent.com/ESC-TECH347/Windows-Kiosk-PC-setup/main/kiosk_setup.bat

:: --- Confirm we are elevated ---
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo This script must be run as Administrator.
    echo Right-click the file and choose "Run as administrator".
    pause
    exit /b 1
)

echo.
echo ===============================================
echo  Step 1: Windows Update - restrict to 1 AM - 9 AM window
echo ===============================================

:: In case this machine previously had the full-block reapply tasks
:: registered - remove them so they don't fight this setup.
schtasks /delete /tn "Kiosk - Reapply Update Block (Startup)" /f >nul 2>&1
schtasks /delete /tn "Kiosk - Reapply Update Block (Weekly)" /f >nul 2>&1

:: Make sure the Update services are enabled and running.
sc config wuauserv start= demand
net start wuauserv

sc config UsoSvc start= auto
net start UsoSvc

sc config WaaSMedicSvc start= demand >nul 2>&1
net start WaaSMedicSvc >nul 2>&1

:: Clear any prior full block, then set scheduled-install options.
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v SetDisableUXWUAccess /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions /t REG_DWORD /d 4 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v ScheduledInstallDay /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v ScheduledInstallTime /t REG_DWORD /d %INSTALL_HOUR% /f

:: Active Hours: no auto-restart 9 AM - 1 AM, so it can only
:: restart 1 AM - 9 AM.
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v SetActiveHours /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v ActiveHoursStart /t REG_DWORD /d %ACTIVE_HOURS_START% /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v ActiveHoursEnd /t REG_DWORD /d %ACTIVE_HOURS_END% /f
reg add "HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" /v IsActiveHoursEnabled /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" /v ActiveHoursStart /t REG_DWORD /d %ACTIVE_HOURS_START% /f
reg add "HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" /v ActiveHoursEnd /t REG_DWORD /d %ACTIVE_HOURS_END% /f

:: Force the reboot to actually happen even though the kiosk
:: account stays logged in 24/7 (otherwise Windows waits forever
:: for a "logout" that never comes).
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoRebootWithLoggedOnUsers /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AlwaysAutoRebootAtScheduledTime /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AlwaysAutoRebootAtScheduledTimeMinutes /t REG_DWORD /d 15 /f

:: Defer updates so this machine isn't first to hit a bad patch.
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v DeferFeatureUpdates /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v DeferFeatureUpdatesPeriodInDays /t REG_DWORD /d %DEFER_FEATURE_DAYS% /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v DeferQualityUpdates /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v DeferQualityUpdatesPeriodInDays /t REG_DWORD /d %DEFER_QUALITY_DAYS% /f

echo.
echo ===============================================
echo  Step 2: Power plan - never sleep, never turn off display
echo ===============================================
powercfg /change monitor-timeout-ac 0
powercfg /change monitor-timeout-dc 0
powercfg /change standby-timeout-ac 0
powercfg /change standby-timeout-dc 0
powercfg /change hibernate-timeout-ac 0
powercfg /change hibernate-timeout-dc 0
powercfg /change disk-timeout-ac 0
powercfg /change disk-timeout-dc 0
powercfg /hibernate off

echo.
echo ===============================================
echo  Step 3: Power button / Sleep button - do nothing
echo ===============================================
powercfg /setacvalueindex scheme_current sub_buttons pbuttonaction 0
powercfg /setdcvalueindex scheme_current sub_buttons pbuttonaction 0
powercfg /setacvalueindex scheme_current sub_buttons sbuttonaction 0
powercfg /setdcvalueindex scheme_current sub_buttons sbuttonaction 0
powercfg /setactive scheme_current

echo.
echo ===============================================
echo  Step 4: Disabling screen saver (current user)
echo ===============================================
reg add "HKCU\Control Panel\Desktop" /v ScreenSaveActive /t REG_SZ /d 0 /f
reg add "HKCU\Control Panel\Desktop" /v SCRNSAVE.EXE /t REG_SZ /d "" /f

echo.
echo ===============================================
echo  Step 5: Disabling Fast Startup
echo ===============================================
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 0 /f

echo.
echo ===============================================
echo  Step 6: DevicePasswordLessBuildVersion -^> 0
echo ===============================================
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device" /v DevicePasswordLessBuildVersion /t REG_DWORD /d 0 /f

echo.
echo ===============================================
echo  Step 7: Turning off notifications ^& "tips" toggles
echo ===============================================
:: Master Notifications switch (Settings ^> System ^> Notifications)
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\PushNotifications" /v ToastEnabled /t REG_DWORD /d 0 /f

:: "Get tips, tricks, and suggestions as you use Windows"
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338389Enabled /t REG_DWORD /d 0 /f

:: "Suggest ways I can finish setting up my device to get the most out of Windows"
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338387Enabled /t REG_DWORD /d 0 /f

echo.
echo ===============================================
echo  Step 8: Time zone - set automatically by location
echo ===============================================
:: This fleet spans multiple time zones, so instead of a single
:: hardcoded value in this shared script, each PC works out its own
:: correct zone using Windows location services.
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /v Value /t REG_SZ /d Allow /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\tzautoupdate" /v Start /t REG_DWORD /d 3 /f
sc start tzautoupdate >nul 2>&1

echo.
echo ===============================================
echo  Step 9: Opening Local Users (netplwiz)
echo ===============================================
echo   This last step needs a manual click because Windows requires
echo   an actual button click and password entry here - it can't be
echo   scripted safely:
echo.
echo     1. Uncheck "Users must enter a user name and password to
echo        use this computer"
echo     2. Click Apply
echo     3. Enter this account's username and password when prompted,
echo        click OK, then OK again
echo.
start netplwiz

echo.
echo ===============================================
echo  Step 10: Creating the "Update PC Kiosk Settings" desktop icon
echo ===============================================
echo   This icon re-downloads and re-runs the latest version of this
echo   script straight from GitHub, so future changes just mean
echo   editing the file at SCRIPT_URL and having someone click it -
echo   nothing to redistribute or copy onto the PC again.

powershell -NoProfile -ExecutionPolicy Bypass -EncodedCommand JAB3AHMAIAA9ACAATgBlAHcALQBPAGIAagBlAGMAdAAgAC0AQwBvAG0ATwBiAGoAZQBjAHQAIABXAFMAYwByAGkAcAB0AC4AUwBoAGUAbABsAAoAJABkAGUAcwBrAHQAbwBwACAAPQAgACQAdwBzAC4AUwBwAGUAYwBpAGEAbABGAG8AbABkAGUAcgBzACgAIgBBAGwAbABVAHMAZQByAHMARABlAHMAawB0AG8AcAAiACkACgAkAHAAYQB0AGgAIAA9ACAASgBvAGkAbgAtAFAAYQB0AGgAIAAkAGQAZQBzAGsAdABvAHAAIAAiAFUAcABkAGEAdABlACAAUABDACAASwBpAG8AcwBrACAAUwBlAHQAdABpAG4AZwBzAC4AbABuAGsAIgAKACQAdQByAGwAIAA9ACAAJABlAG4AdgA6AFMAQwBSAEkAUABUAF8AVQBSAEwACgAkAGkAbgBuAGUAcgAgAD0AIAAnAGkAcgBtACAAJwAgACsAIAAkAHUAcgBsACAAKwAgACcAIAAtAE8AdQB0AEYAaQBsAGUAIAAkAGUAbgB2ADoAVABFAE0AUABcAGsAaQBvAHMAawBfAHMAZQB0AHUAcAAuAGIAYQB0ADsAIAAmACAAJABlAG4AdgA6AFQARQBNAFAAXABrAGkAbwBzAGsAXwBzAGUAdAB1AHAALgBiAGEAdAAnAAoAJABzAGgAbwByAHQAYwB1AHQAIAA9ACAAJAB3AHMALgBDAHIAZQBhAHQAZQBTAGgAbwByAHQAYwB1AHQAKAAkAHAAYQB0AGgAKQAKACQAcwBoAG8AcgB0AGMAdQB0AC4AVABhAHIAZwBlAHQAUABhAHQAaAAgAD0AIAAiAHAAbwB3AGUAcgBzAGgAZQBsAGwALgBlAHgAZQAiAAoAJABzAGgAbwByAHQAYwB1AHQALgBBAHIAZwB1AG0AZQBuAHQAcwAgAD0AIAAnAC0ATgBvAFAAcgBvAGYAaQBsAGUAIAAtAEUAeABlAGMAdQB0AGkAbwBuAFAAbwBsAGkAYwB5ACAAQgB5AHAAYQBzAHMAIAAtAEMAbwBtAG0AYQBuAGQAIAAiACcAIAArACAAJABpAG4AbgBlAHIAIAArACAAJwAiACcACgAkAHMAaABvAHIAdABjAHUAdAAuAEkAYwBvAG4ATABvAGMAYQB0AGkAbwBuACAAPQAgACIAcABvAHcAZQByAHMAaABlAGwAbAAuAGUAeABlACwAMAAiAAoAJABzAGgAbwByAHQAYwB1AHQALgBEAGUAcwBjAHIAaQBwAHQAaQBvAG4AIAA9ACAAIgBSAGUALQBkAG8AdwBuAGwAbwBhAGQAcwAgAGEAbgBkACAAcgBlAC0AYQBwAHAAbABpAGUAcwAgAHQAaABlACAAbABhAHQAZQBzAHQAIABrAGkAbwBzAGsAIABzAGUAdAB1AHAAIABmAHIAbwBtACAARwBpAHQASAB1AGIAIgAKACQAcwBoAG8AcgB0AGMAdQB0AC4AVwBvAHIAawBpAG4AZwBEAGkAcgBlAGMAdABvAHIAeQAgAD0AIAAkAGUAbgB2ADoAVABFAE0AUAAKACQAcwBoAG8AcgB0AGMAdQB0AC4AUwBhAHYAZQAoACkACgAkAGIAeQB0AGUAcwAgAD0AIABbAFMAeQBzAHQAZQBtAC4ASQBPAC4ARgBpAGwAZQBdADoAOgBSAGUAYQBkAEEAbABsAEIAeQB0AGUAcwAoACQAcABhAHQAaAApAAoAJABiAHkAdABlAHMAWwAwAHgAMQA1AF0AIAA9ACAAJABiAHkAdABlAHMAWwAwAHgAMQA1AF0AIAAtAGIAbwByACAAMAB4ADIAMAAKAFsAUwB5AHMAdABlAG0ALgBJAE8ALgBGAGkAbABlAF0AOgA6AFcAcgBpAHQAZQBBAGwAbABCAHkAdABlAHMAKAAkAHAAYQB0AGgALAAgACQAYgB5AHQAZQBzACkACgBXAHIAaQB0AGUALQBIAG8AcwB0ACAAIgBEAGUAcwBrAHQAbwBwACAAcwBoAG8AcgB0AGMAdQB0ACAAYwByAGUAYQB0AGUAZAAvAHUAcABkAGEAdABlAGQAOgAgACQAcABhAHQAaAAiAAoA

echo.
echo ===============================================
echo  Step 11: Installing the Rotate Screen icon image
echo ===============================================

powershell -NoProfile -ExecutionPolicy Bypass -EncodedCommand JABkACAAPQAgACIAQwA6AFwAUAByAG8AZwByAGEAbQBEAGEAdABhAFwASwBpAG8AcwBrAFMAZQB0AHUAcAAiAAoATgBlAHcALQBJAHQAZQBtACAALQBJAHQAZQBtAFQAeQBwAGUAIABEAGkAcgBlAGMAdABvAHIAeQAgAC0AUABhAHQAaAAgACQAZAAgAC0ARgBvAHIAYwBlACAAfAAgAE8AdQB0AC0ATgB1AGwAbAAKACQAYgAgAD0AIABbAEMAbwBuAHYAZQByAHQAXQA6ADoARgByAG8AbQBCAGEAcwBlADYANABTAHQAcgBpAG4AZwAoACIAQQBBAEEAQgBBAEEARQBBAEkAQwBBAEEAQQBBAEEAQQBJAEEARABGAEIAUQBBAEEARgBnAEEAQQBBAEkAbABRAFQAawBjAE4AQwBoAG8ASwBBAEEAQQBBAEQAVQBsAEkAUgBGAEkAQQBBAEEAQQBnAEEAQQBBAEEASQBBAGcARwBBAEEAQQBBAGMAMwBwADYAOQBBAEEAQQBCAFkAeABKAFIARQBGAFUAZQBKAHoATgBsADEAMgBJAFgAVgBjAFYAeAAzADkAcgA3ADMAUAB1AGYAQwBXAFQAeQBVAHoAaQBUAEUAWgBiAHMAWQBSAGkAbwAwADkAYQBVAEMAUQAyADAAMwB5AEkARAAxAEkAUgB1AFIAVwBxAFkAcAB4AEsATgBQAGkAUwBLAEoAVAA2AG8ARABmAG4AVABZAG8AMABJAGgAUQAwADEASwBRAG8AOQBtAEYARwBVAEkAcwBVAFEANQBqAE0AVABTAHQAQwBKAGQAbwBYAHUAVQBwAEoAcQBoAGkAWQB5AFQAUwBaAE4AcABQAE0AbgBUAHYAMwBmAEsAegBsAHcAegBrADMATQAzAGMAbQA4ADUARgBvADEAZgBWAHcANABYAEQAMgBYAGYALwAvAC8AcQArADEAOQB2ADQAZgBlAEYAZgBEAFoASwBNAFYARwB5ADUAWQBsAGIAQwBNAFkAMAA5AFYAcQBGADAAegB4AHMAcwBLAFEASABuAGMAcwBXAGUAbgBVAEIAcwB4AHgAbABFAFEAYQB5AGUAeAAvAFAAbABlAHcAawB3AG8AbQA5AC8AMAArAG4AMgBUAFEAVQA2ADIANwBKAGQASQAzAEQAbQBDAEQAWgBPAFYAeAB6AHcAaQBHAFoAQQBOAGYALwBQAGMAZwBNAFoAZABJADUARAB1AEYAYgBNAEgAVQBkADAAQgBnAEgAUABYAFQAZQBRAE4AQwBIADcAdgBTAG0ARgAxADYAcgBtAFAAegBRAEkATQBiADYAdQArAGIASQBlAC8ALwBwADMAcABGACsAVABQAFYATQB3AFIAaQBhADUATQB2ADMANABKAHkAbQBPAGUAOABjAGUAegA0AGMATwAvAHUAOAA5AEsAWABjAGMAeABuAG4AQgBCAHgAeQBEAGkATQBGAFAAUQBJAHAAOQB6AGkARABnAHcAeABiAEwAawBtAHEAWAB4AEsAWQBXADUAYwBNAHYATwBaADkATAA2ADkAZABmADcAYgA3ADcAbgA0AHoAVgBxAFcAVgA2AHkAOQBuAEsAcwBSAFUAQQBvAGoAegBuAEcASAA4ACsARwBSAHkAZABHAEwAUQBpAGYAYwBVAEgAWABnAEMAVgAxAFQATgBNAE0AdwB4AEIAcAAvADYAKwBaAEkAUQBnAHUAOQBPAEoARAAwAEIAUgBMADQAOABSADEAYgBnAHUAMQBjAGUAUABIADAAMgBjAE8ASABhAFUAeQBHAFIAQQA5AG0AbQA1AEUANABEAGIANAByAHEAKwBkAGYAOQBhAFYAdABoADYAMwB1AEkANQBwAGsAaQBMAGkAUQBTAFQAZgBQAGkAdgBsAEwARwBSAEEARABZAHYARgBLAEIAWABQAHEAUwB0AHQAQwBkAEwARgB1AFMALwBNAG4AUABuAFUARwBQAHMAbQBBAHkANABzAGsAVgBoAE4AbwBHAHkAZQBjAGMAbQBHAFIAcwArAGQAOQBOADAARAB4ADcAVAB4AGQAbwByAGgAawBkAHYAQQBTAE4AagBwAHgASgBmAGEAQgBVAGgAagBMAEcAdQBDAFcAUQBMADQAQQBoAHcATQB4AFEAVQBnAHoASwBmAE4AOQBDAFAAWABmAG4AYgBnADgAdgBKACsAYQBHAC8AQwA4AHAAaABuAFgATABMAEIAMABiAE8ASABmAFYAZgBmAE0AVgAxADQASgAwAEUASQBjAG4AQgBWAEMAVABvAGQATABzAEMAUwBSAHMAMgBTADUAcQBzAEcAbAA0AHAAZAA3AE0AYgBKAEkAegBqAC8AawBHAGwAcQBRAGcARwBlAHYAMwBSAG8AawBrAG0AcABwAHoAYwBJADAAMQA5AFEAbQBkAHgATABEAFcAdQBOADUANQBJAEMAbABZAG8AagBPAG0ARQA3AGoAcgB3AHkARgBLAHIAOQBGAFoARwB0AFoARwBtAGUAQQBNAHMAawA3AFAARwBXAHgAWgBjAE0AbgByADQANgByAEwAOQBaAFcAVQB1AEEAbwBTAGMAbgB2AHUAdgBDADcAbwByAEYAZABVAFUASQBDAG8ARgB6AEQATgBQAFUAZABXADAAUABkAE8ASABHAHMAOQBOAG4ARABuADYANwAxAFEAOQBMAEMAbABSAEgASABFAGcAYQBaAEIATgBQAHUAWQA3AGUAYgBiAHAANABJADAAVgBjAGcASwBsAEsAYQBZAHUAMwB0AFAAawBIAGEAUwBhAFAAVABmAC8AOAAwAEMAeQBRAHoALwBvAEkATQBMADEAVgBBAFAAcgByAGIAMwBVAEIAVAAwAGoAUQA2AGQASABFAG0AeABsAG8AQgBxAGEARwBvAE8AQgBNAEYAKwBjAFcAcABkAFIANQBmAFAAQwByADUAeQBaAG4AbwBrAGQALwBTADMAbgBNAEYAdwByAGsAYwB0AHgALwA5AE4AWAB0AGMAYgBOADUAVwBYAHoAUQBoADYAWgBnAFkAaABLAFUAeABDAHoAOQBSADEAaQB2AGYALwBTAGYATAAzADcAbQBIAFkANQBjAEQARABuADEAYwBOAEsAdQBYAEsAUwBEAG8AMgBjAC8ANwBJAEwAdQA3ADUARQAxAEIAdwB3AFoAeAB0AGcAaABRAHAALwA0AFUAbwBBAFAAOAAvADQAMQBCAGUAZgBSADUAbgB3AFMAdQBPAHkAaABLADYAYwBPAFgASgBiADIAeABqAHYALwBlAGQALwBSAC8AVQB1AE4ANQB6AE0AUQBEADIAUgBTADYAdgBIAFcAbgBQAC8AYwA5AE8AbQBEAHYAMQA0AEYAdgBtAGEAWQBQAEgARABrAFQANwAyADMAbQBOAHMAUgBXAGoAQwBvAGEAdQAvAEYAMgBmAHQAUQB1ADEAOQBNAGQAMABuAEgAbABnADkAbwB2AFAAQwBYAC8AcAB2AFgAagArAFkAbAAyAEYAUABOAGkAVABoADcAQgBQAEcARwBZAFcAQQBxAFkAYQBmAFgANQBxADIALwBYAGIAMwB2ADQARQB2ADUAVABoADkAZQBWAGYAZgBsAG8ATwB5AHIAZQBrAGEAcQBTAGkAVAA2ADUAaQBuAG0AZwBEAG4AZwA4AHAAMQBXAEQAMwA3AHAAYgBFADgATgBzAHEASQBIAFIAdgBMAHgAVQBoADQAMAB6AGEAUQAxAGMAdQBJADcAbgBHAFQATgA4ADAAUwBpAFYAQwBZAEQAaQBOAFkAaABJAE0AWQBGAFUAaQA3AGsARAAyAEIAUQBPAFMASABVAFAAaQBTADgAdABWAE0AWQBLAFoAYgBWAHIAaABsAGoAWgBaADAAUgBxAFUATgByAEQAQwBPAEsANAA5AEUARwBzAEsAeAA5AFgANQBtADkAdQBUAGIAbwAyAG4ASwBBAEwATQBzAEwAQgBUAEYAYQA5AEkAcABmAGMALwB6AHYAdwBnAEIAeQBBAHAAWABXAGkAUwBpAHoAZQBlADgAdABoAFgAaAA1ADQAQgA3AHoAYgA4AHAAcgBGAEEAcABVAEgAWQBBADUAMwBoAEQAbgBEAFQATQBEAG4ARwBWAE4AVABIAFUALwBGAFgATgBRAFYAVABaAHQAWQBBAG8AVABVAHEAawA0AEsAcABWADEAVgBjADUAZgAxAGsAYgB5AFcAcQBtADgAZwBtAFcAQwBJAEkAZwA0AFMANQB1AFoANgA5AGoANgB3AFYAMQBYAEoAaAA0AGoAaQBwAFEAagBGAHoAZgAyAEQANQBXAEsAQQA3AEgAKwBMADcANwBjAFMAeABRAHAAVQBhAFMAMwBEAGMAbwBkADQAdAA4AC8AaQBKAFoASAA4AGUANwA5AFgALwBsAFYAWAB4AHoAMgAvAFIASABoAGQAVABYADMAOQBNAHoAegArAC8ANgArAEYAdAA4AGwAVgBzAFUAMQBPAGYAVABrAHgARQBuAGYAMABYAHQAcwB4AFYASABzAFcAawBmAHgAMQBNAHEAagBHAEsAQQBLAHIAUwB0ADIAKwBNAHYAbgBCAHEAdwBqAGYARQBuAEMAegBrADkAZwBoAG0AawB5AFoAMgBvAC8AaQBCAHYAMQBIADcAMgA5ACsANwBWADUAbwBoAE8AMgAzAEoAVAA4ADUAeQA2AGoAeQBtAFEAdwBOAE8AVQArAEsALwBCADkAOABhAFgAZABGAHQAZQB6AFAATAB2AHoAcgBtAHMANwAyAHAAaQA5ADIATgBNAGQANwA3ADMAVQAvADEAcABDAEYAQgBuAEYARgBMAFQAWABwAGIAQgBnAGcANgBOAG4ARAB3AGQAZAAvAFcAZQAwAGMAVABOAEIATABNAGgATgBTAFAAdAAxAGoARgBuADcAZABTAHoAeQBTAFEAbQA3ADkAdQBSAE8AYQBGAEUAUgA1AHcAcQBRAHgASgBWADYAUwBsAG0AOAA4AEkAMgByAFAAOQAzAC8AawB4AGIARwBhAGcAVgB1AGsANwBoAEgAUQA1AEwARgBXAEwASwBZAHUAeQBRAFIAVgAwAHgAUwA1AHIAcgA3AGcAMgB4AGgAOQBvAGQAWABUAHgAOAA2AGYAaQBkAGoAKwBpADUAWQBNAGoAUABNAE0AbgBGAGgASQBLAFUAZQBOAEwANQAxAGMAdgByADUALwBkADgAcQBkAHEANAB0ADYAZABjAGoAMABFAGIAaQBiAGsAMgBwAHUATQBCAEwAMgBJAE8AbQBqAFYAbABKAGsANgBlAG0AVABoADgANAB2AFIAYgA0AGUAZwBUAHkAdQBBAGQAYgByAG0AbAB6AEIAdQBGAEYAaQBSAHMAbgBwADEANwA0ADkASgBXAFYATgBiADgANwBBAHMAdABJAEEARwB6AHUAdwA2AFIAUgBuAFgAcQB1AEcATgBVAE4AdwBEAGMAZgBkAC8AdABwAFYAagBhAFAAYgBlADQAdQArAEMAOQA4AG4AUAA2AGYAeAA3ADgAQQA5AFYAVQArAFkAbwB0AEoASQBwAE0AQQBBAEEAQQBBAFMAVQBWAE8AUgBLADUAQwBZAEkASQA9ACIAKQAKAFsAUwB5AHMAdABlAG0ALgBJAE8ALgBGAGkAbABlAF0AOgA6AFcAcgBpAHQAZQBBAGwAbABCAHkAdABlAHMAKAAoAEoAbwBpAG4ALQBQAGEAdABoACAAJABkACAAIgByAG8AdABhAHQAZQAuAGkAYwBvACIAKQAsACAAJABiACkACgA=

echo.
echo ===============================================
echo  Step 12: Downloading the Rotate Screen script from GitHub
echo ===============================================
echo   Fetches rotate_screen.ps1 (from the same GitHub folder as this
echo   file) into C:\ProgramData\KioskSetup so it can be updated too.

powershell -NoProfile -ExecutionPolicy Bypass -EncodedCommand JABpAG4AcwB0AGEAbABsAEQAaQByACAAPQAgACIAQwA6AFwAUAByAG8AZwByAGEAbQBEAGEAdABhAFwASwBpAG8AcwBrAFMAZQB0AHUAcAAiAAoATgBlAHcALQBJAHQAZQBtACAALQBJAHQAZQBtAFQAeQBwAGUAIABEAGkAcgBlAGMAdABvAHIAeQAgAC0AUABhAHQAaAAgACQAaQBuAHMAdABhAGwAbABEAGkAcgAgAC0ARgBvAHIAYwBlACAAfAAgAE8AdQB0AC0ATgB1AGwAbAAKACQAdQByAGwAIAA9ACAAJABlAG4AdgA6AFMAQwBSAEkAUABUAF8AVQBSAEwAIAAtAHIAZQBwAGwAYQBjAGUAIAAnAGsAaQBvAHMAawBfAHMAZQB0AHUAcABcAC4AYgBhAHQAJAAnACwAJwByAG8AdABhAHQAZQBfAHMAYwByAGUAZQBuAC4AcABzADEAJwAKACQAZABlAHMAdAAgAD0AIABKAG8AaQBuAC0AUABhAHQAaAAgACQAaQBuAHMAdABhAGwAbABEAGkAcgAgACIAcgBvAHQAYQB0AGUAXwBzAGMAcgBlAGUAbgAuAHAAcwAxACIACgB0AHIAeQAgAHsACgAgACAAIAAgAEkAbgB2AG8AawBlAC0AVwBlAGIAUgBlAHEAdQBlAHMAdAAgAC0AVQByAGkAIAAkAHUAcgBsACAALQBPAHUAdABGAGkAbABlACAAJABkAGUAcwB0ACAALQBVAHMAZQBCAGEAcwBpAGMAUABhAHIAcwBpAG4AZwAgAC0ARQByAHIAbwByAEEAYwB0AGkAbwBuACAAUwB0AG8AcAAKACAAIAAgACAAVwByAGkAdABlAC0ASABvAHMAdAAgACIARABvAHcAbgBsAG8AYQBkAGUAZAAgACQAdQByAGwAIgAKAH0AIABjAGEAdABjAGgAIAB7AAoAIAAgACAAIABXAHIAaQB0AGUALQBIAG8AcwB0ACAAIgBFAFIAUgBPAFIAOgAgAGMAbwB1AGwAZAAgAG4AbwB0ACAAZABvAHcAbgBsAG8AYQBkACAAcgBvAHQAYQB0AGUAXwBzAGMAcgBlAGUAbgAuAHAAcwAxACAAZgByAG8AbQAgACQAdQByAGwAIgAKACAAIAAgACAAVwByAGkAdABlAC0ASABvAHMAdAAgACIAIAAgACAAIAAgACAAIABNAGEAawBlACAAcwB1AHIAZQAgAHIAbwB0AGEAdABlAF8AcwBjAHIAZQBlAG4ALgBwAHMAMQAgAGkAcwAgAGkAbgAgAHQAaABlACAAcwBhAG0AZQAgAEcAaQB0AEgAdQBiACAAZgBvAGwAZABlAHIAIABhAHMAIABrAGkAbwBzAGsAXwBzAGUAdAB1AHAALgBiAGEAdAAuACIACgAgACAAIAAgAFcAcgBpAHQAZQAtAEgAbwBzAHQAIAAiACAAIAAgACAAIAAgACAAJABfACIACgB9AAoA

echo.
echo ===============================================
echo  Step 13: Creating the "Rotate Screen" desktop icon
echo ===============================================
echo   Each click rotates the display 90 degrees clockwise. No admin
echo   prompt - display orientation doesn't need elevation.

powershell -NoProfile -ExecutionPolicy Bypass -EncodedCommand JABpAG4AcwB0AGEAbABsAEQAaQByACAAPQAgACIAQwA6AFwAUAByAG8AZwByAGEAbQBEAGEAdABhAFwASwBpAG8AcwBrAFMAZQB0AHUAcAAiAAoAJAB3AHMAIAA9ACAATgBlAHcALQBPAGIAagBlAGMAdAAgAC0AQwBvAG0ATwBiAGoAZQBjAHQAIABXAFMAYwByAGkAcAB0AC4AUwBoAGUAbABsAAoAJABkAGUAcwBrAHQAbwBwACAAPQAgACQAdwBzAC4AUwBwAGUAYwBpAGEAbABGAG8AbABkAGUAcgBzACgAIgBBAGwAbABVAHMAZQByAHMARABlAHMAawB0AG8AcAAiACkACgAkAHMAaABvAHIAdABjAHUAdABQAGEAdABoACAAPQAgAEoAbwBpAG4ALQBQAGEAdABoACAAJABkAGUAcwBrAHQAbwBwACAAIgBSAG8AdABhAHQAZQAgAFMAYwByAGUAZQBuAC4AbABuAGsAIgAKACQAdABhAHIAZwBlAHQAUwBjAHIAaQBwAHQAIAA9ACAASgBvAGkAbgAtAFAAYQB0AGgAIAAkAGkAbgBzAHQAYQBsAGwARABpAHIAIAAiAHIAbwB0AGEAdABlAF8AcwBjAHIAZQBlAG4ALgBwAHMAMQAiAAoAJABpAGMAbwBuAFAAYQB0AGgAIAA9ACAASgBvAGkAbgAtAFAAYQB0AGgAIAAkAGkAbgBzAHQAYQBsAGwARABpAHIAIAAiAHIAbwB0AGEAdABlAC4AaQBjAG8AIgAKACQAcwBoAG8AcgB0AGMAdQB0ACAAPQAgACQAdwBzAC4AQwByAGUAYQB0AGUAUwBoAG8AcgB0AGMAdQB0ACgAJABzAGgAbwByAHQAYwB1AHQAUABhAHQAaAApAAoAJABzAGgAbwByAHQAYwB1AHQALgBUAGEAcgBnAGUAdABQAGEAdABoACAAPQAgACIAcABvAHcAZQByAHMAaABlAGwAbAAuAGUAeABlACIACgAkAHMAaABvAHIAdABjAHUAdAAuAEEAcgBnAHUAbQBlAG4AdABzACAAPQAgACcALQBOAG8AUAByAG8AZgBpAGwAZQAgAC0AVwBpAG4AZABvAHcAUwB0AHkAbABlACAASABpAGQAZABlAG4AIAAtAEUAeABlAGMAdQB0AGkAbwBuAFAAbwBsAGkAYwB5ACAAQgB5AHAAYQBzAHMAIAAtAEYAaQBsAGUAIAAiACcAIAArACAAJAB0AGEAcgBnAGUAdABTAGMAcgBpAHAAdAAgACsAIAAnACIAJwAKACQAcwBoAG8AcgB0AGMAdQB0AC4ASQBjAG8AbgBMAG8AYwBhAHQAaQBvAG4AIAA9ACAAJABpAGMAbwBuAFAAYQB0AGgAIAArACAAIgAsADAAIgAKACQAcwBoAG8AcgB0AGMAdQB0AC4ARABlAHMAYwByAGkAcAB0AGkAbwBuACAAPQAgACIAUgBvAHQAYQB0AGUAcwAgAHQAaABlACAAZABpAHMAcABsAGEAeQAgADkAMAAgAGQAZQBnAHIAZQBlAHMAIABjAGwAbwBjAGsAdwBpAHMAZQAgAGUAYQBjAGgAIABjAGwAaQBjAGsAIgAKACQAcwBoAG8AcgB0AGMAdQB0AC4AUwBhAHYAZQAoACkACgA=

echo.
echo ===============================================
echo  All automated steps complete.
echo  Windows Update will only install/reboot between %INSTALL_HOUR%:00 AM
echo  and %ACTIVE_HOURS_START%:00 AM (Active Hours block %ACTIVE_HOURS_START%:00-%ACTIVE_HOURS_END%:00).
echo  "Update PC Kiosk Settings" and "Rotate Screen" are now on the
echo  desktop. Update re-applies whatever is currently at
echo  %SCRIPT_URL%
echo  Rotate turns the display 90 degrees clockwise on each click.
echo  A restart is recommended so every change fully applies.
echo ===============================================
pause
