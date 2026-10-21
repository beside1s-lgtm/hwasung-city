# 13대 멀티 엔딩 비디오 자동 OGV 변환기
$ErrorActionPreference = "Stop"

# FFmpeg 실행 파일 탐색
$ffmpegPath = "ffmpeg"
$wingetFfmpeg = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-9.0.2-full_build\bin\ffmpeg.exe"

if (Test-Path $wingetFfmpeg) {
    $ffmpegPath = $wingetFfmpeg
} elseif (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Error "FFmpeg를 찾을 수 없습니다. winget install Gyan.FFmpeg 를 실행하세요."
    exit 1
}

$outputDir = Join-Path $PSScriptRoot "godot_hwashung\assets\endings"
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " [화성성역 1794] 13대 엔딩 영상 자동 변환기" -ForegroundColor Cyan
Write-Host " FFmpeg 경로: $ffmpegPath" -ForegroundColor Gray
Write-Host " 출력 디렉토리: $outputDir" -ForegroundColor Gray
Write-Host "==================================================" -ForegroundColor Cyan

$successCount = 0
1..13 | ForEach-Object {
    $mp4File = "$_.mp4"
    $outFile = Join-Path $outputDir "ending_$_.ogv"

    if (Test-Path $mp4File) {
        Write-Host "변환 중: $mp4File -> ending_$_.ogv ..." -ForegroundColor Yellow
        & $ffmpegPath -i $mp4File -c:v libtheora -q:v 7 -c:a libvorbis -q:a 5 -y $outFile
        if ($LASTEXITCODE -eq 0) {
            Write-Host "변환 완료: ending_$_.ogv" -ForegroundColor Green
            $successCount++
        } else {
            Write-Warning "변환 실패: $mp4File"
        }
    } else {
        Write-Host "파일 없음 건너뜀: $mp4File (나중에 준비되면 재실행하세요)" -ForegroundColor DarkGray
    }
}

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " 총 $successCount 개의 엔딩 영상 변환 완료!" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Cyan
