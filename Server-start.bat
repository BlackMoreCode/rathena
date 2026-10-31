@echo off
setlocal
pushd "%~dp0"
if errorlevel 1 goto :failed
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\Start-CopeServer.ps1" -ServerRoot "%~dp0."
set "copeStartResult=%errorlevel%"
popd
if not "%copeStartResult%"=="0" goto :failed
exit /b 0

:failed
echo.
echo Server startup failed. Review the error above.
pause
exit /b 1
