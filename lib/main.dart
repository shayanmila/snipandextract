import 'dart:convert';
import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  const options = WindowOptions(
    size: Size(570, 520),
    minimumSize: Size(380, 340),
    center: true,
    title: 'Snip & Extract',
  );
  windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  runApp(const SnipApp());
}

class SnipApp extends StatelessWidget {
  const SnipApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Snip & Extract',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff5266dc)),
      useMaterial3: true,
      visualDensity: VisualDensity.compact,
    ),
    home: const SnipHome(),
  );
}

class SnipHome extends StatefulWidget {
  const SnipHome({super.key});
  @override
  State<SnipHome> createState() => _SnipHomeState();
}

class _SnipHomeState extends State<SnipHome> {
  Uint8List? image;
  String status = 'Select a screen area to begin';
  bool busy = false;
  bool helpOpen = false;
  final textController = TextEditingController();

  Future<Map<String, dynamic>> invoke(String action, [Map<String, dynamic>? data]) async {
    final script = File('${File(Platform.resolvedExecutable).parent.path}\\snip_native.ps1');
    if (!await script.exists()) {
      throw Exception('Native helper not found: ${script.path}');
    }
    final p = await Process.run('powershell.exe', [
      '-NoProfile', '-NonInteractive', '-Sta', '-ExecutionPolicy', 'Bypass',
      '-File', script.path, '-Action', action,
      if (data != null) ...['-Payload', base64Encode(utf8.encode(jsonEncode(data)))],
    ]);
    if (p.exitCode != 0) {
      throw Exception(p.stderr.toString().trim().isEmpty ? p.stdout : p.stderr);
    }
    return Map<String, dynamic>.from(jsonDecode(p.stdout.toString().trim()));
  }

