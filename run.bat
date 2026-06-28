@echo off
echo Starting Stella backend and frontend...

start "Stella Backend" cmd /k "cd backend && python.exe manage.py runserver"

start "Stella Frontend" cmd /k "cd frontend && flutter run"
