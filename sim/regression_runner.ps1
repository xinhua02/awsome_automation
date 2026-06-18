<#
Runs sync and async FIFO simulations and collects pass/fail status.
Creates `sync_run.log` and `async_run.log` in the `sim` folder and
returns non-zero exit code if any simulation reports non-zero compile/runtime errors.
#>

param(
    [switch]$NoCoverage,
    [ValidateSet('s', 'b', 'c', 'e', 'f', 't', 'sb', 'sbc', 'sbce', 'sbcef', 'sbceft')]
    [string]$CoverageMode = 'sbceft',
    [ValidateRange(0, 100)]
    [double]$CoverageThreshold = 0,
    [ValidateRange(0, 100)]
    [double]$DutCoverageThreshold = 0
)

function Get-MetricPercent {
    param(
        [string]$Text,
        [string[]]$Names
    )

    foreach ($name in $Names) {
        $patterns = @(
            "(?im)^\s*$name\s*[:=]\s*(?<pct>\d+(?:\.\d+)?)\s*%",
            "(?im)^\s*$name\b[^\r\n]*?(?<pct>\d+(?:\.\d+)?)\s*%"
        )

        foreach ($pattern in $patterns) {
            $m = [regex]::Match($Text, $pattern)
            if ($m.Success) {
                return [double]$m.Groups['pct'].Value
            }
        }
    }

    return $null
}

