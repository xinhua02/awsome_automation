<#
Runs sync and async FIFO simulations and collects pass/fail status.
Creates `sync_run.log` and `async_run.log` in the `sim` folder and
returns non-zero exit code if any simulation reports non-zero compile/runtime errors.
#>

param()

$results = @()

$testCases = @(
    @{ name = 'sync'; tbFile = 'tb_sync_fifo.sv'; tbTop = 'tb_sync_fifo'; logfile = 'sync_run.log' },
    @{ name = 'async'; tbFile = 'tb_async_fifo.sv'; tbTop = 'tb_async_fifo'; logfile = 'async_run.log' }
)

foreach ($testCase in $testCases) {
    $name = $testCase.name
    $tbFile = $testCase.tbFile
    $tbTop = $testCase.tbTop
    $logfile = $testCase.logfile

    Write-Host "=== Running $name simulation => $logfile ==="
    Remove-Item -Path $logfile -ErrorAction SilentlyContinue

    if (Test-Path -Path 'work') {
        Remove-Item -Path 'work' -Recurse -Force
    }

    & vlib work 2>&1 | Tee-Object -FilePath $logfile -Append | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "$($name): FAIL (vlib failed) - see $logfile"
        $results += @{ name = $name; pass = $false; errors = 1; logfile = $logfile }
        continue
    }

    & vmap work ./work 2>&1 | Tee-Object -FilePath $logfile -Append | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "$($name): FAIL (vmap failed) - see $logfile"
        $results += @{ name = $name; pass = $false; errors = 1; logfile = $logfile }
        continue
    }

    & vlog -sv +incdir=../src ../src/*.sv fifo_assertions.sv $tbFile 2>&1 | Tee-Object -FilePath $logfile -Append | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "$($name): FAIL (vlog failed) - see $logfile"
        $results += @{ name = $name; pass = $false; errors = 1; logfile = $logfile }
        continue
    }

    & vsim -c $tbTop -do "run -all; exit" 2>&1 | Tee-Object -FilePath $logfile -Append | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "$($name): FAIL (vsim failed) - see $logfile"
        $results += @{ name = $name; pass = $false; errors = 1; logfile = $logfile }
        continue
    }

    $content = Get-Content -Raw -Path $logfile
    $errs = 0
    $errorLines = [regex]::Matches($content, '\*\* Error:').Count
    if ($errorLines -gt 0) {
        $errs += $errorLines
    }

    $summaryMatches = [regex]::Matches($content, '#\s*Errors:\s*(\d+)')
    if ($summaryMatches.Count -gt 0) {
        $maxSummaryErr = ($summaryMatches | ForEach-Object { [int]$_.Groups[1].Value } | Measure-Object -Maximum).Maximum
        if ($maxSummaryErr -gt $errs) {
            $errs = $maxSummaryErr
        }
    }

    $reportFile = "${name}_tb_report.txt"
    $baselineFile = "${name}_results_full.txt"
    if (Test-Path -Path $reportFile) {
        $report = Get-Content -Raw -Path $reportFile
        if ($report -match 'errors=(\d+)') {
            $tbErrs = [int]$matches[1]
            if ($tbErrs -gt 0) {
                $errs += $tbErrs
            }
        }

        $baselineMissingOrEmpty = (-not (Test-Path -Path $baselineFile)) -or ((Get-Item $baselineFile).Length -eq 0)
        if ($baselineMissingOrEmpty) {
            Set-Content -Path $baselineFile -Value $report
            Write-Host "Baseline created: $baselineFile"
        } else {
            $baseline = Get-Content -Raw -Path $baselineFile
            if ($report.Trim() -ne $baseline.Trim()) {
                Write-Host "$($name): OUTPUT MISMATCH between $reportFile and $baselineFile"
                $errs += 1
            }
        }
    } else {
        Write-Host "Warning: no report file generated ($reportFile) for $name"
    }

    if ($errs -eq 0) {
        Write-Host "$($name): PASS (Errors: 0)"
        $results += @{ name = $name; pass = $true; errors = 0; logfile = $logfile }
    } else {
        Write-Host "$($name): FAIL (Errors: $errs) - see $logfile"
        $results += @{ name = $name; pass = $false; errors = $errs; logfile = $logfile }
    }
}

Write-Host "`n=== Regression Summary ==="
$failed = $results | Where-Object { -not $_.pass }
if ($failed.Count -eq 0) {
    Write-Host "All simulations passed."
    exit 0
}

foreach ($f in $failed) {
    Write-Host "FAILED: $($f.name) (errors=$($f.errors)) -> $($f.logfile)"
}

exit 1