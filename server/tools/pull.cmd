@echo off
cd /d "%~dp0.."
if not exist logs mkdir logs
where dart >nul 2>&1 || (echo [%date% %time%] pull aborted: 'dart' not on PATH for this user>> logs\pull.log & exit /b 9009)
call dart run bin/pull.dart config.json >> logs\pull.log 2>&1
exit /b %ERRORLEVEL%
