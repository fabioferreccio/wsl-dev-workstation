@echo off
title WORKSTATION CONTROL PANEL
setlocal enabledelayedexpansion

:MENU
cls
echo ======================================================
echo    WORKSTATION: O MANUAL DE ARQUITETO (MENU v1.0)
echo ======================================================
echo.
echo   [1] PROVISIONAMENTO    (Setup Inicial - Novo PC)
echo   [2] INICIAR            (Modo Trabalho - Mount W:)
echo   [3] ENCERRAR           (Modo Lazer - Ejetar W:)
echo   [4] SANDBOX            (Ambiente Isolado Descartavel)
echo   [5] MIGRACAO           (Mover C: tools para W:)
echo   [6] RESTAURAR          (Linkar W: ja existente p/ C:)
echo.
echo   [Q] Sair
echo.
echo ============================================================
set /p choice="Escolha uma opcao: "

if "%choice%"=="1" goto PROVISION
if "%choice%"=="2" goto START
if "%choice%"=="3" goto STOP
if "%choice%"=="4" goto SANDBOX
if "%choice%"=="5" goto MIGRATE
if "%choice%"=="6" goto RESTORE
if /i "%choice%"=="q" exit
goto MENU

:PROVISION
echo.
echo [AVISO] O Provisionamento requer privilegios de Administrador.
echo Instalara todas as ferramentas diretamente em W:\Apps\
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0scripts\provision-machine.ps1"
echo.
pause
goto MENU

:START
echo.
echo INICIANDO AMBIENTE DE TRABALHO...
echo Montando W:, verificando symlinks, subindo Docker e WSL.
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0scripts\start-work.ps1"
echo.
pause
goto MENU

:STOP
echo.
echo ENCERRANDO AMBIENTE E LIBERANDO RECURSOS...
echo Fechando IDEs, Docker, WSL e ejetando W:.
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0scripts\stop-work.ps1"
echo.
pause
goto MENU

:SANDBOX
echo.
echo INICIANDO AMBIENTE ISOLADO (WINDOWS SANDBOX)...
echo [Aviso] Nada salvo em C:\ dentro do Sandbox sera mantido.
echo Use Desktop\Projects (mapeado de C:\Worker\projects_legacy).
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0legacy-net\launch-sandbox.ps1"
echo.
pause
goto MENU

:MIGRATE
echo.
echo MIGRACAO: Move ferramentas do C: para W: usando Symlinks.
echo.
echo [AVISO] Este processo requer privilegios de Administrador.
echo [AVISO] O Antigravity sera migrado em 2 etapas — o script
echo         ira guiar voce sobre quando fechar o Antigravity.
echo.
set /p confirm="Deseja continuar? (S/N): "
if /i "%confirm%"=="s" goto MIGRATE_RUN
goto MENU

:MIGRATE_RUN
powershell -ExecutionPolicy Bypass -File "%~dp0scripts\migrate-to-work-drive.ps1"
echo.
pause
goto MENU

:RESTORE
echo.
echo RESTAURAR: Configura uma maquina nova usando o W: Drive ja existente.
echo [AVISO] Este processo requer privilegios de Administrador.
echo [AVISO] Ele criara symlinks em C: e registrara Git/VSCode no Registro.
echo.
set /p confirm="Deseja continuar? (S/N): "
if /i "%confirm%"=="s" goto RESTORE_RUN
goto MENU

:RESTORE_RUN
powershell -ExecutionPolicy Bypass -File "%~dp0scripts\restore-from-work-drive.ps1"
echo.
pause
goto MENU
