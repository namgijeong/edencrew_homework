// ignore_for_file: unused_element, unused_field

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/watchlist_models.dart';
import '../../domain/repositories/watchlist_repository.dart';
import '../../domain/services/watchlist_sorting.dart';
import '../clients/naver_domestic_stock_client.dart';
import '../clients/naver_stock_logo_url_resolver.dart';
import '../dtos/naver_stock_dtos.dart';
import 'favorite_ids_local_store.dart';

class NaverWatchlistRepository implements WatchlistRepository {
  NaverWatchlistRepository({
    required Dio dio,
    required FavoriteIdsLocalStore favoriteIdsLocalStore,
    NaverStockDataClient? client,
    NaverStockLogoUrlResolver? logoUrlResolver,
    this.realtimeCacheTtl = const Duration(seconds: 10),
    this.dailyHistoryFetchBatchSize = 4,
  }) : _client = client ?? NaverDomesticStockClient(dio),
       _favoriteIdsLocalStore = favoriteIdsLocalStore,
       _logoUrlResolver = logoUrlResolver ?? const NaverStockLogoUrlResolver();

  static const _historyRowsPerPage = 10;

  final NaverStockDataClient _client;
  final FavoriteIdsLocalStore _favoriteIdsLocalStore;
  final NaverStockLogoUrlResolver _logoUrlResolver;
  final Duration realtimeCacheTtl;
  final int dailyHistoryFetchBatchSize;

  final Map<String, NaverChartMetadataDto> _metadataCache = {};
  final Map<String, NaverDailyHistoryPageDto> _dailyHistoryPageCache = {};
  final Map<String, _RealtimeQuoteCacheEntry> _realtimeQuoteCache = {};

  Set<String>? _favoriteIdsCache;
  List<DateTime>? _availableDatesCache;

  @override
  Future<WatchlistSnapshot> fetchWatchlist({DateTime? asOf}) async {
    // TODO(assignment): Build the watchlist snapshot from Naver data.
    //
    // Suggested flow:
    // 1. Load canonical favorite ids via loadFavoriteIds(). //표준화된 즐겨찾기 ID 목록
    // 2. Convert each id into a six-digit domestic symbol.
    // 3. Load metadata and realtime quotes for those symbols.
    // 4. When asOf is null, use the latest historical row for each symbol.
    // 5. When asOf is provided, resolve the selected trading day and build a
    //    one-day snapshot for that date.
    // 6. Map every symbol into WatchlistItem.
    //
    // Related tests:
    // - test/features/watchlist/data/naver_watchlist_repository_test.dart

    var favoriteIds = await loadFavoriteIds();
    print(favoriteIds);

    //whereType<String>() //null 자동 제거 + String으로 변환
    var symbols = favoriteIds.map((id)=>domesticSymbolFromFavoriteId(id)).whereType<String>();

    //List<String>으로 변환 필요
    var naverChartMetadataDtoMap = await _loadMetadataBatch(symbols.toList());
    //iterable<String>으로 변환 필요
    var naverRealtimeQuoteDtoMap = await _loadRealtimeQuotes(symbols);

    var availableDates = await fetchAvailableDates();

    //하지만 이렇게 하면 어느 symbol에 대한 건지 몰라서 watchListItem을 만들때 _HistoricalEntry를 만든다
    //날짜에 존재여부 따라 _HistoricalEntry를 구한다 => NaverHistoricalPriceDto + 가장 마지막으로 책정된 가격 반환
    // _loadHistoricalEntryForDate, _loadLatestHistoricalEntry
    // var futureHistoricalEntries = <Future<_HistoricalEntry>>[];
    // var historicalEntries = <_HistoricalEntry>[];
    //
    // if (asOf == null){
    //   futureHistoricalEntries = symbols.map((symbol) =>  _loadLatestHistoricalEntry(symbol)).whereType<Future<_HistoricalEntry>>().toList();
    //   historicalEntries = await Future.wait(futureHistoricalEntries);
    // } else {
    //   //whereType => null 자동제거 및 형변환
    //   futureHistoricalEntries = symbols.map((symbol) =>  _loadHistoricalEntryForDate(symbol:symbol, availableDates:availableDates, asOf:asOf)).whereType<Future<_HistoricalEntry>>().toList();
    //   historicalEntries = await Future.wait(futureHistoricalEntries);
    // }

    //wathchlistitem을 하나씩 만든다
    List<WatchlistItem> items= [];

    items = symbols.map((symbol) {
      //symbol에 맞는 _HistoricalEntry 만들기
      var historicalEntry;
      if (asOf == null){
        historicalEntry = _loadLatestHistoricalEntry(symbol);
      } else {
        historicalEntry = _loadHistoricalEntryForDate(symbol:symbol, availableDates:availableDates, asOf:asOf);
      }

      //! null 아님을 보장
       return _buildWatchlistItem(symbol:symbol,metadata:naverChartMetadataDtoMap[symbol]!, historicalEntry: historicalEntry, realtimeQuote:naverRealtimeQuoteDtoMap[symbol], latestDate:_resolveAsOf(availableDates, asOf));
    }).toList();

    WatchlistSnapshot watchlistSnapshot = WatchlistSnapshot(asOf:asOf ?? _resolveAsOf(availableDates, asOf), items:items, availableDates:availableDates);
    return watchlistSnapshot;

    // throw UnimplementedError(
    //   'TODO(assignment): implement NaverWatchlistRepository.fetchWatchlist',
    // );
  }

