function Search-LogsInZip {
    param (
        [string]$folderPath,          # UNC path to the folder containing .zip files
        [string]$searchPattern,       # Wildcard pattern to match log files
        [string[]]$searchStrings = @(), # Optional array of strings to search for
        [string]$startTimestamp,      # Start timestamp in the format DD/MMM/YYYY:HH:MM:SS
        [string]$endTimestamp,        # End timestamp in the format DD/MMM/YYYY:HH:MM:SS
        [PSCredential]$credentials    # Optional credentials parameter
    )

    # Check if the required PowerShell version supports Expand-Archive
    $isPSCore = $PSVersionTable.PSVersion.Major -ge 6

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
        
        # Extract the zip file to a temporary folder using Expand-Archive (available in PowerShell 5.1 and later)
        $tempFolder = New-TemporaryFile | Remove-Item -Force | New-Item -ItemType Directory
        try {
            # If PowerShell Core, use Expand-Archive cmdlet
            if ($isPSCore) {
                Expand-Archive -Path $zipFile.FullName -DestinationPath $tempFolder.FullName -Force
            }
            else {
                # For Windows PowerShell, load the assembly to extract zip files
                [System.IO.Compression.ZipFile]::ExtractToDirectory($zipFile.FullName, $tempFolder.FullName)
            }

            # Get all the extracted log files (without extensions)
            $logFiles = Get-ChildItem -Path $tempFolder.FullName
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
                        Write-Host "Timestamp does not match the range."
                    }
                } else {
                    Write-Host "No valid timestamp found in the last 6 lines."
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
