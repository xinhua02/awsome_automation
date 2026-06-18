<#
Runs sync and async FIFO simulations and collects pass/fail status.
Creates `sync_run.log` and `async_run.log` in the `sim` folder and
returns non-zero exit code if any simulation reports non-zero compile/runtime errors.
#>

param()

function Test-Simulation {
    param(
        [string]$name,
        [string]$tbFile,
        [string]$tbTop,
        [string]$logfile
    )

    Write-Host "=== Running $name simulation => $logfile ==="
    Remove-Item -Path $logfile -ErrorAction SilentlyContinue

    # Start fresh for each simulation to avoid stale compiled units masking failures.
    if (Test-Path -Path 'work') {
        Remove-Item -Path 'work' -Recurse -Force
    }

    # Ensure library
    & vlib work 2>&1 | Tee-Object -FilePath $logfile -Append | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "$($name): FAIL (vlib failed) - see $logfile"
        return @{ name=$name; pass=$false; errors=1; logfile=$logfile }
    }

    & vmap work ./work 2>&1 | Tee-Object -FilePath $logfile -Append | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "$($name): FAIL (vmap failed) - see $logfile"
        return @{ name=$name; pass=$false; errors=1; logfile=$logfile }
    }

    # Compile all RTL files and selected testbench with assertions.
    & vlog -sv +incdir=../src ../src/*.sv fifo_assertions.sv $tbFile 2>&1 | Tee-Object -FilePath $logfile -Append | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "$($name): FAIL (vlog failed) - see $logfile"
        return @{ name=$name; pass=$false; errors=1; logfile=$logfile }
    }

    # Run simulation (command-line). Capture output in logfile.
    & vsim -c $tbTop -do "run -all; exit" 2>&1 | Tee-Object -FilePath $logfile -Append | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "$($name): FAIL (vsim failed) - see $logfile"
        return @{ name=$name; pass=$false; errors=1; logfile=$logfile }
    }

    # Inspect logfile for real simulation errors.
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

    # Compare testbench-generated report with baseline expected results
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
            # If baseline is missing/empty, create it from this run to establish expected output.
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
        return @{ name=$name; pass=$true; errors=0; logfile=$logfile }
    } else {
        Write-Host "$($name): FAIL (Errors: $errs) - see $logfile"
        return @{ name=$name; pass=$false; errors=$errs; logfile=$logfile }
    }
}

$results = @()
$results += Test-Simulation -name 'sync' -tbFile 'tb_sync_fifo.sv' -tbTop 'tb_sync_fifo' -logfile 'sync_run.log'
$results += Test-Simulation -name 'async' -tbFile 'tb_async_fifo.sv' -tbTop 'tb_async_fifo' -logfile 'async_run.log'

# Summary
Write-Host "`n=== Regression Summary ==="
$failed = $results | Where-Object { -not $_.pass }
if ($failed.Count -eq 0) {
    Write-Host "All simulations passed."
    exit 0
} else {
    foreach ($f in $failed) {
        Write-Host "FAILED: $($f.name) (errors=$($f.errors)) -> $($f.logfile)"
    }
    exit 1
}
