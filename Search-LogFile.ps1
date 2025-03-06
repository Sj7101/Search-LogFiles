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
<#
$logFiles = @("C:\Logs\log1.log", "C:\Logs\log2.log")
$searchStrings = @("Shawn@Test.com", "Bill@Test.com")
$results = Search-LogFiles -logFiles $logFiles -searchStrings $searchStrings

# Display the results
$results | Format-Table -Property LogFile, LineNumber, Match, SearchString
#>