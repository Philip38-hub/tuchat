import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tuchat/models/user.dart';
import 'package:tuchat/providers/auth_provider.dart';
import 'package:tuchat/screens/contacts/qr_scanner_screen.dart';
import 'package:tuchat/screens/profile/profile_setup_screen.dart';
import 'package:tuchat/services/chat_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<AppUser> _searchResults = const [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchFieldChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchFieldChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchFieldChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _searchUsers(String query) async {
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.currentUser;

    if (query.trim().isEmpty || currentUser == null) {
      setState(() {
        _searchResults = const [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await context.read<ChatService>().searchUsersByUsername(
        query,
        excludeUid: currentUser.uid,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _searchResults = results;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _addContact(String contactUid) async {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null) {
      return;
    }

    try {
      await context.read<ChatService>().addContact(
        ownerUid: currentUser.uid,
        contactUid: contactUid,
      );
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contact added successfully.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _scanQrCode() async {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null) {
      return;
    }

    final scannedUid = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const QrScannerScreen()));

    if (!mounted || scannedUid == null || scannedUid.isEmpty) {
      return;
    }

    await _addContact(scannedUid);
  }

  Future<void> _openProfileSetup() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ProfileSetupScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('TuChat'),
        actions: [
          IconButton(
            onPressed: _openProfileSetup,
            icon: const Icon(Icons.person_outline),
            tooltip: 'Edit profile',
          ),
          IconButton(
            onPressed: authProvider.isBusy
                ? null
                : () async {
                    await context.read<AuthProvider>().signOut();
                  },
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _ProfileHeader(user: user),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your QR code',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Share this QR code so another TuChat user can add you instantly.',
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: QrImageView(
                      data: user.uid,
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(user.uid, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _scanQrCode,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scan QR to add contact'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Find people',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text('Search by username to find another TuChat user.'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    onChanged: _searchUsers,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search username',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                _searchUsers('');
                              },
                              icon: const Icon(Icons.clear),
                            ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isSearching)
                    const Center(child: CircularProgressIndicator())
                  else if (_searchController.text.trim().isNotEmpty &&
                      _searchResults.isEmpty)
                    const Text('No users found for that username.')
                  else
                    ..._searchResults.map(
                      (result) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundImage: result.profilePicUrl.isNotEmpty
                              ? NetworkImage(result.profilePicUrl)
                              : null,
                          child: result.profilePicUrl.isEmpty
                              ? Text(
                                  result.username.substring(0, 1).toUpperCase(),
                                )
                              : null,
                        ),
                        title: Text(result.username),
                        subtitle: Text(result.email),
                        trailing: FilledButton(
                          onPressed: () => _addContact(result.uid),
                          child: const Text('Add'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundImage: user.profilePicUrl.isNotEmpty
                  ? NetworkImage(user.profilePicUrl)
                  : null,
              child: user.profilePicUrl.isEmpty
                  ? Text(
                      user.username.substring(0, 1).toUpperCase(),
                      style: Theme.of(context).textTheme.headlineSmall,
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.username,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(user.email),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
