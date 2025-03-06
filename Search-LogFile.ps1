function Search-LogFiles {
    param (
        [string[]]$logFiles,          # Array of log file paths to search
        [string[]]$searchStrings      # Array of strings to search for
    )
    
    $results = @()

    # Prompt for credentials using Get-Credential
    $credentials = Get-Credential

    # Create a temporary PSDrive with the provided credentials
    $driveName = "Z"  # Temporary drive letter
    New-PSDrive -Name $driveName -PSProvider FileSystem -Root "\\server\share" -Credential $credentials -Persist

    # Iterate through each log file
    foreach ($logFile in $logFiles) {
        $mappedPath = $logFile -replace "^\\\\", "\\$driveName\"  # Replace UNC with mapped drive

        if (Test-Path $mappedPath) {
            Write-Host "Searching in: $mappedPath"
            
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
    }

    # Remove the temporary mapped drive after usage
    Remove-PSDrive -Name $driveName

    return $results
}
<#
$logFiles = @("\\server\share\log1.log", "\\server\share\log2.log")
$searchStrings = @("error(s)")  # This will match "1 error(s)", "2 error(s)", etc.
$results = Search-LogFiles -logFiles $logFiles -searchStrings $searchStrings

# Display the results
$results | Format-Table -Property LogFile, LineNumber, Match, SearchString
#>