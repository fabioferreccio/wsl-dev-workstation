@echo off
REM entrypoint.bat — Executado automaticamente ao logar no Sandbox
powershell.exe -ExecutionPolicy Bypass -File "C:\Users\WDAGUtilityAccount\Desktop\Tools\init-inside-sandbox.ps1"
pause