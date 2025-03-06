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


<#
$logFiles = @("C:\Logs\log1.log", "C:\Logs\log2.log")
$searchString = "Error"
$results = Search-LogFiles -logFiles $logFiles -searchString $searchString

# Display the results
$results | Format-Table -Property LogFile, LineNumber, Match

#>