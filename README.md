# Search-LogFiles PowerShell Function

This PowerShell function allows you to search through one or more log files in a specified directory for multiple strings and return an object containing the search results. It supports running the search with a user account for accessing log files that require elevated permissions using `Get-Credential`.

## Features

- Search for multiple strings within one or more `.log` files.
- Return an object with details about each match found:
  - Log file name
  - Line number
  - The exact match
  - The search string that was matched
- Supports elevated permissions by using `Get-Credential` to access log files on remote servers or protected locations.

## Requirements

- PowerShell 5.0 or later.
- Log files should be in the `.log` format (can be customized if needed).
- Elevated permissions (optional) for accessing restricted log files.

## Usage

### Function Definition

```powershell
function Search-LogFiles {
    param (
        [string[]]$logFiles,          # Array of log file paths to search
        [string[]]$searchStrings      # Array of strings to search for
    )
    
    $results = @()

    # Prompt for credentials using Get-Credential
    $credentials = Get-Credential

    # Iterate through each log file
    foreach ($logFile in $logFiles) {
        if (Test-Path $logFile) {
            Write-Host "Searching in: $logFile"
            
            # If elevated permissions are needed, run the script with the provided credentials
            $logContent = Invoke-Command -ScriptBlock {
                Get-Content -Path $using:logFile
            } -Credential $credentials

            # Search for any of the strings in the array
            foreach ($searchString in $searchStrings) {
                $matches = $logContent | Select-String -Pattern $searchString
                if ($matches) {
                    foreach ($match in $matches) {
                        $resultObject = [PSCustomObject]@{
                            LogFile     = $logFile
                            Line        = $match.Line
                            LineNumber  = $match.LineNumber
                            Match       = $match.Matches.Value
                            SearchString= $searchString
                        }
                        $results += $resultObject
                    }
                }
            }
        } else {
            Write-Host "Log file not found: $logFile"
        }
    }

    return $results
}
