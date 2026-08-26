# M2 真机回归自动等待器：设备锁屏时轮询，解锁后自动拉起应用并抓取布局快照。
# 用法：pwsh -File tools/verify/device_watcher.ps1   （后台运行，日志见 m2_watcher.log）
$hdc = 'D:\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
$log = 'm2_watcher.log'
$maxTries = 45
$sleepSec = 60

"[$([DateTime]::Now.ToString('HH:mm:ss'))] watcher start, maxTries=$maxTries interval=${sleepSec}s" | Add-Content $log
for ($i = 1; $i -le $maxTries; $i++) {
  & $hdc shell power-shell wakeup 2>&1 | Out-Null
  Start-Sleep -Milliseconds 800
  # 尝试上滑解锁（无密码时可直接解锁；人脸解锁时触发识别）
  & $hdc shell uinput -T -m 660 2820 660 500 150 2>&1 | Out-Null
  Start-Sleep -Seconds 2
  $out = (& $hdc shell aa start -b com.example.phonebookapp -a EntryAbility 2>&1 | Out-String).Trim()
  "[$([DateTime]::Now.ToString('HH:mm:ss'))] try#$i : $out" | Add-Content $log
  if ($out -notmatch 'failed') {
    "[$([DateTime]::Now.ToString('HH:mm:ss'))] LAUNCH OK, waiting app render" | Add-Content $log
    Start-Sleep -Seconds 6
    $d = & $hdc shell uitest dumpLayout 2>&1 | Out-String
    $d | Add-Content $log
    if ($d -match 'saved to:(\S+)') {
      $remote = $Matches[1]
      & $hdc file recv $remote m2_reg_home.json 2>&1 | Out-Null
      "[$([DateTime]::Now.ToString('HH:mm:ss'))] home layout fetched -> m2_reg_home.json" | Add-Content $log
    }
    "[$([DateTime]::Now.ToString('HH:mm:ss'))] watcher done (launched)" | Add-Content $log
    exit 0
  }
  Start-Sleep -Seconds $sleepSec
}
"[$([DateTime]::Now.ToString('HH:mm:ss'))] watcher done (max tries, still locked)" | Add-Content $log
exit 1