  @override
  Future<List<DateTime>> fetchAvailableDates() async {
    // TODO(assignment): Lazily load and cache the trading-day list.
    //
    // Suggested flow:
    // - Reuse _availableDatesCache when present.
    // - Pick the first valid favorite symbol as the reference symbol. //기준 종목으로 사용하기 위해
    // - Request page 1 first to discover lastPage.
    // - Fetch the remaining pages in small batches. //여러 페이지를 조금씩 나눠서 병렬로 요청
    // - Flatten all localDate values into one descending list.

    final cached = _availableDatesCache;
    if (cached != null) {
      return cached;
    }

    var favoriteIds = await loadFavoriteIds();
    print(favoriteIds);

    //whereType<String>() //null 자동 제거 + String으로 변환
    var symbols = favoriteIds.map((id)=>domesticSymbolFromFavoriteId(id)).whereType<String>();
    var refSymbol = symbols.first;

    var naverDailyHistoryPageDto = await _loadDailyHistoryPage(refSymbol, 1);
    var lastPage = naverDailyHistoryPageDto.lastPage;

    //map은 Iterable 반환
    // ... spread 연산자
    var availableDates = <DateTime>[];
    //addAll => Iterable을 순회해서 요소를 하나씩 넣는다
    availableDates.addAll(naverDailyHistoryPageDto.priceInfos.map((info) => info.localDate));

    var requestResults;
    //batchs를 쓰라 했으므로 혹시나 batchsize가 있는지 찾아보았다
    for(int i = 2; i <= lastPage; i = dailyHistoryFetchBatchSize){
      final batchFutures = <Future>[];
      for (int j = i; j < i + dailyHistoryFetchBatchSize && j <= lastPage; j++) {
        batchFutures.add(_loadDailyHistoryPage(refSymbol, j));
      }

      //Future.wait => 여러 개의 Future(비동기 작업)를 동시에 실행하고, 전부 끝날 때까지 기다리는 함수
      requestResults = await Future.wait(batchFutures);
      availableDates.addAll(requestResults.priceInfos.map((info) => info.localDate));
    }

    return availableDates;
    // throw UnimplementedError(
    //   'TODO(assignment): implement NaverWatchlistRepository.fetchAvailableDates',
    // );
  }

