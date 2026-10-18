import 'package:flutter/material.dart';

enum PaperType { blank, grid, lined }

class DrawingPoint {
  final Offset offset;
  final Paint paint;

  DrawingPoint({required this.offset, required this.paint});

  Map<String, dynamic> toJson() => {
        'dx': offset.dx,
        'dy': offset.dy,
        'color': paint.color.value,
        'strokeWidth': paint.strokeWidth,
        'isEraser': paint.blendMode == BlendMode.clear,
      };

  factory DrawingPoint.fromJson(Map<String, dynamic> json) {
    bool isEraser = json['isEraser'] ?? false;
    return DrawingPoint(
      offset: Offset(json['dx'], json['dy']),
      paint: Paint()
        ..color = isEraser ? Colors.transparent : Color(json['color'])
        ..strokeWidth = json['strokeWidth']
        ..strokeCap = StrokeCap.round
        ..blendMode = isEraser ? BlendMode.clear : BlendMode.srcOver,
    );
  }
}

class DrawingFile {
  String id;
  String name;
  String folderId;
  PaperType paperType;
  List<DrawingPoint?> points;

  DrawingFile({
    required this.id,
    required this.name,
    required this.folderId,
    this.paperType = PaperType.grid,
    required this.points,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'folderId': folderId,
        'paperType': paperType.index,
        'points': points.map((p) => p?.toJson()).toList(),
      };

  factory DrawingFile.fromJson(Map<String, dynamic> json) {
    return DrawingFile(
      id: json['id'],
      name: json['name'],
      folderId: json['folderId'],
      paperType: PaperType.values[json['paperType'] ?? 1],
      points: (json['points'] as List)
          .map((p) => p != null ? DrawingPoint.fromJson(p) : null)
          .toList(),
    );
  }
}

class FolderItem {
  String id;
  String name;
  String? parentId;

  FolderItem({required this.id, required this.name, this.parentId});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'parentId': parentId,
      };

  factory FolderItem.fromJson(Map<String, dynamic> json) {
    return FolderItem(
      id: json['id'],
      name: json['name'],
      parentId: json['parentId'],
    );
  }
}