import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/follow_service.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../widgets/cached_avatar.dart';

/// Screen showing followers or following list for a user.
class FollowersScreen extends StatefulWidget {
  final String userId;
  final String? name;
  final String initialTab; // 'followers' or 'following'

  const FollowersScreen({
    super.key,
    required this.userId,
    this.name,
    this.initialTab = 'followers',
  });

  @override
  State<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends State<FollowersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<dynamic> _followers = [];
  List<dynamic> _following = [];
  bool _loadingFollowers = true;
  bool _loadingFollowing = true;

  // Track which users I follow (for the follow/unfollow button)
  final Set<String> _myFollowingIds = {};

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab == 'following' ? 1 : 0,
    );
    _loadData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final followService = context.read<FollowService>();
    final auth = context.read<AuthProvider>();
    final isOwnProfile = widget.userId == auth.user?.id;

    // Load followers
    try {
      if (isOwnProfile) {
        _followers = await followService.getMyFollowers();
      } else {
        _followers = await followService.getUserFollowers(widget.userId);
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingFollowers = false);

    // Load following
    try {
      if (isOwnProfile) {
        _following = await followService.getMyFollowing();
      } else {
        _following = await followService.getUserFollowing(widget.userId);
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingFollowing = false);

    // Load my following list to show follow/unfollow buttons
    if (auth.isAuthenticated) {
      try {
        final myFollowing = await followService.getMyFollowing();
        for (final f in myFollowing) {
          final id = (f['id'] ?? f['following_id'])?.toString();
          if (id != null) _myFollowingIds.add(id);
        }
        if (mounted) setState(() {});
      } catch (_) {}
    }
  }

  Future<void> _toggleFollow(String userId) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      context.push('/auth/login');
      return;
    }
    if (userId == auth.user?.id) return;

    final followService = context.read<FollowService>();
    final wasFollowing = _myFollowingIds.contains(userId);

    // Optimistic update
    setState(() {
      if (wasFollowing) {
        _myFollowingIds.remove(userId);
      } else {
        _myFollowingIds.add(userId);
      }
    });

    try {
      if (wasFollowing) {
        await followService.unfollow(userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Désabonné'), duration: Duration(seconds: 1)),
          );
        }
      } else {
        final result = await followService.follow(userId);
        if (mounted) {
          final isMutual = result['is_mutual'] == true;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isMutual ? 'Vous êtes maintenant amis !' : 'Abonné !'),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      // Revert on error
      setState(() {
        if (wasFollowing) {
          _myFollowingIds.add(userId);
        } else {
          _myFollowingIds.remove(userId);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgSecondary,
        title: Text(widget.name ?? 'Profil', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.accent,
          tabs: [
            Tab(text: 'Abonnés (${_followers.length})'),
            Tab(text: 'Abonnements (${_following.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildList(_followers, _loadingFollowers, isFollowersList: true),
          _buildList(_following, _loadingFollowing, isFollowersList: false),
        ],
      ),
    );
  }

  Widget _buildList(List<dynamic> users, bool loading, {required bool isFollowersList}) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }

    if (users.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(
            isFollowersList ? Icons.people_outline : Icons.person_add_alt_1,
            color: AppColors.textMuted, size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            isFollowersList ? 'Aucun abonné' : 'Aucun abonnement',
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        itemCount: users.length,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemBuilder: (_, i) {
          final raw = users[i];
          // The API returns either { follower: {...}, following: {...} } or direct user data
          final user = raw is Map<String, dynamic>
              ? (raw['follower'] ?? raw['following'] ?? raw)
              : raw;

          final userId = (user['id'])?.toString() ?? '';
          final name = user['full_name'] ?? user['username'] ?? 'Utilisateur';
          final username = user['username'] ?? '';
          final avatarUrl = user['avatar_url'] ?? '';
          final city = user['city'] ?? '';
          final auth = context.read<AuthProvider>();
          final isMe = userId == auth.user?.id;
          final isFollowingThisUser = _myFollowingIds.contains(userId);

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CachedAvatar(
              url: avatarUrl.isNotEmpty ? ApiConfig.resolveUrl(avatarUrl) : null,
              size: 48,
              name: name,
            ),
            title: Text(name, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('@$username', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              if (city.isNotEmpty)
                Text(city, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ]),
            trailing: isMe
                ? null
                : SizedBox(
                    width: 90, height: 32,
                    child: isFollowingThisUser
                        ? OutlinedButton(
                            onPressed: () => _toggleFollow(userId),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.accent,
                              side: const BorderSide(color: AppColors.accent),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              textStyle: const TextStyle(fontSize: 11),
                            ),
                            child: const Text('Abonné'),
                          )
                        : ElevatedButton(
                            onPressed: () => _toggleFollow(userId),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              textStyle: const TextStyle(fontSize: 11),
                            ),
                            child: const Text('Suivre'),
                          ),
                  ),
            onTap: () {
              if (username.isNotEmpty) {
                context.push('/seller/$username');
              }
            },
          );
        },
      ),
    );
  }
}
