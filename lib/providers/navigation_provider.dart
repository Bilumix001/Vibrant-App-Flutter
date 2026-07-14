// lib/providers/navigation_provider.dart
// Controla la pestaña activa del shell principal (Conversaciones / Mapa).
// Se usa tanto por el bottom nav como por el Drawer (para navegar a una
// pestaña específica desde cualquier pantalla post-login).

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 0 = Conversaciones, 1 = Mapa
final mainTabProvider = StateProvider<int>((ref) => 0);