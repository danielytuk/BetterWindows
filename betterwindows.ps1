# Define the URLs and output file names
$downloads = @(
    @{ Url = "https://github.com/memstechtips/Winhance/releases/latest/download/Winhance.Installer.exe"; File = "Winhance.Installer.exe" },
    @{ Url = "https://github.com/ramensoftware/windhawk/releases/latest/download/windhawk_setup.exe"; File = "windhawk_setup.exe" }
)

# Start downloading files in parallel
$jobs = @()
foreach ($download in $downloads) {
    $jobs += Start-Job -ScriptBlock {
        param ($url, $destination)

        # Function to download a file
        function Download-File {
            param (
                [string]$url,
                [string]$destination
            )

            Write-Host "Downloading $url to $destination..."
            try {
                Invoke-WebRequest -Uri $url -OutFile $destination -ErrorAction Stop
                Write-Host "Downloaded $destination successfully."
            } catch {
                Write-Host "Failed to download $url"  # Fixed variable reference
                exit 1
            }
        }

        # Call the function to download the file
        Download-File -url $url -destination $destination
    } -ArgumentList $download.Url, $download.File
}

# Wait for all jobs to complete
Write-Host "Waiting for downloads to complete..."
$jobs | Wait-Job

# Retrieve job results
$jobs | ForEach-Object { Receive-Job $_ }
$jobs | Remove-Job

# Create a shortcut to run the command in PowerShell
$shortcutPath = Join-Path -Path (Get-Location) -ChildPath "WinUtil.lnk"

# Create the shortcut
$WshShell = New-Object -ComObject WScript.Shell
$shortcut = $WshShell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "powershell.exe"
$shortcut.Arguments = "-NoExit -ExecutionPolicy Bypass -Command ""irm 'https://christitus.com/win' | iex"""
$shortcut.IconLocation = "powershell.exe"
$shortcut.Save()

clear
Write-Host "Everything to make windows better is done downloading."
exit
