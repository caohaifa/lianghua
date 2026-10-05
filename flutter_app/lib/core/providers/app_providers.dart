import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/market/providers/market_provider.dart';
import '../../features/monitor/providers/monitor_provider.dart';
import '../../features/position/providers/position_provider.dart';

class AppProviders {
  static List<SingleChildWidget> providers(AuthProvider authProvider) =>
      <SingleChildWidget>[
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => MarketProvider()),
        ChangeNotifierProvider(create: (_) => MonitorProvider()),
        ChangeNotifierProvider(create: (_) => PositionProvider()),
      ];
}