function Write-CoverageAnalysis {
    param(
        [string]$SummaryPath,
        [string]$DetailsPath,
        [string]$OutputMarkdownPath,
        [string]$CoverageMode
    )

    $summary = if (Test-Path -Path $SummaryPath) { Get-Content -Raw -Path $SummaryPath } else { '' }
    $details = if (Test-Path -Path $DetailsPath) { Get-Content -Raw -Path $DetailsPath } else { '' }

    function Get-HotspotSuggestion {
        param(
            [string]$File,
            [string]$Section
        )

        $f = $File.ToLowerInvariant()
        $s = $Section.ToLowerInvariant()

        if ($f -match '^tb_') {
            if ($s -match 'branch') {
                return 'Add directed stimuli to force both true/false branch outcomes in this testbench decision.'
            }
            if ($s -match 'condition|expression') {
                return 'Drive all operand combinations for this testbench predicate to hit uncovered truth-table rows.'
            }
            if ($s -match 'toggle') {
                return 'Toggle this bench signal both directions or remove unused debug signal paths from active logic.'
            }
            return 'Expand testbench scenario diversity around this control point.'
        }

        if ($f -match 'src/sync_fifo') {
            return 'Add fill/drain boundary sequences and same-cycle read/write corners targeting this FIFO control path.'
        }
        if ($f -match 'src/async_fifo|src/cdc_sync|src/gray_') {
            return 'Add CDC-latency-aware directed tests with phase offset and reset jitter to exercise this path.'
        }

        return 'Create a directed test that reaches this source line with both expected and opposite outcomes.'
    }

    $lines = if ($summary) { $summary -split "`r?`n" } else { @() }
    $currentInstance = ''
    $instanceMetrics = @()

    function Get-ScopeMetricRows {
        param(
            [array]$Metrics,
            [string[]]$MetricNames
        )

        $rows = @()
        foreach ($metric in $MetricNames) {
            $vals = @($Metrics | Where-Object { $_.Metric -eq $metric } | ForEach-Object { $_.Percent })
            $avgMetric = if ($vals.Count -gt 0) { ($vals | Measure-Object -Average).Average } else { $null }
            $rows += @{ Name = $metric; Value = $avgMetric }
        }
        return $rows
    }

    foreach ($line in $lines) {
        $instanceMatch = [regex]::Match($line, '^===\s*Instance:\s*(?<inst>.+)$')
        if ($instanceMatch.Success) {
            $currentInstance = $instanceMatch.Groups['inst'].Value.Trim()
            continue
        }

        $metricMatch = [regex]::Match($line, '^\s*(?<metric>Branches|Conditions|Expressions|Statements|Toggles)\s+\d+\s+\d+\s+\d+\s+(?<pct>\d+(?:\.\d+)?)%\s*$')
        if ($metricMatch.Success -and $currentInstance) {
            $instanceMetrics += [pscustomobject]@{
                Instance = $currentInstance
                Metric = $metricMatch.Groups['metric'].Value.Trim()
                Percent = [double]$metricMatch.Groups['pct'].Value
            }
        }
    }

    $totalMatch = [regex]::Match($summary, '(?im)^\s*Total Coverage By Instance.*:\s*(?<pct>\d+(?:\.\d+)?)%\s*$')
    $totalCoverage = if ($totalMatch.Success) { [double]$totalMatch.Groups['pct'].Value } else { $null }

    $metricNames = @('Statements', 'Branches', 'Conditions', 'Expressions', 'Toggles')
    $metricRows = Get-ScopeMetricRows -Metrics $instanceMetrics -MetricNames $metricNames

    $benchMetrics = @(
        $instanceMetrics |
        Where-Object {
            ($_.Instance -match '^/tb_') -and ($_.Instance -notmatch '/dut')
        }
    )
    $dutMetrics = @(
        $instanceMetrics |
        Where-Object {
            ($_.Instance -match '/dut') -or ($_.Instance -notmatch '^/tb_')
        }
    )

    $dutMetricRows = Get-ScopeMetricRows -Metrics $dutMetrics -MetricNames $metricNames

    $dutAvgKnown = @($dutMetricRows | Where-Object { $null -ne $_.Value } | ForEach-Object { $_.Value })
    $dutAvg = if ($dutAvgKnown.Count -gt 0) { ($dutAvgKnown | Measure-Object -Average).Average } else { $null }
    $dutMin = if ($dutMetrics.Count -gt 0) { ($dutMetrics | Measure-Object -Property Percent -Minimum).Minimum } else { $null }

    $knownValues = @($metricRows | Where-Object { $null -ne $_.Value } | ForEach-Object { $_.Value })
    $avg = if ($knownValues.Count -gt 0) { ($knownValues | Measure-Object -Average).Average } else { $null }

    $thresholdGood = 80.0
    $thresholdWarn = 60.0
    $quality = 'Insufficient data'
    $qualityRef = if ($null -ne $dutAvg) { $dutAvg } elseif ($null -ne $totalCoverage) { $totalCoverage } else { $avg }
    if ($null -ne $qualityRef) {
        if ($qualityRef -ge $thresholdGood) {
            $quality = 'Good'
        } elseif ($qualityRef -ge $thresholdWarn) {
            $quality = 'Moderate'
        } else {
            $quality = 'Needs improvement'
        }
    }

    $lowMetrics = $dutMetricRows |
        Where-Object { $null -ne $_.Value -and $_.Value -lt $thresholdGood } |
        Sort-Object Value |
        ForEach-Object { "- $($_.Name): $([string]::Format('{0:N2}', $_.Value))% (< $thresholdGood%)" }

    $uncoveredHints = @()
    if ($details) {
        $hintMatches = [regex]::Matches($details, '(?im)^.*(?:missed|uncovered|not covered).*$')
        foreach ($m in $hintMatches | Select-Object -First 8) {
            $line = $m.Value.Trim()
            if ($line) {
                $uncoveredHints += "- $line"
            }
        }
    }

    $hotspots = @()
    if ($details) {
        $detailLines = $details -split "`r?`n"
        $currentFile = ''
        $currentSection = ''

        foreach ($line in $detailLines) {
            $fileMatch = [regex]::Match($line, '^\s*File\s+(?<file>.+?)\s*$')
            if ($fileMatch.Success) {
                $currentFile = $fileMatch.Groups['file'].Value.Trim()
                continue
            }

            $sectionMatch = [regex]::Match($line, '^-{5,}(?<section>[^-].*?)\s*-{5,}\s*$')
            if ($sectionMatch.Success) {
                $currentSection = $sectionMatch.Groups['section'].Value.Trim()
                continue
            }

            $zeroLineMatch = [regex]::Match($line, '^\s*(?<ln>\d+)\s+.*\*\*\*0\*\*\*\s*.*$')
            if ($zeroLineMatch.Success -and $currentFile -and ($currentFile -match 'src/')) {
                $ln = [int]$zeroLineMatch.Groups['ln'].Value
                $hotspots += [pscustomobject]@{
                    File = $currentFile
                    Line = $ln
                    Section = if ($currentSection) { $currentSection } else { 'Unknown' }
                    Suggestion = Get-HotspotSuggestion -File $currentFile -Section $currentSection
                }
            }
        }

        $hotspots = @(
            $hotspots |
            Sort-Object File, Line, Section -Unique |
            Select-Object -First 12
        )
    }

    $sb = New-Object System.Text.StringBuilder
    $null = $sb.AppendLine('# Code Coverage Analysis')
    $null = $sb.AppendLine()
    $null = $sb.AppendLine("- Coverage mode: $CoverageMode")
    $null = $sb.AppendLine("- DUT coverage quality: $quality")
    if ($null -ne $totalCoverage) {
        $null = $sb.AppendLine("- Total coverage by instance (includes TB): $([string]::Format('{0:N2}', $totalCoverage))%")
    }
    if ($null -ne $dutAvg) {
        $null = $sb.AppendLine("- DUT-only metric mean: $([string]::Format('{0:N2}', $dutAvg))%")
    }
    if ($null -ne $dutMin) {
        $null = $sb.AppendLine("- DUT minimum metric point: $([string]::Format('{0:N2}', $dutMin))%")
    }
    $null = $sb.AppendLine()
    $null = $sb.AppendLine('## DUT Metric Summary')
    $null = $sb.AppendLine()
    $null = $sb.AppendLine('| Metric | Coverage |')
    $null = $sb.AppendLine('| ------ | -------- |')
    foreach ($row in $dutMetricRows) {
        $valueText = if ($null -eq $row.Value) { 'N/A' } else { "$([string]::Format('{0:N2}', $row.Value))%" }
        $null = $sb.AppendLine("| $($row.Name) | $valueText |")
    }
    $null = $sb.AppendLine()

    $lowDutInstances = @(
        $dutMetrics |
        Where-Object { $_.Percent -lt $thresholdGood } |
        Sort-Object Percent |
        Select-Object -First 6
    )
    if ($lowDutInstances.Count -gt 0) {
        $null = $sb.AppendLine('### Lowest DUT instance-metric pairs')
        foreach ($item in $lowDutInstances) {
            $null = $sb.AppendLine("- $($item.Instance) / $($item.Metric): $([string]::Format('{0:N2}', $item.Percent))%")
        }
        $null = $sb.AppendLine()
    } else {
        $null = $sb.AppendLine('### Lowest DUT instance-metric pairs')
        $null = $sb.AppendLine('- All DUT instance metrics are at or above 80%.')
        $null = $sb.AppendLine()
    }

    $null = $sb.AppendLine('## Analysis')
    $null = $sb.AppendLine()
    if ($lowMetrics.Count -gt 0) {
        $null = $sb.AppendLine('### Metrics below target')
        foreach ($line in $lowMetrics) {
            $null = $sb.AppendLine($line)
        }
    } else {
        $null = $sb.AppendLine('- All DUT metrics meet or exceed the 80% target, or DUT metrics were unavailable.')
    }
    $null = $sb.AppendLine()

    $lowInstances = @($lowDutInstances | Select-Object -First 8)
    if ($lowInstances.Count -gt 0) {
        $null = $sb.AppendLine('### Lowest DUT coverage instance-metric pairs')
        foreach ($item in $lowInstances) {
            $null = $sb.AppendLine("- $($item.Instance) / $($item.Metric): $([string]::Format('{0:N2}', $item.Percent))%")
        }
        $null = $sb.AppendLine()
    }

    if ($uncoveredHints.Count -gt 0) {
        $null = $sb.AppendLine('### Uncovered code hints (from detailed report)')
        foreach ($line in $uncoveredHints) {
            $null = $sb.AppendLine($line)
        }
        $null = $sb.AppendLine()
    }

    if ($hotspots.Count -gt 0) {
        $null = $sb.AppendLine('### Actionable DUT hotspots (file + line + fix hint)')
        foreach ($h in $hotspots) {
            $null = $sb.AppendLine("- $($h.File):$($h.Line) [$($h.Section)]")
            $null = $sb.AppendLine("  Suggested action: $($h.Suggestion)")
        }
        $null = $sb.AppendLine()
    } else {
        $null = $sb.AppendLine('### Actionable DUT hotspots (file + line + fix hint)')
        $null = $sb.AppendLine('- No DUT zero-hit hotspots detected in the detailed report.')
        $null = $sb.AppendLine()
    }

    $null = $sb.AppendLine('## Next focus')
    $null = $sb.AppendLine('- Add directed tests for uncovered branches in full/empty boundary transitions.')
    $null = $sb.AppendLine('- Expand async FIFO scenarios around CDC latency and near-simultaneous read/write events.')
    $null = $sb.AppendLine('- Re-run regression after each testbench enhancement and track metric deltas over time.')

    Set-Content -Path $OutputMarkdownPath -Value ($sb.ToString())

    return [pscustomobject]@{
        TotalCoverage = $totalCoverage
        AverageMetricCoverage = $avg
        DutAverageMetricCoverage = $dutAvg
        DutMinMetricCoverage = $dutMin
        Quality = $quality
    }
}

