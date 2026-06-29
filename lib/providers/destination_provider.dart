// ════════════════════════════════════════════════════════
// lib/providers/destination_provider.dart
// ════════════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/destination_model.dart';
import '../services/destination_service.dart';

class DestinationState {
  final List<DestinationModel> destinations;
  final bool    isLoading;
  final String? error;

  const DestinationState({
    this.destinations = const [],
    this.isLoading    = false,
    this.error,
  });

  DestinationState copyWith({
    List<DestinationModel>? destinations,
    bool?    isLoading,
    String?  error,
  }) => DestinationState(
    destinations: destinations ?? this.destinations,
    isLoading:    isLoading    ?? this.isLoading,
    error:        error,
  );
}

class DestinationNotifier extends StateNotifier<DestinationState> {
  final _service = DestinationService();

  DestinationNotifier() : super(const DestinationState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final destinations = await _service.getDestinations();
      state = state.copyWith(destinations: destinations, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final destinationProvider =
    StateNotifierProvider<DestinationNotifier, DestinationState>(
  (ref) => DestinationNotifier(),
);