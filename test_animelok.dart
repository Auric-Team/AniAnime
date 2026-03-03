import 'package:dio/dio.dart';

void main() async {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.tatakai.me/api/v1'));
  try {
    final res = await dio.get('/animelok/watch/jujutsu-kaisen-hindi-dubbed?ep=1');
    final servers = res.data['data']['servers'] as List;
    final hindiServers = servers.where((s) => s['language'] == 'Hindi' || s['name'] == 'Hindi' || s['tip'] == 'Multi' || s['name'] == 'Multi').toList();
    print(hindiServers);
    print("--- ALL SERVERS ---");
    print(servers);
  } catch (e) {
    print("Error: $e");
  }
}
