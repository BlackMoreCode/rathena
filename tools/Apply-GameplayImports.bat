@echo off
setlocal
set "copeServer=%USERPROFILE%\Desktop\CopeRO"
if not "%~1"=="" set "copeServer=%~1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Apply-CopeGameplayImports.ps1" -ServerRoot "%copeServer%" -PackageRoot "%~dp0."
if errorlevel 1 goto :failed
echo Gameplay settings applied. Review output, then restart the game servers.
pause
exit /b 0
:failed
echo Apply failed. Read the error above before making further changes.
pause
exit /b 1
