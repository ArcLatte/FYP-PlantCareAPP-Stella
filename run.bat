@echo off
echo Starting Stella backend and frontend...

start "Stella Backend" cmd /k "venv\Scripts\Activate.ps1 && cd backend && python.exe manage.py runserver"

start "Stella Frontend" cmd /k "venv\Scripts\Activate.ps1 && cd frontend && flutter run"
