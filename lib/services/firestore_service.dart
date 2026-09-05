import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Lightweight Cloud Firestore layer for the app.
///
/// Synchronizes two things per device (no accounts in this app):
///  - `favorites`     : PDF file names the user starred
///  - `share_history` : PDF file names the user has shared, newest first
///
/// Every method degrades gracefully when Firebase has not been initialized
/// (offline / not configured yet) so the app keeps working fully local.
class FirestoreService {
  FirestoreService._();

  static final FirestoreService instance = FirestoreService._();

  final ValueNotifier<Set<String>> favoritesNames = ValueNotifier(<String>{});
  final ValueNotifier<List<String>> recentlySharedNames = ValueNotifier([]);

  static bool get isConfigured => Firebase.apps.isNotEmpty;

  Future<void> refresh() async {
    if (!isConfigured) return;
    try {
      final fav = await FirebaseFirestore.instance.collection('favorites').get();
      favoritesNames.value = fav.docs.map((d) => d.id).toSet();

      final shared = await FirebaseFirestore.instance
          .collection('share_history')
          .orderBy('lastSharedAt', descending: true)
          .get();
      recentlySharedNames.value = shared.docs.map((d) => d.id).toList();
    } catch (e) {
      debugPrint('Firestore refresh failed: $e');
    }
  }

  Future<bool> isFavorite(String fileName) async {
    if (!isConfigured) return false;
    try {
      final doc = await FirebaseFirestore.instance.collection('favorites').doc(fileName).get();
      return doc.exists;
    } catch (e) {
      debugPrint('Firestore read failed: $e');
      return false;
    }
  }

  Future<void> toggleFavorite(String fileName, {required bool add}) async {
    if (!isConfigured) return;
    try {
      final ref = FirebaseFirestore.instance.collection('favorites').doc(fileName);
      if (add) {
        await ref.set({
          'name': fileName,
          'favoritedAt': FieldValue.serverTimestamp(),
        });
        favoritesNames.value = {...favoritesNames.value, fileName};
      } else {
        await ref.delete();
        final next = {...favoritesNames.value};
        next.remove(fileName);
        favoritesNames.value = next;
      }
    } catch (e) {
      debugPrint('Firestore favorite update failed: $e');
    }
  }

  Future<void> recordShare(String fileName) async {
    if (!isConfigured) return;
    try {
      await FirebaseFirestore.instance.collection('share_history').doc(fileName).set({
        'name': fileName,
        'lastSharedAt': FieldValue.serverTimestamp(),
      });
      final current = recentlySharedNames.value;
      recentlySharedNames.value = [
        fileName,
        ...current.where((n) => n != fileName),
      ];
    } catch (e) {
      debugPrint('Firestore share record failed: $e');
    }
  }
}