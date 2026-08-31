@echo off
rem ============================================================
rem v0.6 PC 意图直达导入：解析 Excel/CSV 名单 → hdc 分批推送
rem 用法：send_list.bat [名单文件]    （缺省取本目录下最新 .xlsx）
rem 环境：需已连接手机（hdc list targets 可见）+ APP 已用 IDE Run 安装
rem ============================================================
setlocal
cd /d "%~dp0"

rem ---- 定位文件：参数优先，否则同目录最新 .xlsx ----
set "FILE=%~1"
if "%FILE%"=="" (
  for /f "delims=" %%f in ('dir /b /o-d /a-d *.xlsx 2^>nul') do (
    set "FILE=%%f"
    goto :found
  )
  echo [send_list] 未找到 xlsx 文件，请传参：send_list.bat ^<文件^>
  exit /b 1
)
:found
if not exist "%FILE%" (
  echo [send_list] 文件不存在: %FILE%
  exit /b 1
)

rem ---- 定位 node（优先 PATH，其次 DevEco 内置 node）----
set "NODE=node"
where node >nul 2>nul || set "NODE=D:\DevEco Studio\tools\node\node.exe"
if not exist "%NODE%" (
  echo [send_list] 未找到 node，请安装 Node.js 或设置 PATH
  exit /b 1
)

rem ---- 定位 hdc（优先 PATH，其次 DevEco SDK 固定路径）----
where hdc >nul 2>nul || set "HDC=D:\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe"
"%HDC%" list targets >nul 2>nul
if errorlevel 1 (
  echo [send_list] hdc 不可用或未连接设备，请检查 USB/授权
  exit /b 1
)

echo [send_list] 文件: %FILE%
echo [send_list] 解析并分批推送中...

"%NODE%" --import ..\verify\register.mjs sender.ts "%FILE%"
if errorlevel 1 (
  echo [send_list] 发送失败，详见上方输出
  exit /b 1
)

echo [send_list] 完成。手机 APP 导入成功后主页会提示“已从内网导入 N 条”
endlocal
