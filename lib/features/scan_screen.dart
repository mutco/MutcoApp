import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app/mutco_theme.dart';
import '../app/app_language.dart';
import '../data/local_repository.dart';
import '../data/scan_record.dart';
import '../services/yolo_inference.dart';
import '../services/crop_photo.dart';

enum CameraRatio {
  portrait('9:16', 9 / 16),
  classic('4:3', .75),
  photo('3:2', 2 / 3),
  square('1:1', 1),
  wide('16:9', 16 / 9);

  const CameraRatio(this.label, this.portraitRatio);
  final String label;
  final double portraitRatio;
}

class ScanScreen extends StatefulWidget {
  final YoloInference inference;
  final LocalRepository repository;
  final double threshold;
  final double iouThreshold;
  final void Function(ScanRecord) onResult;
  const ScanScreen({
    super.key,
    required this.inference,
    required this.repository,
    required this.threshold,
    required this.iouThreshold,
    required this.onResult,
  });
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  CameraController? camera;
  String? error, photo;
  bool busy = false, flash = false, picking = false, initializing = false;
  CameraRatio ratio = CameraRatio.portrait;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    camera?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      final old = camera;
      camera = null;
      old?.dispose();
    } else if (state == AppLifecycleState.resumed &&
        !picking &&
        photo == null &&
        !busy) {
      _initCamera();
    }
  }

  Future<void> _initCamera([CameraDescription? selected]) async {
    if (initializing || camera != null) return;
    initializing = true;
    try {
      final devices = await availableCameras();
      if (!mounted) return;
      if (devices.isEmpty) {
        throw StateError(
          isEnglish(context) ? 'Camera unavailable.' : 'Kamera tidak tersedia.',
        );
      }
      final back = devices.where(
        (e) => e.lensDirection == CameraLensDirection.back,
      );
      final target = selected ?? (back.isNotEmpty ? back.first : devices.first);
      final controller = CameraController(
        target,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);
      if (!mounted || photo != null || busy) {
        await controller.dispose();
        return;
      }
      setState(() {
        camera = controller;
        error = null;
        flash = false;
      });
    } on CameraException catch (e) {
      if (mounted) {
        setState(
          () => error = e.code == 'CameraAccessDenied'
              ? (isEnglish(context)
                    ? 'Camera permission denied. Enable it in Android settings.'
                    : 'Izin kamera ditolak. Aktifkan izin kamera di pengaturan perangkat.')
              : '${isEnglish(context) ? 'Could not open camera' : 'Kamera tidak dapat dibuka'}: ${e.description ?? e.code}',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error =
              '${isEnglish(context) ? 'Could not open camera' : 'Kamera tidak dapat dibuka'}: $e',
        );
      }
    } finally {
      initializing = false;
    }
  }

  Future<void> _capture() async {
    final controller = camera;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture) {
      return;
    }
    try {
      final image = await controller.takePicture();
      final path = await compute(cropCameraPhoto, (
        image.path,
        ratio.portraitRatio,
      ));
      if (mounted) setState(() => photo = path);
    } catch (e) {
      if (mounted) {
        _message(
          '${isEnglish(context) ? 'Capture failed' : 'Gagal mengambil foto'}: $e',
        );
      }
    }
  }

  Future<void> _gallery() async {
    picking = true;
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked != null && mounted) setState(() => photo = picked.path);
    } catch (e) {
      if (mounted) {
        _message(
          '${isEnglish(context) ? 'Could not open gallery' : 'Galeri tidak dapat dibuka'}: $e',
        );
      }
    } finally {
      picking = false;
      if (mounted && photo == null && camera == null) _initCamera();
    }
  }

  Future<void> _retry() async {
    setState(() => photo = null);
    if (camera == null) await _initCamera();
  }

  Future<void> _switchCamera() async {
    try {
      final devices = await availableCameras();
      if (devices.length < 2) return;
      final current = camera?.description.lensDirection;
      final next = devices.firstWhere(
        (e) => e.lensDirection != current,
        orElse: () => devices.first,
      );
      final old = camera;
      setState(() => camera = null);
      await old?.dispose();
      await _initCamera(next);
    } catch (e) {
      if (mounted) {
        _message(
          '${isEnglish(context) ? 'Could not switch camera' : 'Gagal mengganti kamera'}: $e',
        );
      }
    }
  }

  Future<void> _toggleFlash() async {
    final controller = camera;
    if (controller == null) return;
    try {
      final next = !flash;
      await controller.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() => flash = next);
    } catch (e) {
      if (mounted) {
        _message(
          isEnglish(context)
              ? 'Flash unavailable.'
              : 'Lampu kilat tidak tersedia.',
        );
      }
    }
  }

  Future<void> _analyze() async {
    final source = photo;
    if (source == null || busy) return;
    final english = isEnglish(context);
    setState(() => busy = true);
    String? persisted;
    try {
      final old = camera;
      camera = null;
      await old?.dispose();
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      persisted = await widget.repository.persistImage(source, id);
      final result = await widget.inference.detect(
        persisted,
        widget.threshold,
        widget.iouThreshold,
      );
      final now = DateTime.now();
      final record = ScanRecord(
        id: id,
        name:
            '${english ? 'Sample' : 'Sampel'} ${now.day}/${now.month}/${now.year}',
        date: now,
        imagePath: persisted,
        width: result.width,
        height: result.height,
        detections: result.detections,
        threshold: widget.threshold,
        iouThreshold: widget.iouThreshold,
        inferenceMs: result.inferenceMs,
        postprocessMs: result.postprocessMs,
      );
      if (mounted) widget.onResult(record);
    } catch (e) {
      if (persisted != null) {
        final file = File(persisted);
        if (await file.exists()) await file.delete();
      }
      if (mounted) {
        _message(
          '${isEnglish(context) ? 'Analysis failed' : 'Analisis gagal'}: $e',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  void _nextRatio() {
    final next = (ratio.index + 1) % CameraRatio.values.length;
    setState(() => ratio = CameraRatio.values[next]);
  }

  @override
  Widget build(BuildContext context) {
    final p = MutcoPalette.of(context);
    final controlSurface = p.dark ? p.surfaceAlt : const Color(0xffe1e1df);
    if (busy) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 148,
                  height: 148,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          strokeWidth: 5,
                          color: p.accent,
                          backgroundColor: p.surfaceAlt,
                        ),
                      ),
                      Image.asset(
                        'assets/branding/loading_icon.png',
                        width: 100,
                        height: 100,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  tr(context, 'Menganalisis biji kopi...'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: p.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  tr(
                    context,
                    'Mendeteksi biji dan cacat\nMohon tunggu sebentar',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.secondary, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 58,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    tr(context, 'Pindai'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: p.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new),
                    ),
                  ),
                  if (photo == null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Tooltip(
                            message: isEnglish(context)
                                ? 'Tap to change photo ratio'
                                : 'Ketuk untuk mengganti rasio foto',
                            child: TextButton(
                              onPressed: _nextRatio,
                              style: TextButton.styleFrom(
                                backgroundColor: controlSurface,
                                foregroundColor: p.text,
                                minimumSize: const Size(60, 36),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                shape: const StadiumBorder(),
                              ),
                              child: Text(
                                ratio.label,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _toggleFlash,
                            icon: Icon(
                              flash ? Icons.flash_on : Icons.flash_off,
                              color: p.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                color: p.background,
                child: LayoutBuilder(
                  builder: (context, bounds) => Stack(
                    fit: StackFit.expand,
                    children: [
                      if (photo != null)
                        Image.file(
                          File(photo!),
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => Center(
                            child: Text(
                              tr(context, 'Foto tidak dapat dibuka'),
                              style: TextStyle(color: p.secondary),
                            ),
                          ),
                        )
                      else if (camera != null && camera!.value.isInitialized)
                        Center(child: _preview(camera!, ratio, bounds))
                      else
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  error ?? tr(context, 'Menyiapkan kamera...'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: p.text, fontSize: 16),
                                ),
                                if (error != null)
                                  TextButton(
                                    onPressed: () => _initCamera(),
                                    child: Text(tr(context, 'Coba lagi')),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 104,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: photo == null
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: _gallery,
                            tooltip: tr(context, 'Pilih dari galeri'),
                            icon: Icon(
                              Icons.photo_library_outlined,
                              color: p.text,
                              size: 29,
                            ),
                          ),
                          GestureDetector(
                            onTap: _capture,
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: controlSurface,
                              ),
                              child: Center(
                                child: Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: p.text,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _switchCamera,
                            tooltip: tr(context, 'Ganti kamera'),
                            icon: Icon(
                              Icons.cameraswitch_outlined,
                              color: p.text,
                              size: 29,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: _retry,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 54),
                                backgroundColor: controlSurface,
                                foregroundColor: p.text,
                              ),
                              child: Text(tr(context, 'Ulangi')),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: _analyze,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 54),
                              ),
                              child: Text(tr(context, 'Gunakan Foto')),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _preview(
    CameraController controller,
    CameraRatio ratio,
    BoxConstraints bounds,
  ) {
    final targetRatio = ratio.portraitRatio;
    final frameWidth = math.min(
      bounds.maxWidth,
      bounds.maxHeight * targetRatio,
    );
    final frameHeight = frameWidth / targetRatio;
    final sourceRatio = 1 / controller.value.aspectRatio;
    final sourceWidth = frameWidth;
    final sourceHeight = frameWidth / sourceRatio;
    return ClipRect(
      child: SizedBox(
        width: frameWidth,
        height: frameHeight,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: sourceWidth,
            height: sourceHeight,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }
}
