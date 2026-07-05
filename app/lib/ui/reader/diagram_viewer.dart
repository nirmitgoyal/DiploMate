import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;

import '../../domain/models.dart';
import '../../theme/tokens.dart';

class DiagramPlate extends StatefulWidget {
  const DiagramPlate({super.key, required this.image, required this.bytesLoader});
  final ImageRow image;
  final Future<Uint8List> Function() bytesLoader;

  @override
  State<DiagramPlate> createState() => _DiagramPlateState();
}

class _DiagramPlateState extends State<DiagramPlate> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    widget.bytesLoader().then((b) {
      if (mounted) setState(() => _bytes = b);
    });
  }

  void _open() {
    final bytes = _bytes;
    if (bytes == null) return;
    showDiagramViewer(context, widget.image, bytes);
  }

  @override
  Widget build(BuildContext context) {
    final dm = context.dm;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DmSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            image: true,
            label: widget.image.contentDescription,
            child: InkWell(
              onTap: _open,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(DmRadius.md),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 120),
                  color: dm.sunk,
                  child: _bytes == null
                      ? const SizedBox(height: 120)
                      : Image.memory(_bytes!, fit: BoxFit.contain),
                ),
              ),
            ),
          ),
          const SizedBox(height: DmSpace.xs),
          Row(
            children: [
              Expanded(
                  child: Text(widget.image.caption,
                      style: DmType.meta.copyWith(color: dm.ink2))),
              InkWell(
                onTap: _open,
                borderRadius: BorderRadius.circular(DmRadius.sm),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: DmSpace.sm, vertical: DmSpace.xs),
                  decoration: BoxDecoration(
                    border: Border.all(color: dm.ruleStrong),
                    borderRadius: BorderRadius.circular(DmRadius.sm),
                  ),
                  child: Text('Tap to enlarge',
                      style: DmType.meta.copyWith(color: dm.tealInk)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void showDiagramViewer(BuildContext context, ImageRow image, Uint8List bytes) {
  showDialog<void>(
    context: context,
    useSafeArea: false,
    builder: (_) => _DiagramViewer(image: image, bytes: bytes),
  );
}

class _DiagramViewer extends StatefulWidget {
  const _DiagramViewer({required this.image, required this.bytes});
  final ImageRow image;
  final Uint8List bytes;

  @override
  State<_DiagramViewer> createState() => _DiagramViewerState();
}

class _DiagramViewerState extends State<_DiagramViewer> {
  final _controller = TransformationController();
  bool _rotated = false;

  void _toggleRotate() {
    setState(() {
      _rotated = !_rotated;
      _controller.value = Matrix4.identity(); // zoom resets on rotate
    });
  }

  void _doubleTap() {
    final zoomedIn = _controller.value.getMaxScaleOnAxis() > 1.01;
    _controller.value = zoomedIn
        ? Matrix4.identity()
        : (Matrix4.identity()..scaleByDouble(2.5, 2.5, 2.5, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final dm = context.dm;
    return Dialog.fullscreen(
      backgroundColor: dm.paper,
      child: FocusScope(
        autofocus: true,
        child: Shortcuts(
          shortcuts: {
            LogicalKeySet(LogicalKeyboardKey.escape): const _CloseIntent(),
          },
          child: Actions(
            actions: {
              _CloseIntent: CallbackAction<_CloseIntent>(
                  onInvoke: (_) => Navigator.of(context).pop()),
            },
            child: Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: DmSpace.sm, vertical: DmSpace.xs),
                    child: Row(
                      children: [
                        Expanded(
                            child: Text(widget.image.caption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    DmType.meta.copyWith(color: dm.ink2))),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(Icons.close, color: dm.ink),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onDoubleTap: _doubleTap,
                    child: InteractiveViewer(
                      transformationController: _controller,
                      minScale: 1,
                      maxScale: 5,
                      child: Center(
                        child: RotatedBox(
                          quarterTurns: _rotated ? 1 : 0,
                          child: Semantics(
                              image: true,
                              label: widget.image.contentDescription,
                              child: Image.memory(widget.bytes,
                                  fit: BoxFit.contain)),
                        ),
                      ),
                    ),
                  ),
                ),
                OutlinedButton(
                  onPressed: _toggleRotate,
                  style: OutlinedButton.styleFrom(
                      side: BorderSide(color: dm.ruleStrong)),
                  child: Text(
                      _rotated ? 'Back to portrait' : 'Rotate for a larger view',
                      style: DmType.meta.copyWith(color: dm.tealInk)),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(DmSpace.sm),
                    child: Text('Pinch or double-tap to zoom · drag to pan',
                        style: DmType.meta.copyWith(color: dm.ink3)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CloseIntent extends Intent {
  const _CloseIntent();
}
