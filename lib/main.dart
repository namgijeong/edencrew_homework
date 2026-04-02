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

  final result = await client.searchStocks('삼성');

  print('결과: $result');
}
