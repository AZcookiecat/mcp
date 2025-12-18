@echo off

REM Enable delayed expansion
setlocal enabledelayedexpansion

REM Get script directory
set "PROJECT_ROOT=%~dp0"
set "PROJECT_ROOT=%PROJECT_ROOT:~0,-1%"

REM Set virtual environment and Python paths
set "VENV_PATH=%PROJECT_ROOT%\env.UE4-hutb"
set "PYTHON_EXE=%VENV_PATH%\python.exe"

REM Set CarlaUE4.exe path
set "CARLA_EXE=%PROJECT_ROOT%\CarlaUE4.exe"

REM Set main_ai.py path
set "MAIN_AI_PY=%PROJECT_ROOT%\llm\main_ai.py"

REM Define port and URL to check
set "PORT=3000"
set "CHECK_URL=http://localhost:%PORT%"

REM Maximum wait time in seconds for main_ai.py to start
set "MAX_WAIT=60"

REM Wait time after starting CarlaUE4.exe
set "POST_CARLA_WAIT=3"

REM Check if virtual environment exists
if not exist "%VENV_PATH%" (
    echo Error: Virtual environment not found at %VENV_PATH%
    pause
    exit /b 1
)

REM Check if Python interpreter exists
if not exist "%PYTHON_EXE%" (
    echo Error: Python interpreter not found at %PYTHON_EXE%
    pause
    exit /b 1
)

REM Check if CarlaUE4.exe exists
if not exist "%CARLA_EXE%" (
    echo Warning: CarlaUE4.exe not found, skipping startup
    echo CarlaUE4.exe path: %CARLA_EXE%
)

REM Check if main_ai.py exists
if not exist "%MAIN_AI_PY%" (
    echo Error: main_ai.py not found at %MAIN_AI_PY%
    pause
    exit /b 1
)

REM Print activation information
echo Activating virtual environment...

REM Print Python version
echo Virtual environment activated successfully!
echo Python version:
%PYTHON_EXE% --version

REM Set environment variables
set "PATH=%VENV_PATH%\Scripts;%VENV_PATH%;%PATH%"
set "VIRTUAL_ENV=%VENV_PATH%"

REM 1. First, run main_ai.py
echo Running main_ai.py...
start "main_ai" "%PYTHON_EXE%" "%MAIN_AI_PY%"

REM Wait for 5 seconds initially to give main_ai.py time to start
timeout /t 5 /nobreak >nul

REM Wait for main_ai.py to be fully ready to handle requests
echo Waiting for main_ai.py to be ready at %CHECK_URL%...
set "WAIT_COUNT=0"
:WAIT_LOOP
REM Check if port is in use first
netstat -an | findstr ":%PORT% LISTENING" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    REM Port not listening yet, wait and retry
    goto :CHECK_TIMER
)

REM If port is listening, try to get a successful HTTP response
curl -s -o NUL -w "%%{http_code}" "%CHECK_URL%" | findstr "200" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo main_ai.py is ready and responding at %CHECK_URL%!
    goto :START_CARLA
)

:CHECK_TIMER
REM Increment wait count
set /a WAIT_COUNT=WAIT_COUNT+1

REM Check if maximum wait time exceeded
if !WAIT_COUNT! geq %MAX_WAIT% (
    echo Warning: Maximum wait time exceeded (%MAX_WAIT% seconds)
    echo main_ai.py may not be fully ready, but continuing with CarlaUE4.exe startup...
    goto :START_CARLA
)

REM Wait for 2 seconds before checking again
echo Waiting for %PORT%... (Attempt !WAIT_COUNT! of %MAX_WAIT%)
timeout /t 2 /nobreak >nul
goto :WAIT_LOOP

:START_CARLA
REM 2. Then, start CarlaUE4.exe asynchronously
if exist "%CARLA_EXE%" (
    echo Starting CarlaUE4.exe...
    start "CarlaUE4" "%CARLA_EXE%"
    
    REM Wait for specified time after starting CarlaUE4
    timeout /t %POST_CARLA_WAIT% /nobreak >nul
)

REM 3. Finally, open browser to localhost:3000
echo Opening browser to %CHECK_URL%...
start "" "%CHECK_URL%"

REM Set custom prompt
prompt [env.UE4-hutb] $P$G

REM Keep terminal open
cmd /k