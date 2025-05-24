# Import BitsTransfer module for faster downloads
Import-Module BitsTransfer

# Get the current script directory
$currentDir = $PSScriptRoot
if (!$currentDir) {
    $currentDir = (Get-Location).Path
}

# Define the URLs and output file names
$downloads = @(
    @{ Url = "https://github.com/ramensoftware/windhawk/releases/latest/download/windhawk_setup.exe"; File = "windhawk_setup.exe" }
)

# Start downloading files in parallel
$jobs = @()
foreach ($download in $downloads) {
    $destinationPath = Join-Path -Path $currentDir -ChildPath $download.File
    $jobs += Start-Job -ScriptBlock {
        param ($url, $destination)

        # Function to download a file using BITS
        function Download-FileFast {
            param (
                [string]$url,
                [string]$destination
            )

            Write-Host "Downloading $url to $destination..."
            try {
                Start-BitsTransfer -Source $url -Destination $destination -DisplayName "Downloading $(Split-Path $destination -Leaf)" -Priority High
                Write-Host "Downloaded $destination successfully."
                return $true
            } catch {
                Write-Host "Failed to download $url. Falling back to direct download..."
                try {
                    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                    $webClient = New-Object System.Net.WebClient
                    $webClient.DownloadFile($url, $destination)
                    Write-Host "Downloaded $destination successfully using fallback method."
                    return $true
                } catch {
                    Write-Host "All download attempts failed for $url"
                    return $false
                }
            }
        }

        # Call the function to download the file
        Download-FileFast -url $url -destination $destination
    } -ArgumentList $download.Url, $destinationPath
}

# Wait for all jobs to complete with timeout
$timeout = 300 # 5 minutes timeout
$completedJobs = $jobs | Wait-Job -Timeout $timeout
if ($completedJobs.Count -lt $jobs.Count) {
    Write-Host "Some downloads timed out after $timeout seconds"
    $jobs | Where-Object { $_.State -eq 'Running' } | Stop-Job
}

# Retrieve job results
$jobs | ForEach-Object { 
    $result = Receive-Job $_ -ErrorAction SilentlyContinue
    if (-not $result) {
        Write-Host "Download failed for one of the files"
    }
}
$jobs | Remove-Job

# Create a shortcut to run the command in PowerShell
$shortcutPath = Join-Path -Path $currentDir -ChildPath "WinUtil.lnk"

# Create the shortcut
$WshShell = New-Object -ComObject WScript.Shell
$shortcut = $WshShell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "powershell.exe"
$shortcut.Arguments = "-NoExit -ExecutionPolicy Bypass -Command ""Set-ExecutionPolicy Unrestricted -Scope Process -Force; irm 'https://christitus.com/win' | iex"""
$shortcut.IconLocation = "powershell.exe"
$shortcut.Save()

Clear-Host
Write-Host "Everything to make windows better is done downloading."
exit
