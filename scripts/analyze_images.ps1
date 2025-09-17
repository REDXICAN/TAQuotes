# PowerShell script to analyze product images

Write-Host "Analyzing product images..." -ForegroundColor Green

# Get all folder names from assets/screenshots
$imageFolders = Get-ChildItem -Path "assets\screenshots" -Directory | Select-Object -ExpandProperty Name

Write-Host "Found $($imageFolders.Count) image folders" -ForegroundColor Yellow

# Get list of SKUs from product_image_helper_v3.dart
$helperFile = Get-Content "lib\core\utils\product_image_helper_v3.dart" -Raw

# Extract SKUs from the mapping
$pattern = "'([A-Z0-9\-]+)':"
$matches = [regex]::Matches($helperFile, $pattern)
$mappedSKUs = @()

foreach ($match in $matches) {
    $sku = $match.Groups[1].Value
    $mappedSKUs += $sku
}

$mappedSKUs = $mappedSKUs | Select-Object -Unique
Write-Host "Found $($mappedSKUs.Count) SKUs in product image helper" -ForegroundColor Yellow

# Find unused folders
$unusedFolders = @()
$usedFolders = @()

foreach ($folder in $imageFolders) {
    if ($mappedSKUs -contains $folder) {
        $usedFolders += $folder
    } else {
        $unusedFolders += $folder
    }
}

Write-Host "`nAnalysis Results:" -ForegroundColor Cyan
Write-Host "Used folders: $($usedFolders.Count)" -ForegroundColor Green
Write-Host "Unused folders: $($unusedFolders.Count)" -ForegroundColor Red

# Calculate sizes
$totalSize = 0
$unusedSize = 0
$usedSize = 0

foreach ($folder in $imageFolders) {
    $folderPath = "assets\screenshots\$folder"
    $folderSize = (Get-ChildItem -Path $folderPath -File -Recurse | Measure-Object -Property Length -Sum).Sum
    
    if ($folderSize) {
        $totalSize += $folderSize
        
        if ($unusedFolders -contains $folder) {
            $unusedSize += $folderSize
        } else {
            $usedSize += $folderSize
        }
    }
}

$totalSizeMB = [math]::Round($totalSize / 1MB, 2)
$unusedSizeMB = [math]::Round($unusedSize / 1MB, 2)
$usedSizeMB = [math]::Round($usedSize / 1MB, 2)

Write-Host "`nStorage Analysis:" -ForegroundColor Cyan
Write-Host "Total size: $totalSizeMB MB" -ForegroundColor Yellow
Write-Host "Used size: $usedSizeMB MB" -ForegroundColor Green
Write-Host "Unused size: $unusedSizeMB MB (potential savings)" -ForegroundColor Red

# Write results to file
$output = @"
Image Analysis Results
======================
Date: $(Get-Date)
Total folders: $($imageFolders.Count)
Used folders: $($usedFolders.Count)
Unused folders: $($unusedFolders.Count)
Total size: $totalSizeMB MB
Used size: $usedSizeMB MB
Unused size: $unusedSizeMB MB

Unused Folders to Delete:
-------------------------
"@

foreach ($folder in $unusedFolders) {
    $output += "`n$folder"
}

$output | Out-File -FilePath "image_analysis_results.txt"

Write-Host "`nResults written to image_analysis_results.txt" -ForegroundColor Green

# Ask if user wants to delete unused folders
$response = Read-Host "`nDo you want to delete unused folders? (y/n)"
if ($response -eq 'y') {
    Write-Host "Deleting unused folders..." -ForegroundColor Yellow
    
    foreach ($folder in $unusedFolders) {
        $folderPath = "assets\screenshots\$folder"
        Remove-Item -Path $folderPath -Recurse -Force
        Write-Host "Deleted: $folder" -ForegroundColor Red
    }
    
    Write-Host "`nDeleted $($unusedFolders.Count) folders, saved $unusedSizeMB MB" -ForegroundColor Green
} else {
    Write-Host "No folders deleted. Run script again to delete." -ForegroundColor Yellow
}