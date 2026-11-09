import 'dart:io';

import 'package:flutter/material.dart';

/// Local photo with a safe placeholder if the file is missing.
class PhotoTile extends StatelessWidget {
  const PhotoTile({super.key, required this.path, this.fit = BoxFit.cover, this.cacheWidth = 700});
  final String path;
  final BoxFit fit;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Image.file(
      File(path),
      fit: fit,
      cacheWidth: cacheWidth,
      errorBuilder: (_, __, ___) => Container(
        color: cs.primaryContainer,
        child: Icon(Icons.broken_image_rounded, color: cs.primary),
      ),
    );
  }
}

/// Full-screen swipeable, zoomable photo viewer.
class PhotoViewerPage extends StatefulWidget {
  const PhotoViewerPage({super.key, required this.paths, this.initial = 0});
  final List<String> paths;
  final int initial;
  @override
  State<PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<PhotoViewerPage> {
  late final _page = PageController(initialPage: widget.initial);
  late int _index = widget.initial;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text('${_index + 1} / ${widget.paths.length}', style: const TextStyle(color: Colors.white)),
        ),
        body: PageView.builder(
          controller: _page,
          itemCount: widget.paths.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) => InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Center(child: PhotoTile(path: widget.paths[i], fit: BoxFit.contain, cacheWidth: 1600)),
          ),
        ),
      );
}
