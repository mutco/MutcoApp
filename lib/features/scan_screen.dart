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
  final photos = <String>[];
  final completed = <String, ScanRecord>{};
  int processed = 0;
  bool transferred = false;
  final sessionId = DateTime.now().microsecondsSinceEpoch.toString();
  int nextImageId = 0;
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
    if (!transferred) {
      for (final record in completed.values) {
        File(record.imagePath)
            .delete()
            .catchError((Object _) => File(record.imagePath));
      }
    }
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
      if (mounted) {
        setState(() {
          photos.add(path);
          photo = path;
        });
      }
    } catch (e) {
      if (mounted) {
        _message(
          '${isEnglish(context) ? 'Capture failed' : 'Gagal mengambil foto'}: $e',
        );
      }
    }
  }

  Future<void> _gallery() async {
    if (picking || busy) return;
    picking = true;
    try {
      final picked = await ImagePicker().pickMultiImage();
      if (picked.isNotEmpty && mounted) {
        setState(() {
          for (final image in picked) {
            if (!photos.contains(image.path)) photos.add(image.path);
          }
          photo = photos.last;
        });
      }
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

  Future<void> _removePhoto(String path) async {
    final record = completed.remove(path);
    setState(() {
      photos.remove(path);
      photo = photos.isEmpty ? null : photos.last;
    });
    if (record != null) {
      final file = File(record.imagePath);
      if (await file.exists()) await file.delete();
    }
    if (mounted && photo == null && camera == null) await _initCamera();
  }

  Future<void> _analyze() async {
    if (photos.isEmpty || busy) return;
    final english = isEnglish(context);
    setState(() {
      busy = true;
      processed = 0;
    });
    final failed = <int>[];
    try {
      final old = camera;
      camera = null;
      await old?.dispose();
      for (var index = 0; index < photos.length; index++) {
        if (!mounted) return;
        setState(() => processed = index + 1);
        final source = photos[index];
        if (completed.containsKey(source)) continue;
        String? persisted;
        try {
          final id = '${sessionId}_${nextImageId++}';
          persisted = await widget.repository.persistImage(source, id);
          if (!mounted) {
            await File(persisted).delete();
            return;
          }
          final result = await widget.inference.detect(
            persisted,
            widget.threshold,
            widget.iouThreshold,
          );
          if (!mounted) {
            await File(persisted).delete();
            return;
          }
          final now = DateTime.now();
          completed[source] = ScanRecord(
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
        } catch (_) {
          if (persisted != null) {
            final file = File(persisted);
            if (await file.exists()) await file.delete();
          }
          failed.add(index + 1);
        }
      }
      if (!mounted) return;
      if (failed.isNotEmpty) {
        setState(() => busy = false);
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              english ? 'Analysis incomplete' : 'Analisis belum lengkap',
            ),
            content: Text(
              english
                  ? '${completed.length}/${photos.length} photos succeeded. Failed photos: ${failed.join(', ')}. Tap Analyze again to retry failed photos, or remove them.'
                  : '${completed.length}/${photos.length} foto berhasil. Foto gagal: ${failed.join(', ')}. Tekan Analisis lagi untuk mengulang foto yang gagal, atau hapus foto tersebut.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
      final first = completed[photos.first]!;
      final record = ScanRecord(
        id: sessionId,
        name: first.name,
        date: first.date,
        imagePath: first.imagePath,
        width: first.width,
        height: first.height,
        detections: first.detections,
        threshold: first.threshold,
        iouThreshold: first.iouThreshold,
        inferenceMs: first.inferenceMs,
        postprocessMs: first.postprocessMs,
        additionalPhotos: photos
            .skip(1)
            .map((path) => completed[path]!)
            .toList(),
      );
      transferred = true;
      // Remove the scan route so returning from results cannot reuse deleted images.
      Navigator.pop(context);
      widget.onResult(record);
    } catch (e) {
      if (mounted) {
        _message('${english ? 'Analysis failed' : 'Analisis gagal'}: $e');
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
      return PopScope(
        canPop: false,
        child: Scaffold(
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
                    isEnglish(context)
                        ? 'Processing $processed of ${photos.length} photos'
                        : 'Memproses $processed dari ${photos.length} foto',
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
            if (photos.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        isEnglish(context)
                            ? '${photos.length} photos | Different beans in each photo'
                            : '${photos.length} foto | Biji berbeda di tiap foto',
                        style: TextStyle(color: p.secondary, fontSize: 12),
                      ),
                    ),
                    IconButton(
                      onPressed: _gallery,
                      tooltip: isEnglish(context)
                          ? 'Add from gallery'
                          : 'Tambah dari galeri',
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                    ),
                    IconButton(
                      onPressed: _retry,
                      tooltip: isEnglish(context)
                          ? 'Add camera photo'
                          : 'Tambah foto kamera',
                      icon: const Icon(Icons.add_a_photo_outlined),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 76,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: photos.length,
                  itemBuilder: (context, index) {
                    final path = photos[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => photo = path),
                        child: Container(
                          width: 76,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: photo == path ? p.accent : p.separator,
                              width: 2,
                            ),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(
                                File(path),
                                fit: BoxFit.cover,
                                cacheWidth: 150,
                                errorBuilder: (_, _, _) =>
                                    const Icon(Icons.broken_image_outlined),
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: IconButton.filled(
                                    padding: EdgeInsets.zero,
                                    iconSize: 18,
                                    tooltip: isEnglish(context)
                                        ? 'Remove photo'
                                        : 'Hapus foto',
                                    onPressed: () => _removePhoto(path),
                                    icon: const Icon(Icons.close),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 2,
                                bottom: 2,
                                child: Container(
                                  color: Colors.black54,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
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
                            onPressed: photos.isEmpty
                                ? _switchCamera
                                : _analyze,
                            tooltip: photos.isEmpty
                                ? tr(context, 'Ganti kamera')
                                : (isEnglish(context)
                                      ? 'Analyze all photos'
                                      : 'Analisis semua foto'),
                            icon: Icon(
                              photos.isEmpty
                                  ? Icons.cameraswitch_outlined
                                  : Icons.check,
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
                              child: Text(
                                isEnglish(context)
                                    ? 'Add photo'
                                    : 'Tambah foto',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: _analyze,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 54),
                              ),
                              child: Text(
                                isEnglish(context)
                                    ? 'Analyze (${photos.length})'
                                    : 'Analisis (${photos.length})',
                              ),
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
