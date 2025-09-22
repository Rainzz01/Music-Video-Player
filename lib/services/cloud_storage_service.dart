import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/media_information.dart';
import '../models/song.dart';

class CloudStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Map<String, dynamic>> _getMediaMetadata(String filePath, {required bool isVideo}) async {
    Map<String, dynamic> metadata = {
      'overall_duration': 0.0,
      'title': null,
      'artist': null,
      'genre': null,
    };

    try {
      final session = await FFprobeKit.getMediaInformation(filePath);
      final information = await session.getMediaInformation();

      if (information != null) {
        // Safely parse duration to double
        final duration = information.getDuration();
        if (duration is String) {
          metadata['overall_duration'] = double.tryParse(duration) ?? 0.0;
        } else if (duration is double) {
          metadata['overall_duration'] = duration;
        } else {
          metadata['overall_duration'] = 0.0;
        }
        final tags = information.getTags() ?? {};
        metadata['title'] = tags['title'];
        metadata['artist'] = tags['artist'];
        metadata['genre'] = tags['genre'];
      } else {
        print('Error extracting FFprobe metadata for $filePath');
        metadata['error'] = 'Failed to extract FFprobe metadata';
      }

      // Try MetadataGod for additional metadata
      if (await File(filePath).exists()) {
        final metaGod = await MetadataGod.readMetadata(file: filePath);
        metadata['title'] ??= metaGod.title;
        metadata['artist'] ??= metaGod.artist;
        metadata['genre'] ??= metaGod.genre;
      }

      print('Extracted metadata for $filePath: $metadata');
    } catch (e) {
      print('Error extracting metadata for $filePath: $e');
      metadata['error'] = 'Failed to extract metadata: $e';
    }

    return metadata;
  }

  Future<Map<String, dynamic>> uploadFile(File localFile, String fileName, bool isVideo) async {
    if (_auth.currentUser == null) {
      throw Exception('User must be authenticated to upload');
    }

    final userId = _auth.currentUser!.uid;
    final fileHash = await _computeFileHash(localFile);
    final fileExtension = isVideo ? '.mp4' : localFile.path.endsWith('.mp3') ? '.mp3' : '.m4a';
    final storagePath = 'songs/$userId/$fileHash$fileExtension';

    try {
      // Extract metadata before upload
      final metadata = await _getMediaMetadata(localFile.path, isVideo: isVideo);
      final fileNameWithoutExt = fileName.replaceAll('.mp3', '').replaceAll('.m4a', '').replaceAll('.mp4', '');
      final songName = metadata['title'] ?? fileNameWithoutExt;
      final artistName = metadata['artist'] ?? 'Unknown Artist';
      final genre = metadata['genre'] ?? 'Unknown';
      final duration = Duration(milliseconds: ((metadata['overall_duration'] as double) * 1000).round());

      final ref = _storage.ref(storagePath);
      final uploadTask = ref.putFile(localFile);

      // Track progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        print('Upload progress: ${(snapshot.bytesTransferred / snapshot.totalBytes) * 100}%');
      });

      await uploadTask;
      final downloadUrl = await ref.getDownloadURL();
      print('Uploaded to: $downloadUrl');

      // Save metadata to Firestore
      final songDoc = await _firestore.collection('songs').add({
        'songName': songName,
        'artistName': artistName,
        'albumArtImagePath': 'assets/images/default_art.png', // Update later if cloud-based
        'audioPath': downloadUrl,
        'videoPath': isVideo ? downloadUrl : null,
        'album': metadata['album'] ?? 'Unknown Album',
        'genre': genre,
        'fileHash': fileHash,
        'userId': userId,
        'duration': duration.inMilliseconds,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return {
        'downloadUrl': downloadUrl,
        'firestoreId': songDoc.id,
        'songName': songName,
        'artistName': artistName,
        'genre': genre,
        'duration': duration,
      };
    } catch (e) {
      print('Upload failed: $e');
      throw Exception('Failed to upload file: $e');
    }
  }

  Future<String> _computeFileHash(File file) async {
    final bytes = await file.readAsBytes();
    return md5.convert(bytes).toString();
  }

  Future<List<Song>> fetchSongsFromCloud() async {
    if (_auth.currentUser == null) return [];

    final userId = _auth.currentUser!.uid;
    final snapshot = await _firestore
        .collection('songs')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return Song(
        songName: data['songName'] ?? 'Unknown',
        artistName: data['artistName'] ?? 'Unknown Artist',
        albumArtImagePath: data['albumArtImagePath'] ?? 'assets/images/default_art.png',
        audioPath: data['audioPath'],
        videoPath: data['videoPath'],
        album: data['album'],
        genre: data['genre'],
        fileHash: data['fileHash'],
        duration: data['duration'] != null ? Duration(milliseconds: data['duration']) : null,
        firestoreId: doc.id,
      );
    }).toList();
  }

  Future<void> deleteSong(String firestoreId) async {
    final docRef = _firestore.collection('songs').doc(firestoreId);
    final doc = await docRef.get();
    if (doc.exists) {
      final data = doc.data()!;
      final audioRef = _storage.refFromURL(data['audioPath']);
      await audioRef.delete();
      await docRef.delete();
    }
  }
}