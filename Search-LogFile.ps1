function Search-LogFiles {
    param (
        [string[]]$logFiles,          # Array of log file paths to search
        [string[]]$searchStrings,     # Array of strings to search for
        [PSCredential]$credentials    # Optional credentials parameter
    )
    
    $results = @()

    # If no credentials are provided, use the current user's credentials
    if (-not $credentials) {
        $credentials = Get-Credential
    }

    # Iterate through each log file
    foreach ($logFile in $logFiles) {
        $folderPath = [System.IO.Path]::GetDirectoryName($logFile)  # Get the folder path of the log file
        $serverName = ($folderPath -split '\\')[2]  # Extract the server name from the UNC path
        $driveName = "Z$serverName"  # Use a unique temporary drive letter for each server

        # Ensure the folderPath is a valid UNC path
        if ($folderPath -match "^\\\\") {
            try {
                # Create a temporary PSDrive with the provided credentials mapped to the folder
                New-PSDrive -Name $driveName -PSProvider FileSystem -Root $folderPath -Credential $credentials -Persist

                if (Test-Path $logFile) {
                    Write-Host "Searching in: $logFile"
                    
                    # Replace the UNC path with the mapped drive letter for the file
                    $mappedPath = $logFile -replace "^\\\\", "\\$driveName\"

                    # Read the content of the log file
                    $logContent = Get-Content -Path $mappedPath

                    # Search for any of the strings in the array using RegEx
                    foreach ($searchString in $searchStrings) {
                        # If searching for "error(s)", use a RegEx pattern
                        if ($searchString -match "^error\(s\)$") {
                            $pattern = '\d+ error\(s\)'  # Match "1 error(s)", "2 error(s)", etc.
                        } else {
                            $pattern = $searchString  # Use the search string directly
                        }

                        $matches = $logContent | Select-String -Pattern $pattern
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

                # Remove the temporary mapped drive after usage
                Remove-PSDrive -Name $driveName
            } catch {
                Write-Host "Error mapping network drive to $folderPath: $_"
            }
        } else {
            Write-Host "Invalid network path: $folderPath"
        }
    }

    return $results
}

<#
# Get credentials manually
$credentials = Get-Credential

$logFiles = @(
    "\\server1\D$\Logs\Many\log1.log", 
    "\\server2\D$\Logs\Many\log2.log", 
    "\\server3\D$\Logs\Many\log3.log"
)
$searchStrings = @("error(s)", "Warning", "Failed")

$results = Search-LogFiles -logFiles $logFiles -searchStrings $searchStrings -credentials $credentials

# Display the results
$results | Format-Table -Property LogFile, LineNumber, Match, SearchString

#>