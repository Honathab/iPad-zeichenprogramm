import 'package:flutter/material.dart';
import '../models/item_model.dart';
import '../services/storage_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Dark Mode Zustand
  bool _isDarkMode = false;

  // Ordner- und Dateiverwaltung
  List<FolderItem> _folders = [];
  List<DrawingFile> _files = [];
  bool _isLoading = true;

  late DrawingFile _currentFile;

  // Undo / Redo Verläufe
  final List<List<DrawingPoint?>> _undoHistory = [];
  final List<List<DrawingPoint?>> _redoHistory = [];

  // Werkzeug-Einstellungen
  Color _selectedColor = Colors.black;
  bool _isEraser = false;
  double _strokeWidth = 4.0;

  // Dynamische Höhe für unendliches Papier
  double _canvasHeight = 2000.0;
  final ScrollController _scrollController = ScrollController();

  final List<Color> _availableColors = [
    Colors.black,
    Colors.white,
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.yellow,
    Colors.purple,
    Colors.orange,
  ];

  @override
  void initState() {
    super.initState();
    _loadDataFromStorage();
  }

  // Daten beim Start laden und falls leer mit Standardwerten füllen
  Future<void> _loadDataFromStorage() async {
    final loadedFolders = await StorageService.loadFolders();
    final loadedFiles = await StorageService.loadFiles();

    setState(() {
      if (loadedFolders.isEmpty) {
        _folders = [
          FolderItem(id: 'f1', name: 'Skizzen', parentId: null),
          FolderItem(id: 'f2', name: 'Projekte', parentId: null),
        ];
      } else {
        _folders = loadedFolders;
      }

      if (loadedFiles.isEmpty) {
        _files = [
          DrawingFile(
            id: 'd1',
            name: 'Unbenannt.drawing',
            folderId: 'f1',
            paperType: PaperType.grid,
            points: [],
          ),
        ];
      } else {
        _files = loadedFiles;
      }

      _currentFile = _files.first;
      _isLoading = false;
    });
  }

  // Automatisches Speichern bei Änderungen
  Future<void> _saveData() async {
    await StorageService.saveData(_folders, _files);
  }

  void _saveSnapshotForUndo() {
    _undoHistory.add(List<DrawingPoint?>.from(_currentFile.points));
    _redoHistory.clear();
  }

  void _undo() {
    if (_undoHistory.isNotEmpty) {
      setState(() {
        _redoHistory.add(List<DrawingPoint?>.from(_currentFile.points));
        _currentFile.points = _undoHistory.removeLast();
      });
      _saveData();
    }
  }

  void _redo() {
    if (_redoHistory.isNotEmpty) {
      setState(() {
        _undoHistory.add(List<DrawingPoint?>.from(_currentFile.points));
        _currentFile.points = _redoHistory.removeLast();
      });
      _saveData();
    }
  }

  void _saveCurrentFileExplicitly() {
    _saveData();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('„${_currentFile.name}“ erfolgreich gespeichert!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Dialog für den benutzerdefinierten Farbwähler (RGB-Regler)
  void _showColorPickerDialog() {
    double r = _selectedColor.red.toDouble();
    double g = _selectedColor.green.toDouble();
    double b = _selectedColor.blue.toDouble();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Color currentColor = Color.fromRGBO(r.toInt(), g.toInt(), b.toInt(), 1.0);
            return AlertDialog(
              title: const Text('Eigene Farbe mischen'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: currentColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('R', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Slider(
                          value: r,
                          min: 0,
                          max: 255,
                          activeColor: Colors.red,
                          onChanged: (val) => setDialogState(() => r = val),
                        ),
                      ),
                      Text('${r.toInt()}'),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('G', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Slider(
                          value: g,
                          min: 0,
                          max: 255,
                          activeColor: Colors.green,
                          onChanged: (val) => setDialogState(() => g = val),
                        ),
                      ),
                      Text('${g.toInt()}'),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('B', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Slider(
                          value: b,
                          min: 0,
                          max: 255,
                          activeColor: Colors.blue,
                          onChanged: (val) => setDialogState(() => b = val),
                        ),
                      ),
                      Text('${b.toInt()}'),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Abbrechen'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      Color newColor = Color.fromRGBO(r.toInt(), g.toInt(), b.toInt(), 1.0);
                      if (!_availableColors.contains(newColor)) {
                        _availableColors.add(newColor);
                      }
                      _selectedColor = newColor;
                      _isEraser = false;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Farbe wählen'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final bool isTablet = MediaQuery.of(context).size.width > 768;
    final Color canvasBgColor = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    return Theme(
      data: _isDarkMode ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true),
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Icon(Icons.edit_note, size: 24),
              const SizedBox(width: 8),
              Text(_currentFile.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          elevation: 2,
          actions: [
            IconButton(
              icon: Icon(_isDarkMode ? Icons.wb_sunny : Icons.nightlight_round),
              tooltip: _isDarkMode ? 'Heller Modus' : 'Dunkler Modus',
              onPressed: () {
                setState(() {
                  _isDarkMode = !_isDarkMode;
                  if (_isDarkMode && _selectedColor == Colors.black) {
                    _selectedColor = Colors.white;
                  } else if (!_isDarkMode && _selectedColor == Colors.white) {
                    _selectedColor = Colors.black;
                  }
                });
              },
            ),
            PopupMenuButton<PaperType>(
              icon: const Icon(Icons.grid_on),
              tooltip: 'Papierhintergrund ändern',
              onSelected: (PaperType type) {
                setState(() {
                  _currentFile.paperType = type;
                });
                _saveData();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: PaperType.blank,
                  child: Row(
                    children: [Icon(Icons.crop_square, color: Colors.grey), SizedBox(width: 8), Text('Leer (Blanko)')],
                  ),
                ),
                const PopupMenuItem(
                  value: PaperType.grid,
                  child: Row(
                    children: [Icon(Icons.grid_4x4, color: Colors.grey), SizedBox(width: 8), Text('Kariert')],
                  ),
                ),
                const PopupMenuItem(
                  value: PaperType.lined,
                  child: Row(
                    children: [Icon(Icons.reorder, color: Colors.grey), SizedBox(width: 8), Text('Liniert')],
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.undo),
              onPressed: _undoHistory.isNotEmpty ? _undo : null,
              tooltip: 'Rückgängig',
            ),
            IconButton(
              icon: const Icon(Icons.redo),
              onPressed: _redoHistory.isNotEmpty ? _redo : null,
              tooltip: 'Wiederherstellen',
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveCurrentFileExplicitly,
              tooltip: 'Speichern',
            ),
            IconButton(
              icon: const Icon(Icons.folder_open),
              onPressed: _showFileManagerDialog,
              tooltip: 'Dateien & Ordner verwalten',
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever),
              onPressed: () {
                _saveSnapshotForUndo();
                setState(() {
                  _currentFile.points.clear();
                });
                _saveData();
              },
              tooltip: 'Leinwand leeren',
            ),
          ],
        ),
        body: isTablet
            ? Row(
                children: [
                  _buildSidebarToolPanel(),
                  const VerticalDivider(width: 1),
                  Expanded(child: _buildInfiniteDrawingCanvas(canvasBgColor)),
                ],
              )
            : Column(
                children: [
                  Expanded(child: _buildInfiniteDrawingCanvas(canvasBgColor)),
                  const Divider(height: 1),
                  _buildBottomToolPanel(),
                ],
              ),
      ),
    );
  }

  Widget _buildInfiniteDrawingCanvas(Color bgColor) {
    return SingleChildScrollView(
      controller: _scrollController,
      physics: const ClampingScrollPhysics(),
      child: Container(
        height: _canvasHeight,
        width: double.infinity,
        color: bgColor,
        child: GestureDetector(
          onPanStart: (details) {
            _saveSnapshotForUndo();
            _addPoint(details.localPosition);
          },
          onPanUpdate: (details) {
            _addPoint(details.localPosition);
            if (details.localPosition.dy > _canvasHeight - 200) {
              setState(() {
                _canvasHeight += 1000;
              });
            }
          },
          onPanEnd: (details) {
            setState(() {
              _currentFile.points.add(null);
            });
            _saveData();
          },
          child: CustomPaint(
            painter: _InfiniteCanvasPainter(
              points: _currentFile.points,
              paperType: _currentFile.paperType,
              isDarkMode: _isDarkMode,
            ),
            size: Size(double.infinity, _canvasHeight),
          ),
        ),
      ),
    );
  }

  void _addPoint(Offset localPosition) {
    setState(() {
      _currentFile.points.add(DrawingPoint(
        offset: localPosition,
        paint: Paint()
          ..color = _isEraser ? Colors.transparent : _selectedColor
          ..strokeWidth = _isEraser ? (_strokeWidth * 3) : _strokeWidth
          ..strokeCap = StrokeCap.round
          ..blendMode = _isEraser ? BlendMode.clear : BlendMode.srcOver,
      ));
    });
  }

  Widget _buildSidebarToolPanel() {
    return Container(
      width: 130,
      color: _isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[100],
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        children: [
          const Text('Werkzeuge', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 10),
          IconButton.filledTonal(
            icon: Icon(_isEraser ? Icons.cleaning_services : Icons.cleaning_services_outlined),
            color: _isEraser ? Colors.blue : (_isDarkMode ? Colors.white : Colors.black),
            onPressed: () {
              setState(() {
                _isEraser = !_isEraser;
              });
            },
            tooltip: 'Radiergummi',
          ),
          const SizedBox(height: 12),
          const Divider(),
          const Text('Stiftdicke', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Slider(
            value: _strokeWidth,
            min: 1.0,
            max: 20.0,
            onChanged: (val) {
              setState(() {
                _strokeWidth = val;
              });
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [2.0, 5.0, 10.0].map((w) {
              return ChoiceChip(
                label: Text('${w.toInt()}'),
                selected: _strokeWidth == w,
                onSelected: (sel) {
                  if (sel) setState(() => _strokeWidth = w);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Farben', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.tune, size: 18),
                onPressed: _showColorPickerDialog,
                tooltip: 'Farbe mischen',
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListView.separated(
              itemCount: _availableColors.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return _buildColorButton(_availableColors[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomToolPanel() {
    return Container(
      height: 90,
      color: _isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[100],
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          IconButton.filledTonal(
            icon: Icon(_isEraser ? Icons.cleaning_services : Icons.cleaning_services_outlined),
            color: _isEraser ? Colors.blue : (_isDarkMode ? Colors.white : Colors.black),
            onPressed: () {
              setState(() {
                _isEraser = !_isEraser;
              });
            },
            tooltip: 'Radiergummi',
          ),
          const VerticalDivider(indent: 12, endIndent: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Dicke', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              SizedBox(
                width: 90,
                child: Slider(
                  value: _strokeWidth,
                  min: 1.0,
                  max: 20.0,
                  onChanged: (val) {
                    setState(() {
                      _strokeWidth = val;
                    });
                  },
                ),
              ),
            ],
          ),
          const VerticalDivider(indent: 12, endIndent: 12),
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: _showColorPickerDialog,
            tooltip: 'Farbe mischen',
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _availableColors.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                return Center(child: _buildColorButton(_availableColors[index]));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorButton(Color color) {
    bool isSelected = (!_isEraser && color == _selectedColor);
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedColor = color;
          _isEraser = false;
        });
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: Colors.blueAccent, width: 3)
              : Border.all(color: Colors.grey[400]!, width: 1),
        ),
      ),
    );
  }

  // Dateimanager
  void _showFileManagerDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Dateien & Ordner'),
          content: SizedBox(
            width: 420,
            height: 420,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _createNewFileDialog();
                        },
                        icon: const Icon(Icons.add_to_photos),
                        label: const Text('Neue Zeichnung'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _createNewFolderDialog(null);
                        },
                        icon: const Icon(Icons.create_new_folder),
                        label: const Text('Neuer Ordner'),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Expanded(
                  child: ListView(
                    children: [
                      for (var folder in _folders.where((f) => f.parentId == null)) ...[
                        _buildFolderTile(folder),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Schließen'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFolderTile(FolderItem folder) {
    final subFolders = _folders.where((f) => f.parentId == folder.id).toList();
    final folderFiles = _files.where((f) => f.folderId == folder.id).toList();

    return ExpansionTile(
      leading: const Icon(Icons.folder, color: Colors.amber),
      title: Row(
        children: [
          Expanded(child: Text(folder.name)),
          IconButton(
            icon: const Icon(Icons.create_new_folder, size: 18),
            tooltip: 'Unterordner erstellen',
            onPressed: () {
              Navigator.pop(context);
              _createNewFolderDialog(folder.id);
            },
          ),
        ],
      ),
      children: [
        for (var sub in subFolders) ...[
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: _buildFolderTile(sub),
          ),
        ],
        for (var file in folderFiles) ...[
          ListTile(
            contentPadding: const EdgeInsets.only(left: 32.0, right: 8.0),
            leading: const Icon(Icons.insert_drive_file, size: 20),
            title: Text(file.name),
            selected: file.id == _currentFile.id,
            onTap: () {
              setState(() {
                _currentFile = file;
                _undoHistory.clear();
                _redoHistory.clear();
              });
              Navigator.pop(context);
            },
            trailing: IconButton(
              icon: const Icon(Icons.drive_file_move, size: 18),
              tooltip: 'Verschieben',
              onPressed: () {
                Navigator.pop(context);
                _moveFileDialog(file);
              },
            ),
          ),
        ],
      ],
    );
  }

  void _createNewFolderDialog(String? parentId) {
    String folderName = '';
    String parentName = parentId != null ? _folders.firstWhere((f) => f.id == parentId).name : 'Hauptverzeichnis';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(parentId == null ? 'Neuen Ordner erstellen' : 'Unterordner in "$parentName"'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Ordnername'),
            onChanged: (val) => folderName = val,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showFileManagerDialog();
              },
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () {
                if (folderName.trim().isNotEmpty) {
                  setState(() {
                    _folders.add(FolderItem(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: folderName.trim(),
                      parentId: parentId,
                    ));
                  });
                  _saveData();
                }
                Navigator.pop(context);
                _showFileManagerDialog();
              },
              child: const Text('Erstellen'),
            ),
          ],
        );
      },
    );
  }

  void _createNewFileDialog() {
    String fileName = 'Neue Zeichnung.drawing';
    String selectedFolderId = _folders.first.id;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Neue Zeichnung anlegen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Dateiname'),
                onChanged: (val) => fileName = val,
                controller: TextEditingController(text: fileName),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedFolderId,
                items: _folders.map((f) {
                  return DropdownMenuItem(value: f.id, child: Text(f.name));
                }).toList(),
                onChanged: (val) {
                  if (val != null) selectedFolderId = val;
                },
                decoration: const InputDecoration(labelText: 'Ordner wählen'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  final newFile = DrawingFile(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: fileName.isEmpty ? 'Unbenannt.drawing' : fileName,
                    folderId: selectedFolderId,
                    paperType: PaperType.grid,
                    points: [],
                  );
                  _files.add(newFile);
                  _currentFile = newFile;
                  _undoHistory.clear();
                  _redoHistory.clear();
                });
                _saveData();
                Navigator.pop(context);
              },
              child: const Text('Erstellen'),
            ),
          ],
        );
      },
    );
  }

  void _moveFileDialog(DrawingFile file) {
    String targetFolderId = file.folderId;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Verschiebe "${file.name}"'),
          content: DropdownButtonFormField<String>(
            value: targetFolderId,
            items: _folders.map((f) {
              return DropdownMenuItem(value: f.id, child: Text(f.name));
            }).toList(),
            onChanged: (val) {
              if (val != null) targetFolderId = val;
            },
            decoration: const InputDecoration(labelText: 'Zielordner'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  file.folderId = targetFolderId;
                });
                _saveData();
                Navigator.pop(context);
              },
              child: const Text('Verschieben'),
            ),
          ],
        );
      },
    );
  }
}

// CustomPainter für Muster-Hintergrund und Zeichnung
class _InfiniteCanvasPainter extends CustomPainter {
  final List<DrawingPoint?> points;
  final PaperType paperType;
  final bool isDarkMode;

  _InfiniteCanvasPainter({
    required this.points,
    required this.paperType,
    required this.isDarkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint gridPaint = Paint()
      ..color = isDarkMode ? Colors.white.withOpacity(0.12) : Colors.blue.withOpacity(0.15)
      ..strokeWidth = 1.0;

    const double step = 30.0;

    if (paperType == PaperType.grid) {
      for (double x = 0; x < size.width; x += step) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
      for (double y = 0; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
    } else if (paperType == PaperType.lined) {
      for (double y = step; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
    }

    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!.offset, points[i + 1]!.offset, points[i]!.paint);
      } else if (points[i] != null && points[i + 1] == null) {
        canvas.drawCircle(points[i]!.offset, points[i]!.paint.strokeWidth / 2, points[i]!.paint);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _InfiniteCanvasPainter oldDelegate) => true;
}