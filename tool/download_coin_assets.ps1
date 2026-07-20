# Downloads missing coin logos into assets/coins/
$ErrorActionPreference = 'Stop'
$outDir = Join-Path $PSScriptRoot '..\assets\coins'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$svgBase = 'https://cdn.jsdelivr.net/npm/cryptocurrency-icons@0.18.1/svg/color'
foreach ($pair in @(
    @{ File = 'QNT.svg'; Url = "$svgBase/qnt.svg" },
    @{ File = 'ETC.svg'; Url = "$svgBase/etc.svg" }
)) {
    Invoke-WebRequest -Uri $pair.Url -OutFile (Join-Path $outDir $pair.File)
    Write-Host "Saved $($pair.File)"
}

$renderPng = Join-Path $outDir 'RENDER.png'
Invoke-WebRequest -Uri 'https://assets.coingecko.com/coins/images/11636/large/rndr.png' -OutFile $renderPng
Write-Host 'Saved RENDER.png'

Write-Host 'Done. Bundled coins: BTC ETH SOL BNB USDT USDC TRX QNT ETC + RENDER.png'