  Future<void> capture() async {
    if (busy) return;
    setState(() { busy = true; status = 'Drag to select area; Esc to cancel'; });
    try {
      // Hide the Flutter window so it cannot obscure the area being captured.
      await windowManager.hide();
      final result = await invoke('capture');
      if (!mounted) return;
      if (result['cancelled'] == true) {
        setState(() => status = 'Capture cancelled');
      } else {
        setState(() {
          image = base64Decode(result['image'] as String);
          textController.clear();
          status = 'Captured ${result['width']} × ${result['height']} pixels';
        });
      }
    } catch (e) {
      if (mounted) setState(() => status = 'Capture failed: $e');
    } finally {
      await windowManager.show();
      await windowManager.focus();
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (image == null || busy) { return; }
    final f = await getSaveLocation(
      suggestedName: 'Snip_${DateTime.now().millisecondsSinceEpoch}.png',
      acceptedTypeGroups: [const XTypeGroup(label: 'PNG image', extensions: ['png'])],
    );
    if (f == null) return;
    try {
      await File(f.path).writeAsBytes(image!);
      if (mounted) setState(() => status = 'Saved to ${f.path}');
    } catch (e) {
      if (mounted) setState(() => status = 'Save failed: $e');
    }
  }

  Future<void> copyImage() async {
    if (image == null || busy) return;
    setState(() => busy = true);
    try {
      await invoke('copyImage', {'image': base64Encode(image!)});
      if (mounted) setState(() => status = 'Image copied');
    } catch (e) {
      if (mounted) setState(() => status = 'Image copy failed: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> ocr() async {
    if (image == null || busy) return;
    setState(() { busy = true; status = 'Recognising text offline…'; });
    try {
      final r = await invoke('ocr', {'image': base64Encode(image!)});
      if (mounted) setState(() {
        textController.text = (r['text'] ?? '').toString();
        status = textController.text.trim().isEmpty ? 'No text detected' : 'Text extracted';
      });
    } catch (e) {
      if (mounted) setState(() => status = 'OCR failed: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> copyText() async {
    if (textController.text.trim().isEmpty) { return; }
    await Clipboard.setData(ClipboardData(text: textController.text));
    if (mounted) setState(() => status = 'Text copied');
  }

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  Widget action(IconData icon, String title, VoidCallback? callback, {bool primary = false}) =>
    primary
      ? FilledButton.icon(onPressed: callback, icon: Icon(icon, size: 17), label: Text(title))
      : OutlinedButton.icon(onPressed: callback, icon: Icon(icon, size: 17), label: Text(title));

  Widget shortcutsHelp() => Container(
    width: 238,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      border: Border(left: BorderSide(color: Theme.of(context).dividerColor)),
    ),
    child: ListView(padding: const EdgeInsets.all(12), children: [
      Row(children: [
        const Expanded(child: Text('Keyboard shortcuts', style: TextStyle(fontWeight: FontWeight.bold))),
        IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => helpOpen = false)),
      ]),
      const Divider(),
      for (final item in const [
        ('Ctrl + N', 'New screen capture'),
        ('Ctrl + S', 'Save PNG'),
        ('Ctrl + Shift + C', 'Copy screenshot'),
        ('Ctrl + E', 'Extract text'),
        ('Ctrl + Shift + T', 'Copy extracted text'),
        ('F1', 'Show / hide help'),
        ('Esc', 'Cancel screen selection'),
      ])
        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(item.$1, style: const TextStyle(fontWeight: FontWeight.w600)), Text(item.$2, style: const TextStyle(fontSize: 12))],
        )),
      const Divider(),
      const Text('Shortcuts work when this app is focused. During screen selection, press Esc to cancel.', style: TextStyle(fontSize: 12)),
    ]),
  );

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.keyN, control: true): capture,
      const SingleActivator(LogicalKeyboardKey.keyS, control: true): save,
      const SingleActivator(LogicalKeyboardKey.keyC, control: true, shift: true): copyImage,
      const SingleActivator(LogicalKeyboardKey.keyE, control: true): ocr,
      const SingleActivator(LogicalKeyboardKey.keyT, control: true, shift: true): copyText,
      const SingleActivator(LogicalKeyboardKey.f1): () => setState(() => helpOpen = !helpOpen),
    },
    child: Focus(
      autofocus: true,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 44,
          title: const Text('Snip & Extract', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          actions: [
            IconButton(tooltip: 'Keyboard shortcuts (F1)', onPressed: () => setState(() => helpOpen = !helpOpen), icon: const Icon(Icons.keyboard_outlined)),
          ],
        ),
        body: LayoutBuilder(builder: (context, constraints) {
          final sideBySide = helpOpen && constraints.maxWidth >= 650;
          return Row(children: [
            Expanded(child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    action(Icons.crop_free, 'New Snip', busy ? null : capture, primary: true),
                    const SizedBox(width: 6),
                    action(Icons.save_alt, 'Save PNG', busy || image == null ? null : save),
                    const SizedBox(width: 6),
                    action(Icons.copy, 'Copy Image', busy || image == null ? null : copyImage),
                    const SizedBox(width: 6),
                    action(Icons.document_scanner_outlined, 'Extract Text', busy || image == null ? null : ocr),
                  ]),
                ),
                const SizedBox(height: 6),
                Text(status, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 6),
                Expanded(flex: 3, child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    color: const Color(0xfff1f2f5),
                    child: image == null
                      ? const Center(child: Text('Screenshot preview'))
                      : InteractiveViewer(child: Center(child: Image.memory(image!, fit: BoxFit.contain))),
                  ),
                )),
                const SizedBox(height: 6),
                Row(children: [
                  const Expanded(child: Text('Extracted Text', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                  TextButton.icon(
                    onPressed: textController.text.trim().isEmpty ? null : copyText,
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy Text'),
                  ),
                ]),
                Expanded(flex: 2, child: TextField(
                  controller: textController,
                  expands: true,
                  maxLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(8),
                    hintText: 'Extracted text appears here',
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                )),
              ]),
            )),
            if (sideBySide) shortcutsHelp(),
            if (helpOpen && !sideBySide)
              SizedBox(width: constraints.maxWidth < 470 ? 172 : 210, child: shortcutsHelp()),
          ]);
        }),
      ),
    ),
  );
}
