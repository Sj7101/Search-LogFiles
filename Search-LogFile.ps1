function Search-LogFiles {
    param (
        [string]$folderPath,          # UNC path to the folder to search
        [string]$searchPattern,       # Wildcard pattern to match log files
        [string[]]$searchStrings = @(), # Optional array of strings to search for
        [PSCredential]$credentials    # Optional credentials parameter
    )
    
    $results = @()

    # If no credentials are provided, use the current user's credentials
    if (-not $credentials) {
        $credentials = Get-Credential
    }

    # Debugging: Confirm UNC path access using Test-Path
    Write-Host "Checking UNC path access: $folderPath"

    try {
        # Check if the UNC path is accessible
        if (Test-Path $folderPath) {
            Write-Host "The UNC path '$folderPath' is accessible."
        } else {
            Write-Host "ERROR: The UNC path '$folderPath' is not accessible."
            return
        }

        # Test listing files directly using Get-ChildItem to confirm accessibility
        Write-Host "Attempting to list files in the directory: $folderPath"
        
        $testFiles = Get-ChildItem -Path $folderPath
        if ($testFiles.Count -eq 0) {
            Write-Host "No files found in the directory '$folderPath'."
        } else {
            Write-Host "Found files in the directory: $($testFiles.Count)"
            Write-Host "Files found: $($testFiles.Name)"
        }

        # Now attempt to search for the files matching the pattern
        Write-Host "Searching for files matching pattern '$searchPattern' in folder '$folderPath'"
        $logFiles = Get-ChildItem -Path $folderPath -Filter $searchPattern -File -Recurse

        # Check if any files are found
        if ($logFiles.Count -eq 0) {
            Write-Host "No files found matching the pattern '$searchPattern'."
        }

        # Iterate over each found log file
        foreach ($logFile in $logFiles) {
            Write-Host "Searching in: $($logFile.FullName)"
            
            # Read the content of the log file
            $logContent = Get-Content -Path $logFile.FullName

            # If no search strings are provided, use the default regex (e.g., 1 error, 2 error)
            if ($searchStrings.Count -eq 0) {
                Write-Host "No search strings provided. Using default pattern to match '1 error', '2 error', etc."
                # Updated regex pattern to match "1 error", "2 error", etc., and avoid "0 error"
                $pattern = '([1-9][0-9]*|[1-9]) error' 
                Write-Host "Applying default pattern: $pattern"
                $matches = $logContent | Select-String -Pattern $pattern -AllMatches
                if ($matches) {
                    foreach ($match in $matches) {
                        Write-Host "Found match: $($match.Matches.Value)"
                        $resultObject = [PSCustomObject]@{
                            LogFile     = $logFile.FullName
                            Line        = $match.Line
                            LineNumber  = $match.LineNumber
                            Match       = $match.Matches.Value
                            SearchString= "Default pattern: $pattern"
                        }
                        $results += $resultObject
                    }
                } else {
                    Write-Host "No match found for default pattern: $pattern"
                }
            } else {
                Write-Host "Searching using custom search strings."
                # Use the provided search strings
                foreach ($searchString in $searchStrings) {
                    $pattern = $searchString
                    Write-Host "Applying custom pattern: $pattern"
                    $matches = $logContent | Select-String -Pattern $pattern -AllMatches

                    if ($matches) {
                        foreach ($match in $matches) {
                            Write-Host "Found match: $($match.Matches.Value)"
                            $resultObject = [PSCustomObject]@{
                                LogFile     = $logFile.FullName
                                Line        = $match.Line
                                LineNumber  = $match.LineNumber
                                Match       = $match.Matches.Value
                                SearchString= $searchString
                            }
                            $results += $resultObject
                        }
                    } else {
                        Write-Host "No match found for custom pattern: $pattern"
                    }
                }
            }
        }
    } catch {
        Write-Host "ERROR: There was an issue: $_"
    }

    return $results
}
