@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo ================================================
echo FFmpeg Auto Installer
echo ================================================
echo.

:: 检查是否以管理员权限运行
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo This script requires administrator privileges.
    echo Please right-click and select "Run as administrator"
    echo.
    pause
    exit /b 1
)

:: 检查 FFmpeg 是否已安装
ffmpeg -version >nul 2>&1
if %errorLevel% equ 0 (
    echo FFmpeg is already installed!
    echo.
    ffmpeg -version | findstr "version"
    echo.
    set /p "reinstall=Do you want to reinstall? (y/N): "
    if /i not "!reinstall!"=="y" (
        echo Installation cancelled.
        pause
        exit /b 0
    )
)

echo.
echo Starting FFmpeg installation...
echo.

:: 设置安装目录
set "INSTALL_DIR=C:\ffmpeg"
set "BIN_DIR=%INSTALL_DIR%\bin"

:: 创建安装目录
if not exist "!INSTALL_DIR!" (
    echo Creating installation directory: !INSTALL_DIR!
    mkdir "!INSTALL_DIR!"
)

:: 下载 FFmpeg
echo.
echo Downloading FFmpeg (this may take a few minutes)...
echo Please wait...
echo.

:: FFmpeg 下载链接 (使用 gyan.dev 的构建版本)
set "DOWNLOAD_URL=https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
set "ZIP_FILE=%TEMP%\ffmpeg.zip"

:: 使用 PowerShell 下载（绕过执行策略）
powershell -NoProfile -ExecutionPolicy Bypass -Command "& {[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri '%DOWNLOAD_URL%' -OutFile '%ZIP_FILE%' -UseBasicParsing}"

if errorlevel 1 (
    echo.
    echo Failed to download FFmpeg.
    echo Please check your internet connection.
    echo.
    echo Alternative: Download manually from https://ffmpeg.org/download.html
    pause
    exit /b 1
)

echo Download completed!
echo.

:: 解压 FFmpeg
echo Extracting FFmpeg...

powershell -NoProfile -ExecutionPolicy Bypass -Command "& {Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::ExtractToDirectory('%ZIP_FILE%', '%TEMP%\ffmpeg_extract')}"

if errorlevel 1 (
    echo Failed to extract FFmpeg.
    pause
    exit /b 1
)

:: 查找解压后的 bin 目录
for /d %%d in ("%TEMP%\ffmpeg_extract\ffmpeg-*") do (
    set "EXTRACTED_DIR=%%d"
)

:: 复制文件到安装目录
echo Copying files to !INSTALL_DIR!...

if exist "!EXTRACTED_DIR!\bin" (
    xcopy /E /I /Y "!EXTRACTED_DIR!\bin" "!BIN_DIR!" >nul
    xcopy /E /I /Y "!EXTRACTED_DIR!\doc" "!INSTALL_DIR!\doc" >nul 2>nul
    xcopy /E /I /Y "!EXTRACTED_DIR!\presets" "!INSTALL_DIR!\presets" >nul 2>nul
) else (
    echo Error: Could not find FFmpeg bin directory.
    pause
    exit /b 1
)

:: 清理临时文件
echo Cleaning up temporary files...
del "%ZIP_FILE%" >nul 2>&1
rmdir /s /q "%TEMP%\ffmpeg_extract" >nul 2>&1

:: 设置环境变量
echo.
echo Setting up environment variables...

:: 获取当前 PATH
for /f "tokens=2*" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do set "CURRENT_PATH=%%b"

:: 检查 PATH 中是否已包含 FFmpeg
echo !CURRENT_PATH! | findstr /i /c:"!BIN_DIR!" >nul
if %errorLevel% equ 0 (
    echo FFmpeg path already exists in PATH.
) else (
    echo Adding FFmpeg to system PATH...
    
    :: 添加到系统 PATH
    setx /M PATH "!CURRENT_PATH!;!BIN_DIR!" >nul
    
    if errorlevel 1 (
        echo Warning: Failed to update system PATH automatically.
        echo Please add this path manually: !BIN_DIR!
    ) else (
        echo Successfully added to system PATH.
    )
)

:: 刷新当前会话的环境变量
set "PATH=%PATH%;!BIN_DIR!"

echo.
echo ================================================
echo FFmpeg Installation Complete!
echo ================================================
echo.
echo Installation directory: !INSTALL_DIR!
echo Binary directory: !BIN_DIR!
echo.

:: 验证安装
echo Verifying installation...
echo.

ffmpeg -version >nul 2>&1
if %errorLevel% equ 0 (
    echo ✓ FFmpeg is working correctly!
    echo.
    ffmpeg -version | findstr "version"
    echo.
    echo You can now use FFmpeg in any command prompt.
    echo Note: You may need to restart your command prompt for PATH changes to take effect.
) else (
    echo ✗ FFmpeg verification failed.
    echo.
    echo Please try the following:
    echo 1. Close and reopen this command prompt
    echo 2. Run: ffmpeg -version
    echo.
    echo If it still doesn't work, add this to your PATH manually:
    echo !BIN_DIR!
)

echo.
echo ================================================
pause
endlocal