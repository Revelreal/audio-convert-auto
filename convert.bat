@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo Audio File Converter
echo ====================
echo.

:: 检查是否是安装后重启
if "%1"=="--after-install" goto skip_ffmpeg_check

:: 检查 FFmpeg 是否已安装
echo Checking FFmpeg installation...

:: 首先尝试从常见安装位置直接调用
set "FFMPEG_FOUND=0"

:: 检查系统 PATH
ffmpeg -version >nul 2>&1
if %errorLevel% equ 0 (
    set "FFMPEG_FOUND=1"
    goto ffmpeg_ok
)

:: 检查常见安装位置
if exist "C:\ffmpeg\bin\ffmpeg.exe" (
    set "PATH=%PATH%;C:\ffmpeg\bin"
    set "FFMPEG_FOUND=1"
    goto ffmpeg_ok
)

if exist "C:\Program Files\ffmpeg\bin\ffmpeg.exe" (
    set "PATH=%PATH%;C:\Program Files\ffmpeg\bin"
    set "FFMPEG_FOUND=1"
    goto ffmpeg_ok
)

:: FFmpeg 未找到，询问是否安装
if !FFMPEG_FOUND!==0 (
    echo.
    echo FFmpeg is not installed or not in PATH.
    echo FFmpeg is required for audio conversion.
    echo.
    set /p "install_ffmpeg=Would you like to install FFmpeg automatically? (Y/n): "
    
    if /i "!install_ffmpeg!"=="" set "install_ffmpeg=Y"
    
    if /i "!install_ffmpeg!"=="Y" (
        echo.
        echo Installing FFmpeg...
        echo This requires administrator privileges.
        echo.
        
        :: 检查是否有管理员权限
        net session >nul 2>&1
        if !errorLevel! neq 0 (
            echo Requesting administrator privileges...
            
            :: 创建临时的 FFmpeg 安装脚本
            set "TEMP_INSTALLER=%TEMP%\install_ffmpeg.bat"
            
            (
                echo @echo off
                echo chcp 65001 ^>nul
                echo setlocal enabledelayedexpansion
                echo.
                echo echo ================================================
                echo echo Installing FFmpeg...
                echo echo ================================================
                echo echo.
                echo.
                echo :: 设置安装目录
                echo set "INSTALL_DIR=C:\ffmpeg"
                echo set "BIN_DIR=%%INSTALL_DIR%%\bin"
                echo.
                echo :: 创建目录
                echo if not exist "%%INSTALL_DIR%%" mkdir "%%INSTALL_DIR%%"
                echo.
                echo :: 下载 FFmpeg
                echo echo [1/4] Downloading FFmpeg...
                echo set "DOWNLOAD_URL=https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
                echo set "ZIP_FILE=%%TEMP%%\ffmpeg.zip"
                echo.
                echo powershell -NoProfile -ExecutionPolicy Bypass -Command "^& {[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $ProgressPreference = 'SilentlyContinue'; Write-Host 'Downloading...'; Invoke-WebRequest -Uri '%%DOWNLOAD_URL%%' -OutFile '%%ZIP_FILE%%' -UseBasicParsing; Write-Host 'Download complete!'}"
                echo.
                echo if errorlevel 1 ^(
                echo     echo Download failed. Please check your internet connection.
                echo     pause
                echo     exit /b 1
                echo ^)
                echo.
                echo :: 解压
                echo echo [2/4] Extracting...
                echo powershell -NoProfile -ExecutionPolicy Bypass -Command "^& {Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::ExtractToDirectory('%%ZIP_FILE%%', '%%TEMP%%\ffmpeg_extract'^)}"
                echo.
                echo :: 复制文件
                echo echo [3/4] Installing files...
                echo for /d %%%%d in ^("%%TEMP%%\ffmpeg_extract\ffmpeg-*"^) do set "EXTRACTED_DIR=%%%%d"
                echo xcopy /E /I /Y "%%EXTRACTED_DIR%%\bin" "%%BIN_DIR%%" ^>nul
                echo.
                echo :: 设置 PATH
                echo echo [4/4] Setting environment variables...
                echo for /f "tokens=2*" %%%%a in ^('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^^^>nul'^) do set "CURRENT_PATH=%%%%b"
                echo.
                echo :: 检查是否已在 PATH 中
                echo echo %%CURRENT_PATH%% ^| findstr /i /c:"%%BIN_DIR%%" ^>nul
                echo if errorlevel 1 ^(
                echo     setx /M PATH "%%CURRENT_PATH%%;%%BIN_DIR%%" ^>nul
                echo     echo Added to system PATH.
                echo ^) else ^(
                echo     echo Already in system PATH.
                echo ^)
                echo.
                echo :: 清理
                echo del "%%ZIP_FILE%%" ^>nul 2^>^&1
                echo rmdir /s /q "%%TEMP%%\ffmpeg_extract" ^>nul 2^>^&1
                echo.
                echo echo ================================================
                echo echo FFmpeg installed successfully!
                echo echo Location: %%BIN_DIR%%
                echo echo ================================================
                echo echo.
                echo timeout /t 3 /nobreak ^>nul
            ) > "!TEMP_INSTALLER!"
            
            :: 以管理员权限运行安装脚本
            powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd -ArgumentList '/c !TEMP_INSTALLER!' -Verb RunAs -Wait"
            
            :: 检查安装是否成功
            if exist "C:\ffmpeg\bin\ffmpeg.exe" (
                echo.
                echo FFmpeg installed successfully!
                echo Restarting converter with FFmpeg enabled...
                echo.
                timeout /t 2 /nobreak >nul
                
                :: 重启脚本
                start "" "%~f0" --after-install
                exit /b 0
            ) else (
                echo.
                echo FFmpeg installation may have failed.
                echo Please check C:\ffmpeg\bin\ for ffmpeg.exe
                echo.
                pause
                exit /b 1
            )
        ) else (
            :: 已有管理员权限，直接安装
            call :install_ffmpeg_direct
            
            if !errorLevel! neq 0 (
                echo FFmpeg installation failed.
                pause
                exit /b 1
            )
            
            :: 添加到当前会话 PATH
            set "PATH=%PATH%;C:\ffmpeg\bin"
        )
    ) else (
        echo.
        echo FFmpeg is required for this application.
        echo Please install FFmpeg manually from: https://ffmpeg.org/download.html
        echo Or download from: https://www.gyan.dev/ffmpeg/builds/
        echo.
        echo After installation, add FFmpeg to your system PATH.
        pause
        exit /b 1
    )
)

