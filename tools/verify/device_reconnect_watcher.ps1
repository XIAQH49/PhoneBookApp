# 设备重连自动验证：轮询 hdc targets，一旦设备上线即拉起应用并抓取主页布局。
$hdc = 'D:\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
$log = 'm2_reconnect.log'
$maxTries = 40
$sleepSec = 45

"[$([DateTime]::Now.ToString('HH:mm:ss'))] reconnect watcher start" | Add-Content $log
for ($i = 1; $i -le $maxTries; $i++) {
  $t = (& $hdc list targets 2>&1 | Out-String).Trim()
  if ($t -ne '[Empty]' -and $t.Length -ge 6 -and $t -notmatch '\s') {
    "[$([DateTime]::Now.ToString('HH:mm:ss'))] device online: $t" | Add-Content $log
    & $hdc shell aa start -b com.example.phonebookapp -a EntryAbility 2>&1 | Out-Null
    Start-Sleep -Seconds 8
    $d = & $hdc shell uitest dumpLayout 2>&1 | Out-String
    if ($d -match 'saved to:(\S+)') {
      & $hdc file recv $Matches[1] m2_reg_home.json 2>&1 | Out-Null
      "[$([DateTime]::Now.ToString('HH:mm:ss'))] home layout fetched" | Add-Content $log
    } else {
      "[$([DateTime]::Now.ToString('HH:mm:ss'))] dumpLayout failed: $d" | Add-Content $log
    }
    "[$([DateTime]::Now.ToString('HH:mm:ss'))] watcher done (device online)" | Add-Content $log
    exit 0
  }
  Start-Sleep -Seconds $sleepSec
}
"[$([DateTime]::Now.ToString('HH:mm:ss'))] watcher done (device offline)" | Add-Content $log
exit 1
