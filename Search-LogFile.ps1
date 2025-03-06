function Search-LogFiles {
    param (
        [string]$logDirectory,    # Directory to search for log files
        [string]$searchString     # The string to search for
    )
    
    # Get all .log files in the specified directory
    $logFiles = Get-ChildItem -Path $logDirectory -Filter "*.log"
    
    # Iterate through each log file
    foreach ($logFile in $logFiles) {
        Write-Host "Searching in: $($logFile.FullName)"
        
        # Read the content of the log file
        $logContent = Get-Content -Path $logFile.FullName
        
        # Search for the string and display results
        $matches = $logContent | Select-String -Pattern $searchString
        if ($matches) {
            Write-Host "Found in: $($logFile.FullName)"
            $matches | ForEach-Object { Write-Host $_.Line }
        } else {
            Write-Host "No matches found in: $($logFile.FullName)"
        }
    }
}
