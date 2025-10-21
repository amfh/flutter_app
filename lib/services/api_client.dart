import 'dart:convert';
import 'dart:io';

class ApiClient {
  static ApiClient? _instance;
  static ApiClient get instance {
    _instance ??= ApiClient._();
    return _instance!;
  }

  ApiClient._();

  final String _apiKey = '1234'; // Your API key

  HttpClient get _httpClient {
    final client = HttpClient();
    client.badCertificateCallback =
        (cert, host, port) => true; // For development
    return client;
  }

  Future<HttpClientResponse> get(String url) async {
    final httpClient = _httpClient;
    try {
      final uri = Uri.parse(url);
      final request = await httpClient.getUrl(uri);

      // Add the API key header to all requests
      request.headers.add('X-API-Key', _apiKey);
      print('🔑 API Client: Added X-API-Key header to GET request: $url');
      print('🔑 API Client: Headers: ${request.headers}');

      return await request.close();
    } catch (e) {
      httpClient.close();
      rethrow;
    }
  }

  Future<HttpClientResponse> post(String url, {String? body}) async {
    final httpClient = _httpClient;
    try {
      final uri = Uri.parse(url);
      final request = await httpClient.postUrl(uri);

      // Add the API key header to all requests
      request.headers.add('X-API-Key', _apiKey);
      request.headers.contentType = ContentType.json;
      print('🔑 API Client: Added X-API-Key header to POST request: $url');
      print('🔑 API Client: Headers: ${request.headers}');

      if (body != null) {
        request.write(body);
      }

      return await request.close();
    } catch (e) {
      httpClient.close();
      rethrow;
    }
  }

  Future<String> getJson(String url) async {
    final response = await get(url);
    return await response.transform(utf8.decoder).join();
  }

  Future<String> postJson(String url, {Map<String, dynamic>? data}) async {
    final body = data != null ? jsonEncode(data) : null;
    final response = await post(url, body: body);
    return await response.transform(utf8.decoder).join();
  }
}
