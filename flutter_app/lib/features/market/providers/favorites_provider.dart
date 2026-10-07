import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 自选标的集合(SharedPreferences 持久化,key: fav_symbols)
class FavoritesProvider extends ChangeNotifier {
  static const _key = 'fav_symbols';
  final Set<String> _favs = {};
  bool _loaded = false;

  bool get loaded => _loaded;

  FavoritesProvider() {
    _load();
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    _favs
      ..clear()
      ..addAll(sp.getStringList(_key) ?? const []);
    _loaded = true;
    notifyListeners();
  }

  bool isFav(String symbol) => _favs.contains(symbol);

  List<String> get all => _favs.toList();

  Future<void> toggle(String symbol) async {
    if (!_favs.remove(symbol)) _favs.add(symbol);
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(_key, _favs.toList());
  }
}
