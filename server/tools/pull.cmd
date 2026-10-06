@echo off
cd /d "%~dp0.."
if not exist logs mkdir logs
call dart run bin/pull.dart config.json >> logs\pull.log 2>&1
exit /b %ERRORLEVEL%