  @override
  Future<WatchlistDetail> fetchWatchlistDetail({
    required String symbol,
    required MarketType market,
    DateTime? asOf,
  }) async {
    // TODO(assignment): Build the detail panel from a 30-trading-day window.
    //
    // Requirements:
    // - Only domestic stocks are supported.
    // - When asOf is null, show the latest available detail.
    // - When asOf is set, resolve the requested trading day and collect the
    //   previous 30 trading days (including the selected day).
    // - Use realtime data only for the latest trading day.
    // - Compute changeAmount, changeRate, volumeRatio, and candles.

    //changeAmount, changeRate => NaverRealtimeQuoteDto 필요
    //volumeRatio, and candles => NaverHistoricalPriceDto 필요

    if (!_isCanonicalFavoriteId(symbol)){
      throw FormatException('domestic 국내 주식만 볼 수 있습니다.');
    }

    var availableDates = await fetchAvailableDates();

    //NaverRealtimeQuoteDto를 구하기 위해
    var naverRealtimeQuoteDtoMap = await _loadRealtimeQuotes([symbol]);
    var naverRealtimeQuoteDto = naverRealtimeQuoteDtoMap[symbol]!;

    //NaverHistoricalPriceDto를 구하기 위해 _HistoricalEntry
    //asOf가 없으면 최근것만
    //asOf가 있으면 이전 30일 기록
    var historicalEntry;
    var historicalEntryList = <_HistoricalEntry>[];
    final historicalFutures = <Future<_HistoricalEntry?>>[];
    var candlePoints = <CandlePoint>[];
    if (asOf == null){
      historicalEntry = await _loadHistoricalEntryForDate(symbol:symbol, availableDates:availableDates, asOf:_resolveAsOf(availableDates, asOf));
    } else {
      var previous30Dates = getWindowDates(windowDatesDescending:availableDates, asOf:asOf);
      previous30Dates.map((date){
        historicalFutures.add(_loadHistoricalEntryForDate(symbol:symbol, availableDates:availableDates, asOf:date));
      });

      var result = await Future.wait(historicalFutures);
      //whereType => Iterable
      historicalEntryList = result.whereType<_HistoricalEntry>().toList();

      // List<CandlePoint> _candles({
      //   required List<DateTime> windowDatesDescending,
      //   required Map<String, NaverHistoricalPriceDto> rowsByDate,
      // })
    }



    throw UnimplementedError(
      'TODO(assignment): implement NaverWatchlistRepository.fetchWatchlistDetail',
    );
  }

  @override
  Future<List<StockSearchItem>> searchStocks({required String query}) async {
    // TODO(assignment): Search domestic stocks and convert them into
    // StockSearchItem values.
    //
    // Requirements:
    // - Trim the query and return [] for empty input.
    // - Use _client.searchStocks(trimmedQuery).
    // - Keep only domestic six-digit stock results.
    // - Deduplicate duplicate symbols.
    // - Convert every symbol into canonical id: domestic:{symbol}
    // - Set isFavorite by comparing against loadFavoriteIds().
    // - Fill logoUrl via _logoUrlResolver.
    throw UnimplementedError(
      'TODO(assignment): implement NaverWatchlistRepository.searchStocks',
    );
  }

  @override
  Future<Set<String>> loadFavoriteIds() async {
    if (_favoriteIdsCache != null) {
      return Set<String>.unmodifiable(_favoriteIdsCache!);
    }

    final rawIds = await _favoriteIdsLocalStore.loadRawIds();
    final canonicalIds = rawIds.where(_isCanonicalFavoriteId).toSet();
    final hasLegacyOrInvalidIds =
        rawIds.isNotEmpty && canonicalIds.length != rawIds.length;

    final resolvedIds = !_favoriteIdsLocalStore.hasStoredIds
        ? <String>{...defaultNaverDomesticFavoriteIds}
        : hasLegacyOrInvalidIds
        ? <String>{...defaultNaverDomesticFavoriteIds}
        : canonicalIds;

    _favoriteIdsCache = resolvedIds;

    if (!setEquals(rawIds, resolvedIds)) {
      await _favoriteIdsLocalStore.saveRawIds(resolvedIds);
    }

    return Set<String>.unmodifiable(resolvedIds);
  }

