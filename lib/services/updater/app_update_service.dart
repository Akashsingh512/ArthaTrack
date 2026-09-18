import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../data/secure_storage/secure_storage_service.dart';

class UpdateInfo {
  final bool hasUpdate;
  final String latestVersion;
  final int latestBuild;
  final String tagName;
  final String releaseName;
  final String releaseNotes;
  final String apkDownloadUrl;
  final double apkSizeMb;
  final DateTime? publishedAt;
  final String currentVersion;
  final int currentBuild;

  const UpdateInfo({
    required this.hasUpdate,
    required this.latestVersion,
    required this.latestBuild,
    required this.tagName,
    required this.releaseName,
    required this.releaseNotes,
    required this.apkDownloadUrl,
    required this.apkSizeMb,
    this.publishedAt,
    this.currentVersion = AppConstants.appVersion,
    this.currentBuild = AppConstants.appBuildNumber,
  });

  factory UpdateInfo.noUpdate({
    String currentVersion = AppConstants.appVersion,
    int currentBuild = AppConstants.appBuildNumber,
  }) {
    return UpdateInfo(
      hasUpdate: false,
      latestVersion: currentVersion,
      latestBuild: currentBuild,
      tagName: 'v$currentVersion-beta$currentBuild',
      releaseName: 'ArthaTrack Beta v$currentVersion (Build $currentBuild)',
      releaseNotes: '',
      apkDownloadUrl: '',
      apkSizeMb: 0.0,
      currentVersion: currentVersion,
      currentBuild: currentBuild,
    );
  }
}

class AppUpdateService {
  static const MethodChannel _channel = MethodChannel(AppConstants.updaterChannel);
  final SecureStorageService _storage;

  AppUpdateService({SecureStorageService? storage})
      : _storage = storage ?? SecureStorageService();

