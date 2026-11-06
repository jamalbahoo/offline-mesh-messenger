import 'dart:async';
import 'dart:io';

/// Tiny allow-listed HTTP portal: only GET / and GET /app.apk are served.
/// The APK path comes from PackageManager, never from a URL parameter.
class ApkPortalServer {
  static const port = 8080;
  HttpServer? _server;
  String? _apkPath;

  Future<String> start({required String apkPath, required String hostAddress}) async {
    if (_server != null) return 'http://$hostAddress:$port';
    final apk = File(apkPath);
    if (!await apk.exists()) throw FileSystemException('Installed APK not found', apkPath);
    _apkPath = apk.absolute.path;
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port, shared: true);
    _server!.listen(_handle, onError: (_) {});
    return 'http://$hostAddress:$port';
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    response.headers.set('X-Content-Type-Options', 'nosniff');
    if (request.method != 'GET') {
      response.statusCode = HttpStatus.methodNotAllowed;
      response.headers.set(HttpHeaders.allowHeader, 'GET');
      await response.close();
      return;
    }
    if (request.uri.path == '/' || request.uri.path.isEmpty) {
      response.headers.contentType = ContentType.html;
      response.write('''<!doctype html><html lang="en"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Mesh Messenger APK</title><style>body{font:16px system-ui;max-width:36rem;margin:10vh auto;padding:1.5rem;color:#153b34}a{display:inline-block;background:#087f6e;color:white;padding:1rem 1.4rem;border-radius:10px;text-decoration:none}</style><h1>Mesh Messenger</h1><p>Download the APK shared by the device owner.</p><a href="/app.apk">Download APK</a></html>''');
      await response.close();
      return;
    }
    if (request.uri.path == '/app.apk') {
      final file = _apkPath;
      if (file == null || !await File(file).exists()) {
        response.statusCode = HttpStatus.notFound;
        await response.close();
        return;
      }
      response.headers.contentType = ContentType('application', 'vnd.android.package-archive');
      response.headers.set(HttpHeaders.contentDispositionHeader, 'attachment; filename="mesh-messenger.apk"');
      response.headers.set(HttpHeaders.contentLengthHeader, await File(file).length());
      await response.addStream(File(file).openRead());
      await response.close();
      return;
    }
    response.statusCode = HttpStatus.notFound;
    await response.close();
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    _apkPath = null;
    await server?.close(force: true);
  }
}
