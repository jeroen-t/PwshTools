function Invoke-jtWaitAnimation {
    Param (
        [int]$iterations = 10
    )
    Process {
        [Console]::CursorVisible = $false
        $i = 0
        do {
            '\','|','/','-' | ForEach-Object {
                Write-Host "`r$_" -NoNewline -ForegroundColor Yellow
                Start-Sleep -ms 300
            }
            $i++
        } until ($i -eq $iterations)
    }
}

Invoke-jtWaitAnimation