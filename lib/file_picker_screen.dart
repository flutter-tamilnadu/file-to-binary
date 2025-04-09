import 'dart:io';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class FilePickerWithBinaryViewer extends StatefulWidget {
  const FilePickerWithBinaryViewer({super.key});

  @override
  State<FilePickerWithBinaryViewer> createState() => _FilePickerWithBinaryViewerState();
}

class _FilePickerWithBinaryViewerState extends State<FilePickerWithBinaryViewer> {
  Uint8List? _fileBytes;
  String? _fileName;
  String _binaryData = 'No file selected';
  bool _isLoading = false;
  bool _showBinaryInput = false;
  TextEditingController _binaryInputController = TextEditingController();
  Uint8List? _convertedFileBytes;
  String _convertedFileName = 'converted_file';

  Future<void> _pickFile() async {
    setState(() {
      _isLoading = true;
      _convertedFileBytes = null;
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _fileBytes = result.files.single.bytes;
          _fileName = result.files.single.name;
          _binaryData = _formatBinaryData(_fileBytes!);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatBinaryData(Uint8List bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(' ');
  }

  void _copyToClipboard() {
    if (_binaryData.isNotEmpty && _binaryData != 'No file selected') {
      Clipboard.setData(ClipboardData(text: _binaryData));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Binary data copied to clipboard')),
      );
    }
  }

  void _toggleBinaryInput() {
    setState(() {
      _showBinaryInput = !_showBinaryInput;
      if (!_showBinaryInput) {
        _binaryInputController.clear();
        _convertedFileBytes = null;
      }
    });
  }

  Future<void> _convertBinaryToFile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      String cleanBinaryString = _binaryInputController.text.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
      if (cleanBinaryString.isEmpty) {
        throw Exception('Invalid binary data');
      }

      if (cleanBinaryString.length % 2 != 0) {
        cleanBinaryString = '0$cleanBinaryString';
      }

      List<int> bytes = [];
      for (int i = 0; i < cleanBinaryString.length; i += 2) {
        String byteString = cleanBinaryString.substring(i, i + 2);
        bytes.add(int.parse(byteString, radix: 16));
      }

      final bytesList = Uint8List.fromList(bytes);

      // File type detection
      if (_isImage(bytesList)) {
        if (bytesList[0] == 0xFF && bytesList[1] == 0xD8) {
          _convertedFileName = 'converted_file.jpg';
        } else if (bytesList.length >= 8 &&
            bytesList[0] == 0x89 &&
            bytesList[1] == 0x50 &&
            bytesList[2] == 0x4E &&
            bytesList[3] == 0x47) {
          _convertedFileName = 'converted_file.png';
        } else if (bytesList.length >= 3 &&
            bytesList[0] == 0x47 &&
            bytesList[1] == 0x49 &&
            bytesList[2] == 0x46) {
          _convertedFileName = 'converted_file.gif';
        }
      }
      // Audio file detection
      else if (bytesList.length >= 3 &&
          bytesList[0] == 0x49 &&
          bytesList[1] == 0x44 &&
          bytesList[2] == 0x33) {
        _convertedFileName = 'converted_file.mp3';
      } else if (bytesList.length >= 4 &&
          bytesList[0] == 0x52 &&
          bytesList[1] == 0x49 &&
          bytesList[2] == 0x46 &&
          bytesList[3] == 0x46) {
        _convertedFileName = 'converted_file.wav';
      } else if (bytesList.length >= 4 &&
          bytesList[0] == 0x66 &&
          bytesList[1] == 0x4C &&
          bytesList[2] == 0x61 &&
          bytesList[3] == 0x43) {
        _convertedFileName = 'converted_file.flac';
      } else if (bytesList.length >= 4 &&
          bytesList[0] == 0x4F &&
          bytesList[1] == 0x67 &&
          bytesList[2] == 0x67 &&
          bytesList[3] == 0x53) {
        _convertedFileName = 'converted_file.ogg';
      } else {
        _convertedFileName = 'converted_file.bin';
      }

      setState(() {
        _convertedFileBytes = bytesList;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error converting binary: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadConvertedFile() async {
    if (_convertedFileBytes == null) return;

    try {
      if (kIsWeb) {
        final bytes = _convertedFileBytes!;
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..download = _convertedFileName
          ..click();
        html.Url.revokeObjectUrl(url);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download started')),
        );
      } else {
        Directory? directory;
        if (Platform.isAndroid || Platform.isIOS) {
          directory = await getDownloadsDirectory();
        } else {
          directory = await getApplicationDocumentsDirectory();
        }

        if (directory == null) {
          throw Exception('Could not access storage directory');
        }

        final filePath = '${directory.path}/$_convertedFileName';
        await File(filePath).writeAsBytes(_convertedFileBytes!);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File saved to $filePath')),
        );

        if (!kIsWeb) {
          await OpenFile.open(filePath);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving file: $e')),
      );
    }
  }

  bool _isImage(Uint8List bytes) {
    if (bytes.length >= 2) {
      if (bytes[0] == 0xFF && bytes[1] == 0xD8) return true;
      if (bytes.length >= 8 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47 &&
          bytes[4] == 0x0D &&
          bytes[5] == 0x0A &&
          bytes[6] == 0x1A &&
          bytes[7] == 0x0A) return true;
      if (bytes.length >= 3 &&
          bytes[0] == 0x47 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('File ↔ Binary Converter'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.code,color: Colors.white,),
              label: const Text('Binary to File',style: TextStyle(color: Colors.white),),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                textStyle: const TextStyle(fontSize: 16,color: Colors.white),
              ),
              onPressed: _toggleBinaryInput,
            ),
          ),

        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _showBinaryInput
          ? _buildBinaryInputView()
          : _buildMainView(),
    );
  }

  Widget _buildMainView() {
    return Row(
      children: [
        // Left half - File Picker
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _pickFile,
                  child: const Text('Select File'),
                ),
                const SizedBox(height: 20),
                if (_fileName != null)
                  Text(
                    'Selected file: $_fileName',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ),

        // Vertical divider
        const VerticalDivider(width: 1, thickness: 1),

        // Right half - Binary Data Viewer
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Binary Data:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      tooltip: 'Copy binary data',
                      onPressed: _copyToClipboard,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        _binaryData,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBinaryInputView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Binary to File Converter',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Binary input field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _binaryInputController,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.all(12),
                  border: InputBorder.none,
                  labelText: 'Paste hexadecimal binary data',
                  hintText: 'Example: 89 50 4E 47 0D 0A 1A 0A (PNG header)',
                ),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Action buttons
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 20.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.change_circle,color: Colors.white,),
                  label: const Text('Convert',style: TextStyle(color: Colors.white),),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    textStyle: const TextStyle(fontSize: 16,color: Colors.white),
                  ),
                  onPressed: _convertBinaryToFile,
                ),
              ),
              const SizedBox(width: 10),
              if (_convertedFileBytes != null)
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.download,color: Colors.white,),
                    label: const Text('Download',style: TextStyle(color: Colors.white),),
                    onPressed: _downloadConvertedFile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Results display
          if (_convertedFileBytes != null)
            Expanded(
              flex: 2,
              child: Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _isImage(_convertedFileBytes!)
                      ? Image.memory(
                    _convertedFileBytes!,
                    fit: BoxFit.contain,
                  )
                      : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.insert_drive_file, size: 50),
                      const SizedBox(height: 10),
                      Text(
                        'File ready for download',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${(_convertedFileBytes!.length / 1024).toStringAsFixed(2)} KB',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _binaryInputController.dispose();
    super.dispose();
  }
}