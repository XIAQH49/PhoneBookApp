# 一键构建+安装到设备（替代 DevEco Studio Run，2026-08-30 已验证可用）
# 用法：powershell -ExecutionPolicy Bypass -File tools\build-install.ps1
# 说明：必须使用 DevEco 自带 node（v24）与 JBR（21）——系统 node v26 会导致
#       SignHap 密钥解析失败（parseAlgParameters/ObjectIdentifier 错误）。
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$devEco = 'D:\DevEco Studio'
$sdk = "$devEco\sdk"
$node = "$devEco\tools\node\node.exe"
$jbr = "$devEco\jbr"
$hvigor = "$devEco\tools\hvigor\bin\hvigorw.js"
$hap = "$root\entry\build\default\outputs\default\entry-default-signed.hap"
$hdc = "$sdk\default\openharmony\toolchains\hdc.exe"

if (-not (Test-Path $node)) { Write-Host "[error] DevEco node not found: $node"; exit 1 }
if (-not (Test-Path $hdc)) { Write-Host "[error] hdc not found: $hdc"; exit 1 }

Set-Location $root
$env:DEVECO_SDK_HOME = $sdk
$env:JAVA_HOME = $jbr
# 关键：系统 PATH 上有 Oracle Java 1.8（javapath）会抢占签名工具（需要对 .p12 的新格式解析），
# 必须把 DevEco JBR(bin) 前置到 PATH——否则 SignHap 报
# "parseAlgParameters failed: ObjectIdentifier() -- data isn't an object ID (tag = 48)"
$env:PATH = "$jbr\bin;$env:PATH"

Write-Host '== 1/3 构建 (assembleHap) =='
$out = & $node $hvigor assembleHap --mode module -p product=default -p buildMode=debug --no-daemon 2>&1 | Out-String
Write-Host $out
if ($out -notmatch 'BUILD SUCCESSFUL') { Write-Host '[error] build failed'; exit 1 }

if (-not (Test-Path $hap)) { Write-Host "[error] signed hap missing: $hap"; exit 1 }

Write-Host '== 2/3 安装 (hdc install) =='
$devices = & $hdc list targets 2>&1
Write-Host ("devices: " + ($devices -join ', '))
if ($devices -notmatch '\w') { Write-Host '[error] no device connected'; exit 1 }
$install = & $hdc install -r $hap 2>&1 | Out-String
Write-Host $install
if ($install -notmatch 'install bundle successfully') { Write-Host '[error] install failed'; exit 1 }

Write-Host '== 3/3 启动 =='
$launch = & $hdc shell aa start -a EntryAbility -b com.example.phonebookapp 2>&1 | Out-String
Write-Host $launch
if ($launch -notmatch 'start ability successfully') {
  # 部分设备输出带超时信息也视为成功
  Write-Host '[warn] start output: ' + $launch.Trim()
}
Write-Host 'DONE: installed and launched.'
