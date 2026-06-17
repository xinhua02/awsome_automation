@echo off
REM Simulation script for QuestaSim
setlocal enabledelayedexpansion

set QUESTASIM=C:\questasim64_2021.1\win64\questasim.exe
set WORK_DIR=%CD%

echo.
echo ============================================
echo FIFO Synchronous and Asynchronous Simulation
echo ============================================
echo.

REM Create simulation directory
if not exist sim\work (
    mkdir sim\work
)

cd sim

echo [1/4] Compiling Synchronous FIFO testbench...
"%QUESTASIM%" -batch -do "vlib work; vmap work work; vlog -sv +incdir+../src ../src/sync_fifo.v; vlog -sv +incdir+. tb_sync_fifo.sv; quit" > sync_compile.log 2>&1

if errorlevel 1 (
    echo ERROR: Compilation failed for sync FIFO!
    type sync_compile.log
    exit /b 1
)
echo [1/4] ✓ Sync FIFO compiled successfully

echo [2/4] Running Synchronous FIFO simulation...
"%QUESTASIM%" -batch -do "vsim -c -do {run -all; quit} tb_sync_fifo" > sync_simulation.log 2>&1

if errorlevel 1 (
    echo WARNING: Sync FIFO simulation completed with warnings
) else (
    echo [2/4] ✓ Sync FIFO simulation completed
)

REM Clean work directory for async FIFO simulation
rmdir /s /q work

echo [3/4] Compiling Asynchronous FIFO testbench...
"%QUESTASIM%" -batch -do "vlib work; vmap work work; vlog -sv +incdir+../src ../src/async_fifo.v; vlog -sv +incdir+. tb_async_fifo.sv; quit" > async_compile.log 2>&1

if errorlevel 1 (
    echo ERROR: Compilation failed for async FIFO!
    type async_compile.log
    exit /b 1
)
echo [3/4] ✓ Async FIFO compiled successfully

echo [4/4] Running Asynchronous FIFO simulation...
"%QUESTASIM%" -batch -do "vsim -c -do {run -all; quit} tb_async_fifo" > async_simulation.log 2>&1

if errorlevel 1 (
    echo WARNING: Async FIFO simulation completed with warnings
) else (
    echo [4/4] ✓ Async FIFO simulation completed
)

echo.
echo ============================================
echo Simulation Results
echo ============================================
echo.

echo --- Synchronous FIFO Simulation Output ---
type sync_simulation.log
echo.
echo --- Asynchronous FIFO Simulation Output ---
type async_simulation.log
echo.

cd ..

echo ✓ All simulations completed!
echo.
pause