:ffmpeg_ok
echo ✓ FFmpeg detected

:skip_ffmpeg_check
:: 如果是安装后重启，直接添加 FFmpeg 到 PATH
if "%1"=="--after-install" (
    set "PATH=%PATH%;C:\ffmpeg\bin"
    echo FFmpeg loaded from C:\ffmpeg\bin
    echo.
)

:: 验证 FFmpeg
ffmpeg -version >nul 2>&1
if %errorLevel% neq 0 (
    echo.
    echo Error: FFmpeg is still not accessible.
    echo Please restart your computer and try again.
    pause
    exit /b 1
)

ffmpeg -version | findstr "version"

echo.
echo ====================
echo.

:: 初始化环境检查标志文件
set "env_check_flag=.env_check_complete"

:: 检查环境标志文件
if exist "!env_check_flag!" (
    echo Environment already checked and configured.
    echo.
    
    :: 尝试激活虚拟环境
    if exist "venv\Scripts\activate.bat" (
        call venv\Scripts\activate.bat
    ) else if exist ".env\Scripts\activate.bat" (
        call .env\Scripts\activate.bat
    ) else if exist "virtualenv\Scripts\activate.bat" (
        call virtualenv\Scripts\activate.bat
    )
) else (
    echo First-time setup: Checking environment...
    echo.
    
    :: 寻找虚拟环境目录
    set "venv_found=0"
    
    :: 检查常见的虚拟环境目录
    if exist "venv\Scripts\activate.bat" (
        set "venv_dir=venv"
        set "venv_found=1"
    )
    
    if exist ".env\Scripts\activate.bat" (
        set "venv_dir=.env"
        set "venv_found=1"
    )
    
    if exist "virtualenv\Scripts\activate.bat" (
        set "venv_dir=virtualenv"
        set "venv_found=1"
    )
    
    :: 如果没有找到虚拟环境，询问是否创建
    if !venv_found!==0 (
        echo No virtual environment found.
        set /p "create_venv=Would you like to create a virtual environment? (Y/n): "
        
        if /i "!create_venv!"=="" set "create_venv=Y"
        
        if /i "!create_venv!"=="Y" (
            echo Creating virtual environment...
            python -m venv venv
            
            if errorlevel 1 (
                echo Failed to create virtual environment.
                echo Please check if Python is installed correctly.
                pause
                exit /b 1
            )
            
            set "venv_dir=venv"
            set "venv_found=1"
        ) else (
            echo Virtual environment is required for this application.
            echo Please create one manually: python -m venv venv
            pause
            exit /b 1
        )
    )
    
    :: 激活虚拟环境
    echo Activating virtual environment: !venv_dir!
    call "!venv_dir!\Scripts\activate.bat"
    
    :: 检查并安装依赖
    echo Checking dependencies...
    
    :: 检查requirements.txt是否存在
    if exist "requirements.txt" (
        echo Installing packages from requirements.txt...
        pip install -r requirements.txt
        
        if errorlevel 1 (
            echo Failed to install dependencies from requirements.txt.
            echo Please check the requirements file and try again.
            pause
            exit /b 1
        )
    ) else (
        :: 如果没有requirements.txt，则安装pydub和tqdm
        echo Installing pydub...
        pip install pydub
        if errorlevel 1 (
            echo Failed to install pydub.
            set "install_failed=1"
        )
        
        echo Installing tqdm...
        pip install tqdm
        if errorlevel 1 (
            echo Failed to install tqdm.
            set "install_failed=1"
        )
        
        if defined install_failed (
            echo Some dependencies failed to install.
            echo Please install them manually and try again.
            pause
            exit /b 1
        )
    )
    
    :: 验证依赖是否安装成功
    python -c "import pydub, tqdm" 2>nul
    if errorlevel 1 (
        echo Failed to verify dependencies.
        echo Please install manually: pip install pydub tqdm
        pause
        exit /b 1
    )
    
    :: 创建环境检查完成标志
    echo. > "!env_check_flag!"
    echo Environment setup completed successfully!
    echo.
)

