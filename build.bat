@echo off
REM Script to build and compose the custom image and services
REM Reads variables from .env file

setlocal enabledelayedexpansion

REM Port range configuration
set PORT_RANGE_START=8000
set PORT_RANGE_END=8099

echo === Build and Compose Script ===
echo.

REM Verify that .env file exists
if not exist .env (
    echo [ERROR] .env file not found
    echo Please copy .env.example to .env and configure the required variables
    exit /b 1
)

REM Load variables from .env
echo Loading variables from .env...
for /f "usebackq tokens=1,2 delims==" %%a in (.env) do (
    set "line=%%a"
    REM Ignore lines starting with # or empty lines
    if not "!line:~0,1!"=="#" (
        if not "%%a"=="" (
            set "%%a=%%b"
        )
    )
)

REM Verify required variables
if "%CUSTOM_APPS%"=="" (
    echo [WARNING] CUSTOM_APPS variable is not defined in .env
    echo No custom apps will be installed. Only Frappe will be available.
)

REM Default values
if "%FRAPPE_BRANCH%"=="" set FRAPPE_BRANCH=version-15
if "%PYTHON_VERSION%"=="" set PYTHON_VERSION=3.11.6
if "%CUSTOM_IMAGE%"=="" set CUSTOM_IMAGE=frappe-custom
if "%CUSTOM_TAG%"=="" set CUSTOM_TAG=latest

REM Find available port dynamically
echo Searching for available port in range %PORT_RANGE_START%-%PORT_RANGE_END%...
set FRAPPE_PORT=
set PREFERRED_PORT=%FRAPPE_PORT%

REM Try preferred port first if set
if not "%PREFERRED_PORT%"=="" (
    netstat -an | findstr /r ":%PREFERRED_PORT% " >nul 2>&1
    if errorlevel 1 (
        set FRAPPE_PORT=%PREFERRED_PORT%
        goto :port_found
    ) else (
        echo [WARNING] Preferred port %PREFERRED_PORT% not available, searching for alternative...
    )
)

REM Search for available port in range
for /l %%p in (%PORT_RANGE_START%,1,%PORT_RANGE_END%) do (
    if "!FRAPPE_PORT!"=="" (
        netstat -an | findstr /r ":%%p " >nul 2>&1
        if errorlevel 1 (
            set FRAPPE_PORT=%%p
        )
    )
)

if "%FRAPPE_PORT%"=="" (
    echo [ERROR] No available ports found in range %PORT_RANGE_START%-%PORT_RANGE_END%
    exit /b 1
)

:port_found
echo [OK] Available port found: %FRAPPE_PORT%
echo.

echo Configuration:
echo   CUSTOM_APPS: %CUSTOM_APPS%
echo   FRAPPE_BRANCH: %FRAPPE_BRANCH%
echo   PYTHON_VERSION: %PYTHON_VERSION%
echo   IMAGE: %CUSTOM_IMAGE%:%CUSTOM_TAG%
echo   FRAPPE_PORT: %FRAPPE_PORT% ^(auto-detected^)
if not "%GITHUB_TOKEN%"=="" (
    echo   GITHUB_TOKEN: ******* ^(configured^)
) else (
    echo   GITHUB_TOKEN: ^(not configured - may fail on private repositories^)
)
echo.

REM Build the image
echo Starting image build...
echo.

docker build ^
    --build-arg GITHUB_TOKEN=%GITHUB_TOKEN% ^
    --build-arg CUSTOM_APPS=%CUSTOM_APPS% ^
    --build-arg FRAPPE_BRANCH=%FRAPPE_BRANCH% ^
    --build-arg PYTHON_VERSION=%PYTHON_VERSION% ^
    -t %CUSTOM_IMAGE%:%CUSTOM_TAG% ^
    -f images/develop/Containerfile ^
    .

if %errorlevel% equ 0 (
    echo.
    echo [OK] Image built successfully: %CUSTOM_IMAGE%:%CUSTOM_TAG%
) else (
    echo.
    echo [ERROR] Error building image
    exit /b 1
)

REM Compose and start services
echo Starting services with docker-compose...
echo.

docker-compose -f compose.yaml up -d

if %errorlevel% equ 0 (
    echo.
    echo [OK] Services started successfully
    echo Waiting for services to initialize ^(30 seconds^)...
    timeout /t 30 /nobreak >nul
    echo.
    echo Services status:
    docker-compose -f compose.yaml ps
    echo.
    
    REM Verify service connectivity
    echo Verifying service connectivity...
    set ALL_OK=true
    
    REM Check Backend health
    echo   Checking Backend health...
    docker-compose ps 2>nul | findstr /i "backend.*up\|backend.*running" >nul 2>&1
    if %errorlevel% equ 0 (
        echo   [OK] Backend is running
    ) else (
        echo   [FAIL] Backend check failed
        set ALL_OK=false
    )
    
    REM Check MariaDB health
    echo   Checking MariaDB health...
    docker-compose ps 2>nul | findstr /i "mariadb.*healthy" >nul 2>&1
    if %errorlevel% equ 0 (
        echo   [OK] MariaDB is healthy
    ) else (
        echo   [FAIL] MariaDB health check failed
        set ALL_OK=false
    )
    
    REM Check Redis Cache health
    echo   Checking Redis Cache health...
    docker-compose ps 2>nul | findstr /i "redis-cache.*healthy" >nul 2>&1
    if %errorlevel% equ 0 (
        echo   [OK] Redis Cache is healthy
    ) else (
        echo   [FAIL] Redis Cache health check failed
        set ALL_OK=false
    )
    
    REM Check Redis Queue health
    echo   Checking Redis Queue health...
    docker-compose ps 2>nul | findstr /i "redis-queue.*healthy" >nul 2>&1
    if %errorlevel% equ 0 (
        echo   [OK] Redis Queue is healthy
    ) else (
        echo   [FAIL] Redis Queue health check failed
        set ALL_OK=false
    )
    
    echo.
    
    REM Final result
    if "!ALL_OK!"=="true" (
        echo ============================================================
        echo [OK] All services are running and connected successfully!
        echo ============================================================
        echo.
        echo Environment Information:
        echo   Database Host: mariadb:3306
        echo   Database Name: %DB_NAME%
        echo   Database User: %DB_USER%
        echo   Site Name: %SITE_NAME%
        echo   Admin Email: Administrator
        echo   Admin Password: %ADMIN_PASSWORD%
        echo.
        echo ============================================================
        echo   Access your ERP at: http://localhost:%FRAPPE_PORT%
        echo ============================================================
    ) else (
        echo ============================================================
        echo [WARNING] Some services may not be fully initialized yet.
        echo Check logs with: docker-compose logs -f
        echo.
        echo When ready, access your ERP at: http://localhost:%FRAPPE_PORT%
        echo ============================================================
    )
) else (
    echo.
    echo [ERROR] Error starting services
    exit /b 1
)

endlocal
