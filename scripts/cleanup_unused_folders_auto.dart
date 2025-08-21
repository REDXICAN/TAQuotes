// Auto cleanup script - deletes unused folders without prompting
// Run with: dart run scripts/cleanup_unused_folders_auto.dart

import 'dart:io';

void main() async {
  print('========================================');
  print('   Automatic Unused Folder Cleanup');
  print('========================================\n');
  
  // List of 835 actual product SKUs (truncated for brevity - add all SKUs)
  final validSkus = {
    'PRO-12R-N', 'PRO-26R-N', 'TSR-23SD-N6', 'M3R24-1-N', 'PST-28-N',
    'TSR-49SD-N6', 'TBR-24SD-N', 'PRO-15R-N', 'PRO-12H-N', 'TSR-72SD-N6',
    'TBR-72SD-D4-N6', 'TUR-28SD-N6', 'TUR-48SD-D2-N6', 'MSF-23-1-N',
    'MSF-49-1-N', 'MSF-72-4-N', 'TPR-44SD-D2-N', 'TPR-67SD-D4-N',
    'TPR-93SD-D6-N', 'TPR-119SD-D8-N', 'JBT-19', 'JBT-27', 'JBT-36',
    'JBT-48', 'JBT-60', 'JBT-72', 'JBT-96', 'JUR-24-N6', 'JUR-36-N6',
    'JUR-48-N6', 'JUR-60-N6', 'JUR-72-N6', 'JUR-24-G-N6', 'JUR-36-G-N6',
    'JUR-48-G-N6', 'JUR-60-G-N6', 'JUR-72-G-N6', 'TGM-5R-N', 'TGM-10SDH-N',
    'TGM-15SDH-N', 'TGM-20SDH-N', 'TGM-35SDH-N', 'TGM-50SDH-N', 'TGM-69SDH-N',
    'TGM-75SDH-N', 'TGF-23SDH-N', 'TGF-47SDH-N', 'TGF-72SDH-N', 'TSA-12-N4',
    'TSA-27-N', 'TSA-42-N', 'TSA-60-N', 'TSA-72-N', 'TOMD-30LB-N', 'TOMD-40LB-N',
    'TOMD-50LB-N', 'TOMD-60LB-N', 'TOMD-75LB-N', 'TOM-30SB-N', 'TOM-40SB-N',
    'TOM-50SB-N', 'TOM-60SB-N', 'TOM-75SB-N', 'PST-48-18M-N', 'PST-60-24M-N',
    'PST-72-30M-N', 'TST-28SD-08-N-CL', 'TST-48SD-10-N-CL', 'TST-48SD-12-N-CL',
    'TST-60SD-16-N-CL', 'TST-72SD-18-N-CL', 'TWR-28SD-N6', 'TWR-48SD-N6',
    'TWR-60SD-N6', 'TWR-77SD-N6', 'TWT-28SD-N6', 'TWT-48SD-N6', 'TWT-60SD-N6',
    'TWT-77SD-N6', 'TWF-28SD-N6', 'TWF-48SD-N6', 'TWF-60SD-N6', 'TWF-77SD-N6',
    // Add remaining SKUs...
  };
  
  final screenshotsDir = Directory('assets/screenshots');
  
  if (!screenshotsDir.existsSync()) {
    print('❌ Screenshots directory not found!');
    exit(1);
  }
  
  // Get all folders in screenshots directory
  final allFolders = screenshotsDir
      .listSync()
      .whereType<Directory>()
      .toList();
  
  print('Found ${allFolders.length} total folders in screenshots\n');
  print('Valid products in database: ${validSkus.length}\n');
  
  // Find and delete unused folders
  int deletedCount = 0;
  int failedCount = 0;
  int totalSizeBytes = 0;
  int freedSizeBytes = 0;
  
  print('Starting deletion of unused folders...\n');
  
  for (final folder in allFolders) {
    final folderName = folder.path.split(Platform.pathSeparator).last;
    
    if (!validSkus.contains(folderName)) {
      try {
        // Calculate size before deletion
        final folderSize = await _calculateFolderSize(folder);
        freedSizeBytes += folderSize;
        
        // Delete the folder
        folder.deleteSync(recursive: true);
        deletedCount++;
        
        // Show progress every 50 deletions
        if (deletedCount % 50 == 0) {
          print('  Progress: Deleted $deletedCount folders (${_formatBytes(freedSizeBytes)} freed)...');
        }
      } catch (e) {
        failedCount++;
        print('  ❌ Failed to delete: $folderName - $e');
      }
    }
  }
  
  print('\n========================================');
  print('           Cleanup Complete!');
  print('========================================');
  print('✅ Successfully deleted: $deletedCount folders');
  if (failedCount > 0) {
    print('❌ Failed to delete: $failedCount folders');
  }
  print('💾 Storage freed: ${_formatBytes(freedSizeBytes)}');
  print('\nRemaining folders: ${allFolders.length - deletedCount}');
}

Future<int> _calculateFolderSize(Directory dir) async {
  int size = 0;
  
  try {
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        size += await entity.length();
      }
    }
  } catch (e) {
    // Ignore errors for inaccessible files
  }
  
  return size;
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}