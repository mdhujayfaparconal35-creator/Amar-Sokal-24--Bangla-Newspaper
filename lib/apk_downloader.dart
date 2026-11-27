import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;

/// APK ডাউনলোডার: সার্ভার Range সাপোর্ট করলে ৪টি সংযোগে ভাগ করে একসাথে নামায় (ধীর নেটে অনেক দ্রুত),
/// না করলে সাধারণ এক-সংযোগে নামায়। কোনো অংশ ছিঁড়ে গেলে ওই অংশ থেকেই আবার শুরু হয়।
/// ভুল পাতা (HTML) এলে 'notapk' ছোঁড়ে।
class ApkDownloader {
  static const int parts = 4;

  static Future<void> download(String url, File dest, void Function(int got, int total) onProgress) async {
    if (await dest.exists()) await dest.delete();
    final total = await _probe(url);
    if (total != null && total > 2 * 1024 * 1024) {
      try {
        await _parallel(url, dest, total, onProgress);
        return;
      } catch (e) {
        if (e == 'notapk') rethrow;
        // সমান্তরাল ব্যর্থ হলে সাধারণ ডাউনলোডে ফিরে যায়
        if (await dest.exists()) await dest.delete();
      }
    }
    await _single(url, dest, onProgress);
  }

  /// সার্ভার Range মানে কিনা ও ফাইলের মোট সাইজ
  static Future<int?> _probe(String url) async {
    final c = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(url))..headers['Range'] = 'bytes=0-0';
      final res = await c.send(req).timeout(const Duration(seconds: 20));
      if (res.statusCode != 206) return null;
      final cr = res.headers['content-range'] ?? '';
      final m = RegExp(r'/(\d+)\s*$').firstMatch(cr);
      return m == null ? null : int.tryParse(m.group(1)!);
    } catch (_) {
      return null;
    } finally {
      c.close();
    }
  }

  static Future<void> _parallel(String url, File dest, int total, void Function(int, int) onProgress) async {
    final size = (total + parts - 1) ~/ parts;
    final got = List<int>.filled(parts, 0);
    final files = List.generate(parts, (i) => File('${dest.path}.part$i'));
    var lastReport = 0;
    void report() {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - lastReport < 150) return;
      lastReport = now;
      onProgress(got.fold<int>(0, (a, b) => a + b), total);
    }

    try {
      for (final f in files) {
        if (await f.exists()) await f.delete();
      }
      await Future.wait(List.generate(parts, (i) {
        final start = i * size;
        final end = (start + size - 1) > total - 1 ? total - 1 : start + size - 1;
        return _part(url, files[i], start, end, i == 0, (b) {
          got[i] = b;
          report();
        });
      }));
      onProgress(total, total);
      final sink = dest.openWrite();
      try {
        for (final f in files) {
          await sink.addStream(f.openRead());
        }
      } finally {
        await sink.close();
      }
      if (await dest.length() != total) throw 'size';
    } finally {
      for (final f in files) {
        try {
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
    }
  }

  static Future<void> _part(String url, File file, int start, int end, bool checkPk, void Function(int) onBytes) async {
    var have = 0;
    for (var attempt = 0; attempt < 4; attempt++) {
      final c = http.Client();
      try {
        final req = http.Request('GET', Uri.parse(url))..headers['Range'] = 'bytes=${start + have}-$end';
        final res = await c.send(req).timeout(const Duration(seconds: 30));
        if (res.statusCode != 206) throw 'range';
        final sink = file.openWrite(mode: FileMode.append);
        try {
          var first = have == 0;
          await for (final chunk in res.stream.timeout(const Duration(seconds: 30))) {
            if (first) {
              first = false;
              if (checkPk && chunk.length >= 2 && (chunk[0] != 0x50 || chunk[1] != 0x4B)) throw 'notapk';
            }
            sink.add(chunk);
            have += chunk.length;
            onBytes(have);
          }
        } finally {
          await sink.close();
        }
        if (have >= end - start + 1) return;
        throw 'short';
      } catch (e) {
        if (e == 'notapk' || attempt == 3) rethrow;
        have = await file.exists() ? await file.length() : 0;
        onBytes(have);
        await Future.delayed(const Duration(seconds: 1));
      } finally {
        c.close();
      }
    }
  }

  static Future<void> _single(String url, File dest, void Function(int, int) onProgress) async {
    final c = http.Client();
    try {
      final res = await c.send(http.Request('GET', Uri.parse(url))).timeout(const Duration(seconds: 40));
      if (res.statusCode != 200) throw 'http ${res.statusCode}';
      final total = res.contentLength ?? 0;
      var got = 0;
      var first = true;
      final sink = dest.openWrite();
      try {
        await for (final chunk in res.stream.timeout(const Duration(seconds: 40))) {
          if (first) {
            first = false;
            if (chunk.length < 2 || chunk[0] != 0x50 || chunk[1] != 0x4B) throw 'notapk';
          }
          sink.add(chunk);
          got += chunk.length;
          onProgress(got, total);
        }
      } finally {
        await sink.close();
      }
    } finally {
      c.close();
    }
  }
}
