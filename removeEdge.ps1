# Stop related processes
env:ErrorActionPreference = 'SilentlyContinue'
"MicrosoftEdgeUpdate","OneDrive","WidgetService","Widgets","msedge" |
    Stop-Process -Force

# Uninstall Copilot
Get-AppxPackage -AllUsers *Microsoft.Windows.Ai.Copilot.Provider* |
    Remove-AppxPackage

# Disable Edge update & allow uninstall
$regSettings = @{
    'HKLM:\SOFTWARE\Microsoft\EdgeUpdate'            = @{ DoNotUpdateToEdgeWithChromium = @{Type='DWORD'; Value=1} }
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdateDev' = @{ AllowUninstall = @{Type='SZ'; Value=''}}
}
foreach ($path in $regSettings.Keys) {
    foreach ($name in $regSettings[$path].Keys) {
        reg add $path /v $name /t REG_$($regSettings[$path][$name].Type) /d $($regSettings[$path][$name].Value) /f >$null
    }
}

# Uninstall Edge
$edgeKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge'
$uninstall = (Get-ItemProperty $edgeKey).UninstallString + ' --force-uninstall'
if ($uninstall) { Start-Process -FilePath cmd -Args "/c $uninstall" -WindowStyle Hidden -Wait }
Remove-Item "$env:SystemRoot\SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe" -Recurse -Force

# Remove EdgeUpdate services & registry
$paths = @('LocalApplicationData','ProgramFilesX86','ProgramFiles') |
    ForEach-Object { $p = [Environment]::GetFolderPath($_); Get-ChildItem "$p\Microsoft\EdgeUpdate\*.*.*.*\MicrosoftEdgeUpdate.exe" -Recurse }
$regs  = @(
    'HKCU:\SOFTWARE','HKLM:\SOFTWARE','HKCU:\SOFTWARE\Policies','HKLM:\SOFTWARE\Policies',
    'HKCU:\SOFTWARE\WOW6432Node','HKLM:\SOFTWARE\WOW6432Node','HKCU:\SOFTWARE\WOW6432Node\Policies','HKLM:\SOFTWARE\WOW6432Node\Policies'
)
$regs | % { Remove-Item "$_\Microsoft\EdgeUpdate" -Recurse -Force }

foreach ($exe in $paths) {
    if (Test-Path $exe) {
        & $exe /unregsvc; Start-Sleep 3
        & $exe /uninstall; Start-Sleep 3
    }
}

# Cleanup EdgeWebView & folders
reg delete "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft EdgeWebView" /f >$null 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft EdgeWebView" /f >$null 2>&1
Remove-Item "$env:SystemDrive\Program Files (x86)\Microsoft" -Recurse -Force

# Remove Edge shortcuts
taskshell = {
    $list = @(
        "$env:SystemDrive\Windows\System32\config\systemprofile\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\Microsoft Edge.lnk",
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk",
        "$env:PUBLIC\Desktop\Microsoft Edge.lnk",
        "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk"
    )
    $list | Remove-Item -Force -ErrorAction SilentlyContinue
}
& $taskshell

# Clean user profiles & startup entries
Get-ChildItem 'C:\Users' -Directory |
    Where-Object { $_.Name -notin 'Public','Default','Default User','All Users' -and Test-Path "$_\NTUSER.DAT" } |
    ForEach-Object {
        $base = $_.FullName
        @( "Quick Launch\Microsoft Edge.lnk", "Desktop\Microsoft Edge.lnk",
           "Quick Launch\User Pinned\TaskBar\Microsoft Edge.lnk", "Start Menu\Programs\Microsoft Edge.lnk" ) |
            ForEach-Object { Remove-Item "$base\AppData\Roaming\Microsoft\Internet Explorer\$_" -Force -ErrorAction SilentlyContinue }
    }

Get-CimInstance Win32_UserProfile |
    Where-Object { -not $_.Special -and $_.SID -notmatch 'S-1-5-18|S-1-5-19|S-1-5-20' } |
    ForEach-Object {
        $sid = $_.SID; $hive = "HKU\\$sid"
        if (-not (Test-Path $hive)) { reg load $hive "$($_.LocalPath)\NTUSER.DAT" | Out-Null; Start-Sleep 2 }
        $key = "Registry::$hive\Software\Microsoft\Windows\CurrentVersion\Run"
        if (Test-Path $key) { Get-ItemProperty $key |
            Where-Object { $_.PSObject.Properties.Name -like 'MicrosoftEdgeAutoLaunch*' } |
            ForEach-Object { Remove-ItemProperty $key -Name $_.PSObject.Properties.Name -Force }
        }
        if (Test-Path $hive) { Start-Sleep 2; reg unload $hive }
    }

# Reinstall WebView2
winget install Microsoft.WebView2 --accept-source-agreements --accept-package-agreements -h