$results = @()
$enableCoverage = -not $NoCoverage
$coverageDir = 'coverage'
$coverageUcdbFiles = @()
$coverageGateFailed = $false

if (($CoverageThreshold -gt 0) -and ($DutCoverageThreshold -eq 0)) {
    Write-Host "Warning: -CoverageThreshold evaluates total coverage including TB metrics. Prefer -DutCoverageThreshold for DUT closure."
}

if ($enableCoverage -and -not (Test-Path -Path $coverageDir)) {
    New-Item -ItemType Directory -Path $coverageDir | Out-Null
}

$testCases = @(
    @{ name = 'sync'; tbFile = 'tb_sync_fifo.sv'; tbTop = 'tb_sync_fifo'; logfile = 'sync_run.log' },
    @{ name = 'async'; tbFile = 'tb_async_fifo.sv'; tbTop = 'tb_async_fifo'; logfile = 'async_run.log' }
)

foreach ($testCase in $testCases) {
    $name = $testCase.name
    $tbFile = $testCase.tbFile
    $tbTop = $testCase.tbTop
    $logfile = $testCase.logfile
    $ucdbFile = Join-Path $coverageDir "$name.ucdb"
    $ucdbFileTcl = ($ucdbFile -replace '\\', '/')

    Write-Host "=== Running $name simulation => $logfile ==="
    Remove-Item -Path $logfile -ErrorAction SilentlyContinue
    if ($enableCoverage) {
        Remove-Item -Path $ucdbFile -ErrorAction SilentlyContinue
    }

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

    $vlogArgs = @('-sv', '+incdir=../src')
    if ($enableCoverage) {
        $vlogArgs += "+cover=$CoverageMode"
    }
    $vlogArgs += @('../src/*.sv', 'fifo_assertions.sv', $tbFile)

    & vlog @vlogArgs 2>&1 | Tee-Object -FilePath $logfile -Append | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "$($name): FAIL (vlog failed) - see $logfile"
        $results += @{ name = $name; pass = $false; errors = 1; logfile = $logfile }
        continue
    }

    $vsimArgs = @('-c', '-onfinish', 'stop', $tbTop)
    if ($enableCoverage) {
        $vsimArgs = @('-coverage') + $vsimArgs
        $vsimArgs += @('-do', "coverage save -onexit $ucdbFileTcl; run -all; exit")
    } else {
        $vsimArgs += @('-do', 'run -all; exit')
    }

    & vsim @vsimArgs 2>&1 | Tee-Object -FilePath $logfile -Append | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "$($name): FAIL (vsim failed) - see $logfile"
        $results += @{ name = $name; pass = $false; errors = 1; logfile = $logfile }
        continue
    }

    if ($enableCoverage) {
        if (Test-Path -Path $ucdbFile) {
            $coverageUcdbFiles += $ucdbFile
        } else {
            Write-Host "Warning: coverage file not generated for $name ($ucdbFile)"
        }
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

if ($enableCoverage) {
    Write-Host "`n=== Coverage Report Generation ==="

    $vcover = Get-Command vcover -ErrorAction SilentlyContinue
    if (-not $vcover) {
        Write-Host 'Coverage skipped: vcover command not found.'
    } elseif ($coverageUcdbFiles.Count -eq 0) {
        Write-Host 'Coverage skipped: no UCDB files produced by simulation.'
    } else {
        $mergedUcdb = Join-Path $coverageDir 'coverage_merged.ucdb'
        $summaryTxt = Join-Path $coverageDir 'coverage_summary.txt'
        $detailsTxt = Join-Path $coverageDir 'coverage_details.txt'
        $analysisMd = Join-Path $coverageDir 'coverage_analysis.md'

        Remove-Item -Path $mergedUcdb, $summaryTxt, $detailsTxt, $analysisMd -ErrorAction SilentlyContinue

        & vcover merge $mergedUcdb @coverageUcdbFiles 2>&1 | Tee-Object -FilePath (Join-Path $coverageDir 'coverage_merge.log') | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host 'Coverage merge failed. See coverage/coverage_merge.log'
        } else {
            & vcover report -code $CoverageMode -output $summaryTxt $mergedUcdb | Out-Null
            & vcover report -details -all -code $CoverageMode -output $detailsTxt $mergedUcdb | Out-Null

            if ($LASTEXITCODE -eq 0) {
                $analysis = Write-CoverageAnalysis -SummaryPath $summaryTxt -DetailsPath $detailsTxt -OutputMarkdownPath $analysisMd -CoverageMode $CoverageMode
                Write-Host "Coverage artifacts generated in ./$coverageDir"
                Write-Host "- $summaryTxt"
                Write-Host "- $detailsTxt"
                Write-Host "- $analysisMd"

                if ($CoverageThreshold -gt 0) {
                    if ($null -eq $analysis.TotalCoverage) {
                        Write-Host "Coverage threshold check skipped: total coverage not found in summary."
                    } elseif ($analysis.TotalCoverage -lt $CoverageThreshold) {
                        Write-Host "Coverage gate FAILED: total coverage $([string]::Format('{0:N2}', $analysis.TotalCoverage))% < threshold $([string]::Format('{0:N2}', $CoverageThreshold))%"
                        $coverageGateFailed = $true
                    } else {
                        Write-Host "Coverage gate PASSED: total coverage $([string]::Format('{0:N2}', $analysis.TotalCoverage))% >= threshold $([string]::Format('{0:N2}', $CoverageThreshold))%"
                    }
                }

                if ($DutCoverageThreshold -gt 0) {
                    if ($null -eq $analysis.DutMinMetricCoverage) {
                        Write-Host "DUT coverage threshold check skipped: DUT metric points not found in summary."
                    } elseif ($analysis.DutMinMetricCoverage -lt $DutCoverageThreshold) {
                        Write-Host "DUT coverage gate FAILED: DUT minimum metric point $([string]::Format('{0:N2}', $analysis.DutMinMetricCoverage))% < threshold $([string]::Format('{0:N2}', $DutCoverageThreshold))%"
                        $coverageGateFailed = $true
                    } else {
                        Write-Host "DUT coverage gate PASSED: DUT minimum metric point $([string]::Format('{0:N2}', $analysis.DutMinMetricCoverage))% >= threshold $([string]::Format('{0:N2}', $DutCoverageThreshold))%"
                    }
                }
            } else {
                Write-Host 'Coverage report generation failed.'
            }
        }
    }
}

if ($failed.Count -eq 0) {
    if ($coverageGateFailed) {
        Write-Host 'Simulations passed, but coverage gate failed.'
        exit 2
    }
    Write-Host "All simulations passed."
    exit 0
}

foreach ($f in $failed) {
    Write-Host "FAILED: $($f.name) (errors=$($f.errors)) -> $($f.logfile)"
}

exit 1