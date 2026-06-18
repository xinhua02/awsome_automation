@echo off
REM Wrapper to run the PowerShell regression script from cmd
set "DEFAULT_ARGS="
echo %* | findstr /I /C:"-CoverageThreshold" /C:"-DutCoverageThreshold" >nul
if errorlevel 1 (
  echo %* | findstr /I /C:"-NoCoverage" >nul
  if errorlevel 1 (
    set "DEFAULT_ARGS=-DutCoverageThreshold 100"
  )
)

powershell -NoProfile -ExecutionPolicy Bypass -File regression_runner.ps1 %* %DEFAULT_ARGS%
if %errorlevel% neq 0 (
  echo Regression failed with exit code %errorlevel%
  exit /b %errorlevel%
) else (
  echo Regression passed
)
