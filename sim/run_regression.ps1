<#
Runs sync and async FIFO simulations and collects pass/fail status.
Creates `sync_run.log` and `async_run.log` in the `sim` folder and
returns non-zero exit code if any simulation reports non-zero compile/runtime errors.
#>

param()

function Run-Sim {
    param(
        [string]$name,
        [string]$vsrc,
        [string]$tb,
        [string]$logfile
    )

    Write-Host "=== Running $name simulation => $logfile ==="
    Remove-Item -Path $logfile -ErrorAction SilentlyContinue

    # Ensure library
    & vlib work 2>&1 | Tee-Object -FilePath $logfile -Append | Out-Null
    & vmap work ./work 2>&1 | Tee-Object -FilePath $logfile -Append | Out-Null

    # Compile design and testbench with assertions
    & vlog -sv +incdir=../src $vsrc 2>&1 | Tee-Object -FilePath $logfile -Append | Out-Null
    & vlog -sv fifo_assertions.sv $tb 2>&1 | Tee-Object -FilePath $logfile -Append | Out-Null

    # Run simulation (command-line). Capture output in logfile.
    & vsim -c $tb -do "run -all; exit" 2>&1 | Tee-Object -FilePath $logfile -Append | Out-Null

    # Inspect logfile for Errors: N pattern
    $content = Get-Content -Raw -Path $logfile
    $errs = 0
    if ($content -match 'Errors:\s*(\d+)') { $errs = [int]$matches[1] }

    if ($errs -eq 0) {
        Write-Host "$($name): PASS (Errors: 0)"
        return @{ name=$name; pass=$true; errors=0; logfile=$logfile }
    } else {
        Write-Host "$($name): FAIL (Errors: $errs) - see $logfile"
        return @{ name=$name; pass=$false; errors=$errs; logfile=$logfile }
    }
}

$results = @()
$results += Run-Sim -name 'sync' -vsrc '../src/sync_fifo.v' -tb 'tb_sync_fifo' -logfile 'sync_run.log'
$results += Run-Sim -name 'async' -vsrc '../src/async_fifo.v' -tb 'tb_async_fifo' -logfile 'async_run.log'

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
