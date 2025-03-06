# Search-LogFiles PowerShell Function

This PowerShell function allows you to search through log files in a specified directory for a specific string and display the results.

## Features

- Search for a string within all `.log` files in a given directory.
- Display the log file names where the string is found.
- Show the lines in the log files where the string matches.

## Requirements

- PowerShell 5.0 or later.
- Log files should be in the `.log` format (can be customized in the script if needed).

## Usage

### Function Definition

```powershell
function Search-LogFiles {
    param (
        [string]$logDirectory,    # Directory to search for log files
        [string]$searchString     # The string to search for
    )
    
    # Get all .log files in the specified directory
    $logFiles = Get-ChildItem -Path $logDirectory -Filter "*.log"
    
    # Iterate through each log file
    foreach ($logFile in $logFiles) {
        Write-Host "Searching in: $($logFile.FullName)"
        
        # Read the content of the log file
        $logContent = Get-Content -Path $logFile.FullName
        
        # Search for the string and display results
        $matches = $logContent | Select-String -Pattern $searchString
        if ($matches) {
            Write-Host "Found in: $($logFile.FullName)"
            $matches | ForEach-Object { Write-Host $_.Line }
        } else {
            Write-Host "No matches found in: $($logFile.FullName)"
        }
    }
}
