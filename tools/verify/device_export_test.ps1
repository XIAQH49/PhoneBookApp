# v0.6 真机验证驱动：主页点"导出原始文件"按钮 → 检查保存选择器是否弹出。
# 依赖：m2_reg_home.json（reconnect watcher 产出）；保存框需用户手动确认保存。
$hdc = 'D:\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
$log = 'm2_export_test.log'

function Find-Bounds($jsonPath, $textMatch) {
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
          $script:found = @{ x = [int]$x; y = [int]$y }
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

"[$([DateTime]::Now.ToString('HH:mm:ss'))] export test start" | Add-Content $log
if (-not (Test-Path m2_reg_home.json)) {
  "[export] no m2_reg_home.json" | Add-Content $log
  Write-Output 'NO_HOME'
  exit 1
}
$b = Find-Bounds m2_reg_home.json '导出原始文件'
if (-not $b) {
  "[export] button not found" | Add-Content $log
  Write-Output 'NO_BUTTON'
  exit 1
}
"[$([DateTime]::Now.ToString('HH:mm:ss'))] tap button at ($($b.x), $($b.y))" | Add-Content $log
& $hdc shell uinput -T -c $b.x $b.y 2>&1 | Out-Null
Start-Sleep -Seconds 3
$missions = & $hdc shell aa dump --all 2>&1 | Out-String
$pickerHit = ($missions -match 'filepicker|FilePicker|picker')
"[export] missions: $($missions.Substring(0, [Math]::Min(300, $missions.Length)))" | Add-Content $log
Write-Output ("PICKER_DETECTED=" + $pickerHit)
Write-Output 'EXPORT_TEST_DONE'
exit 0
