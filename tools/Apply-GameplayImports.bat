@echo off
setlocal
set "copeServer=%USERPROFILE%\Desktop\CopeRO"
if not "%~1"=="" set "copeServer=%~1"
pushd "%~dp0"
if errorlevel 1 goto :failed
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%CD%\Apply-CopeGameplayImports.ps1" -ServerRoot "%copeServer%" -PackageRoot "%CD%"
set "copeApplyResult=%errorlevel%"
popd
if not "%copeApplyResult%"=="0" goto :failed
echo Gameplay settings applied. Review output, then restart the game servers.
pause
exit /b 0
:failed
echo Apply failed. Read the error above before making further changes.
pause
exit /b 1
