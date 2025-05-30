// lib/views/widgets/documents_info_widget.dart - Information about Documents directory
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'dart:io';

class DocumentsInfoWidget extends StatefulWidget {
  const DocumentsInfoWidget({super.key});

  @override
  State<DocumentsInfoWidget> createState() => _DocumentsInfoWidgetState();
}

class _DocumentsInfoWidgetState extends State<DocumentsInfoWidget> {
  final Logger _logger = Logger();
  bool _isLoading = false;
  Map<String, dynamic> _info = {};

  @override
  void initState() {
    super.initState();
    _loadDocumentsInfo();
  }

  Future<void> _loadDocumentsInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      const String documentsPath = '/storage/emulated/0/Documents/alarm_manager';
      final Directory dir = Directory(documentsPath);
      
      final Map<String, dynamic> info = {
        'path': documentsPath,
        'exists': await dir.exists(),
        'audioFiles': <Map<String, dynamic>>[],
        'totalFiles': 0,
        'error': null,
      };

      if (info['exists'] as bool) {
        try {
          final List<FileSystemEntity> entities = await dir.list().toList();
          final List<File> audioFiles = entities
              .whereType<File>()
              .where((file) {
                final fileName = file.path.split('/').last.toLowerCase();
                return fileName.endsWith('.mp3') ||
                       fileName.endsWith('.wav') ||
                       fileName.endsWith('.m4a') ||
                       fileName.endsWith('.aac');
              })
              .toList();

          info['totalFiles'] = entities.length;
          info['audioFiles'] = <Map<String, dynamic>>[];

          for (final file in audioFiles) {
            try {
              final FileStat stat = await file.stat();
              (info['audioFiles'] as List).add({
                'name': file.path.split('/').last,
                'size': stat.size,
                'sizeFormatted': _formatFileSize(stat.size),
                'modified': stat.modified,
              });
            } catch (e) {
              _logger.e('Error getting file stats: $e');
            }
          }

          // Sort by name
          (info['audioFiles'] as List).sort((a, b) => 
              (a['name'] as String).compareTo(b['name'] as String));

        } catch (e) {
          info['error'] = 'Error reading directory: $e';
          _logger.e('Error reading Documents directory: $e');
        }
      }

      setState(() {
        _info = info;
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _info = {'error': 'Error loading directory info: $e'};
        _isLoading = false;
      });
      _logger.e('Error loading Documents info: $e');
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}-'
           '${dateTime.month.toString().padLeft(2, '0')}-'
           '${dateTime.year} '
           '${dateTime.hour.toString().padLeft(2, '0')}:'
           '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.folder, color: Colors.orange),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Documents Directory Info',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _loadDocumentsInfo,
                  icon: _isLoading 
                      ? const SizedBox(
                          width: 16, 
                          height: 16, 
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_info['error'] != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _info['error'].toString(),
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              // Directory path
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.folder_open, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _info['path'].toString(),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Directory status
              Row(
                children: [
                  Icon(
                    _info['exists'] as bool ? Icons.check_circle : Icons.cancel,
                    color: _info['exists'] as bool ? Colors.green : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _info['exists'] as bool 
                        ? 'Directory exists' 
                        : 'Directory does not exist',
                    style: TextStyle(
                      color: _info['exists'] as bool ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_info['exists'] as bool) ...[
                // File statistics
                Text(
                  'Total files: ${_info['totalFiles']} | Audio files: ${(_info['audioFiles'] as List).length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 12),

                // Audio files list
                if ((_info['audioFiles'] as List).isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      border: Border.all(color: Colors.orange),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info, color: Colors.orange, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'No audio files found',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'To add custom audio files:\n'
                          '• Connect your phone to computer via USB\n'
                          '• Navigate to Documents/alarm_manager/\n'
                          '• Copy .mp3 or .wav files to this folder\n'
                          '• Refresh this view to see new files',
                          style: TextStyle(fontSize: 12, color: Colors.orange),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Available Audio Files:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ...(_info['audioFiles'] as List).map((file) => 
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            border: Border.all(color: Colors.green.shade200),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.audiotrack, 
                                       color: Colors.green, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      file['name'].toString(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      '${file['sizeFormatted']} • Modified: ${_formatDateTime(file['modified'])}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).toList(),
                    ],
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}