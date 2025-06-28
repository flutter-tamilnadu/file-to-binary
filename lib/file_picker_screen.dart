import 'dart:convert';
import 'dart:io';
import 'dart:html' as html;
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

import 'about_widget.dart';

class FilePickerWithBinaryViewer extends StatefulWidget {
  const FilePickerWithBinaryViewer({super.key});

  @override
  State<FilePickerWithBinaryViewer> createState() =>
      _FilePickerWithBinaryViewerState();
}

class _FilePickerWithBinaryViewerState
    extends State<FilePickerWithBinaryViewer>  with TickerProviderStateMixin{
  String _binaryData = 'No file selected';
  Uint8List? _fileBytes;
  String? _fileName;
  bool _isLoading = false;
  bool _showBinaryInput = false;
  TextEditingController _binaryInputController = TextEditingController();
  Uint8List? _convertedFileBytes;
  String _convertedFileName = 'converted_file';
  late DropzoneViewController _dropController;
  String _selectedType = 'File To Hex';
  late final AnimationController _controller;


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
        final name = result.files.single.name;
        final bytes = result.files.single.bytes!;
        await _handleFileData(name, bytes);
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

  Future<void> _handleFileData(String name, Uint8List bytes) async {
    setState(() {
      _fileName = name;
      _fileBytes = bytes;
      _binaryData = _formatBinaryData(bytes);
    });
  }

  String _formatBinaryData(Uint8List bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(' ');
  }

  void _copyToClipboard() {
    if (_binaryData.isNotEmpty && _binaryData != 'No file selected') {
      Clipboard.setData(ClipboardData(text: _binaryData));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            backgroundColor: Colors.blue,
            content: Text('Binary data copied successfully')),
      );
    }else{
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.blue,
            content: Text('No data available')),
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
      String cleanBinaryString =
          _binaryInputController.text.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
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
      } else if (bytesList.length >= 4 &&
          bytesList[0] == 0x25 &&
          bytesList[1] == 0x50 &&
          bytesList[2] == 0x44 &&
          bytesList[3] == 0x46) {
        _convertedFileName = 'converted_file.pdf';
      } else if (bytesList.length >= 4 &&
          bytesList[0] == 0x50 &&
          bytesList[1] == 0x4B &&
          bytesList[2] == 0x03 &&
          bytesList[3] == 0x04) {
        final hexString =
            bytesList.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
        if (hexString.contains('776f72642f646f63756d656e742e786d6c')) {
          _convertedFileName = 'converted_file.docx';
        } else if (hexString.contains('786c2f')) {
          _convertedFileName = 'converted_file.xlsx';
        } else if (hexString.contains('7070742f')) {
          _convertedFileName = 'converted_file.pptx';
        } else {
          _convertedFileName = 'converted_file.zip';
        }
      } else if (_canDecodeAsUtf8(bytesList)) {
        _convertedFileName = 'converted_file.txt';
      } else if (bytesList.length >= 3 &&
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
      } else if (bytesList.length >= 12 &&
          bytesList[4] == 0x66 &&
          bytesList[5] == 0x74 &&
          bytesList[6] == 0x79 &&
          bytesList[7] == 0x70) {
        final brand = String.fromCharCodes(bytesList.sublist(8, 12));
        if (brand == 'mp42' || brand == 'isom' || brand == 'avc1') {
          _convertedFileName = 'converted_file.mp4';
        } else if (brand == 'M4A ') {
          _convertedFileName = 'converted_file.m4a';
        } else {
          _convertedFileName = 'converted_file.mp4'; // default fallback to mp4
        }
      }
      else if (bytesList.length >= 4 &&
          bytesList[0] == 0x00 &&
          bytesList[1] == 0x00 &&
          bytesList[2] == 0x01 &&
          bytesList[3] == 0xBA) {
        _convertedFileName = 'converted_file.mpg';
      } else if (bytesList.length >= 4 &&
          bytesList[0] == 0x1A &&
          bytesList[1] == 0x45 &&
          bytesList[2] == 0xDF &&
          bytesList[3] == 0xA3) {
        _convertedFileName = 'converted_file.mkv';
      } else if (bytesList.length >= 8 &&
          bytesList[0] == 0x89 &&
          bytesList[1] == 0x48 &&
          bytesList[2] == 0x44 &&
          bytesList[3] == 0x46) {
        _convertedFileName = 'converted_file.exe';
      } else {
        _convertedFileName = 'converted_file.bin';
      }

      setState(() {
        _convertedFileBytes = bytesList;
      });
    } catch (e) {
      _convertedFileBytes =  null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
            content: Text('Error converting binary: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _canDecodeAsUtf8(Uint8List bytes) {
    try {
      utf8.decode(bytes);
      return true;
    } catch (_) {
      return false;
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
          const SnackBar(
            backgroundColor: Colors.blue,
              content: Text('Download started')),
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
  void initState() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    super.initState();
  }

  bool _isHovering = false;


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xfff2f7ff),
      appBar: AppBar(
        toolbarHeight: 74,
        backgroundColor: Color(0xfff2f7ff),
        surfaceTintColor: Colors.transparent,
        title: Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: Row(
            children: [
              SizedBox(width: 110),
              Image.asset(
                  height: 46,
                  width: 46,
                  'assets/preview.png'),
              SizedBox(width: 20),
              Text('Hex Crafter Online', style: GoogleFonts.arvo(
                textStyle: Theme.of(context).textTheme.displayLarge,
                fontSize: 30,
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic,
              ),
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: CupertinoSlidingSegmentedControl<String>(
              padding: const EdgeInsets.symmetric(horizontal: 6,vertical: 4),
              backgroundColor: Colors.lightBlue,
              thumbColor: CupertinoColors.white,
              groupValue: _selectedType,
              children: {
                'File To Hex': Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'File To Hex',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _selectedType == 'File To Hex'
                          ? Colors.black
                          : Colors.white,
                    ),
                  ),
                ),
                'Hex To File': Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'Hex To File',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _selectedType == 'Hex To File'
                          ? Colors.black
                          : Colors.white,
                    ),
                  ),
                ),
              },
              onValueChanged: (value) {
                _binaryInputController.text = "";
                _convertedFileBytes = null;
                _fileName = null;
                _binaryData = "";
                if (value != null) {
                  setState(() {
                    _selectedType = value;
                  });
                  _selectedType == 'Hex To File' ? _controller.forward() : _controller.reverse();
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 100,left : 20,top: 14),
            child: AboutWidget(),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 14.0),
        child: AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, Widget? child) {
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()..setEntry(3,2, 0.001)..rotateY((_controller.value<0.5)?pi*_controller.value:(pi*(1+_controller.value))),

                child: (_controller.value<0.5)?fileToBinaryWidget():_buildBinaryInputView(),
              );}
        ),
      ),
    );
  }

  Column fileToBinaryWidget() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 60,
          margin: EdgeInsets.symmetric(horizontal: 100),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.white24),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Spacer(),
            Text(
              'Click here to convert Hex into File',
              style: TextStyle(
                color: Colors.black45
              ),
            ),
            SizedBox(width: 10),
            IconButton(
              icon: const Icon(Icons.copy,color: Colors.black45,),
              tooltip: 'Copy binary data',
              onPressed: _copyToClipboard,
            ),
            SizedBox(width: 20)
          ],
        ),
        ),
        SizedBox(height: 2,),
        Expanded(child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 50.0,left: 100),
                child:  Stack(
                  children: [
                    Container(
                        color:
                        _isHovering ? Colors.blue[50] : Colors.white,
                        width: double.infinity,
                        child: DropzoneView(
                          onHover: (){
                            setState(() {
                              _isHovering = true;
                            });
                          },
                          onLeave: (){
                            setState(() {
                              _isHovering = false;
                            });
                          },
                          onCreated: (ctrl) => _dropController = ctrl,
                          onDropFile: (ev) async {
                            setState(() {
                              _isHovering = false;
                              _convertedFileBytes = null;
                            });

                            try {
                              final name =
                              await _dropController.getFilename(ev);
                              final bytes =
                              await _dropController.getFileData(ev);
                              await _handleFileData(name, bytes);
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Error dropping file: $e')),
                              );
                            } finally {

                            }
                          },
                        )),
                    InkWell(
                      onTap: _pickFile,
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          border: Border.all(color: Colors.white24),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.file_upload_outlined,
                                size: 100, color: Colors.black45),
                            SizedBox(
                              height: 20,
                            ),
                            const Text('Choose a file or drag it here',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 20),
                            if (_fileName != null)
                              Text(
                                'File: $_fileName',
                                style: GoogleFonts.arvo(
                                  textStyle:
                                  Theme.of(context).textTheme.displayLarge,
                                  fontSize: 20,
                                  fontStyle: FontStyle.italic,
                                ),
                                textAlign: TextAlign.center,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Container(
                margin : const EdgeInsets.only(right: 100 ,bottom: 50,left: 2),
                padding: const EdgeInsets.all(16.0),
                height: double.infinity,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: SelectableText(
                    _binaryData,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
          ],
        )),
      ],
    );
  }


  Widget _buildBinaryInputView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            height: 60,
            margin: EdgeInsets.symmetric(horizontal: 100),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Spacer(),
                Text(
                  'Click here to download file',
                  style: TextStyle(
                      color: Colors.black45
                  ),
                ),
                SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.download,color: Colors.black45,),
                  tooltip: 'Download converted file',
                  onPressed: _downloadConvertedFile,
                ),
                SizedBox(width: 20)
              ],
            ),
          ),
          SizedBox(height: 2,),

          Expanded(
              child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 50.0,left: 100),
                  child:Container(
                    color: Colors.white,
                    width: double.infinity,
                    child: TextField(
                      onChanged: (_) {
                        _convertBinaryToFile();
                      },
                      autofocus: true,
                      controller: _binaryInputController,
                      maxLines: null,
                      expands: true,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.all(12),
                        border: InputBorder.none,
                        labelText: 'Paste hexadecimal binary data',
                        hintText: 'Example: 89 50 4E 47 0D 0A 1A 0A',
                      ),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                    ),
                  ),
                ),
              ),

              Expanded(
                child: Container(
                  margin : const EdgeInsets.only(right: 100 ,bottom: 50,left: 2),
                  padding: const EdgeInsets.all(16.0),
                  height: double.infinity,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    children: [
                      if (_convertedFileBytes != null)...[
                        Expanded(
                          flex: 2,
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
                                const Icon(Icons.insert_drive_file, size: 50,color: Colors.blue,),
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
                                const SizedBox(height: 10),
                                ElevatedButton.icon(
                                  icon: const Icon(
                                    Icons.download,
                                    color: Colors.blue, // Light appearance
                                  ),
                                  label: const Text(
                                    'Download',
                                    style: TextStyle(color: Colors.blue), // Light text color
                                  ),
                                  onPressed: _downloadConvertedFile,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white, // Light background
                                    foregroundColor: Colors.blue, // Splash/overlay color
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8), // Curved corners
                                      side: const BorderSide(color: Colors.blue), // Optional border
                                    ),
                                    elevation: 2, // Optional for slight shadow
                                  ),
                                )
                              ],
                            ),
                          ),
                        ),
                      ]

                    ],
                  )
                ),
              ),
            ],
          )),

          // Binary input field
          // Expanded(
          //   child: Container(
          //     decoration: BoxDecoration(
          //       border: Border.all(color: Colors.grey.shade300),
          //       borderRadius: BorderRadius.circular(8),
          //     ),
          //     child: TextField(
          //       controller: _binaryInputController,
          //       maxLines: null,
          //       expands: true,
          //       decoration: const InputDecoration(
          //         contentPadding: EdgeInsets.all(12),
          //         border: InputBorder.none,
          //         labelText: 'Paste hexadecimal binary data',
          //         hintText: 'Example: 89 50 4E 47 0D 0A 1A 0A (PNG header)',
          //       ),
          //       style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
          //     ),
          //   ),
          // ),
          // const SizedBox(height: 20),

          // Action buttons
        /*  Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 20.0),
                child: ElevatedButton.icon(
                  icon: const Icon(
                    Icons.change_circle,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Convert',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    textStyle:
                        const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  onPressed: _convertBinaryToFile,
                ),
              ),
              const SizedBox(width: 10),
              if (_convertedFileBytes != null)
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(
                      Icons.download,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Download',
                      style: TextStyle(color: Colors.white),
                    ),
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
            ),*/
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
