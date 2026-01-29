$ErrorActionPreference = 'Continue'

Write-Host "Testing WSL Detection..." -ForegroundColor Cyan

$wsl = Get-Command wsl -ErrorAction SilentlyContinue

if ($wsl) {
    $version = (wsl --version 2>&1)

    if ($version -is [Array] -and $version.Count -gt 0) {
        $firstLine = $version[0].ToString()

        Write-Host "First line visible: '$firstLine'"
        Write-Host "First line length: $($firstLine.Length)"
        Write-Host "First 20 char codes: $([string]::Join(', ', ($firstLine[0..([Math]::Min(19, $firstLine.Length-1))] | ForEach-Object { [int][char]$_ })))"

        # Try trimming and replacing potential problem characters
        $cleaned = $firstLine.Trim() -replace '\x00', '' -replace '\r', '' -replace '\n', ''
        Write-Host "Cleaned: '$cleaned'"
        Write-Host "Cleaned matches: $($cleaned -match 'WSL')"

        # Try just checking if any line in the array works
        $found = $false
        foreach ($line in $version) {
            $lineStr = $line.ToString().Trim()
            if ($lineStr -like '*WSL*' -or $lineStr -like '*version*') {
                Write-Host "PASS - Found WSL in output" -ForegroundColor Green
                $found = $true
                break
            }
        }

        if (-not $found) {
            Write-Host "FAIL - No WSL found in any line" -ForegroundColor Red
        }
    }
}
