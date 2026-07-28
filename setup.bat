@echo off
setlocal
:: Alinha o CMD para UTF-8 antes de iniciar
chcp 65001 > nul

:: Se não foi chamado como "Invisible", reabre o próprio batch de forma oculta
if "%~1" neq "Invisible" (
    powershell -NoProfile -Command "Start-Process '%~f0' -ArgumentList 'Invisible' -WindowStyle Hidden"
    exit /b
)

:: Agora chama o PowerShell de verdade (janela oculta)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0BaixadorDeMidiaPro.ps1"
exit /b
