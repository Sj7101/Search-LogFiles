function Search-LogsInZip {
    param (
        [string[]]$folderPaths,        # List of UNC paths to the folders containing .zip files
        [string]$searchPattern,        # Wildcard pattern to match log files (e.g., SMTP*)
        [string[]]$searchStrings = @(), # Optional array of strings to search for
        [string]$startTimestamp,       # Start timestamp in the format DD/MMM/YYYY:HH:MM:SS
        [string]$endTimestamp,         # End timestamp in the format DD/MMM/YYYY:HH:MM:SS
        [PSCredential]$credentials     # Optional credentials parameter
    )

    $allResults = @()

    # If no credentials are provided, use the current user's credentials
    if (-not $credentials) {
        $credentials = Get-Credential
    }

    # Iterate over each UNC path provided in the array
    foreach ($folderPath in $folderPaths) {
        # Check if the UNC path is accessible
        if (-not (Test-Path $folderPath)) {
            Write-Host "ERROR: The UNC path '$folderPath' is not accessible."
            continue
        }

        # Get the list of all .zip files in the directory
        $zipFiles = Get-ChildItem -Path $folderPath -Filter "*.zip"
        if ($zipFiles.Count -eq 0) {
            Write-Host "No zip files found in the folder '$folderPath'."
            continue
        }

        # Iterate over each .zip file
        foreach ($zipFile in $zipFiles) {
            Write-Host "Processing zip file: $($zipFile.FullName)"
            
            # Create a temporary folder for extraction
            $tempFolderPath = Join-Path -Path $env:TEMP -ChildPath ([System.IO.Path]::GetFileNameWithoutExtension($zipFile.Name))
            New-Item -Path $tempFolderPath -ItemType Directory -Force | Out-Null

            try {
                # Use Expand-Archive cmdlet to extract the zip file to the temporary folder (Suppress output)
                Expand-Archive -Path $zipFile.FullName -DestinationPath $tempFolderPath -Force | Out-Null

                # Get all the extracted log files (without extensions) and filter by the search pattern
                $logFiles = Get-ChildItem -Path $tempFolderPath | Where-Object { 
                    $_.Name -like $searchPattern -and -not $_.PSIsContainer
                }

                # Process only the files that match the search pattern
                foreach ($logFile in $logFiles) {
                    Write-Host "Processing log file: $($logFile.FullName)"
                    
                    # Read the content of the log file
                    $logContent = Get-Content -Path $logFile.FullName
                    $lastLine = $logContent[-1]
                    $timestampPattern = '\d{2}/[A-Z]{3}/\d{4}:\d{2}:\d{2}:\d{2}'  # Pattern to match the timestamp format

                    # Check for timestamp in the last line or the previous 5 lines
                    $logTimestamp = $null
                    $linesToCheck = $logContent[-6..-1]  # Get the last 6 lines (last line + 5 lines before)

                    foreach ($line in $linesToCheck) {
                        if ($line -match $timestampPattern) {
                            $logTimestamp = $matches[0]
                            Write-Host "Timestamp found: $logTimestamp"
                            break
                        }
                    }

                    if ($logTimestamp) {
                        # Compare the extracted timestamp (as a string) with the provided range
                        if ($logTimestamp -ge $startTimestamp -and $logTimestamp -le $endTimestamp) {
                            Write-Host "Timestamp matches the range. Searching for matches in log file."

                            # Search for the provided search strings or the default regex
                            $pattern = if ($searchStrings.Count -eq 0) { '([1-9][0-9]* error)' } else { $searchStrings }
                            
                            # Process each line of the log file
                            $lineMatches = $logContent | Select-String -Pattern $pattern -AllMatches
                            
                            foreach ($lineMatch in $lineMatches) {
                                # Capture the matched line and the 5 lines above it
                                $lineNumber = $lineMatch.LineNumber
                                $matchedLine = $lineMatch.Line
                                $linesToCapture = @()

                                # Capture the matched line and 5 lines above
                                for ($i = $lineNumber - 5; $i -le $lineNumber; $i++) {
                                    if ($i -gt 0 -and $i -lt $logContent.Count) {
                                        $linesToCapture += $logContent[$i]
                                    }
                                }

                                # Create a result object with the matched lines and include the original .zip file path
                                $resultObject = [PSCustomObject]@{
                                    ZipFile     = $zipFile.FullName       # Store the original .zip file path
                                    LogFile     = $logFile.FullName       # Store the extracted log file path
                                    LineNumber  = $lineNumber
                                    Match       = $matchedLine
                                    LinesAbove  = $linesToCapture -join "`n"
                                    SearchString= $pattern
                                }
                                # Add the result to the total results array
                                $allResults += $resultObject
                            }
                        } else {
                            Write-Host "Timestamp does not match the range."
                        }
                    } else {
                        Write-Host "No valid timestamp found in the last 6 lines."
                    }
                }
            } catch {
                Write-Host "ERROR: Failed to extract or process zip file: $($zipFile.FullName) - $_"
            } finally {
                # Clean up the temporary folder (Suppress output from Remove-Item)
                Remove-Item -Path $tempFolderPath -Recurse -Force | Out-Null
            }
        }
    }

    # Return the aggregated results from all paths
    return $allResults
}
