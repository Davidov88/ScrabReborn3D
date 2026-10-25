$ErrorActionPreference='Stop'
$runtimeCache='D:\GameDev\cache\LowGridRuntime'
$mount=Join-Path $env:APPDATA 'LowGridScrapReborn3D'
New-Item -ItemType Directory -Path $runtimeCache -Force | Out-Null
if(Test-Path -LiteralPath $mount){
    $existing=Get-Item -LiteralPath $mount -Force
    if($existing.LinkType -ne 'Junction' -or $existing.Target -ne $runtimeCache){throw "Storage mount already exists with another target: $mount"}
}else{
    New-Item -ItemType Junction -Path $mount -Target $runtimeCache | Out-Null
}
Write-Output "Low Grid runtime data: $runtimeCache"
