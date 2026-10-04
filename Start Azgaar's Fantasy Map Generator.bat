@echo off
setlocal EnableExtensions

rem Azgaar's Fantasy Map Generator - one-click launcher
rem Place this Start.bat in the installed Fantasy Map Generator root folder.

cd /d "%~dp0"
set "APPDIR=%CD%"
set "NODEDIR=%APPDIR%\runtime\node"
set "NODEEXE=%NODEDIR%\node.exe"
set "NPMCMD=%NODEDIR%\npm.cmd"

if not exist "%APPDIR%\package.json" goto :missing_app
if not exist "%NODEEXE%" goto :missing_node
if not exist "%NPMCMD%" goto :missing_node

set "PATH=%NODEDIR%;%PATH%"
title Azgaar's Fantasy Map Generator

echo Starting Azgaar's Fantasy Map Generator...
echo.
echo The generator will open automatically in your default browser.
echo Keep this window open while you are using the generator.
echo Close this window or press Ctrl+C when you want to stop it.
echo.

call "%NPMCMD%" run dev -- --open
set "EXITCODE=%ERRORLEVEL%"

if "%EXITCODE%"=="0" exit /b 0

echo.
echo The generator stopped with exit code %EXITCODE%.
echo.
echo If this is the first run after moving or repairing the folder,
echo run Azgaar's Fantasy Map Generator.Bat and choose Repair.
echo.
pause
exit /b %EXITCODE%

:missing_app
echo.
echo ERROR: Fantasy Map Generator was not found in:
echo   %APPDIR%
echo.
echo Put Start.bat inside the installed Azgaar's Fantasy Map folder,
echo next to package.json, then double-click it again.
echo.
pause
exit /b 2

:missing_node
echo.
echo ERROR: The local Node.js runtime was not found in:
echo   %NODEDIR%
echo.
echo Run Azgaar's Fantasy Map Generator.Bat and choose Repair.
echo.
pause
exit /b 3