:: 检查converter.py是否存在
if not exist "converter.py" (
    echo Error: converter.py not found in current directory.
    echo Please make sure converter.py exists in the same folder as this script.
    pause
    exit /b 1
)

:main_menu
:: 选择是否使用默认音乐文件夹路径
echo Default music folder: %USERPROFILE%\Music
set /p "use_default=Use default music folder? (Y/n): "

if /i "!use_default!"=="n" (
    :get_custom_path
    set /p "music_folder=Enter custom folder path: "
    
    :: 检查路径是否存在
    if not exist "!music_folder!\" (
        echo Error: Path "!music_folder!" does not exist.
        goto get_custom_path
    )
    
    :: 规范化路径（移除末尾的\）
    if "!music_folder:~-1!"=="\" (
        set "music_folder=!music_folder:~0,-1!"
    )
) else (
    set "music_folder=%USERPROFILE%\Music"
    
    :: 如果默认路径不存在，提示创建
    if not exist "!music_folder!\" (
        echo Default music folder does not exist.
        set /p "create_default=Create it? (Y/n): "
        if /i not "!create_default!"=="n" (
            mkdir "!music_folder!"
            echo Created folder: !music_folder!
        ) else (
            echo Please specify a custom folder.
            goto get_custom_path
        )
    )
)

echo.
echo Using folder: !music_folder!
echo.

:select_input_format
:: 选择输入音频格式
echo Select the INPUT audio format:
echo 1. mp3
echo 2. m4a
echo 3. ogg
echo 4. flac
echo 5. wav
echo 6. Change folder
echo 7. Exit
echo.

:select_input
set "input_choice="
set /p "input_choice=Enter your choice (1-7): "

:: 验证输入
if not defined input_choice goto invalid_input

:: 使用标准变量而不是延迟扩展进行比较
if "%input_choice%"=="1" set "input_format=mp3" & goto input_selected
if "%input_choice%"=="2" set "input_format=m4a" & goto input_selected
if "%input_choice%"=="3" set "input_format=ogg" & goto input_selected
if "%input_choice%"=="4" set "input_format=flac" & goto input_selected
if "%input_choice%"=="5" set "input_format=wav" & goto input_selected
if "%input_choice%"=="6" goto main_menu
if "%input_choice%"=="7" goto end_script

:invalid_input
echo Please select a valid input format (1-7).
goto select_input

:input_selected
:: 扫描音乐文件夹中的音频文件
echo.
echo Scanning for *.!input_format! files in !music_folder!...
echo.

set "file_count=0"

:: 创建一个临时文件来存储找到的文件路径
if exist "found_files.tmp" del "found_files.tmp"

:: 显示找到的文件列表
echo Found files:
echo ----------------------------------------

:: 使用dir命令查找文件，兼容性更好
dir /b /s "!music_folder!\*.!input_format!" > "found_files.tmp" 2>nul

if exist "found_files.tmp" (
    for /f "tokens=*" %%f in (found_files.tmp) do (
        set /a file_count+=1
        echo !file_count!. %%~nxf
        echo    Path: %%~dpf
        echo.
    )
    del "found_files.tmp"
)

if !file_count!==0 (
    echo No *.!input_format! files found in !music_folder!
    echo.
    
    set /p "try_again=Try another format? (Y/n): "
    if /i "!try_again!"=="" goto select_input_format
    if /i not "!try_again!"=="n" goto select_input_format
    goto end_script
)

echo.
echo Found !file_count! *.!input_format! files in !music_folder!
echo.

:select_output_format
:: 选择输出音频格式
echo Select the OUTPUT audio format:
echo 1. wav
echo 2. mp3
echo 3. ogg
echo 4. flac
echo 5. Back to input format selection
echo 6. Back to main menu
echo 7. Exit
echo.

