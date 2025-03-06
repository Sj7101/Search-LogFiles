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
        $folderPath = [System.IO.Path]::GetDirectoryName($logFile)  # Get the folder path of the log file
        $serverName = ($folderPath -split '\\')[2]  # Extract the server name from the UNC path
        $driveName = "Z$serverName"  # Use a unique temporary drive letter for each server

        # Ensure the folderPath is a valid UNC path
        if ($folderPath -match "^\\\\") {
            try {
                # Create a temporary PSDrive with the provided credentials mapped to the folder on the server
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
<# $logFiles = @(
    "\\server1\share\folder\log1.log", 
    "\\server2\share\folder\log2.log", 
    "\\server3\share\folder\log3.log"
)
$searchStrings = @("error(s)", "Warning", "Failed")
$results = Search-LogFiles -logFiles $logFiles -searchStrings $searchStrings

# Display the results
$results | Format-Table -Property LogFile, LineNumber, Match, SearchString
#>