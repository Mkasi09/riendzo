class GoogleApiConfig {
  const GoogleApiConfig._();

  // Existing project key, kept as a local development fallback so Android
  // Studio runs work even when dart-defines are not configured.
  static const _localDevelopmentApiKey =
      'AIzaSyBS6FrbtuEV7MD2GsyZ7lkFehwLDo_U7BY';

  static const _mapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: _localDevelopmentApiKey,
  );

  static const _placesApiKey = String.fromEnvironment(
    'GOOGLE_PLACES_API_KEY',
    defaultValue: '',
  );

  static String get mapsApiKey => _clean(_mapsApiKey);

  static String get placesApiKey {
    final placesKey = _clean(_placesApiKey);
    return placesKey.isNotEmpty ? placesKey : mapsApiKey;
  }

  static bool get hasMapsApiKey => mapsApiKey.isNotEmpty;

  static bool get hasPlacesApiKey => placesApiKey.isNotEmpty;

  static String _clean(String value) {
    final trimmed = value.trim();
    return trimmed == 'YOUR_GOOGLE_API_KEY' ? '' : trimmed;
  }
}
