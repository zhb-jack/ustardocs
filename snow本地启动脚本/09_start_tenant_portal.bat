@echo off
setlocal

set "ROOT=D:\snow"
set "APP_DIR=%ROOT%\ustarpay-frontend-admin\tenant-portal"

cd /d "%APP_DIR%"
set "BROWSER=none"

start "tenant-portal" /b npm exec vite -- --host 127.0.0.1 --port 3002

echo tenant-portal started on http://127.0.0.1:3002
