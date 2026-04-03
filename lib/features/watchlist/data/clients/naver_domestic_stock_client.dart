// ignore_for_file: unused_element, unused_field

import 'dart:convert';

import 'package:dio/dio.dart';

import '../dtos/naver_stock_dtos.dart';

//Future => 비동기 결과값 => promise와 유사
abstract interface class NaverStockDataClient {
  Future<List<NaverAutocompleteItemDto>> searchStocks(String query);

  Future<Map<String, NaverRealtimeQuoteDto>> fetchRealtimeQuotes(
    Iterable<String> symbols,
  );

  Future<NaverChartMetadataDto> fetchChartMetadata(String symbol);

  Future<NaverDailyHistoryPageDto> fetchDailyHistoryPage({
    required String symbol,
    required int page,
  });
}

class NaverDomesticStockClient implements NaverStockDataClient {
  const NaverDomesticStockClient(this._dio);

  final Dio _dio;

  static const Map<String, String> _defaultHeaders = {
    'accept': 'application/json, text/plain, */*',
    'referer': 'https://m.stock.naver.com/',
    'accept-language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
    'user-agent':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/123.0.0.0 Safari/537.36',
  };

  static Map<String, dynamic> _decodeJsonObjectBody(
    Object? data,
    String contextLabel,
  ) {
    if (data == null) {
      throw FormatException('$contextLabel response body is empty');
    }

    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw FormatException('$contextLabel response is not a JSON object');
    }

