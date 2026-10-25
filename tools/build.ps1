$ErrorActionPreference='Stop'
$projectDirectory=Split-Path -Parent $PSScriptRoot
$buildDirectory=Join-Path $projectDirectory 'build\windows'
New-Item -ItemType Directory -Path $buildDirectory -Force | Out-Null
& 'D:\GameDev\bin\godot.cmd' --headless --editor --path $projectDirectory --import --quit
if($LASTEXITCODE -ne 0){throw 'Godot import failed'}
$versionEntry=Select-String -LiteralPath (Join-Path $projectDirectory 'project.godot') -Pattern '^config/version="(.+)"'
$buildVersion=$versionEntry.Matches[0].Groups[1].Value
$executablePath=Join-Path $buildDirectory ('ScrapReborn-'+$buildVersion+'.exe')
& 'D:\GameDev\bin\godot.cmd' --headless --path $projectDirectory --export-release 'Windows Desktop' $executablePath
if($LASTEXITCODE -ne 0){throw 'Godot Windows export failed'}
Copy-Item -LiteralPath (Join-Path $projectDirectory 'README.md') -Destination $buildDirectory -Force
Copy-Item -LiteralPath (Join-Path $projectDirectory 'docs\CHANGES-0.1.1.md') -Destination $buildDirectory -Force
Copy-Item -LiteralPath (Join-Path $projectDirectory 'docs\CHANGES-0.1.2.md') -Destination $buildDirectory -Force
Copy-Item -LiteralPath (Join-Path $projectDirectory 'docs\STATUS.md') -Destination $buildDirectory -Force
Copy-Item -LiteralPath (Join-Path $projectDirectory 'third_party') -Destination $buildDirectory -Recurse -Force
Write-Output "Windows build: $buildDirectory"
