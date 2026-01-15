import 'package:nocodb/directus_sdk/client.dart';

// Global Directus client instance
late DirectusClient directus;

void initDirectus(String baseUrl, {String? token}) {
  directus = DirectusClient(baseUrl);
  if (token != null) {
    directus.setToken(token);
  }
}
