@echo off
rem Abre o Firestick Makeover. Use o PowerShell 7 se estiver instalado; senao, o que vem com o Windows.
cd /d "%~dp0"
if not exist "%~dp0makeover.ps1" (
  echo Extraia o zip primeiro: clique com o botao direito no zip, "Extrair tudo", e rode Start-Here.bat da pasta nova.
  pause
  exit /b 1
)
where pwsh >nul 2>nul
if %errorlevel%==0 (
  pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0makeover.ps1" %*
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0makeover.ps1" %*
)
pause
