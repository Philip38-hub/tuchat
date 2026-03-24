import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tuchat/models/chat.dart';
import 'package:tuchat/models/user.dart';
import 'package:tuchat/providers/auth_provider.dart';
import 'package:tuchat/screens/chat/chat_screen.dart';
import 'package:tuchat/screens/contacts/qr_scanner_screen.dart';
import 'package:tuchat/screens/profile/profile_setup_screen.dart';
import 'package:tuchat/services/chat_service.dart';
import 'package:tuchat/utils/profile_image.dart';

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
    final currentUser = context.read<AuthProvider>().currentUser;

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

  Future<void> _removeContact(AppUser contact) async {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete contact'),
          content: Text(
            'Remove ${contact.username} from your contacts? This will not delete existing chat messages.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    try {
      await context.read<ChatService>().removeContact(
        ownerUid: currentUser.uid,
        contactUid: contact.uid,
      );
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${contact.username} removed from contacts.')),
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

  Future<void> _openChat(
    AppUser otherUser, {
    bool isSecretChat = false,
  }) async {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null) {
      return;
    }

    try {
      final chat = await context.read<ChatService>().createOrGetDirectChat(
        currentUserId: currentUser.uid,
        otherUserId: otherUser.uid,
        isSecretChat: isSecretChat,
      );

      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            currentUser: currentUser,
            otherUser: otherUser,
            chat: chat,
          ),
        ),
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

    final chatService = context.read<ChatService>();

    return MultiProvider(
      providers: [
        StreamProvider<List<AppUser>>.value(
          value: chatService.streamContacts(user.uid),
          initialData: const [],
        ),
        StreamProvider<List<Chat>>.value(
          value: chatService.streamChats(user.uid),
          initialData: const [],
        ),
      ],
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            title: const Text('TuChat'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Chats'),
                Tab(text: 'Contacts'),
                Tab(text: 'Connect'),
              ],
            ),
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
          body: TabBarView(
            children: [
              _ChatsTab(
                currentUser: user,
                onOpenChat: _openChat,
              ),
              _ContactsTab(
                currentUser: user,
                onOpenChat: _openChat,
                onDeleteContact: _removeContact,
              ),
              _ConnectTab(
                currentUser: user,
                searchController: _searchController,
                searchResults: _searchResults,
                isSearching: _isSearching,
                onSearchChanged: _searchUsers,
                onAddContact: _addContact,
                onOpenChat: _openChat,
                onScanQrCode: _scanQrCode,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatsTab extends StatelessWidget {
  const _ChatsTab({
    required this.currentUser,
    required this.onOpenChat,
  });

  final AppUser currentUser;
  final Future<void> Function(AppUser otherUser, {bool isSecretChat}) onOpenChat;

  @override
  Widget build(BuildContext context) {
    final chats = context.watch<List<Chat>>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ProfileHeader(user: currentUser),
        const SizedBox(height: 16),
        if (chats.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('No chats yet. Add a contact or start one from the Connect tab.'),
            ),
          )
        else
          ...chats.map(
            (chat) => _ChatListTile(
              currentUserId: currentUser.uid,
              chat: chat,
              onOpenChat: onOpenChat,
            ),
          ),
      ],
    );
  }
}

class _ContactsTab extends StatelessWidget {
  const _ContactsTab({
    required this.currentUser,
    required this.onOpenChat,
    required this.onDeleteContact,
  });

  final AppUser currentUser;
  final Future<void> Function(AppUser otherUser, {bool isSecretChat}) onOpenChat;
  final Future<void> Function(AppUser contact) onDeleteContact;

  @override
  Widget build(BuildContext context) {
    final contacts = context.watch<List<AppUser>>();

    if (contacts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('No contacts yet. Use search or scan a QR code to add someone.'),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        final contact = contacts[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: buildProfileImageProvider(contact.profilePicUrl),
              child: contact.profilePicUrl.isEmpty
                  ? Text(contact.username.substring(0, 1).toUpperCase())
                  : null,
            ),
            title: Text(contact.username),
            subtitle: Text(contact.email),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'chat') {
                  onOpenChat(contact);
                } else if (value == 'secret') {
                  onOpenChat(contact, isSecretChat: true);
                } else if (value == 'delete') {
                  onDeleteContact(contact);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'chat',
                  child: Text('Open chat'),
                ),
                PopupMenuItem(
                  value: 'secret',
                  child: Text('Open secret chat'),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete contact'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ConnectTab extends StatelessWidget {
  const _ConnectTab({
    required this.currentUser,
    required this.searchController,
    required this.searchResults,
    required this.isSearching,
    required this.onSearchChanged,
    required this.onAddContact,
    required this.onOpenChat,
    required this.onScanQrCode,
  });

  final AppUser currentUser;
  final TextEditingController searchController;
  final List<AppUser> searchResults;
  final bool isSearching;
  final ValueChanged<String> onSearchChanged;
  final Future<void> Function(String contactUid) onAddContact;
  final Future<void> Function(AppUser otherUser, {bool isSecretChat}) onOpenChat;
  final Future<void> Function() onScanQrCode;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
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
                    data: currentUser.uid,
                    size: 200,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(currentUser.uid, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onScanQrCode,
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
                  controller: searchController,
                  onChanged: onSearchChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search username',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              searchController.clear();
                              onSearchChanged('');
                            },
                            icon: const Icon(Icons.clear),
                          ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                if (isSearching)
                  const Center(child: CircularProgressIndicator())
                else if (searchController.text.trim().isNotEmpty &&
                    searchResults.isEmpty)
                  const Text('No users found for that username.')
                else
                  ...searchResults.map(
                    (result) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundImage: buildProfileImageProvider(
                          result.profilePicUrl,
                        ),
                        child: result.profilePicUrl.isEmpty
                            ? Text(result.username.substring(0, 1).toUpperCase())
                            : null,
                      ),
                      title: Text(result.username),
                      subtitle: Text(result.email),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () => onAddContact(result.uid),
                            child: const Text('Add'),
                          ),
                          FilledButton(
                            onPressed: () => onOpenChat(result),
                            child: const Text('Chat'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatListTile extends StatelessWidget {
  const _ChatListTile({
    required this.currentUserId,
    required this.chat,
    required this.onOpenChat,
  });

  final String currentUserId;
  final Chat chat;
  final Future<void> Function(AppUser otherUser, {bool isSecretChat}) onOpenChat;

  @override
  Widget build(BuildContext context) {
    final otherUserId = chat.participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
    final chatService = context.read<ChatService>();

    return FutureBuilder<AppUser?>(
      future: chatService.getUserByUid(otherUserId),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) {
          return const SizedBox.shrink();
        }

        final unreadCount = chat.unreadCountFor(currentUserId);
        return Card(
          child: ListTile(
            onTap: () => onOpenChat(user, isSecretChat: chat.isSecretChat),
            leading: CircleAvatar(
              backgroundImage: buildProfileImageProvider(user.profilePicUrl),
              child: user.profilePicUrl.isEmpty
                  ? Text(user.username.substring(0, 1).toUpperCase())
                  : null,
            ),
            title: Row(
              children: [
                Expanded(child: Text(user.username)),
                if (chat.isSecretChat) const Icon(Icons.lock_outline, size: 18),
              ],
            ),
            subtitle: Text(
              chat.lastMessage ?? 'Start chatting',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: unreadCount > 0
                ? CircleAvatar(
                    radius: 12,
                    child: Text(
                      unreadCount.toString(),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  )
                : null,
          ),
        );
      },
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
              backgroundImage: buildProfileImageProvider(user.profilePicUrl),
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
