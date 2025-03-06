function Search-LogFiles {
    param (
        [string]$folderPath,          # UNC path to the folder to search
        [string]$searchPattern,       # Wildcard pattern to match log files
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
        $logFolderPath = [System.IO.Path]::GetDirectoryName($logFile)  # Get the folder path of the log file

        try {
            # Create a temporary PSDrive with the provided credentials mapped to the folder (without Persist)
            New-PSDrive -Name Z -PSProvider FileSystem -Root $logFolderPath -Credential $credentials

            # Get all the log files matching the search pattern (e.g., SMTP*) - no file extension filter
            $logFiles = Get-ChildItem -Path "Z:\" -Filter $searchPattern -File

            # Check if any files are found
            if ($logFiles.Count -eq 0) {
                Write-Host "No files found matching the pattern '$searchPattern'."
            }

            # Iterate over each found log file
            foreach ($logFile in $logFiles) {
                Write-Host "Searching in: $($logFile.FullName)"
                
                # Read the content of the log file
                $logContent = Get-Content -Path $logFile.FullName

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
                                LogFile     = $logFile.FullName
                                Line        = $match.Line
                                LineNumber  = $match.LineNumber
                                Match       = $match.Matches.Value
                                SearchString= $searchString
                            }
                            $results += $resultObject
                        }
                    }
                }
            }

            # Remove the temporary mapped drive after usage
            Remove-PSDrive -Name Z
        } catch {
            Write-Host "Error mapping network drive to $($logFolderPath): $_"
        }
    }

    return $results
}
<#
$folderPath = "\\server1\D$\Logs\Many"
$searchPattern = "SMTP*"  # Match all files starting with SMTP
$searchStrings = @("error(s)", "Warning", "Failed")

# Call the Search-LogFiles function
$results = Search-LogFiles -folderPath $folderPath -searchPattern $searchPattern -searchStrings $searchStrings

# Display the results
$results | Format-Table -Property LogFile, LineNumber, Match, SearchString
#>