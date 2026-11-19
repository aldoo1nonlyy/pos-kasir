param (
    [switch]$Restart,
    [switch]$Stop,
    [switch]$Desktop,
    [switch]$Dev
)

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "   POS Kasir Toko Buku (Dynamic ABC)      " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

function Stop-PosServices {
    Write-Host "Menghentikan layanan POS yang berjalan..." -ForegroundColor Yellow
    $ports = @(5000, 8080)
    foreach ($p in $ports) {
        $conns = Get-NetTCPConnection -LocalPort $p -ErrorAction SilentlyContinue
        if ($conns) {
            $pids = $conns.OwningProcess | Select-Object -Unique
            foreach ($procId in $pids) {
                if ($procId -gt 0) {
                    try {
                        Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
                        Write-Host "Menghentikan proses PID $procId pada port $p" -ForegroundColor DarkGray
                    } catch {}
                }
            }
        }
    }
}

if ($Stop) {
    Stop-PosServices
    Write-Host "Semua layanan POS telah dihentikan." -ForegroundColor Green
    exit 0
}

if ($Restart) {
    Stop-PosServices
    Start-Sleep -Seconds 2
}

# 1. Pastikan Backend Flask Berjalan
$conn5000 = Get-NetTCPConnection -LocalPort 5000 -State Listen -ErrorAction SilentlyContinue
if (-not $conn5000) {
    Write-Host "[1/2] Menjalankan Flask Backend pada http://127.0.0.1:5000..." -ForegroundColor Green
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$PSScriptRoot\backend'; .\venv\Scripts\python.exe app.py"
    Start-Sleep -Seconds 2
} else {
    Write-Host "[1/2] Flask Backend sudah aktif di http://127.0.0.1:5000 (Zero-delay)" -ForegroundColor Green
}

# 2. Jalankan Frontend Flutter
$flutterPath = "C:\Users\ADVAN\flutter\bin\flutter.bat"
if ($Desktop) {
    Write-Host "[2/2] Menjalankan Flutter Desktop Windows..." -ForegroundColor Green
    cd "$PSScriptRoot\frontend"
    & $flutterPath run -d windows
} else {
    $conn8080 = Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue
    if ($conn8080) {
        Write-Host "[2/2] Flutter Web Frontend sudah aktif di http://localhost:8080" -ForegroundColor Green
        Write-Host "Membuka browser..." -ForegroundColor Cyan
        Start-Process "http://localhost:8080"
    } else {
        $webBuildIndex = "$PSScriptRoot\frontend\build\web\index.html"
        $pythonExe = "$PSScriptRoot\backend\venv\Scripts\python.exe"
        if (-not (Test-Path $pythonExe)) { $pythonExe = "python" }

        if (-not $Dev -and (Test-Path $webBuildIndex)) {
            Write-Host "[2/2] Menjalankan Flutter Web (Production Build) pada http://localhost:8080..." -ForegroundColor Green
            Start-Process powershell -ArgumentList "-WindowStyle", "Hidden", "-Command", "cd '$PSScriptRoot'; & '$pythonExe' -m http.server 8080 --directory frontend/build/web --bind 0.0.0.0"
            Start-Sleep -Seconds 2
            Start-Process "http://localhost:8080"
        } elseif (Test-Path $flutterPath) {
            Write-Host "[2/2] Menjalankan Flutter Frontend pada Chrome (http://localhost:8080)..." -ForegroundColor Green
            cd "$PSScriptRoot\frontend"
            & $flutterPath run -d chrome --web-port=8080
        } else {
            Write-Host "Flutter tidak ditemukan. Membuka demo web..." -ForegroundColor Yellow
            Start-Process "http://localhost:5000"
        }
    }
}