:select_output
set "output_choice="
set /p "output_choice=Enter your choice (1-7): "

:: 验证输入
if not defined output_choice goto invalid_output

:: 使用标准变量而不是延迟扩展进行比较
if "%output_choice%"=="1" set "output_format=wav" & goto output_selected
if "%output_choice%"=="2" set "output_format=mp3" & goto output_selected
if "%output_choice%"=="3" set "output_format=ogg" & goto output_selected
if "%output_choice%"=="4" set "output_format=flac" & goto output_selected
if "%output_choice%"=="5" goto select_input_format
if "%output_choice%"=="6" goto main_menu
if "%output_choice%"=="7" goto end_script

:invalid_output
echo Please select a valid output format (1-7).
goto select_output

:output_selected
:: 检查输入和输出格式是否相同
if "!input_format!"=="!output_format!" (
    echo.
    echo Warning: Input format and output format are the same!
    echo This will convert files from !input_format! to !input_format!.
    echo.
    set /p "same_format=Continue anyway? (y/N): "
    if /i not "!same_format!"=="y" (
        goto select_output_format
    )
)

echo.
echo ================================================
echo CONVERSION SUMMARY
echo ================================================
echo Source folder: !music_folder!
echo Input format:  !input_format!
echo Output format: !output_format!
echo Files to convert: !file_count!
echo ================================================
echo.

:: 询问是否删除原文件
set /p "delete_original=Delete original files after conversion? (y/N): "
if /i "!delete_original!"=="y" (
    set "delete_flag=--delete-original"
    echo.
    echo WARNING: Original !input_format! files will be DELETED after conversion!
    echo.
) else (
    set "delete_flag="
    echo.
    echo Original files will be kept.
    echo.
)

:: 确认转换
set /p "confirm=Are you sure you want to proceed? (y/N): "
if /i not "!confirm!"=="y" (
    echo Conversion cancelled.
    echo.
    set /p "another=Try different settings? (Y/n): "
    if /i "!another!"=="" goto main_menu
    if /i not "!another!"=="n" goto main_menu
    goto end_script
)

:: 运行converter.py进行转换
echo.
echo Starting conversion...
echo.

python converter.py "!music_folder!" "!input_format!" "!output_format!" !delete_flag!

if errorlevel 1 (
    echo.
    echo Conversion failed with error code: !errorlevel!
    echo.
) else (
    echo.
    echo Conversion completed successfully!
    echo.
    
    :: 显示转换后的文件
    echo Listing converted files:
    echo ----------------------------------------
    dir /b /s "!music_folder!\*.!output_format!" 2>nul
    
    :: 统计转换后的文件数量
    set "converted_count=0"
    for /f "tokens=*" %%f in ('dir /b /s "!music_folder!\*.!output_format!" 2^>nul') do (
        set /a converted_count+=1
    )
    
    echo ----------------------------------------
    echo Total converted files: !converted_count!
    echo.
)

echo.
set /p "another=Convert more files? (Y/n): "
if /i "!another!"=="" goto main_menu
if /i not "!another!"=="n" goto main_menu

:end_script
echo.
echo Audio File Converter closing...
echo Goodbye!
pause
endlocal
exit /b 0

:: 直接安装 FFmpeg 的函数（已有管理员权限）
:install_ffmpeg_direct
echo Installing FFmpeg directly...

set "INSTALL_DIR=C:\ffmpeg"
set "BIN_DIR=%INSTALL_DIR%\bin"

if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

echo Downloading FFmpeg...
set "DOWNLOAD_URL=https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
set "ZIP_FILE=%TEMP%\ffmpeg.zip"

powershell -NoProfile -ExecutionPolicy Bypass -Command "& {[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri '%DOWNLOAD_URL%' -OutFile '%ZIP_FILE%' -UseBasicParsing}"

if errorlevel 1 exit /b 1

echo Extracting...
powershell -NoProfile -ExecutionPolicy Bypass -Command "& {Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::ExtractToDirectory('%ZIP_FILE%', '%TEMP%\ffmpeg_extract')}"

for /d %%d in ("%TEMP%\ffmpeg_extract\ffmpeg-*") do set "EXTRACTED_DIR=%%d"
xcopy /E /I /Y "%EXTRACTED_DIR%\bin" "%BIN_DIR%" >nul

echo Setting PATH...
for /f "tokens=2*" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do set "CURRENT_PATH=%%b"
setx /M PATH "%CURRENT_PATH%;%BIN_DIR%" >nul

del "%ZIP_FILE%" >nul 2>&1
rmdir /s /q "%TEMP%\ffmpeg_extract" >nul 2>&1

echo FFmpeg installed successfully!
exit /b 0