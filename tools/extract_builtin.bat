@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
rem ============================================================
rem 从已安装的外呼名单 APP 中提取内置名单（rawfile/名单.xlsx）
rem 用途：办公手机上提取打包时的完整名单用于比对/调试
rem 使用：手机连电脑（开发者模式）后双击运行本脚本
rem ============================================================

set "HDC=hdc"
where hdc >nul 2>nul
if errorlevel 1 (
    if exist "D:\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe" (
        set "HDC=D:\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe"
    ) else (
        echo [错误] 未找到 hdc。请确认 DevEco Studio 安装路径，并手动修改本脚本开头的 HDC 变量。
        pause
        exit /b 1
    )
)

echo [1/5] 检查设备连接...
%HDC% list targets
if errorlevel 1 (
    echo [错误] 未检测到设备。请检查 USB 连接与开发者模式。
    pause
    exit /b 1
)

echo [2/5] 查找已安装 HAP 路径...
for /f "tokens=2 delims=:" %%a in ('%HDC% shell bm dump -n com.example.phonebookapp 2^>nul ^| findstr /c:"hapPath"') do set "HAPPATH=%%a"
if not defined HAPPATH (
    echo [错误] 未找到应用安装路径。请确认手机已安装"外呼名单"APP。
    pause
    exit /b 1
)
rem 去掉引号与首尾空格
set "HAPPATH=!HAPPATH: =!"
set "HAPPATH=!HAPPATH:"=!"
echo        HAP 路径: !HAPPATH!

echo [3/5] 复制到可拉取目录并下载...
%HDC% shell "cp !HAPPATH! /data/local/tmp/extract_entry.hap"
if errorlevel 1 (
    echo [错误] 无法读取安装包（shell 用户无 /data/app 权限，属正常限制）。
    echo        备选方案：
    echo          A. 完整名单就在电脑仓库 entry\src\main\resources\rawfile\名单.xlsx（打包源文件）；
    echo          B. 用仓库内 tools\verify\file_hash.ts 比对 该文件 与 内网最新导出 的哈希；
    echo          C. 从内网重新导出一次即可。
    pause
    exit /b 1
)
%HDC% file recv /data/local/tmp/extract_entry.hap extracted_entry.hap
if errorlevel 1 (
    echo [错误] 下载失败。
    pause
    exit /b 1
)

echo [4/5] 解包（HAP 即 zip）...
if exist extracted rmdir /s /q extracted
mkdir extracted
tar -xf extracted_entry.hap -C extracted
if errorlevel 1 (
    echo [错误] 解包失败。
    pause
    exit /b 1
)

echo [5/5] 查找内置名单...
set "FOUND="
for /r extracted %%f in (*.xlsx *.csv) do (
    echo        找到: %%f
    set "FOUND=1"
)
if not defined FOUND (
    echo [提示] 安装包内未发现 xlsx/csv 名单文件（该版本可能未内置名单）。
) else (
    echo 完成：请用 Excel 打开上面路径的文件核对名单。
)
pause