  @override
  Future<void> addFavorite({required String itemId}) async {
    final canonicalId = _requireCanonicalFavoriteId(itemId);
    final favoriteIds = {...await loadFavoriteIds(), canonicalId};
    _favoriteIdsCache = favoriteIds;
    await _favoriteIdsLocalStore.saveRawIds(favoriteIds);
  }

  @override
  Future<void> removeFavorite({required String itemId}) async {
    final canonicalId = _requireCanonicalFavoriteId(itemId);
    final favoriteIds = {...await loadFavoriteIds()}..remove(canonicalId);
    _favoriteIdsCache = favoriteIds;
    await _favoriteIdsLocalStore.saveRawIds(favoriteIds);
  }

  //fetchChartMetadata 불러오기
  Future<Map<String, NaverChartMetadataDto>> _loadMetadataBatch(
    List<String> symbols,
  ) async {
    final results = <String, NaverChartMetadataDto>{};
    for (final symbol in symbols) {
      try {
        results[symbol] = await _loadMetadata(symbol);
      } catch (error, stackTrace) {
        debugPrint('Skipping Naver metadata for $symbol: $error\n$stackTrace');
      }
    }
    return results;
  }

  //fetchChartMetadata 불러오기 => symbol한개일때만 유용
  Future<NaverChartMetadataDto> _loadMetadata(String symbol) async {
    final cached = _metadataCache[symbol];
    if (cached != null) {
      return cached;
    }

    final metadata = await _client.fetchChartMetadata(symbol);
    _metadataCache[symbol] = metadata;
    return metadata;
  }

  //fetchDailyHistoryPage 일일 시세 불러오기
  Future<NaverDailyHistoryPageDto> _loadDailyHistoryPage(
    String symbol,
    int page,
  ) async {
    final cacheKey = _dailyHistoryPageCacheKey(symbol, page);
    final cached = _dailyHistoryPageCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    final historyPage = await _client.fetchDailyHistoryPage(
      symbol: symbol,
      page: page,
    );
    _dailyHistoryPageCache[cacheKey] = historyPage;
    return historyPage;
  }

  //fetchRealtimeQuotes 여러 symbol을 가지고 불러오기
  Future<Map<String, NaverRealtimeQuoteDto>> _loadRealtimeQuotes(
    Iterable<String> symbols,
  ) async {
    final requestedSymbols = symbols.toSet();
    final now = DateTime.now();
    final missingSymbols = <String>[];
    final quotes = <String, NaverRealtimeQuoteDto>{};

    for (final symbol in requestedSymbols) {
      final cached = _realtimeQuoteCache[symbol];
      final isFresh =
          cached != null &&
          now.difference(cached.fetchedAt) <= realtimeCacheTtl;
      if (isFresh) {
        quotes[symbol] = cached.quote;
      } else {
        missingSymbols.add(symbol);
      }
    }

    if (missingSymbols.isNotEmpty) {
      try {
        final fetchedQuotes = await _client.fetchRealtimeQuotes(missingSymbols);
        final fetchedAt = DateTime.now();
        for (final entry in fetchedQuotes.entries) {
          _realtimeQuoteCache[entry.key] = _RealtimeQuoteCacheEntry(
            quote: entry.value,
            fetchedAt: fetchedAt,
          );
          quotes[entry.key] = entry.value;
        }
      } catch (error, stackTrace) {
        debugPrint(
          'Falling back to historical-only Naver data for realtime batch: '
          '$error\n$stackTrace',
        );
      }
    }

    return quotes;
  }

