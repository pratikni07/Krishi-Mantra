// lib/data/market_data.dart
import 'dart:math';

class MarketData {
  static final List<String> markets = [
    'Azadpur Mandi, Delhi',
    'Vashi Market, Mumbai',
    'KR Market, Bangalore',
    'Koyambedu Market, Chennai',
    'Danyapur Market, Pune'
  ];

  static final List<Map<String, dynamic>> vegetables = [
    {
      'name': 'Tomatoes',
      'basePrice': 40.0,
      'priceHistory': [35.0, 38.0, 40.0, 42.0, 40.0, 39.0, 40.0],
      'unit': 'kg',
      'icon': '🍅'
    },
    {
      'name': 'Potatoes',
      'basePrice': 30.0,
      'priceHistory': [28.0, 29.0, 30.0, 30.0, 31.0, 30.0, 30.0],
      'unit': 'kg',
      'icon': '🥔'
    },
    {
      'name': 'Onions',
      'basePrice': 35.0,
      'priceHistory': [32.0, 34.0, 35.0, 38.0, 36.0, 35.0, 35.0],
      'unit': 'kg',
      'icon': '🧅'
    },
    {
      'name': 'Cauliflower',
      'basePrice': 45.0,
      'priceHistory': [42.0, 43.0, 45.0, 45.0, 46.0, 45.0, 45.0],
      'unit': 'piece',
      'icon': '🥦'
    },
    {
      'name': 'Green Peas',
      'basePrice': 60.0,
      'priceHistory': [58.0, 59.0, 60.0, 62.0, 61.0, 60.0, 60.0],
      'unit': 'kg',
      'icon': '🫛'
    },
    {
      'name': 'Carrots',
      'basePrice': 45.0,
      'priceHistory': [42.0, 44.0, 45.0, 46.0, 45.0, 45.0, 45.0],
      'unit': 'kg',
      'icon': '🥕'
    },
    {
      'name': 'Cabbage',
      'basePrice': 25.0,
      'priceHistory': [23.0, 24.0, 25.0, 26.0, 25.0, 25.0, 25.0],
      'unit': 'piece',
      'icon': '🥬'
    }
  ];
}

class MockDataService {
  final Random _random = Random();

  List<VegetablePrice> getMarketPrices() {
    return MarketData.vegetables.map((veg) {
      double variation = ((_random.nextDouble() * 20) - 10) / 100;
      double currentPrice = veg['basePrice'] * (1 + variation);

      return VegetablePrice(
        veg['name'],
        currentPrice,
        veg['unit'],
        List<double>.from(veg['priceHistory']),
        _calculateTrend(veg['priceHistory']),
        veg['icon'],
      );
    }).toList();
  }

  String getRandomMarket() {
    return MarketData.markets[_random.nextInt(MarketData.markets.length)];
  }

  PriceTrend _calculateTrend(List<dynamic> history) {
    if (history.length < 2) return PriceTrend.stable;
    double last = history.last.toDouble();
    double previous = history[history.length - 2].toDouble();
    if (last > previous) return PriceTrend.up;
    if (last < previous) return PriceTrend.down;
    return PriceTrend.stable;
  }
}

class VegetablePrice {
  final String vegetableName;
  final double price;
  final String unit;
  final List<double> priceHistory;
  final PriceTrend trend;
  final String icon;

  VegetablePrice(this.vegetableName, this.price, this.unit, this.priceHistory,
      this.trend, this.icon);
}

enum PriceTrend { up, down, stable }