  /// Check GitHub releases for a newer APK build than currently installed
  Future<UpdateInfo> checkForUpdate({bool force = false}) async {
    try {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (!force) {
        final lastCheck = await _storage.getLastUpdateCheck();
        // If checked less than 4 hours ago and not forced, skip network check
        if (lastCheck != null && (nowMs - lastCheck) < 4 * 3600 * 1000) {
          return UpdateInfo.noUpdate();
        }
      }

      await _storage.setLastUpdateCheck(nowMs);

      final uri = Uri.parse(
        'https://api.github.com/repos/${AppConstants.githubRepo}/releases?per_page=5',
      );

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'ArthaTrack-App-Updater',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return UpdateInfo.noUpdate();
      }

      final List<dynamic> releases = jsonDecode(response.body);
      if (releases.isEmpty) {
        return UpdateInfo.noUpdate();
      }

      int highestBuild = AppConstants.appBuildNumber;
      dynamic bestRelease;
      dynamic bestApkAsset;

      final buildRegex = RegExp(r'(?:beta|build)[^\d]*(\d+)', caseSensitive: false);
      final versionRegex = RegExp(r'v?(\d+\.\d+\.\d+)');

      for (final rel in releases) {
        if (rel is! Map<String, dynamic>) continue;
        final tagName = rel['tag_name']?.toString() ?? '';
        final name = rel['name']?.toString() ?? '';

        // Extract build number
        int? foundBuild;
        final matchBuild = buildRegex.firstMatch('$tagName $name');
        if (matchBuild != null) {
          foundBuild = int.tryParse(matchBuild.group(1) ?? '');
        }

        // Look for APK in assets
        final assets = rel['assets'] as List<dynamic>?;
        dynamic apkAsset;
        if (assets != null) {
          for (final asset in assets) {
            final assetName = asset['name']?.toString() ?? '';
            if (assetName.endsWith('.apk')) {
              apkAsset = asset;
              break;
            }
          }
        }

        if (foundBuild != null && foundBuild > highestBuild && apkAsset != null) {
          highestBuild = foundBuild;
          bestRelease = rel;
          bestApkAsset = apkAsset;
        }
      }

      if (bestRelease != null && bestApkAsset != null && highestBuild > AppConstants.appBuildNumber) {
        final tagName = bestRelease['tag_name']?.toString() ?? '';
        final name = bestRelease['name']?.toString() ?? 'ArthaTrack Update';
        final body = bestRelease['body']?.toString() ?? '';
        final downloadUrl = bestApkAsset['browser_download_url']?.toString() ?? '';
        final sizeBytes = (bestApkAsset['size'] as num?)?.toInt() ?? 0;
        final sizeMb = (sizeBytes / (1024 * 1024));
        final publishedAtStr = bestRelease['published_at']?.toString();
        DateTime? publishedAt;
        if (publishedAtStr != null) {
          publishedAt = DateTime.tryParse(publishedAtStr);
        }

        String version = AppConstants.appVersion;
        final vMatch = versionRegex.firstMatch(tagName);
        if (vMatch != null) {
          version = vMatch.group(1) ?? version;
        }

        return UpdateInfo(
          hasUpdate: true,
          latestVersion: version,
          latestBuild: highestBuild,
          tagName: tagName,
          releaseName: name,
          releaseNotes: body,
          apkDownloadUrl: downloadUrl,
          apkSizeMb: double.parse(sizeMb.toStringAsFixed(1)),
          publishedAt: publishedAt,
        );
      }

      return UpdateInfo.noUpdate();
    } catch (e) {
      debugPrint('[AppUpdateService] Error checking for updates: $e');
      return UpdateInfo.noUpdate();
    }
  }

  /// Download the APK file with real-time streaming progress using robust HttpClient
  Future<String?> downloadApk({
    required String downloadUrl,
    required void Function(double progress, int received, int total) onProgress,
    bool Function()? isCancelled,
  }) async {
    HttpClient? client;
    IOSink? sink;
    File? targetFile;

    try {
      final tempDir = await getTemporaryDirectory();
      targetFile = File('${tempDir.path}/arthatrack_update.apk');

      if (await targetFile.exists()) {
        try {
          await targetFile.delete();
        } catch (_) {}
      }

      client = HttpClient();
      client.userAgent =
          'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';
      client.connectionTimeout = const Duration(seconds: 45);
      client.idleTimeout = const Duration(seconds: 45);
      client.autoUncompress = true;
      client.badCertificateCallback = (cert, host, port) => true;

      final uri = Uri.parse(downloadUrl);
      final request = await client.getUrl(uri);
      request.followRedirects = true;
      request.maxRedirects = 10;
      request.headers.set(HttpHeaders.acceptHeader, '*/*');

      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        debugPrint('[AppUpdateService] HTTP error: ${response.statusCode}');
        return null;
      }

      final totalBytes = response.contentLength;
      int receivedBytes = 0;
      sink = targetFile.openWrite();

      await for (final chunk in response) {
        if (isCancelled != null && isCancelled()) {
          await sink.close();
          sink = null;
          if (await targetFile.exists()) {
            await targetFile.delete();
          }
          return null;
        }

        sink.add(chunk);
        receivedBytes += chunk.length;

        final progress = totalBytes > 0 ? (receivedBytes / totalBytes) : 0.0;
        onProgress(progress.clamp(0.0, 1.0), receivedBytes, totalBytes);
      }

      await sink.flush();
      await sink.close();
      sink = null;

      if (await targetFile.exists() && await targetFile.length() > 0) {
        return targetFile.path;
      }
      return null;
    } catch (e) {
      debugPrint('[AppUpdateService] Download error: $e');
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }
      if (targetFile != null && await targetFile.exists()) {
        try {
          await targetFile.delete();
        } catch (_) {}
      }
      return null;
    } finally {
      client?.close(force: true);
    }
  }

  /// Open external URL in Android system browser (Chrome) for 1-tap fallback download
  Future<void> openInBrowser(String url) async {
    try {
      await _channel.invokeMethod('openBrowser', {'url': url});
    } catch (e) {
      debugPrint('[AppUpdateService] Open browser error: $e');
    }
  }

  /// Launch Android package installer to install the downloaded APK
  Future<bool> installApk(String filePath) async {
    try {
      final success = await _channel.invokeMethod<bool>('installApk', {'filePath': filePath});
      return success ?? false;
    } catch (e) {
      debugPrint('[AppUpdateService] Install APK error: $e');
      return false;
    }
  }

  /// Check if the app has permission to request package installs (Android 8.0+)
  Future<bool> canInstallPackages() async {
    try {
      final canInstall = await _channel.invokeMethod<bool>('canInstallPackages');
      return canInstall ?? true;
    } catch (e) {
      return true;
    }
  }

  /// Open Android settings so user can enable "Install unknown apps" for ArthaTrack
  Future<void> openInstallPermissionSettings() async {
    try {
      await _channel.invokeMethod('openInstallPermissionSettings');
    } catch (e) {
      debugPrint('[AppUpdateService] Open settings error: $e');
    }
  }
}