    if (data is List<int>) {
      final decoded = jsonDecode(utf8.decode(data));
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw FormatException('$contextLabel response is not a JSON object');
    }

    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }

    throw FormatException('$contextLabel response body has unsupported shape');
  }

  static Map<String, dynamic> _asStringKeyedMap(
    Object? value,
    String contextLabel,
  ) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }

    throw FormatException('$contextLabel is not a JSON object');
  }

  @override
  Future<List<NaverAutocompleteItemDto>> searchStocks(String query) async {
    // TODO(assignment): Implement the Naver autocomplete request.
    //
    // Goal:
    // - Call https://ac.stock.naver.com/ac with Dio.
    // - Send q=<query> and target=stock,ipo,index,marketindicator.
    // - Use _defaultHeaders and ResponseType.plain because the response body
    //   may arrive as a String instead of a decoded JSON map.
    // - Decode the response with _decodeJsonObjectBody.
    // - Read the "items" array and map each entry with
    //   NaverAutocompleteItemDto.fromJson.
    //
    // Related tests:
    // - test/features/watchlist/data/naver_stock_dtos_test.dart
    // - test/features/watchlist/data/naver_watchlist_repository_test.dart

    final response = await _dio.get(
      'https://ac.stock.naver.com/ac',
      queryParameters: {
        'q': query,
        'target': 'stock,ipo,index,marketindicator',
      },
      options: Options(
        headers: _defaultHeaders,
        responseType: ResponseType.plain,
      ),
    );

    //print('1');
    //print(response);

    //response 자체를 넘겨줄 경우 FormatException: searchStocks response body has unsupported shape
    var decodedResponse = _decodeJsonObjectBody(response.data, 'searchStocks');

    // {query: 삼성, items: [
    // {code: 0044K0, name: 삼성스팩10호, typeCode: KOSDAQ, typeName: 코스닥, url: /domestic/stock/0044K0/total, reutersCode: 0044K0, nationCode: KOR, nationName: 대한민국, category: stock, hasDiscussion: true},
    // {code: 0071M0, name: 삼성스팩11호, typeCode: KOSDAQ, typeName: 코스닥, url: /domestic/stock/0071M0/total, reutersCode: 0071M0, nationCode: KOR, nationName: 대한민국, category: stock, hasDiscussion: true}
    // ] }
    // print('2');
    // print(decodedResponse);

    var decodedItems = decodedResponse['items'] as List;
    var naverAutocompleteItemDtoList = decodedItems.map((item) => NaverAutocompleteItemDto.fromJson(item)).toList();
    return naverAutocompleteItemDtoList;

    // throw UnimplementedError(
    //   'TODO(assignment): implement NaverDomesticStockClient.searchStocks',
    // );
  }

  @override
  Future<Map<String, NaverRealtimeQuoteDto>> fetchRealtimeQuotes(
    Iterable<String> symbols,
  ) async {
    // TODO(assignment): Implement the Naver realtime quote request.
    //
    // Goal:
    // - Deduplicate the incoming symbols. //중복을 제거하라
    // - Return an empty map when there is nothing to request.
    // - Build query=SERVICE_ITEM:005930|SERVICE_ITEM:000660 style payload.
    // - Call https://polling.finance.naver.com/api/realtime.
    // - Decode the JSON body, then traverse result -> areas -> datas.
    // - Convert each realtime row with NaverRealtimeQuoteDto.fromJson.
    // - Return a map keyed by the six-digit domestic symbol.
    //
    // Note:
    // - The response body may be plain text JSON, so use ResponseType.plain.
    // - Some tests use a fake client, but the real app depends on this method.

    //set => list로 변환 필요
    var deDuplicatedSymbols = symbols.toSet().toList();
    //join('|') 내부 동작 => 요소1 + '|' + 요소2 + '|' + 요소3
    var queryString = deDuplicatedSymbols.map((symbol)=>'SERVICE_ITEM:$symbol').join('|');
    print(0);
    print(queryString);
    print(Uri.encodeQueryComponent(queryString));

    var finedQueryString = Uri.encodeQueryComponent(queryString).replaceAll('%7C', '|')
        .replaceAll('%3A', ':');

    //인코딩 버전
    // final response = await _dio.get(
    //   'https://polling.finance.naver.com/api/realtime',
    //   queryParameters: {
    //     'query': queryString,
    //   },
    //   options: Options(
    //     headers: _defaultHeaders,
    //     responseType: ResponseType.plain,
    //   ),
    // );

    //직접 Url 버전
    // final url =
    //     'https://polling.finance.naver.com/api/realtime?query=$finedQueryString';
    // print(url);
    // final response = await _dio.get(
    //   url,
    //   options: Options(
    //     headers: _defaultHeaders,
    //     responseType: ResponseType.plain,
    //   ),
    // );

    //하나하니씩 보내는 버전
    final futures = deDuplicatedSymbols.map((symbol) async {
      final response = await _dio.get(
        'https://polling.finance.naver.com/api/realtime',
        queryParameters: {
          'query': 'SERVICE_ITEM:$symbol',
        },
        options: Options(
          headers: _defaultHeaders,
          responseType: ResponseType.plain,
        ),
      );

    var decodedResponse = _decodeJsonObjectBody(response.data, 'fetchRealtimeQuotes');
      print('2');
      print(decodedResponse);

      // {resultCode: success,
      // result: {pollingInterval: 7000,
      // areas: [{name: SERVICE_ITEM, datas: [{cd: 000660, nm: SK���̴н�, sv: 830000, nv: 880000, cv: 50000, cr: 6.02, rf: 2, mt: 1, ms: OPEN, tyn: N, pcv: 830000, ov: 867000, hv: 886000, lv: 860000, ul: 1079000, ll: 581000, aq: 2501030, aa: 2189654076500.0, nav: null, keps: 28732, eps: 58955, bps: 174538.50083, cnsEps: 194874, dv: 3000.0, countOfListedStock: 712702365, nxtOverMarketPriceInfo: {tradingSessionType: REGULAR_MARKET, overMarketStatus: OPEN, overPrice: 880,000, openPrice: 843,000, highPrice: 886,000, lowPrice: 843,000, compareToPreviousPrice: {code: 2, text: ���, name: RISING}, compareToPreviousClosePrice: 50,000, fluctuationsRatio: 6.02, localTradedAt: 2026-04-03T14:38:21.507635+09:00, tradeStopType: {code: 1, text: �.Trading, name: TRADING}, accumulatedTradingVolume: 1,629,927, accumulatedTradingValue: 1,420,250�鸸}}]}], time: 1775194701507}}
      print('3');
      print(decodedResponse['result']['areas'][0]['datas'].length);

      //MapEntry = Map의 “한 쌍 (key, value)”
      return MapEntry(symbol, NaverRealtimeQuoteDto.fromJson(decodedResponse['result']['areas'][0]['datas'][0]));
    });

    final results = Map.fromEntries(await Future.wait(futures));
    print('4');
    print(results);

    // print('1');
    // print(response.data);
    //
    // //response 자체를 넘겨줄 경우 FormatException: searchStocks response body has unsupported shape
    // var decodedResponse = _decodeJsonObjectBody(response.data, 'fetchRealtimeQuotes');
    // print('2');
    // print(decodedResponse);
    //
    // print('3');
    // print(decodedResponse['result']['areas'][0]['datas'].length);

    return results;

    throw UnimplementedError(
      'TODO(assignment): implement NaverDomesticStockClient.fetchRealtimeQuotes',
    );
  }

  @override
  Future<NaverChartMetadataDto> fetchChartMetadata(String symbol) async {
    // TODO(assignment): Implement the chart metadata request.
    //
    // Goal:
    // - Call
    //   https://stock.naver.com/api/securityFe/api/fchart/domestic/stock/{symbol}
    // - Decode the JSON object with _decodeJsonObjectBody.
    // - Convert the payload with NaverChartMetadataDto.fromJson.
    //
    // Required fields for the DTO:
    // - symbolCode
    // - stockName
    // - stockExchangeNameKor
    throw UnimplementedError(
      'TODO(assignment): implement NaverDomesticStockClient.fetchChartMetadata',
    );
  }

  @override
  Future<NaverDailyHistoryPageDto> fetchDailyHistoryPage({
    required String symbol,
    required int page,
  }) async {
    // TODO(assignment): Implement parsing for the legacy daily history page.
    //
    // Goal:
    // - Validate that page >= 1.
    // - Request https://finance.naver.com/item/sise_day.naver
    //   with code=<symbol> and page=<page>.
    // - Use ResponseType.bytes and decode the HTML with latin1.
    // - Parse one page of historical rows from the HTML table.
    // - For each row, extract:
    //   - localDate (yyyyMMdd)
    //   - closePrice
    //   - openPrice
    //   - highPrice
    //   - lowPrice
    //   - accumulatedTradingVolume
    // - Also extract lastPage from the pagination area.
    //
    // Hint:
    // - The rendered table order is close, change, open, high, low, volume.
    // - You can keep using NaverHistoricalPriceDto.fromJson to build rows.
    throw UnimplementedError(
      'TODO(assignment): implement NaverDomesticStockClient.fetchDailyHistoryPage',
    );
  }
}

double _parseDouble(String value) {
  return double.parse(value.replaceAll(',', ''));
}

int _parseInt(String value) {
  return int.parse(value.replaceAll(',', ''));
}

Map<String, String> naverDesktopLikeHeaders() =>
    Map<String, String>.unmodifiable(NaverDomesticStockClient._defaultHeaders);
