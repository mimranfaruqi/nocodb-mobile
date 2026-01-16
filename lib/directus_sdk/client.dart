import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:nocodb/common/logger.dart';
import 'package:nocodb/directus_sdk/models.dart';

class DirectusClient {
  DirectusClient(this.baseUrl) : _client = http.Client();
  
  final String baseUrl;
  final http.Client _client;
  String? _accessToken;

  Uri _buildUri(String path, [Map<String, dynamic>? queryParams]) {
    final uri = Uri.parse(baseUrl);
    return uri.replace(
      path: path,
      queryParameters: queryParams?.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );
  }

  Map<String, String> _headers() => {
    'Content-Type': 'application/json',
    if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
  };

  Future<T> _request<T>(
    String method,
    String path, {
    Map<String, dynamic>? queryParams,
    dynamic body,
    T Function(dynamic)? parser,
  }) async {
    final uri = _buildUri(path, queryParams);
    late http.Response response;

    logger.fine('$method $uri');
    if (body != null) {
      logger.fine('Body: ${jsonEncode(body)}');
    }

    try {
      switch (method.toLowerCase()) {
        case 'get':
          response = await _client.get(uri, headers: _headers());
        case 'post':
          response = await _client.post(
            uri,
            headers: _headers(),
            body: body != null ? jsonEncode(body) : null,
          );
        case 'patch':
          response = await _client.patch(
            uri,
            headers: _headers(),
            body: body != null ? jsonEncode(body) : null,
          );
        case 'delete':
          response = await _client.delete(uri, headers: _headers());
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      logger.fine('Response: ${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) return null as T;
        final data = jsonDecode(response.body);
        logger.fine('Data: $data');
        return parser != null ? parser(data) : data as T;
      } else {
        final error = jsonDecode(response.body);
        throw DirectusException(
          response.statusCode,
          error['errors']?[0]?['message'] ?? 'Unknown error',
        );
      }
    } catch (e) {
      logger.shout('Request failed: $e');
      rethrow;
    }
  }

  // Authentication
  Future<DirectusAuthResponse> login(String email, String password) async {
    final response = await _request<Map<String, dynamic>>(
      'POST',
      '/auth/login',
      body: {'email': email, 'password': password},
    );

    _accessToken = response['data']['access_token'];
    return DirectusAuthResponse.fromJson(response['data']);
  }

  Future<DirectusUser> getCurrentUser() async {
    final response = await _request<Map<String, dynamic>>(
      'GET',
      '/users/me',
      queryParams: {'fields': '*'},
    );
    return DirectusUser.fromJson(response['data']);
  }

  void setToken(String token) {
    _accessToken = token;
  }

  void clearToken() {
    _accessToken = null;
  }

  // Collections (equivalent to Tables in NocoDB)
  Future<List<DirectusCollection>> getCollections() async {
    final response = await _request<Map<String, dynamic>>(
      'GET',
      '/collections',
    );
    return (response['data'] as List)
        .map((e) => DirectusCollection.fromJson(e))
        .toList();
  }

  Future<DirectusCollection> getCollection(String collection) async {
    final response = await _request<Map<String, dynamic>>(
      'GET',
      '/collections/$collection',
    );
    return DirectusCollection.fromJson(response['data']);
  }

  // Fields (equivalent to Columns in NocoDB)
  Future<List<DirectusField>> getFields(String collection) async {
    final response = await _request<Map<String, dynamic>>(
      'GET',
      '/fields/$collection',
    );
    return (response['data'] as List)
        .map((e) => DirectusField.fromJson(e))
        .toList();
  }

  // Items (equivalent to Rows in NocoDB)
  Future<DirectusItemsResponse> getItems(
    String collection, {
    int? limit,
    int? offset,
    String? search,
    Map<String, dynamic>? filter,
    List<String>? fields,
    String? sort,
  }) async {
    final queryParams = <String, dynamic>{};
    
    if (limit != null) queryParams['limit'] = limit;
    if (offset != null) queryParams['offset'] = offset;
    if (search != null) queryParams['search'] = search;
    if (filter != null) queryParams['filter'] = jsonEncode(filter);
    if (fields != null) queryParams['fields'] = fields.join(',');
    if (sort != null) queryParams['sort'] = sort;

    final response = await _request<Map<String, dynamic>>(
      'GET',
      '/items/$collection',
      queryParams: queryParams,
    );

    return DirectusItemsResponse(
      data: response['data'] as List<dynamic>,
      meta: response['meta'] != null 
          ? DirectusMeta.fromJson(response['meta']) 
          : null,
    );
  }

  Future<Map<String, dynamic>> getItem(
    String collection,
    String id, {
    List<String>? fields,
  }) async {
    final queryParams = <String, dynamic>{};
    if (fields != null) queryParams['fields'] = fields.join(',');

    final response = await _request<Map<String, dynamic>>(
      'GET',
      '/items/$collection/$id',
      queryParams: queryParams,
    );
    return response['data'];
  }

  Future<Map<String, dynamic>> createItem(
    String collection,
    Map<String, dynamic> data,
  ) async {
    final response = await _request<Map<String, dynamic>>(
      'POST',
      '/items/$collection',
      body: data,
    );
    return response['data'];
  }

  Future<Map<String, dynamic>> updateItem(
    String collection,
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await _request<Map<String, dynamic>>(
      'PATCH',
      '/items/$collection/$id',
      body: data,
    );
    return response['data'];
  }

  Future<void> deleteItem(String collection, String id) async {
    await _request(
      'DELETE',
      '/items/$collection/$id',
    );
  }

  // Relations (for linked records)
  Future<DirectusItemsResponse> getRelatedItems(
    String collection,
    String itemId,
    String relationField, {
    int? limit,
    int? offset,
  }) async {
    final queryParams = <String, dynamic>{};
    if (limit != null) queryParams['limit'] = limit;
    if (offset != null) queryParams['offset'] = offset;

    final response = await _request<Map<String, dynamic>>(
      'GET',
      '/items/$collection/$itemId/$relationField',
      queryParams: queryParams,
    );

    return DirectusItemsResponse(
      data: response['data'] as List<dynamic>,
      meta: response['meta'] != null 
          ? DirectusMeta.fromJson(response['meta']) 
          : null,
    );
  }

  void dispose() {
    _client.close();
  }
}

class DirectusException implements Exception {
  DirectusException(this.statusCode, this.message);
  
  final int statusCode;
  final String message;

  @override
  String toString() => 'DirectusException($statusCode): $message';
}
