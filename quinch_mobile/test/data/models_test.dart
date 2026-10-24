import 'package:flutter_test/flutter_test.dart';
import 'package:quinch_mobile/core/config/media_url.dart';
import 'package:quinch_mobile/core/format/fcfa.dart';
import 'package:quinch_mobile/core/json/json_utils.dart';
import 'package:quinch_mobile/data/models/messaging.dart';
import 'package:quinch_mobile/data/models/notifications.dart';
import 'package:quinch_mobile/data/models/paginated.dart';
import 'package:quinch_mobile/data/models/premium.dart';
import 'package:quinch_mobile/data/models/product.dart';
import 'package:quinch_mobile/data/models/user.dart';

// ATTENTION : ces JSON sont écrits à la main d'après la lecture du backend
// (étape 3). Ils vérifient la tolérance des modèles, pas le comportement réel
// d'un serveur en marche.

void main() {
  group('json_utils', () {
    test('conversions tolérantes', () {
      expect(asInt('12'), 12);
      expect(asInt(3.9), 3);
      expect(asInt(null, 5), 5);
      expect(asDouble('1500.5'), 1500.5);
      expect(asBool('true'), isTrue);
      expect(asBool(0), isFalse);
      expect(asBool('peut-être', true), isTrue);
      expect(asStringOrNull(''), isNull);
      expect(asDate('pas une date'), isNull);
    });

    test('listes : les éléments invalides sont ignorés', () {
      expect(
        asMapList(<Object?>[
          <String, dynamic>{'a': 1},
          3,
          null,
          'x',
        ]),
        hasLength(1),
      );
      expect(asMapList('pas une liste'), isEmpty);
      expect(asStringList(<Object?>['a', null, 2]), <String>['a', '2']);
    });
  });

  group('AppUser', () {
    test('forme formatUser (login, me)', () {
      final u = AppUser.fromJson(<String, dynamic>{
        'id': 'u1',
        'email': 'a@b.sn',
        'username': 'awa',
        'full_name': 'Awa Diop',
        'email_verified': true,
        'is_premium': true,
        'premium_expires_at': '2999-01-01T00:00:00.000000Z',
      });
      expect(u.emailVerified, isTrue);
      expect(u.isPremium, isTrue);
      expect(u.phoneNumber, isNull);
    });

    test(
      'forme modèle brut (user/profile) : email_verified_at et premium expiré',
      () {
        final u = AppUser.fromJson(<String, dynamic>{
          'id': 'u1',
          'email': 'a@b.sn',
          'username': 'awa',
          'full_name': 'Awa Diop',
          'email_verified_at': '2026-01-01T00:00:00.000000Z',
          'is_premium': true,
          'premium_expires_at': '2020-01-01T00:00:00.000000Z',
          'phone_number': '+221771234567',
        });
        expect(u.emailVerified, isTrue);
        expect(u.isPremium, isFalse);
        expect(u.phoneNumber, '+221771234567');
      },
    );

    test('email non vérifié', () {
      final u = AppUser.fromJson(<String, dynamic>{
        'id': 'u1',
        'email_verified_at': null,
      });
      expect(u.emailVerified, isFalse);
    });

    test('AuthSession', () {
      final s = AuthSession.fromJson(<String, dynamic>{
        'message': 'ok',
        'token': 'abc',
        'user': <String, dynamic>{'id': 'u1', 'full_name': 'Awa'},
      });
      expect(s.token, 'abc');
      expect(s.user.fullName, 'Awa');
    });
  });

  group('Paginated', () {
    test('paginateur standard', () {
      final p = Paginated<String>.fromJson(<String, dynamic>{
        'data': <Object?>[
          <String, dynamic>{'id': 'a'},
          <String, dynamic>{'id': 'b'},
        ],
        'current_page': 1,
        'last_page': 3,
        'total': 55,
        'per_page': 20,
      }, (j) => asString(j['id']));
      expect(p.items, <String>['a', 'b']);
      expect(p.hasMore, isTrue);
      expect(p.total, 55);
    });

    test('enveloppe meta (notifications)', () {
      final p = Paginated<String>.fromJson(<String, dynamic>{
        'data': <Object?>[],
        'meta': <String, dynamic>{
          'current_page': 2,
          'last_page': 2,
          'total': 40,
        },
      }, (j) => asString(j['id']));
      expect(p.currentPage, 2);
      expect(p.hasMore, isFalse);
    });

    test('corps vide ou inattendu', () {
      final p = Paginated<String>.fromJson(null, (j) => asString(j['id']));
      expect(p.items, isEmpty);
      expect(p.hasMore, isFalse);
    });
  });

  group('ProductCard', () {
    test('forme du feed : catégorie objet, vendeur, vidéo relative', () {
      final p = ProductCard.fromJson(<String, dynamic>{
        'id': 'p1',
        'slug': 'robe-wax',
        'title': 'Robe wax',
        'price': 15000.0,
        'currency': 'XOF',
        'poster': 'https://api.quinch.sn/storage/p.jpg',
        'category': <String, dynamic>{'id': 'c1', 'name': 'Mode', 'icon': 'x'},
        'seller': <String, dynamic>{
          'id': 's1',
          'full_name': 'Fatou',
          'trust_score': 80,
        },
        'video': <String, dynamic>{
          'id': 'v1',
          'url': '/api/v1/videos/v1/stream',
          'thumbnail': '/api/v1/videos/v1/thumbnail',
          'duration': 22,
        },
        'is_liked': true,
        'like_count': 4,
      });
      expect(p.categoryName, 'Mode');
      expect(p.categoryId, 'c1');
      expect(p.seller?.fullName, 'Fatou');
      expect(p.video?.streamPath, '/api/v1/videos/v1/stream');
      expect(p.video?.durationSeconds, 22);
      expect(p.isLiked, isTrue);
      expect(p.coverImage, 'https://api.quinch.sn/storage/p.jpg');
    });

    test('forme Explorer : catégorie en texte', () {
      final p = ProductCard.fromJson(<String, dynamic>{
        'id': 'p2',
        'slug': 's',
        'title': 'T',
        'price': '2500',
        'category': 'Électronique',
        'category_id': 'c9',
        'thumbnail': 'https://api.quinch.sn/t.jpg',
      });
      expect(p.categoryName, 'Électronique');
      expect(p.categoryId, 'c9');
      expect(p.price, 2500);
      expect(p.coverImage, 'https://api.quinch.sn/t.jpg');
    });

    test('forme brute : user, poster_full_url, video_url', () {
      final p = ProductCard.fromJson(<String, dynamic>{
        'id': 'p3',
        'slug': 's',
        'title': 'T',
        'price': 1000,
        'poster_full_url': 'https://api.quinch.sn/p.jpg',
        'user': <String, dynamic>{'id': 'u9', 'full_name': 'Moussa'},
        'video': <String, dynamic>{
          'id': 'v',
          'video_url': '/api/v1/videos/v/stream',
          'duration_seconds': 9,
        },
        'status': 'draft',
      });
      expect(p.posterUrl, 'https://api.quinch.sn/p.jpg');
      expect(p.seller?.id, 'u9');
      expect(p.video?.streamPath, '/api/v1/videos/v/stream');
      expect(p.status, 'draft');
    });

    test('produit sans aucune image : pas de couverture inventée', () {
      final p = ProductCard.fromJson(<String, dynamic>{
        'id': 'p',
        'slug': 's',
        'title': 'T',
        'price': 1,
      });
      expect(p.coverImage, isNull);
    });

    test('ProductDetail applique vendeur et indicateurs de la réponse', () {
      final d = ProductDetail.fromJson(<String, dynamic>{
        'product': <String, dynamic>{
          'id': 'p1',
          'slug': 's',
          'title': 'T',
          'price': 1,
        },
        'seller': <String, dynamic>{
          'id': 's1',
          'full_name': 'Fatou',
          'is_following': true,
        },
        'is_liked': true,
        'is_saved': true,
      });
      expect(d.product.isLiked, isTrue);
      expect(d.product.isSaved, isTrue);
      expect(d.seller.isFollowing, isTrue);
      expect(d.product.seller?.fullName, 'Fatou');
    });

    test('ProductSaveResult : paiement dû', () {
      final r = ProductSaveResult.fromJson(<String, dynamic>{
        'message': 'Paiement requis',
        'product': <String, dynamic>{
          'id': 'p',
          'slug': 's',
          'title': 'T',
          'price': 1,
          'status': 'draft',
        },
        'payment_url': 'https://pay.example/xyz',
        'fee': 150,
      });
      expect(r.paymentUrl, 'https://pay.example/xyz');
      expect(r.fee, 150);
    });
  });

  group('Messagerie', () {
    test('Message conserve created_at tel quel', () {
      final m = Message.fromJson(<String, dynamic>{
        'id': 'm1',
        'conversation_id': 'c1',
        'sender_id': 'u1',
        'body': 'Bonjour',
        'created_at': '2026-10-19T12:00:00.123456Z',
      });
      expect(m.createdAtRaw, '2026-10-19T12:00:00.123456Z');
      expect(m.type, 'text');
      expect(m.createdAt, isNotNull);
    });

    test('Conversation de liste', () {
      final c = Conversation.fromJson(<String, dynamic>{
        'id': 'c1',
        'buyer_id': 'u1',
        'seller_id': 'u2',
        'unread_count': 3,
        'other_user': <String, dynamic>{
          'id': 'u2',
          'full_name': 'Fatou',
          'is_friend': false,
        },
        'last_message': <String, dynamic>{
          'id': 'm',
          'body': 'Salut',
          'created_at': '2026-10-19T10:00:00Z',
        },
        'product': <String, dynamic>{
          'id': 'p',
          'title': 'T',
          'slug': 's',
          'price': 100,
        },
      });
      expect(c.unreadCount, 3);
      expect(c.otherUser?.fullName, 'Fatou');
      expect(c.lastMessage?.body, 'Salut');
      expect(c.messages, isEmpty);
    });

    test('NewMessages', () {
      final n = NewMessages.fromJson(<String, dynamic>{
        'messages': <Object?>[
          <String, dynamic>{
            'id': 'm1',
            'body': 'a',
            'created_at': '2026-10-19T10:00:00Z',
          },
        ],
        'other_user': <String, dynamic>{'id': 'u2', 'full_name': 'Fatou'},
      });
      expect(n.messages, hasLength(1));
      expect(n.otherUser?.id, 'u2');
    });
  });

  group('Notifications', () {
    test('compteurs de liste et de unread-count', () {
      final a = NotificationCounts.fromListCounts(<String, dynamic>{
        'all': 5,
        'interactions': 2,
        'messages': 1,
        'system': 2,
      });
      expect(a.all, 5);
      final b = NotificationCounts.fromUnreadCount(<String, dynamic>{
        'count': 4,
        'tabs': <String, dynamic>{
          'interactions': 1,
          'messages': 2,
          'system': 1,
        },
      });
      expect(b.messages, 2);
    });

    test('NotificationDetail avec contestation possible', () {
      final d = NotificationDetail.fromJson(<String, dynamic>{
        'notification': <String, dynamic>{
          'id': 'n1',
          'type': 'system',
          'title': 'T',
          'body': 'B',
        },
        'contest': <String, dynamic>{
          'type': 'x',
          'can_contest': true,
          'appeal': null,
        },
      });
      expect(d.hasContest, isTrue);
      expect(d.canContest, isTrue);
      expect(d.appeal, isNull);
    });

    test('NotificationDetail sans contestation', () {
      final d = NotificationDetail.fromJson(<String, dynamic>{
        'notification': <String, dynamic>{'id': 'n1'},
        'contest': null,
      });
      expect(d.hasContest, isFalse);
      expect(d.canContest, isFalse);
    });

    test('préférence : push_enabled est lu mais n\'implique aucun push', () {
      final p = NotificationPreference.fromJson(<String, dynamic>{
        'type': 'message',
        'push_enabled': true,
        'in_app_enabled': true,
        'email_enabled': false,
      });
      expect(p.pushEnabled, isTrue);
      expect(p.label, 'message');
    });
  });

  group('Premium et paiements', () {
    test('PublicConfig', () {
      final c = PublicConfig.fromJson(<String, dynamic>{
        'beta': true,
        'listing_fee_with_video': 0,
        'premium_offer_slots': 100,
        'premium_payments': false,
      });
      expect(c.beta, isTrue);
      expect(c.premiumPayments, isFalse);
    });

    test('PaymentStart : https exigé', () {
      expect(
        PaymentStart.tryFromJson(<String, dynamic>{
          'payment_url': 'https://pay.example/x',
        }),
        isNotNull,
      );
      expect(
        PaymentStart.tryFromJson(<String, dynamic>{
          'payment_url': 'http://pay.example/x',
        }),
        isNull,
      );
      expect(
        PaymentStart.tryFromJson(<String, dynamic>{
          'payment_url': 'javascript:alert(1)',
        }),
        isNull,
      );
      expect(PaymentStart.tryFromJson(<String, dynamic>{}), isNull);
    });

    test('PremiumStatus et offre', () {
      final s = PremiumStatus.fromJson(<String, dynamic>{
        'is_premium': false,
        'pending_subscription': <String, dynamic>{'id': 's1'},
      });
      expect(s.pendingSubscription, isNotNull);
      final o = PremiumOffer.fromJson(<String, dynamic>{
        'slots_total': 100,
        'slots_left': 12,
        'days': 30,
      });
      expect(o.myStatus, isNull);
      expect(o.slotsLeft, 12);
    });

    test('RankingEntry : mesures séparées des champs d\'identité', () {
      final entries = RankingEntry.listFromBody(<String, dynamic>{
        'ranking': <Object?>[
          <String, dynamic>{
            'rank': 1,
            'anonymous': false,
            'full_name': 'Fatou',
            'sales_count': 12,
            'badges': <Object?>[],
          },
        ],
      });
      expect(entries.single.rank, 1);
      expect(entries.single.metrics, <String, dynamic>{'sales_count': 12});
    });
  });

  group('Recherche, j\'aime, favoris', () {
    test('résultat de recherche : seller est un nom d\'utilisateur', () {
      final r = SearchResults.fromJson(<String, dynamic>{
        'products': <Object?>[
          <String, dynamic>{
            'id': 'p1',
            'slug': 'robe',
            'title': 'Robe',
            'price': '12000',
            'poster': null,
            'image': 'https://api.quinch.sn/i.jpg',
            'seller': 'fatou',
            'seller_id': 'u1',
            'seller_is_premium': true,
          },
        ],
        'users': <Object?>[
          <String, dynamic>{
            'id': 'u1',
            'full_name': 'Fatou',
            'username': 'fatou',
            'trust_score': 80,
          },
        ],
      });
      expect(r.isEmpty, isFalse);
      expect(r.products.single.sellerUsername, 'fatou');
      expect(r.products.single.price, 12000);
      expect(r.products.single.coverImage, 'https://api.quinch.sn/i.jpg');
      expect(r.products.single.sellerIsPremium, isTrue);
      expect(r.users.single.trustScore, 80);
    });

    test('recherche sans résultat ou corps vide', () {
      expect(
        SearchResults.fromJson(<String, dynamic>{
          'products': <Object?>[],
          'users': <Object?>[],
        }).isEmpty,
        isTrue,
      );
      expect(SearchResults.fromJson(null).isEmpty, isTrue);
    });

    test('LikeResult', () {
      final r = LikeResult.fromJson(<String, dynamic>{
        'liked': true,
        'like_count': 12,
      });
      expect(r.liked, isTrue);
      expect(r.likeCount, 12);
    });

    test('FavoriteEntry : annonce brute ou supprimée', () {
      final ok = FavoriteEntry.fromJson(<String, dynamic>{
        'id': 'f1',
        'product_id': 'p1',
        'price_at_save': 5000,
        'product': <String, dynamic>{
          'id': 'p1',
          'slug': 's',
          'title': 'T',
          'price': 6000,
        },
      });
      expect(ok.product?.price, 6000);
      expect(ok.priceAtSave, 5000);
      final gone = FavoriteEntry.fromJson(<String, dynamic>{
        'id': 'f2',
        'product_id': 'p2',
      });
      expect(gone.product, isNull);
      expect(gone.priceAtSave, isNull);
    });
  });

  group('Formats et médias', () {
    test('formatFcfa', () {
      expect(formatFcfa(15000), '15\u00A0000\u00A0FCFA');
      expect(formatFcfa(0), '0\u00A0FCFA');
      expect(formatFcfa(1234567), '1\u00A0234\u00A0567\u00A0FCFA');
      expect(formatFcfa(999), '999\u00A0FCFA');
    });

    test('formatPrice : XOF en FCFA, autre devise sans conversion', () {
      expect(formatPrice(2500, 'XOF'), '2\u00A0500\u00A0FCFA');
      expect(formatPrice(2500, null), '2\u00A0500\u00A0FCFA');
      expect(formatPrice(20, 'EUR'), '20\u00A0EUR');
    });

    test('MediaUrl', () {
      final media = MediaUrl.fromApiBase('https://api.quinch.sn/api/v1/');
      expect(
        media.resolve('https://cdn.example/a.jpg'),
        'https://cdn.example/a.jpg',
      );
      expect(
        media.resolve('/api/v1/videos/1/stream'),
        'https://api.quinch.sn/api/v1/videos/1/stream',
      );
      expect(media.resolve('javascript:alert(1)'), isNull);
      expect(media.resolve('ftp://x/y'), isNull);
      expect(media.resolve(''), isNull);
      expect(media.resolve(null), isNull);
    });
  });
}
