# PowerShell script to compress product images and create thumbnails
# This will create a new thumbnails folder with compressed versions

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "     Product Image Compression Tool" -ForegroundColor Yellow
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$sourceFolder = "assets\screenshots"
$thumbnailFolder = "assets\thumbnails"
$quality = 85  # JPEG quality (1-100)
$maxWidth = 600  # Maximum width for thumbnails
$maxHeight = 600  # Maximum height for thumbnails

# Check if ImageMagick is installed
$imageMagickPath = Get-Command magick -ErrorAction SilentlyContinue
if (-not $imageMagickPath) {
    Write-Host "ERROR: ImageMagick is not installed!" -ForegroundColor Red
    Write-Host "Please download and install ImageMagick from:" -ForegroundColor Yellow
    Write-Host "https://imagemagick.org/script/download.php#windows" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "After installation, run this script again." -ForegroundColor Yellow
    exit
}

Write-Host "✓ ImageMagick found at: $($imageMagickPath.Path)" -ForegroundColor Green
Write-Host ""

# Create thumbnails folder if it doesn't exist
if (!(Test-Path $thumbnailFolder)) {
    New-Item -ItemType Directory -Path $thumbnailFolder | Out-Null
    Write-Host "✓ Created thumbnails folder" -ForegroundColor Green
} else {
    Write-Host "✓ Thumbnails folder exists" -ForegroundColor Green
}

# Get all product folders
$productFolders = Get-ChildItem -Path $sourceFolder -Directory
$totalFolders = $productFolders.Count
Write-Host "Found $totalFolders product folders to process" -ForegroundColor Yellow
Write-Host ""

# Calculate current size
$currentSize = (Get-ChildItem -Path $sourceFolder -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB
Write-Host "Current screenshots size: $([math]::Round($currentSize, 2)) MB" -ForegroundColor Cyan

# Process each folder
$processed = 0
$errors = 0
$totalOriginalSize = 0
$totalCompressedSize = 0

foreach ($folder in $productFolders) {
    $sku = $folder.Name
    $processed++
    
    # Create SKU folder in thumbnails
    $thumbPath = Join-Path $thumbnailFolder $sku
    if (!(Test-Path $thumbPath)) {
        New-Item -ItemType Directory -Path $thumbPath | Out-Null
    }
    
    # Progress indicator
    $percentComplete = [math]::Round(($processed / $totalFolders) * 100, 1)
    Write-Progress -Activity "Compressing Images" -Status "Processing $sku ($processed of $totalFolders)" -PercentComplete $percentComplete
    
    # Get first image (P.1.png) for thumbnail
    $mainImage = Join-Path $folder.FullName "$sku P.1.png"
    
    if (Test-Path $mainImage) {
        try {
            # Get original size
            $originalSize = (Get-Item $mainImage).Length
            $totalOriginalSize += $originalSize
            
            # Create compressed thumbnail
            $outputFile = Join-Path $thumbPath "$sku.jpg"
            
            # Use ImageMagick to compress and resize
            & magick $mainImage `
                -resize "${maxWidth}x${maxHeight}>" `
                -quality $quality `
                -strip `
                -interlace Plane `
                -gaussian-blur 0.05 `
                -colorspace sRGB `
                $outputFile 2>$null
            
            if (Test-Path $outputFile) {
                $compressedSize = (Get-Item $outputFile).Length
                $totalCompressedSize += $compressedSize
                $reduction = [math]::Round((1 - ($compressedSize / $originalSize)) * 100, 1)
                
                # Only show significant compressions
                if ($reduction -gt 50) {
                    Write-Host "  ✓ $sku - Reduced by $reduction%" -ForegroundColor Green
                }
            } else {
                $errors++
                Write-Host "  ✗ Failed to compress $sku" -ForegroundColor Red
            }
            
        } catch {
            $errors++
            Write-Host "  ✗ Error processing $sku: $_" -ForegroundColor Red
        }
    } else {
        # If no P.1.png, try to find any image
        $anyImage = Get-ChildItem -Path $folder.FullName -Filter "*.png" | Select-Object -First 1
        if ($anyImage) {
            try {
                $originalSize = $anyImage.Length
                $totalOriginalSize += $originalSize
                
                $outputFile = Join-Path $thumbPath "$sku.jpg"
                
                & magick $anyImage.FullName `
                    -resize "${maxWidth}x${maxHeight}>" `
                    -quality $quality `
                    -strip `
                    -interlace Plane `
                    -gaussian-blur 0.05 `
                    -colorspace sRGB `
                    $outputFile 2>$null
                
                if (Test-Path $outputFile) {
                    $compressedSize = (Get-Item $outputFile).Length
                    $totalCompressedSize += $compressedSize
                }
            } catch {
                $errors++
            }
        }
    }
}

Write-Progress -Activity "Compressing Images" -Completed
Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "              Compression Complete!" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# Calculate results
$originalSizeMB = [math]::Round($totalOriginalSize / 1MB, 2)
$compressedSizeMB = [math]::Round($totalCompressedSize / 1MB, 2)
$savedMB = [math]::Round(($totalOriginalSize - $totalCompressedSize) / 1MB, 2)
$compressionRatio = if ($totalOriginalSize -gt 0) { 
    [math]::Round((1 - ($totalCompressedSize / $totalOriginalSize)) * 100, 1) 
} else { 0 }

Write-Host "📊 Results:" -ForegroundColor Yellow
Write-Host "  • Processed: $processed folders" -ForegroundColor White
Write-Host "  • Errors: $errors" -ForegroundColor $(if ($errors -eq 0) { "Green" } else { "Red" })
Write-Host "  • Original size: $originalSizeMB MB" -ForegroundColor White
Write-Host "  • Compressed size: $compressedSizeMB MB" -ForegroundColor White
Write-Host "  • Space saved: $savedMB MB ($compressionRatio% reduction)" -ForegroundColor Green
Write-Host ""

# Estimate full folder compression
$estimatedFullSize = $currentSize * ($compressedSizeMB / $originalSizeMB)
Write-Host "💡 Estimated total size after compression:" -ForegroundColor Cyan
Write-Host "  • Current screenshots: $([math]::Round($currentSize, 2)) MB" -ForegroundColor White
Write-Host "  • After compression: ~$([math]::Round($estimatedFullSize, 2)) MB" -ForegroundColor Green
Write-Host "  • Potential savings: ~$([math]::Round($currentSize - $estimatedFullSize, 2)) MB" -ForegroundColor Yellow
Write-Host ""

Write-Host "✅ Thumbnails created in: $thumbnailFolder" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Update your Flutter app to use thumbnails from: assets/thumbnails/" -ForegroundColor White
Write-Host "  2. Keep original screenshots for product detail views" -ForegroundColor White
Write-Host "  3. Run 'flutter pub get' to update assets" -ForegroundColor White
Write-Host ""