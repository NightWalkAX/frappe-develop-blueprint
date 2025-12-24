@echo off
REM Script to build custom image on Windows
REM Reads variables from .env file

setlocal enabledelayedexpansion

echo === Build Script for Custom Image ===
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
if "%FRAPPE_BRANCH%"=="" set FRAPPE_BRANCH=version-14
if "%PYTHON_VERSION%"=="" set PYTHON_VERSION=3.11.6

echo Configuration:
echo   CUSTOM_APPS: %CUSTOM_APPS%
echo   FRAPPE_BRANCH: %FRAPPE_BRANCH%
echo   PYTHON_VERSION: %PYTHON_VERSION%
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
    -t frappe-custom:latest ^
    -f images/develop/Containerfile ^
    .

if %errorlevel% equ 0 (
    echo.
    echo [OK] Image built successfully: frappe-custom:latest
) else (
    echo.
    echo [ERROR] Error building image
    exit /b 1
)

endlocal
