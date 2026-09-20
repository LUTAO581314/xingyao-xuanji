param([string]$Root = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$assetRoot = Join-Path $Root 'src\assets\favicon'
$publicRoot = Join-Path (Split-Path -Parent $Root) 'app\public'
$glyphs = @{
    B = @('11110', '10001', '10001', '11110', '10001', '10001', '11110')
    A = @('01110', '10001', '10001', '11111', '10001', '10001', '10001')
    I = @('11111', '00100', '00100', '00100', '00100', '00100', '11111')
    R = @('11110', '10001', '10001', '11110', '10100', '10010', '10001')
    U = @('10001', '10001', '10001', '10001', '10001', '10001', '01110')
}
function Write-PixelPng([string]$Destination, [int]$Width, [int]$Height, [string]$Text, [int]$Scale) {
    $bitmap = New-Object System.Drawing.Bitmap($Width, $Height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#131010'))
        $x = [int](($Width - ($Text.Length * 6 - 1) * $Scale) / 2)
        $y = [int](($Height - 7 * $Scale) / 2)
        foreach ($letter in $Text.ToCharArray()) {
            $rows = $glyphs[[string]$letter]
            for ($row = 0; $row -lt 7; $row++) {
                for ($column = 0; $column -lt 5; $column++) {
                    if ($rows[$row][$column] -eq '1') {
                        $graphics.FillRectangle([System.Drawing.Brushes]::White, $x + $column * $Scale, $y + $row * $Scale, $Scale, $Scale)
                    }
                }
            }
            $x += 6 * $Scale
        }
        $bitmap.Save($Destination, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}
foreach ($item in @(
    @{ Name = 'favicon-96x96.png'; Size = 96 },
    @{ Name = 'favicon-96x96-v3.png'; Size = 96 },
    @{ Name = 'apple-touch-icon.png'; Size = 180 },
    @{ Name = 'apple-touch-icon-v3.png'; Size = 180 },
    @{ Name = 'web-app-manifest-192x192.png'; Size = 192 },
    @{ Name = 'web-app-manifest-512x512.png'; Size = 512 }
)) {
    $file = Join-Path $assetRoot $item.Name
    Write-PixelPng $file $item.Size $item.Size 'B' ([int][Math]::Floor($item.Size * 0.6 / 7))
    Copy-Item -LiteralPath $file -Destination (Join-Path $publicRoot $item.Name) -Force
}
foreach ($name in @('favicon.ico', 'favicon-v3.ico')) {
    $png = [System.IO.File]::ReadAllBytes((Join-Path $assetRoot 'favicon-96x96.png'))
    $stream = New-Object System.IO.MemoryStream
    $writer = New-Object System.IO.BinaryWriter($stream)
    try {
        $writer.Write([uint16]0); $writer.Write([uint16]1); $writer.Write([uint16]1)
        $writer.Write([byte]96); $writer.Write([byte]96); $writer.Write([byte]0); $writer.Write([byte]0)
        $writer.Write([uint16]1); $writer.Write([uint16]32)
        $writer.Write([uint32]$png.Length); $writer.Write([uint32]22)
        $writer.Write($png)
        [System.IO.File]::WriteAllBytes((Join-Path $assetRoot $name), $stream.ToArray())
        Copy-Item -LiteralPath (Join-Path $assetRoot $name) -Destination (Join-Path $publicRoot $name) -Force
    } finally {
        $writer.Dispose()
        $stream.Dispose()
    }
}
Write-PixelPng (Join-Path $publicRoot 'social-share.png') 1200 630 'BAIRUI' 24
