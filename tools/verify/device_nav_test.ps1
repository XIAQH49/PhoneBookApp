# M2 真机导航回归驱动（依赖设备已解锁 + 应用已拉起 + m2_reg_home.json 布局快照存在）。
# 流程：主页 → 点 ⚙ 进设置 → 验证设置页布局 → 点 ← 返回 → 验证回主页。
# 用法：pwsh -NoProfile -File tools/verify/device_nav_test.ps1
$hdc = 'D:\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
$log = 'm2_nav_test.log'
$ErrorActionPreference = 'Continue'

function Get-Center($jsonPath, $textMatch) {
  $j = Get-Content $jsonPath -Raw | ConvertFrom-Json
  $found = $null
  $walk = { param($n)
    foreach ($c in $n.children) {
      $a = $c.attributes
      if ($a.text -and $a.text.Contains($textMatch) -and $a.bounds) {
        $m = [regex]::Match($a.bounds, '[(d+),(d+)][(d+),(d+)]')
        if ($m.Success) {
          $x = ([int]$m.Groups[1].Value + [int]$m.Groups[3].Value) / 2
          $y = ([int]$m.Groups[2].Value + [int]$m.Groups[4].Value) / 2
          $script:found = @{ x = [int]$x; y = [int]$y; text = $a.text }
          return
        }
      }
      & $walk $c
      if ($script:found) { return }
    }
  }
  & $walk $j
  return $script:found
}

function Dump-Layout($name) {
  $d = (& $hdc shell uitest dumpLayout 2>&1 | Out-String)
  if ($d -match 'saved to:(S+)') {
    & $hdc file recv $Matches[1] $name 2>&1 | Out-Null
    return $name
  }
  return $null
}

function Get-Texts($jsonPath) {
  $j = Get-Content $jsonPath -Raw | ConvertFrom-Json
  $out = @()
  $walk = { param($n)
    foreach ($c in $n.children) {
      $a = $c.attributes
      if ($a.text) { $out += $a.text.Trim() }
      & $walk $c
    }
  }
  & $walk $j
  return ($out | Where-Object { $_ -ne '' })
}

"[$([DateTime]::Now.ToString('HH:mm:ss'))] nav test start" | Add-Content $log

if (-not (Test-Path m2_reg_home.json)) {
  "[nav] no m2_reg_home.json, run device_watcher first" | Add-Content $log
  Write-Output 'NO_HOME_LAYOUT'
  exit 1
}

$home1 = Get-Texts m2_reg_home.json
"[nav] home texts: $($home1 -join ' | ')" | Add-Content $log
Write-Output ("HOME1: " + ($home1 -join ' | '))

# 1. 点 ⚙ 进设置
$g = Get-Center m2_reg_home.json ' ⚙'
if (-not $g) { $g = Get-Center m2_reg_home.json '⚙' }
if (-not $g) {
  "[nav] settings gear icon not found" | Add-Content $log
  Write-Output 'NO_GEAR'
  exit 1
}
& $hdc shell uinput -T -c $g.x $g.y 2>&1 | Out-Null
Start-Sleep -Seconds 4
$settingsPath = Dump-Layout m2_reg_settings.json
$settingsTexts = Get-Texts m2_reg_settings.json
"[nav] settings texts: $($settingsTexts -join ' | ')" | Add-Content $log
Write-Output ("SETTINGS: " + ($settingsTexts -join ' | '))

# 2. 点 ← 返回 回主页
$back = Get-Center m2_reg_settings.json '← 返回'
if (-not $back) { $back = Get-Center m2_reg_settings.json '返回' }
if (-not $back) {
  "[nav] back button not found in settings" | Add-Content $log
  Write-Output 'NO_BACK'
  exit 1
}
& $hdc shell uinput -T -c $back.x $back.y 2>&1 | Out-Null
Start-Sleep -Seconds 4
$homePath = Dump-Layout m2_reg_home2.json
$home2 = Get-Texts m2_reg_home2.json
"[nav] home2 texts: $($home2 -join ' | ')" | Add-Content $log
Write-Output ("HOME2: " + ($home2 -join ' | '))

"[$([DateTime]::Now.ToString('HH:mm:ss'))] nav test done" | Add-Content $log
Write-Output 'NAV_TEST_DONE'
exit 0
