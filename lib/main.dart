import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'features/watchlist/data/providers/watchlist_repository_provider.dart';
import 'theme/app_theme.dart';

// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
//   SystemChrome.setSystemUIOverlayStyle(
//     SystemUiOverlayStyle(
//       statusBarColor: Colors.transparent,
//       statusBarIconBrightness: Brightness.light,
//       statusBarBrightness: Brightness.dark,
//       systemNavigationBarColor: AppColors.bg.bg_2_212121,
//       systemNavigationBarDividerColor: AppColors.bg.bg_2_212121,
//       systemNavigationBarIconBrightness: Brightness.light,
//     ),
//   );
//
//   final sharedPreferences = await SharedPreferences.getInstance();
//
//   runApp(
//     ProviderScope(
//       overrides: [
//         sharedPreferencesProvider.overrideWithValue(sharedPreferences),
//       ],
//       child: const SampleApp(),
//     ),
//   );
// }


//api 호출 테스트 main
import 'package:dio/dio.dart';
import 'features/watchlist/data/clients/naver_domestic_stock_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dio = Dio();

  final client = NaverDomesticStockClient(dio);

  print('호출 시작');

  //searchStocks 테스트
  //final result = await client.searchStocks('삼성');

  //fetchRealtimeQuotes 테스트
  //실험결과 맨 마지막에 있는것만 조회를 함
  //즉 한번에 query로 다 있는것이 아닌 한개당 한번씩 api 요청 필요
  //final result = await client.fetchRealtimeQuotes(['005930','000660']);
  final result = await client.fetchRealtimeQuotes(['000660','005930']);

  print('결과: $result');
}