  //입력한 date에 일치하는것 찾기
  Future<_HistoricalEntry?> _loadHistoricalEntryForDate({
    required String symbol,
    required List<DateTime> availableDates,
    required DateTime asOf,
  }) async {
    final selectedIndex = _indexOfDate(availableDates, asOf);
    if (selectedIndex == null) {
      return null;
    }

    final selectedPageNumber = _pageNumberForIndex(selectedIndex);
    //fetchDailyHistoryPage => NaverDailyHistoryPageDto 불러오기
    final selectedPage = await _loadDailyHistoryPage(
      symbol,
      selectedPageNumber,
    );
    //날짜와 일치하는 NaverHistoricalPriceDto
    final selectedRow = _rowForDate(selectedPage.priceInfos, asOf);
    if (selectedRow == null) {
      return null;
    }

    // map 생성 문법
    //{
    //   for (요소 in 리스트)
    //     key: value
    // }

    //가장 마지막으로 책정된 가격 반환
    final previousClose = await _resolvePreviousClose(
      symbol: symbol,
      availableDates: availableDates,
      selectedIndex: selectedIndex,
      fallbackOpenPrice: selectedRow.openPrice, //NaverHistoricalPriceDto의 openPrice
      rowsByDate: {
        for (final row in selectedPage.priceInfos) _dateKey(row.localDate): row,
      },
    );

    //NaverHistoricalPriceDto + 가장 마지막으로 책정된 가격 반환
    return _HistoricalEntry(row: selectedRow, previousClose: previousClose);
  }

  //입력한 date가 없을때 
  Future<_HistoricalEntry?> _loadLatestHistoricalEntry(String symbol) async {
    //fetchDailyHistoryPage => NaverDailyHistoryPageDto 불러오기
    final firstPage = await _loadDailyHistoryPage(symbol, 1);
    if (firstPage.priceInfos.isEmpty) {
      return null;
    }

    //NaverHistoricalPriceDto
    //충분한 개수가 없으면 다음 페이지를 조회하여 가장 최근 이전 거래일 종가를 찾는다
    //.first => List에서 첫번째 요소
    final selectedRow = firstPage.priceInfos.first;
    double previousClose = selectedRow.openPrice;
    if (firstPage.priceInfos.length > 1) {
      previousClose = firstPage.priceInfos[1].closePrice;
    } else {
      final nextPageRows = (await _loadDailyHistoryPage(symbol, 2)).priceInfos;
      if (nextPageRows.isNotEmpty) {
        previousClose = nextPageRows.first.closePrice;
      }
    }

    //NaverHistoricalPriceDto + 가장 마지막으로 책정된 가격 반환
    return _HistoricalEntry(row: selectedRow, previousClose: previousClose);
  }

  //가장 마지막으로 책정된 가격 반환
  Future<double> _resolvePreviousClose({
    required String symbol,
    required List<DateTime> availableDates,
    required int selectedIndex,
    required double fallbackOpenPrice,
    required Map<String, NaverHistoricalPriceDto> rowsByDate,
  }) async {
    if (selectedIndex >= availableDates.length - 1) {
      return fallbackOpenPrice;
    }

    final previousDate = availableDates[selectedIndex + 1];
    final previousRowFromCache = rowsByDate[_dateKey(previousDate)];
    if (previousRowFromCache != null) {
      return previousRowFromCache.closePrice;
    }

    //fetchDailyHistoryPage 일일 시세 불러오기
    //즉 이전날짜가 없으면 페이지를 증가시켜 이전 날짜를 불러오는 것 같다
    final page = await _loadDailyHistoryPage(
      symbol,
      _pageNumberForIndex(selectedIndex + 1),
    );
    final previousRow = _rowForDate(page.priceInfos, previousDate);
    return previousRow?.closePrice ?? fallbackOpenPrice;
  }

