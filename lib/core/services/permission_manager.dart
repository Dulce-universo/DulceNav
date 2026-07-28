// ============================================================
// DulceNav — permission_manager.dart
// Gestor centralizado de permisos por sitio web.
// ============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'storage_service.dart';

enum PermissionDecision { allow, ask, block }

class PermissionManager extends ChangeNotifier {
  PermissionManager._() {
    _loadPermissions();
  }
  static final PermissionManager instance = PermissionManager._();

  static const String _keyDefaultCamera = 'perm_default_camera';
  static const String _keyDefaultMic = 'perm_default_mic';
  static const String _keyDefaultLocation = 'perm_default_location';
  static const String _keyDefaultNotifications = 'perm_default_notifications';
  static const String _keyDefaultClipboard = 'perm_default_clipboard';
  static const String _keySiteRules = 'perm_site_rules';

  PermissionDecision _defaultCamera = PermissionDecision.ask;
  PermissionDecision _defaultMic = PermissionDecision.ask;
  PermissionDecision _defaultLocation = PermissionDecision.ask;
  PermissionDecision _defaultNotifications = PermissionDecision.ask;
  PermissionDecision _defaultClipboard = PermissionDecision.ask;

  // Mapa de dominio -> tipoPermiso -> Decision
  final Map<String, Map<String, PermissionDecision>> _siteRules = {};

  PermissionDecision get defaultCamera => _defaultCamera;
  PermissionDecision get defaultMic => _defaultMic;
  PermissionDecision get defaultLocation => _defaultLocation;
  PermissionDecision get defaultNotifications => _defaultNotifications;
  PermissionDecision get defaultClipboard => _defaultClipboard;
  Map<String, Map<String, PermissionDecision>> get siteRules => _siteRules;

  void _loadPermissions() {
    try {
      final storage = StorageService.instance;
      _defaultCamera = _parseDecision(storage.getString(_keyDefaultCamera) ?? 'ask');
      _defaultMic = _parseDecision(storage.getString(_keyDefaultMic) ?? 'ask');
      _defaultLocation = _parseDecision(storage.getString(_keyDefaultLocation) ?? 'ask');
      _defaultNotifications = _parseDecision(storage.getString(_keyDefaultNotifications) ?? 'ask');
      _defaultClipboard = _parseDecision(storage.getString(_keyDefaultClipboard) ?? 'ask');

      final rulesStr = storage.getString(_keySiteRules);
      if (rulesStr != null && rulesStr.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(rulesStr);
        decoded.forEach((domain, perms) {
          if (perms is Map) {
            final Map<String, PermissionDecision> domainMap = {};
            perms.forEach((permType, decisionStr) {
              domainMap[permType] = _parseDecision(decisionStr.toString());
            });
            _siteRules[domain] = domainMap;
          }
        });
      }
    } catch (_) {}
  }

  void _savePermissions() {
    try {
      final storage = StorageService.instance;
      storage.setString(_keyDefaultCamera, _decisionToString(_defaultCamera));
      storage.setString(_keyDefaultMic, _decisionToString(_defaultMic));
      storage.setString(_keyDefaultLocation, _decisionToString(_defaultLocation));
      storage.setString(_keyDefaultNotifications, _decisionToString(_defaultNotifications));
      storage.setString(_keyDefaultClipboard, _decisionToString(_defaultClipboard));

      final Map<String, Map<String, String>> rulesToSerialize = {};
      _siteRules.forEach((domain, perms) {
        final Map<String, String> domainMap = {};
        perms.forEach((permType, decision) {
          domainMap[permType] = _decisionToString(decision);
        });
        rulesToSerialize[domain] = domainMap;
      });

      storage.setString(_keySiteRules, jsonEncode(rulesToSerialize));
    } catch (_) {}
  }

  PermissionDecision _parseDecision(String val) {
    switch (val) {
      case 'allow':
        return PermissionDecision.allow;
      case 'block':
        return PermissionDecision.block;
      case 'ask':
      default:
        return PermissionDecision.ask;
    }
  }

  String _decisionToString(PermissionDecision d) {
    switch (d) {
      case PermissionDecision.allow:
        return 'allow';
      case PermissionDecision.block:
        return 'block';
      case PermissionDecision.ask:
        return 'ask';
    }
  }

  // Get active decision for a domain and permission type
  PermissionDecision getDecisionFor(String domain, String permissionType) {
    final cleanDomain = _cleanDomain(domain);
    final domainRules = _siteRules[cleanDomain];
    if (domainRules != null && domainRules.containsKey(permissionType)) {
      return domainRules[permissionType]!;
    }
    // Fallback to global defaults
    switch (permissionType) {
      case 'camera':
        return _defaultCamera;
      case 'microphone':
        return _defaultMic;
      case 'location':
        return _defaultLocation;
      case 'notifications':
        return _defaultNotifications;
      case 'clipboard':
        return _defaultClipboard;
      default:
        return PermissionDecision.ask;
    }
  }

  void setDecisionFor(String domain, String permissionType, PermissionDecision decision) {
    final cleanDomain = _cleanDomain(domain);
    if (!_siteRules.containsKey(cleanDomain)) {
      _siteRules[cleanDomain] = {};
    }
    _siteRules[cleanDomain]![permissionType] = decision;
    _savePermissions();
    notifyListeners();
  }

  void revokePermission(String domain, String permissionType) {
    final cleanDomain = _cleanDomain(domain);
    if (_siteRules.containsKey(cleanDomain)) {
      _siteRules[cleanDomain]!.remove(permissionType);
      if (_siteRules[cleanDomain]!.isEmpty) {
        _siteRules.remove(cleanDomain);
      }
      _savePermissions();
      notifyListeners();
    }
  }

  void revokeAllForDomain(String domain) {
    final cleanDomain = _cleanDomain(domain);
    if (_siteRules.containsKey(cleanDomain)) {
      _siteRules.remove(cleanDomain);
      _savePermissions();
      notifyListeners();
    }
  }

  void updateDefaultDecision(String permissionType, PermissionDecision decision) {
    switch (permissionType) {
      case 'camera':
        _defaultCamera = decision;
        break;
      case 'microphone':
        _defaultMic = decision;
        break;
      case 'location':
        _defaultLocation = decision;
        break;
      case 'notifications':
        _defaultNotifications = decision;
        break;
      case 'clipboard':
        _defaultClipboard = decision;
        break;
    }
    _savePermissions();
    notifyListeners();
  }

  String _cleanDomain(String domain) {
    var d = domain.trim().toLowerCase();
    try {
      final uri = Uri.tryParse(d);
      if (uri != null && uri.host.isNotEmpty) {
        d = uri.host;
      }
    } catch (_) {}
    return d;
  }
}
