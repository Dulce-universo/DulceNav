// ==============================================================
// DulceNav - sync_repository.dart
// Interfaz abstracta para la sincronizacion de datos (LAN/Nube).
// ==============================================================

abstract class SyncRepository {
  Future<void> uploadBookmarks(List<String> bookmarks);
  Future<List<String>> fetchBookmarks();
  Future<void> uploadPasswords(List<Map<String, dynamic>> passwords);
  Future<List<Map<String, dynamic>>> fetchPasswords();
  Future<void> uploadSettings(Map<String, dynamic> settings);
  Future<Map<String, dynamic>> fetchSettings();
  Future<int> getLastSyncTimestamp();
}
