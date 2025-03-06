# Search-LogFiles PowerShell Function

This PowerShell function allows you to search through one or more log files in a specified directory for a specific string and return an object containing the search results.

## Features

- Search for a string within multiple `.log` files.
- Return an object with details about each match found.
  - Log file name
  - Line number
  - The exact match
- Support for searching multiple log files at once.
- Allows easy integration into other scripts for further processing.

## Requirements

- PowerShell 5.0 or later.
- Log files should be in the `.log` format (can be customized if needed).

## Usage

### Function Definition

```powershell
function Search-LogFiles {
    param (
        [string[]]$logFiles,      # Array of log file paths to search
        [string]$searchString     # The string to search for
    )
    
    $results = @()

    # Iterate through each log file
    foreach ($logFile in $logFiles) {
        if (Test-Path $logFile) {
            Write-Host "Searching in: $logFile"
            
            # Read the content of the log file
            $logContent = Get-Content -Path $logFile
            
            # Search for the string and collect matches
            $matches = $logContent | Select-String -Pattern $searchString
            if ($matches) {
                foreach ($match in $matches) {
                    $resultObject = [PSCustomObject]@{
                        LogFile   = $logFile
                        Line      = $match.Line
                        LineNumber= $match.LineNumber
                        Match     = $match.Matches.Value
                    }
                    $results += $resultObject
                }
            } else {
                Write-Host "No matches found in: $logFile"
            }
        } else {
            Write-Host "Log file not found: $logFile"
        }
    }

    return $results
}
