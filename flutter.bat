@echo off
set PUB_HOSTED_URL=https://pub.flutter-io.cn
set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
set PUB_CACHE=%~dp0.pub-cache

REM 本机地址必须绕开代理：flutter test 靠本地 WebSocket 连 flutter_tester，
REM 若 HTTP(S)_PROXY 已设而 NO_PROXY 未含 localhost，这条连接会被送进代理，
REM 报 "Invalid WebSocket upgrade request" 导致所有测试无法加载。
REM 不要写成 if/else 括号块：值里的 "::" 会被批处理当成标签，整个脚本解析失败。
set _RWB_BYPASS=localhost,127.0.0.1
if defined NO_PROXY set _RWB_BYPASS=%_RWB_BYPASS%,%NO_PROXY%
set NO_PROXY=%_RWB_BYPASS%
set _RWB_BYPASS=

REM 国内镜像 + Flutter SDK 路径
if not defined FLUTTER_ROOT set FLUTTER_ROOT=D:\flutter_windows_3.44.8-stable\flutter

REM 下面刻意用 goto 而非 if(...) 块：括号块内的 %errorlevel% 在解析整块时就被
REM 展开，拿到的是调用前的旧值，会把 flutter 的失败一律报成 0（测试失败也返回
REM 成功）。必须让 call 与 exit /b 各自独立成行，errorlevel 才是真实结果。
if not exist "%FLUTTER_ROOT%\bin\flutter.bat" goto :find_on_path
call "%FLUTTER_ROOT%\bin\flutter.bat" %*
exit /b %errorlevel%

:find_on_path
set _RWB_FLUTTER=
for /f "delims=" %%F in ('where flutter.bat 2^>nul') do call :pick_candidate "%%~fF"
if not defined _RWB_FLUTTER goto :not_found
call "%_RWB_FLUTTER%" %*
exit /b %errorlevel%

:pick_candidate
if defined _RWB_FLUTTER exit /b 0
if /i "%~f1"=="%~f0" exit /b 0
set _RWB_FLUTTER=%~f1
exit /b 0

:not_found
echo Flutter SDK not found. Add Flutter's bin directory to PATH or set FLUTTER_ROOT. 1>&2
exit /b 1