  WatchlistItem _buildWatchlistItem({
    required String symbol,
    required NaverChartMetadataDto metadata,
    required _HistoricalEntry historicalEntry, //NaverHistoricalPriceDto + 가장 마지막으로 책정된 가격 반환
    required NaverRealtimeQuoteDto? realtimeQuote,
    required DateTime? latestDate,
  }) {
    final isLatest =
        latestDate != null &&
        normalizeAsOfDate(historicalEntry.row.localDate) == latestDate;
    final currentPrice = isLatest && realtimeQuote != null
        ? realtimeQuote.currentPrice
        : historicalEntry.row.closePrice;
    final changeRate = isLatest && realtimeQuote != null
        ? realtimeQuote.changeRate
        : _percentChange(
            currentPrice - historicalEntry.previousClose,
            historicalEntry.previousClose,
          );
    final tradeVolume = isLatest && realtimeQuote != null
        ? realtimeQuote.accumulatedTradingVolume
        : historicalEntry.row.accumulatedTradingVolume;
    final marketCap = realtimeQuote == null
        ? 0
        : (realtimeQuote.countOfListedStock * realtimeQuote.currentPrice)
              .round();

    return WatchlistItem(
      id: canonicalDomesticFavoriteId(symbol),
      market: MarketType.domestic,
      symbol: symbol,
      name: metadata.stockName,
      currency: 'KRW',
      currentPrice: currentPrice,
      changeRate: changeRate,
      tradeVolume: tradeVolume,
      marketCap: marketCap,
      logoUrl: _logoUrlResolver.resolveDomesticStockLogoUrl(symbol),
    );
  }

  //최근날짜 뽑기
  DateTime _resolveAsOf(
    List<DateTime> availableDates,
    DateTime? requestedAsOf,
  ) {
    if (availableDates.isEmpty) {
      return normalizeAsOfDate(requestedAsOf ?? DateTime.now());
    }

    if (requestedAsOf == null) {
      return availableDates.first;
    }

    final normalizedAsOf = normalizeAsOfDate(requestedAsOf);
    for (final date in availableDates) {
      if (date == normalizedAsOf) {
        return date;
      }
    }

    return availableDates.first;
  }

  ////yyyy-mm-dd 00:00:00.000 => 시간을 00으로 초기화 한후,
  //asOf 입력한 날짜와 동일한 availableDates에 해당하는 인덱스를 리턴
  int? _indexOfDate(List<DateTime> availableDates, DateTime asOf) {
    final normalizedAsOf = normalizeAsOfDate(asOf);
    for (var index = 0; index < availableDates.length; index += 1) {
      if (availableDates[index] == normalizedAsOf) {
        return index;
      }
    }
    return null;
  }

  // ~/ 는정수 나눗셈 => 이 인덱스 데이터가 위치한 페이지 번호가 뭔지
  int _pageNumberForIndex(int index) {
    return (index ~/ _historyRowsPerPage) + 1;
  }

  //날짜에 일치하는 일별 시세 한줄을 찾기
  NaverHistoricalPriceDto? _rowForDate(
    Iterable<NaverHistoricalPriceDto> rows,
    DateTime date,
  ) {
    final dateKey = _dateKey(date);
    for (final row in rows) {
      if (_dateKey(row.localDate) == dateKey) {
        return row;
      }
    }
    return null;
  }

