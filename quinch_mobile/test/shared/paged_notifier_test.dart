import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quinch_mobile/core/network/api_error.dart';
import 'package:quinch_mobile/data/models/paginated.dart';
import 'package:quinch_mobile/shared/paging/paged_notifier.dart';

import '../support/fakes.dart';

class _TestNotifier extends PagedNotifier<int> {
  _TestNotifier(this.fetcher);

  final Future<Paginated<int>> Function(int page) fetcher;

  @override
  Future<Paginated<int>> fetchPage(int page) => fetcher(page);
}

void main() {
  late List<int> requested;
  late Future<Paginated<int>> Function(int page) fetcher;
  late ProviderContainer container;
  late NotifierProvider<_TestNotifier, PagedState<int>> provider;

  setUp(() {
    requested = <int>[];
    fetcher = (page) async =>
        pageOf<int>(<int>[page * 10, page * 10 + 1], page: page, last: 3);
    provider = NotifierProvider<_TestNotifier, PagedState<int>>(
      () => _TestNotifier((page) {
        requested.add(page);
        return fetcher(page);
      }),
    );
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  PagedState<int> state() => container.read(provider);
  _TestNotifier notifier() => container.read(provider.notifier);

  test('état initial : rien chargé', () {
    expect(state().status, PagedStatus.idle);
    expect(state().isFirstLoad, isTrue);
  });

  test('refresh : charge la première page', () async {
    await notifier().refresh();
    expect(state().items, <int>[10, 11]);
    expect(state().status, PagedStatus.loaded);
    expect(state().hasMore, isTrue);
    expect(requested, <int>[1]);
  });

  test(
    'loadMore : ajoute la page suivante puis s\'arrête à la dernière',
    () async {
      await notifier().refresh();
      await notifier().loadMore();
      await notifier().loadMore();
      expect(state().items, <int>[10, 11, 20, 21, 30, 31]);
      expect(state().hasMore, isFalse);
      await notifier().loadMore();
      expect(requested, <int>[1, 2, 3]);
    },
  );

  test('loadMore : ignoré tant qu\'un chargement est en cours', () async {
    await notifier().refresh();
    final pending = Completer<Paginated<int>>();
    fetcher = (page) => pending.future;
    final first = notifier().loadMore();
    final second = notifier().loadMore();
    pending.complete(pageOf<int>(<int>[20], page: 2, last: 3));
    await first;
    await second;
    expect(requested, <int>[1, 2]);
    expect(state().items, <int>[10, 11, 20]);
  });

  test('échec du premier chargement, puis réessai', () async {
    fetcher = (page) async => throw ApiError.network();
    await notifier().refresh();
    expect(state().isFirstLoadFailure, isTrue);
    expect(state().error?.kind, ApiErrorKind.network);

    fetcher = (page) async => pageOf<int>(<int>[1], page: 1, last: 1);
    await notifier().refresh();
    expect(state().items, <int>[1]);
    expect(state().error, isNull);
  });

  test(
    'échec de la suite : la liste est conservée, réessai possible',
    () async {
      await notifier().refresh();
      fetcher = (page) async => throw ApiError.timeout();
      await notifier().loadMore();
      expect(state().status, PagedStatus.failed);
      expect(state().items, <int>[10, 11]);

      fetcher = (page) async => pageOf<int>(<int>[20], page: page, last: 3);
      await notifier().loadMore();
      expect(state().items, <int>[10, 11, 20]);
      expect(state().status, PagedStatus.loaded);
    },
  );

  test('résultat vide', () async {
    fetcher = (page) async => pageOf<int>(<int>[], page: 1, last: 1);
    await notifier().refresh();
    expect(state().isEmptyResult, isTrue);
    expect(state().hasMore, isFalse);
  });

  test(
    'réponse périmée ignorée quand un nouveau chargement a démarré',
    () async {
      final slow = Completer<Paginated<int>>();
      fetcher = (page) => slow.future;
      final stale = notifier().refresh();

      fetcher = (page) async => pageOf<int>(<int>[99], page: 1, last: 1);
      await notifier().refresh();
      expect(state().items, <int>[99]);

      slow.complete(pageOf<int>(<int>[1, 2, 3], page: 1, last: 1));
      await stale;
      expect(state().items, <int>[99]);
    },
  );

  test('removeWhere', () async {
    await notifier().refresh();
    notifier().removeWhere((item) => item == 10);
    expect(state().items, <int>[11]);
  });
}
