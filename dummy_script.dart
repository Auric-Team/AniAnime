import 'package:dio/dio.dart';

void main() async {
  final dio = Dio();
  final res = await dio.get(
    'https://hianime-api-gamma-ebon.vercel.app/api/v2/hianime/anime/demon-slayer-kimetsu-no-yaiba-47',
  );
  print('--- INFO KEYS ---');
  print(res.data['data']['anime']['info'].keys.toList());
  print('--- MORE INFO KEYS ---');
  print(res.data['data']['anime']['moreInfo'].keys.toList());
  print('--- GENRES ---');
  print(res.data['data']['anime']['moreInfo']['genres']);
}
