@echo off
REM Wrapper to run the PowerShell regression script from cmd
powershell -NoProfile -ExecutionPolicy Bypass -File regression_runner.ps1
if %errorlevel% neq 0 (
  echo Regression failed with exit code %errorlevel%
  exit /b %errorlevel%
) else (
  echo Regression passed
)
