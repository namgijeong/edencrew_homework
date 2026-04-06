import 'package:intl/intl.dart';

import '../models/watchlist_models.dart';

List<WatchlistItem> sortWatchlistItems(
  List<WatchlistItem> items,
  WatchlistSortMode sortMode,
) {
  final sortedItems = List<WatchlistItem>.of(items);

  //b.compareTo(a) 내림차순
  //a.compareTo(b) 오름차순
  //이름은 오름차순
  //가격등은 내림차순
  sortedItems.sort((left, right) {
    switch (sortMode) {
      //현재가순
      case WatchlistSortMode.price: 
        final priceCompare = right.currentPrice.compareTo(left.currentPrice);
        if (priceCompare != 0) {
          return priceCompare;
        }
        return left.name.compareTo(right.name);
        //등락률순
      case WatchlistSortMode.changeRate:
        final changeCompare = right.changeRate.compareTo(left.changeRate);
        if (changeCompare != 0) {
          return changeCompare;
        }
        return left.name.compareTo(right.name);
        //가나다순
      case WatchlistSortMode.alphabetical:
        final nameCompare = left.name.compareTo(right.name);
        if (nameCompare != 0) {
          return nameCompare;
        }
        return left.symbol.compareTo(right.symbol);
        //시총순
      case WatchlistSortMode.marketCap:
        final marketCapCompare = right.marketCap.compareTo(left.marketCap);
        if (marketCapCompare != 0) {
          return marketCapCompare;
        }
        return left.name.compareTo(right.name);
    }
  });

  return sortedItems;
}

//yyyy-mm-dd 00:00:00.000 => 시간을 00으로 초기화
DateTime normalizeAsOfDate(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

//yyyy-mm-dd 00:00:00.000 => 시간을 00으로 초기화
String formatApiDate(DateTime value) {
  return DateFormat('yyyyMMdd').format(normalizeAsOfDate(value));
}