  //WatchlistDetail의 volumeRatio 계산
  double _volumeRatio({
    required List<DateTime> windowDatesDescending,
    required Map<String, NaverHistoricalPriceDto> rowsByDate,
  }) {
    if (windowDatesDescending.isEmpty) {
      return 0;
    }

    //00.00.00으로 초기화 한후 날짜를 가지고 일별시세 NaverHistoricalPriceDto 뽑기
    final selectedRow = rowsByDate[_dateKey(windowDatesDescending.first)];
    if (selectedRow == null) {
      return 0;
    }

    //거래량을 저장
    final previousVolumes = <int>[];
    for (
      var index = 1;
      index < windowDatesDescending.length && previousVolumes.length < 5;
      index += 1
    ) {
      final row = rowsByDate[_dateKey(windowDatesDescending[index])];
      if (row != null) {
        previousVolumes.add(row.accumulatedTradingVolume);
      }
    }

    if (previousVolumes.isEmpty) {
      return 0;
    }

    //reduce => 배열을 하나의 값으로 누적하는 함수
    final averageVolume =
        previousVolumes.reduce((left, right) => left + right) /
        previousVolumes.length;
    if (averageVolume == 0) {
      return 0;
    }

    //최근 거래량 / 과거 평균 거래량
    return double.parse(
      (selectedRow.accumulatedTradingVolume / averageVolume).toStringAsFixed(2),
    );
  }

  //WatchlistDetail의 candles
  List<CandlePoint> _candles({
    required List<DateTime> windowDatesDescending,
    required Map<String, NaverHistoricalPriceDto> rowsByDate,
  }) {
    //reversed => 역순 => 오래된순부터 최신순
    return windowDatesDescending.reversed
        .map((date) => rowsByDate[_dateKey(date)])
        .whereType<NaverHistoricalPriceDto>()
        .map(
          (item) => CandlePoint(
            time: item.localDate,
            open: item.openPrice,
            high: item.highPrice,
            low: item.lowPrice,
            close: item.closePrice,
            direction: directionFromDelta(item.closePrice - item.openPrice),
          ),
        )
        .toList(growable: false); 
    //toList(growable: false) => 크기 변경이 불가능한 리스트
  }

  //선택한 날짜를 기준으로 선택한 날짜포함 30일전까지 날짜뽑기
  List<DateTime> getWindowDates({
    required List<DateTime> windowDatesDescending,
    required DateTime asOf,
    int daySize = 30,
  }) {
    final index = windowDatesDescending.indexWhere(
          (d) =>
      d.year == asOf.year &&
          d.month == asOf.month &&
          d.day == asOf.day,
    );

    if (index == -1) return [];

    //skip(index) => index 만큼 리스트 맨앞에서 생략
    return windowDatesDescending
        .skip(index)
        .take(daySize)
        .toList();
  }

  //favoriteId가 형식을 지켰는지 판단
  bool _isCanonicalFavoriteId(String itemId) {
    return domesticSymbolFromFavoriteId(itemId) != null;
  }

  String _requireCanonicalFavoriteId(String itemId) {
    //domestic : 을 떼어내는 역할
    final symbol = domesticSymbolFromFavoriteId(itemId);
    if (symbol == null) {
      throw ArgumentError.value(
        itemId,
        'itemId',
        'Naver repository only accepts canonical domestic favorite ids',
      );
    }
    //domestic: 붙인다
    return canonicalDomesticFavoriteId(symbol);
  }

  String _dailyHistoryPageCacheKey(String symbol, int page) => '$symbol::$page';

  //00.00.00으로 초기화
  String _dateKey(DateTime value) => formatApiDate(value);

  //증감률을 구할때 사용
  double _percentChange(double delta, double base) {
    if (base == 0) {
      return 0;
    }
    return double.parse(((delta / base) * 100).toStringAsFixed(2));
  }
}

//실시간 시세인데 언제 fetch함수를 사용했는지인것 같다
class _RealtimeQuoteCacheEntry {
  const _RealtimeQuoteCacheEntry({
    required this.quote,
    required this.fetchedAt,
  });

  final NaverRealtimeQuoteDto quote;
  final DateTime fetchedAt;
}

//일별시세인데 previousClose가 뭘까?
//previousClose => 가장 마지막으로 책정된 가격
class _HistoricalEntry {
  const _HistoricalEntry({required this.row, required this.previousClose});

  final NaverHistoricalPriceDto row;
  final double previousClose;
}
