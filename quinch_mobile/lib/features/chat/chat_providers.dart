import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/chat.dart';
import '../../data/models/paginated.dart';
import '../../data/repositories/chat_repository.dart';
import '../../shared/paging/paged_notifier.dart';

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(ref.watch(apiClientProvider)),
);

/// Boîte de réception : conversations de la plus récente à la plus ancienne.
class ConversationsController extends PagedNotifier<Conversation> {
  @override
  Future<Paginated<Conversation>> fetchPage(int page) =>
      ref.read(chatRepositoryProvider).conversations(page: page);
}

final conversationsProvider =
    NotifierProvider<ConversationsController, PagedState<Conversation>>(
      ConversationsController.new,
    );

/// Nombre de messages non lus, pour l'enveloppe de l'Accueil.
///
/// Le serveur ne fournit pas de total : c'est la somme des `unread_count` des
/// 20 conversations les plus récentes (première page). Il n'est donc pas exact
/// au-delà, et n'est pas mis à jour en temps réel : il est relu à l'ouverture de
/// l'Accueil, au retour d'une conversation et au retour au premier plan.
final unreadMessagesProvider = FutureProvider.autoDispose<int>((ref) async {
  final page = await ref.watch(chatRepositoryProvider).conversations();
  return page.items.fold<int>(0, (sum, c) => sum + c.unreadCount);
});
