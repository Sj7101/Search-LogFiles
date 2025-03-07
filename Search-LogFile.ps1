function Search-LogsInZip {
    param (
        [string]$folderPath,          # UNC path to the folder containing .zip files
        [string]$searchPattern,       # Wildcard pattern to match log files
        [string[]]$searchStrings = @(), # Optional array of strings to search for
        [datetime]$timestampToMatch,  # Timestamp in the format DD/MMM/YYYY:HH:MM:SS (e.g., "05/MAR/2025:17:32:02")
        [PSCredential]$credentials    # Optional credentials parameter
    )
    
    $results = @()

    # If no credentials are provided, use the current user's credentials
    if (-not $credentials) {
        $credentials = Get-Credential
    }

    # Check if the UNC path is accessible
    if (-not (Test-Path $folderPath)) {
        Write-Host "ERROR: The UNC path '$folderPath' is not accessible."
        return
    }

    # Get the list of all .zip files in the directory
    $zipFiles = Get-ChildItem -Path $folderPath -Filter "*.zip"
    if ($zipFiles.Count -eq 0) {
        Write-Host "No zip files found in the folder '$folderPath'."
        return
    }

    # Iterate over each .zip file
    foreach ($zipFile in $zipFiles) {
        Write-Host "Processing zip file: $($zipFile.FullName)"
        
        # Extract the zip file to a temporary folder
        $tempFolder = New-TemporaryFile | Remove-Item -Force | New-Item -ItemType Directory
        try {
            [System.IO.Compression.ZipFile]::ExtractToDirectory($zipFile.FullName, $tempFolder.FullName)

            # Get all the extracted log files (without extensions)
            $logFiles = Get-ChildItem -Path $tempFolder.FullName
            foreach ($logFile in $logFiles) {
                Write-Host "Processing log file: $($logFile.FullName)"
                
                # Read the last line of the log file to check the timestamp
                $logContent = Get-Content -Path $logFile.FullName
                $lastLine = $logContent[-1]

                # Match the timestamp in the last line (DD/MMM/YYYY:HH:MM:SS)
                $timestampPattern = '\d{2}/[A-Z]{3}/\d{4}:\d{2}:\d{2}:\d{2}'
                if ($lastLine -match $timestampPattern) {
                    $logTimestamp = $matches[0]
                    Write-Host "Last line timestamp: $logTimestamp"

                    # Compare the log file timestamp with the provided timestamp
                    if ($logTimestamp -eq $timestampToMatch) {
                        Write-Host "Timestamp matches. Searching for matches in log file."

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

                            # Create a result object with the matched lines
                            $resultObject = [PSCustomObject]@{
                                LogFile     = $logFile.FullName
                                LineNumber  = $lineNumber
                                Match       = $matchedLine
                                LinesAbove  = $linesToCapture -join "`n"
                                SearchString= $pattern
                            }
                            $results += $resultObject
                        }
                    } else {
                        Write-Host "Timestamp does not match."
                    }
                } else {
                    Write-Host "Last line does not contain a valid timestamp."
                }
            }
        } catch {
            Write-Host "ERROR: Failed to extract or process zip file: $($zipFile.FullName) - $_"
        } finally {
            # Clean up the temporary folder
            Remove-Item -Path $tempFolder.FullName -Recurse -Force
        }
    }

    return $results
}

<#
$folderPath = "\\server1\D$\Logs\Many\ziplip\logs"
$searchPattern = "SMTP*"  # Match all files starting with SMTP
$timestampToMatch = "05/MAR/2025:17:32:02"  # Exact timestamp to match

# Call the Search-LogsInZip function (no search strings provided, uses default pattern '1 error', '2 error', etc.)
$results = Search-LogsInZip -folderPath $folderPath -searchPattern $searchPattern -timestampToMatch $timestampToMatch

# Display the results
$results | Format-Table -Property LogFile, LineNumber, Match, SearchString, LinesAbove


$folderPath = "\\server1\D$\Logs\Many\ziplip\logs"
$searchPattern = "SMTP*"  # Match all files starting with SMTP
$searchStrings = @("Warning", "Failed")  # Custom search strings
$timestampToMatch = "05/MAR/2025:17:32:02"  # Exact timestamp to match

$results = Search-LogsInZip -folderPath $folderPath -searchPattern $searchPattern -searchStrings $searchStrings -timestampToMatch $timestampToMatch

# Display the results
$results | Format-Table -Property LogFile, LineNumber, Match, SearchString, LinesAbove

#>