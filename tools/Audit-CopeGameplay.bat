@echo off
setlocal
set "copeServer=%USERPROFILE%\Desktop\CopeRO"
if not "%~1"=="" set "copeServer=%~1"
set "copeReport=%USERPROFILE%\Desktop\CopeRO-gameplay-audit.json"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Get-CopeGameplayAudit.ps1" -ServerRoot "%copeServer%" -OutputPath "%copeReport%"
if errorlevel 1 goto :failed
echo Audit complete. Share the generated JSON report for comparison.
echo Report: %copeReport%
pause
exit /b 0
:failed
echo Audit failed. No configuration was applied.
pause
exit /b 1
