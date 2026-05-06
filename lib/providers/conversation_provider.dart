import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/conversation_model.dart';
import '../services/conversation_service.dart';

class ConversationState {
  final List<ConversationModel> conversations;
  final bool isLoading;
  final String? error;

  const ConversationState({
    this.conversations = const [],
    this.isLoading     = false,
    this.error,
  });

  ConversationState copyWith({
    List<ConversationModel>? conversations,
    bool? isLoading,
    String? error,
  }) => ConversationState(
        conversations: conversations ?? this.conversations,
        isLoading:     isLoading     ?? this.isLoading,
        error:         error         ?? this.error,
      );
}

class ConversationNotifier extends StateNotifier<ConversationState> {
  final _service = ConversationService();

  ConversationNotifier() : super(const ConversationState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      final list = await _service.getConversations();
      state = state.copyWith(conversations: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> delete(int id) async {
    await _service.deleteConversation(id);
    state = state.copyWith(
      conversations: state.conversations.where((c) => c.id != id).toList(),
    );
  }
}

final conversationProvider =
    StateNotifierProvider<ConversationNotifier, ConversationState>(
  (ref) => ConversationNotifier(),
);