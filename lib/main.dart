import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AuthService.instance.initializeGoogleSignIn();
  runApp(const JihcApp());
}

const kPrimary = Color(0xFF1982C4);
const kPrimaryDark = Color(0xFF0C447C);
const kPrimarySoft = Color(0xFFE6F1FB);
const kBackground = Color(0xFFF7F8FA);
const kText = Color(0xFF1A1A1A);
const kTextMuted = Color(0xFF6B6B6B);
const kBorder = Color(0xFFE6E8EC);
const kSuccess = Color(0xFF3B6D11);
const kSuccessSoft = Color(0xFFEAF3DE);
const kWarning = Color(0xFF854F0B);
const kWarningSoft = Color(0xFFFAEEDA);
const kError = Color(0xFFA32D2D);
const kErrorSoft = Color(0xFFFCEBEB);

const identityName = 'Magzhan Samatuly';
const identityId = '090217553070';
const accentLabel = '#1982C4 Sky Blue';
const googleServerClientId =
    '52976884725-3fki6fc13i1vp31lhbjqt7dpmgp06ufa.apps.googleusercontent.com';

final mainTabNotifier = ValueNotifier<int>(0);
const kMaxChatImageBytes = 600 * 1024;
const kChatImageDimensions = [1280, 1024, 800, 640, 480, 360];
const kChatImageQualities = [82, 74, 66, 58];

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _googleInitialized = false;

  Stream<User?> get authStateChanges =>
      FirebaseAuth.instance.authStateChanges();

  Future<void> initializeGoogleSignIn() async {
    if (_googleInitialized) return;
    await _googleSignIn.initialize(serverClientId: googleServerClientId);
    _googleInitialized = true;
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await _saveUserIfNeeded(credential.user);
      return credential;
    } on FirebaseAuthException catch (error) {
      throw AuthException(_messageForFirebaseAuthError(error));
    } on FirebaseException catch (error) {
      throw AuthException(_messageForFirebaseError(error));
    } catch (_) {
      throw const AuthException('Unable to sign in. Please try again.');
    }
  }

  Future<UserCredential> registerWithEmail({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final trimmedFullName = fullName.trim();
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );
      if (trimmedFullName.isNotEmpty) {
        await credential.user?.updateDisplayName(trimmedFullName);
      }
      await _saveUserIfNeeded(credential.user, fullName: trimmedFullName);
      return credential;
    } on FirebaseAuthException catch (error) {
      throw AuthException(_messageForFirebaseAuthError(error));
    } on FirebaseException catch (error) {
      throw AuthException(_messageForFirebaseError(error));
    } catch (_) {
      throw const AuthException(
        'Unable to create your account. Please try again.',
      );
    }
  }

  Future<UserCredential> signInWithGoogle() async {
    try {
      await initializeGoogleSignIn();
      if (!_googleSignIn.supportsAuthenticate()) {
        throw const AuthException(
          'Google Sign-In is not available on this platform.',
        );
      }

      final googleUser = await _googleSignIn.authenticate();
      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        throw const AuthException(
          'Google Sign-In did not return an ID token. Check your Firebase OAuth configuration.',
        );
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      await _saveUserIfNeeded(
        userCredential.user,
        fullName: googleUser.displayName,
      );
      return userCredential;
    } on AuthException {
      rethrow;
    } on GoogleSignInException catch (error) {
      throw AuthException(_messageForGoogleSignInError(error));
    } on FirebaseAuthException catch (error) {
      throw AuthException(_messageForFirebaseAuthError(error));
    } on FirebaseException catch (error) {
      throw AuthException(_messageForFirebaseError(error));
    } catch (_) {
      throw const AuthException('Google Sign-In failed. Please try again.');
    }
  }

  Future<void> signOut() async {
    await Future.wait([
      FirebaseAuth.instance.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  Future<void> _saveUserIfNeeded(User? user, {String? fullName}) async {
    if (user == null) return;

    final userDoc = _firestore.collection('users').doc(user.uid);
    final snapshot = await userDoc.get();
    final resolvedName = (fullName?.trim().isNotEmpty ?? false)
        ? fullName!.trim()
        : (user.displayName?.trim().isNotEmpty ?? false)
        ? user.displayName!.trim()
        : user.email?.split('@').first ?? 'JIHC Student';

    if (!snapshot.exists) {
      await userDoc.set({
        'uid': user.uid,
        'email': user.email ?? '',
        'fullName': resolvedName,
        'createdAt': FieldValue.serverTimestamp(),
        'role': 'student',
      });
      return;
    }

    final update = <String, Object?>{
      'uid': user.uid,
      'email': user.email ?? '',
    };

    if ((fullName?.trim().isNotEmpty ?? false) ||
        (user.displayName?.trim().isNotEmpty ?? false)) {
      update['fullName'] = resolvedName;
    }

    await userDoc.set(update, SetOptions(merge: true));
  }

  String _messageForGoogleSignInError(GoogleSignInException error) {
    switch (error.code) {
      case GoogleSignInExceptionCode.canceled:
        return 'Google Sign-In was cancelled.';
      case GoogleSignInExceptionCode.interrupted:
        return 'Google Sign-In was interrupted. Please try again.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'Google Sign-In is not available right now.';
      default:
        return 'Google Sign-In failed. Check your Google/Firebase configuration.';
    }
  }

  String _messageForFirebaseAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'wrong-password':
        return 'Wrong password. Please try again.';
      case 'user-not-found':
        return 'No account was found for this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'operation-not-allowed':
        return 'This sign-in provider is disabled in Firebase Console.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'account-exists-with-different-credential':
        return 'This email is already connected to another sign-in method.';
      default:
        return error.message ?? 'Authentication failed. Please try again.';
    }
  }

  String _messageForFirebaseError(FirebaseException error) {
    if (error.code == 'unavailable' || error.code == 'deadline-exceeded') {
      return 'Network error. Check your internet connection.';
    }
    if (error.code == 'permission-denied') {
      return 'Firestore rejected the user profile write. Check security rules.';
    }
    return error.message ?? 'Firebase error. Please try again.';
  }
}

class JihcApp extends StatelessWidget {
  const JihcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'JIHC Hall Booking',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: kBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrimary,
          primary: kPrimary,
          secondary: const Color(0xFF1D9E75),
          surface: Colors.white,
          error: kError,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: kPrimary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: kPrimary,
            side: const BorderSide(color: kPrimary, width: 1.4),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: kBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: kPrimary, width: 1.5),
          ),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AuthLoadingScreen();
        }

        if (snapshot.hasData) {
          return const MainShell();
        }

        mainTabNotifier.value = 0;
        return const LoginScreen();
      },
    );
  }
}

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    const pages = <Widget>[
      DashboardScreen(),
      MyBookingsScreen(),
      ChatsListScreen(),
      ProfileScreen(),
    ];

    return ValueListenableBuilder<int>(
      valueListenable: mainTabNotifier,
      builder: (context, index, child) => pages[index],
    );
  }
}

class AuthLoadingScreen extends StatelessWidget {
  const AuthLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: kPrimary,
      body: Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}

enum BookingStatus { pending, approved, rejected }

class Hall {
  const Hall({
    required this.id,
    required this.name,
    required this.location,
    required this.description,
    required this.rules,
    required this.capacity,
    required this.availability,
    required this.icon,
    required this.accent,
    required this.tint,
    required this.features,
  });

  final String id;
  final String name;
  final String location;
  final String description;
  final String rules;
  final int capacity;
  final String availability;
  final IconData icon;
  final Color accent;
  final Color tint;
  final List<String> features;
}

class Booking {
  const Booking({
    required this.id,
    required this.hall,
    required this.date,
    required this.time,
    required this.purpose,
    required this.status,
  });

  final String id;
  final Hall hall;
  final String date;
  final String time;
  final String purpose;
  final BookingStatus status;
}

class ChatPreview {
  const ChatPreview({
    required this.title,
    required this.preview,
    required this.time,
    required this.icon,
    required this.color,
    this.unread = 0,
    this.isGroup = false,
  });

  final String title;
  final String preview;
  final String time;
  final IconData icon;
  final Color color;
  final int unread;
  final bool isGroup;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.imageBase64,
    required this.imageUrl,
    required this.storagePath,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    required this.isEdited,
  });

  factory ChatMessage.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot, {
    required String chatId,
  }) {
    final data = snapshot.data() ?? <String, dynamic>{};
    String stringValue(String key) {
      final value = data[key];
      return value is String ? value : '';
    }

    Timestamp? timestampValue(String key) {
      final value = data[key];
      return value is Timestamp ? value : null;
    }

    final type = stringValue('type') == 'image' ? 'image' : 'text';
    final id = stringValue('id');

    return ChatMessage(
      id: id.isNotEmpty ? id : snapshot.id,
      chatId: stringValue('chatId').isNotEmpty ? stringValue('chatId') : chatId,
      senderId: stringValue('senderId'),
      senderName: stringValue('senderName'),
      text: stringValue('text'),
      imageBase64: stringValue('imageBase64'),
      imageUrl: stringValue('imageUrl'),
      storagePath: stringValue('storagePath'),
      type: type,
      createdAt: timestampValue('createdAt'),
      updatedAt: timestampValue('updatedAt'),
      isEdited: data['isEdited'] == true,
    );
  }

  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final String text;
  final String imageBase64;
  final String imageUrl;
  final String storagePath;
  final String type;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final bool isEdited;

  bool get isText => type == 'text';
  bool get isImage => type == 'image';

  DateTime get displayDate =>
      createdAt?.toDate() ?? updatedAt?.toDate() ?? DateTime.now();
}

class ChatService {
  ChatService._();

  static final ChatService instance = ChatService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _messagesRef(String chatId) {
    return _firestore.collection('chats').doc(chatId).collection('messages');
  }

  Stream<List<ChatMessage>> messagesStream(String chatId) {
    return _messagesRef(chatId)
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatMessage.fromSnapshot(doc, chatId: chatId))
              .toList(),
        );
  }

  Future<void> sendTextMessage({
    required String chatId,
    required String text,
  }) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      throw const AuthException('Type a message before sending.');
    }

    final user = _requireUser();
    final doc = _messagesRef(chatId).doc();

    await doc.set({
      'id': doc.id,
      'chatId': chatId,
      'senderId': user.uid,
      'senderName': _senderName(user),
      'text': trimmedText,
      'imageBase64': '',
      'imageUrl': '',
      'storagePath': '',
      'type': 'text',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isEdited': false,
    });
  }

  Future<void> sendImageMessage({
    required String chatId,
    required XFile image,
  }) async {
    final user = _requireUser();
    final messageRef = _messagesRef(chatId).doc();
    final messageId = messageRef.id;

    try {
      final imageBase64 = await _imageToBase64(image);

      await messageRef.set({
        'id': messageId,
        'chatId': chatId,
        'senderId': user.uid,
        'senderName': _senderName(user),
        'text': '',
        'imageBase64': imageBase64,
        'imageUrl': null,
        'storagePath': null,
        'type': 'image',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isEdited': false,
      });
    } on FirebaseException catch (error) {
      throw AuthException(_messageForFirebaseChatError(error));
    } on StateError catch (error) {
      throw AuthException(error.message);
    } catch (_) {
      throw const AuthException('Image processing failed. Please try again.');
    }
  }

  Future<void> deleteMessage(ChatMessage message) async {
    final user = _requireUser();
    final messageRef = _messagesRef(message.chatId).doc(message.id);
    final snapshot = await messageRef.get();

    if (!snapshot.exists) return;

    final savedMessage = ChatMessage.fromSnapshot(
      snapshot,
      chatId: message.chatId,
    );

    if (savedMessage.senderId != user.uid) {
      throw const AuthException('You can delete only your own messages.');
    }

    try {
      await messageRef.delete();
    } on FirebaseException catch (error) {
      throw AuthException(_messageForFirebaseChatError(error));
    }
  }

  Future<void> editTextMessage({
    required ChatMessage message,
    required String text,
  }) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      throw const AuthException('Message cannot be empty.');
    }
    if (!message.isText) {
      throw const AuthException('Only text messages can be edited.');
    }

    final user = _requireUser();
    if (message.senderId != user.uid) {
      throw const AuthException('You can edit only your own messages.');
    }

    await _messagesRef(message.chatId).doc(message.id).update({
      'text': trimmedText,
      'updatedAt': FieldValue.serverTimestamp(),
      'isEdited': true,
    });
  }

  User _requireUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const AuthException('Please sign in to use chat.');
    }
    return user;
  }

  String _senderName(User user) {
    final displayName = user.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    final email = user.email?.trim();
    if (email != null && email.isNotEmpty) return email.split('@').first;
    return 'JIHC Student';
  }

  Future<String> _imageToBase64(XFile image) async {
    final originalBytes = await image.readAsBytes();
    if (originalBytes.isEmpty) {
      throw StateError('Selected image is empty.');
    }

    final decodedImage = img.decodeImage(originalBytes);
    if (decodedImage == null) {
      if (originalBytes.length <= kMaxChatImageBytes) {
        return base64Encode(originalBytes);
      }
      throw StateError('This image format is too large to save in chat.');
    }

    for (final maxDimension in kChatImageDimensions) {
      final resizedImage = _resizeImage(decodedImage, maxDimension);
      for (final quality in kChatImageQualities) {
        final compressedBytes = img.encodeJpg(resizedImage, quality: quality);
        if (compressedBytes.length <= kMaxChatImageBytes) {
          return base64Encode(compressedBytes);
        }
      }
    }

    throw StateError(
      'Image is too large. Please choose a smaller image or crop it first.',
    );
  }

  img.Image _resizeImage(img.Image source, int maxDimension) {
    final longestSide = source.width > source.height
        ? source.width
        : source.height;
    if (longestSide <= maxDimension) return source;

    if (source.width >= source.height) {
      return img.copyResize(
        source,
        width: maxDimension,
        interpolation: img.Interpolation.average,
      );
    }

    return img.copyResize(
      source,
      height: maxDimension,
      interpolation: img.Interpolation.average,
    );
  }

  String _messageForFirebaseChatError(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'Firebase rules blocked this chat action.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Network error. Check your connection and try again.';
      default:
        return error.message ?? 'Chat action failed. Please try again.';
    }
  }
}

const halls = <Hall>[
  Hall(
    id: 'sport',
    name: 'Sport Hall',
    location: 'JIHC Campus - Floor 1',
    description:
        'A bright multi-purpose gym for tournaments, PE events, rehearsals, and student gatherings.',
    rules:
        'Use indoor shoes, return equipment after the event, and keep food outside the sport area.',
    capacity: 200,
    availability: 'Available today',
    icon: Icons.sports_basketball,
    accent: kPrimary,
    tint: kPrimarySoft,
    features: ['Projector', 'AC', 'Locker room'],
  ),
  Hall(
    id: 'act',
    name: 'Act Hall',
    location: 'JIHC Campus - Main block',
    description:
        'A large event hall with a stage, sound system, and seating for ceremonies or performances.',
    rules:
        'Reserve sound checks in advance, keep stage exits clear, and close the hall on schedule.',
    capacity: 500,
    availability: 'Available today',
    icon: Icons.mic,
    accent: Color(0xFF534AB7),
    tint: Color(0xFFEEEDFE),
    features: ['Stage', 'Sound', 'Lighting'],
  ),
  Hall(
    id: 'auditorium',
    name: 'Auditorium',
    location: 'JIHC Campus - Floor 2',
    description:
        'A focused lecture space for seminars, exams, workshops, and club presentations.',
    rules:
        'Keep tables in order, clean whiteboards after use, and avoid moving fixed equipment.',
    capacity: 150,
    availability: 'Busy until 14:00',
    icon: Icons.school,
    accent: Color(0xFF0F6E56),
    tint: Color(0xFFE1F5EE),
    features: ['Boards', 'Wi-Fi', 'Speakers'],
  ),
];

final bookings = <Booking>[
  Booking(
    id: 'JH-2401',
    hall: halls[0],
    date: 'May 30, 2026',
    time: '10:00-11:00',
    purpose: 'Sports event',
    status: BookingStatus.pending,
  ),
  Booking(
    id: 'JH-2398',
    hall: halls[1],
    date: 'May 28, 2026',
    time: '14:00-15:00',
    purpose: 'Graduation rehearsal',
    status: BookingStatus.approved,
  ),
  Booking(
    id: 'JH-2384',
    hall: halls[2],
    date: 'May 25, 2026',
    time: '09:00-10:00',
    purpose: 'Lecture',
    status: BookingStatus.rejected,
  ),
];

const chatPreviews = <ChatPreview>[
  ChatPreview(
    title: 'Sport Hall Booking',
    preview: 'Admin: Request received, reviewing your slot.',
    time: '2m',
    icon: Icons.sports_basketball,
    color: kPrimary,
    unread: 2,
  ),
  ChatPreview(
    title: 'Act Hall Booking',
    preview: 'Your booking has been approved.',
    time: '1h',
    icon: Icons.mic,
    color: Color(0xFF534AB7),
  ),
  ChatPreview(
    title: 'Admin Support',
    preview: 'How can I help you today?',
    time: '1d',
    icon: Icons.support_agent,
    color: Color(0xFF1D9E75),
  ),
  ChatPreview(
    title: 'Event Organizers',
    preview: 'Aibek: Meeting tomorrow at 10.',
    time: '3h',
    icon: Icons.groups,
    color: Color(0xFFD85A30),
    unread: 5,
    isGroup: true,
  ),
];

String statusText(BookingStatus status) {
  switch (status) {
    case BookingStatus.pending:
      return 'Pending';
    case BookingStatus.approved:
      return 'Approved';
    case BookingStatus.rejected:
      return 'Rejected';
  }
}

Color statusBackground(BookingStatus status) {
  switch (status) {
    case BookingStatus.pending:
      return kWarningSoft;
    case BookingStatus.approved:
      return kSuccessSoft;
    case BookingStatus.rejected:
      return kErrorSoft;
  }
}

Color statusForeground(BookingStatus status) {
  switch (status) {
    case BookingStatus.pending:
      return kWarning;
    case BookingStatus.approved:
      return kSuccess;
    case BookingStatus.rejected:
      return kError;
  }
}

void pushPage(BuildContext context, Widget page) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
}

void replaceWith(BuildContext context, Widget page) {
  Navigator.of(
    context,
  ).pushReplacement(MaterialPageRoute(builder: (_) => page));
}

void openMainTab(BuildContext context, int index) {
  Navigator.of(context).popUntil((route) => route.isFirst);
  mainTabNotifier.value = index;
}

Future<void> signOutAndReturnToLogin(BuildContext context) async {
  try {
    await AuthService.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  } on FirebaseAuthException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Logout failed.')),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logout failed. Please try again.')),
      );
    }
  }
}

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions = const [],
    this.currentTab,
    this.showBack = true,
    this.floatingActionButton,
    this.bottomBar,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget> actions;
  final int? currentTab;
  final bool showBack;
  final Widget? floatingActionButton;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: showBack ? const BackButton(color: Colors.white) : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitle != null)
              Text(
                subtitle!,
                style: const TextStyle(
                  color: Color(0xFFB5D4F4),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            Text(title),
          ],
        ),
        actions: actions,
      ),
      body: body,
      bottomNavigationBar:
          bottomBar ??
          (currentTab == null ? null : AppBottomNav(currentIndex: currentTab!)),
      floatingActionButton: floatingActionButton,
    );
  }
}

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.currentIndex});

  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: kPrimary,
      unselectedItemColor: const Color(0xFFB8BDC5),
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800),
      onTap: (index) {
        if (index != currentIndex) {
          openMainTab(context, index);
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_month),
          label: 'Bookings',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_outline),
          label: 'Chats',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'Profile',
        ),
      ],
    );
  }
}

class AppScroll extends StatelessWidget {
  const AppScroll({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.all(16),
  });

  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(padding: padding, children: children),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: kText,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class SurfaceBox extends StatelessWidget {
  const SurfaceBox({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color = Colors.white,
    this.borderColor = kBorder,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: statusBackground(status),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        statusText(status),
        style: TextStyle(
          color: statusForeground(status),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class HallVisual extends StatelessWidget {
  const HallVisual({
    super.key,
    required this.hall,
    this.height = 118,
    this.radius = 10,
  });

  final Hall hall;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: hall.tint,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Center(
        child: Icon(hall.icon, size: height * 0.42, color: hall.accent),
      ),
    );
  }
}

class InfoChip extends StatelessWidget {
  const InfoChip({
    super.key,
    required this.icon,
    required this.label,
    this.color = kPrimary,
    this.background = kPrimarySoft,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.outline = false,
    this.color = kPrimary,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool outline;
  final Color color;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: outline ? color : Colors.white,
            ),
          )
        : icon == null
        ? Text(label)
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    if (outline) {
      return OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color, width: 1.4),
        ),
        child: child,
      );
    }

    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(backgroundColor: color),
      child: child,
    );
  }
}

class BookingRow extends StatelessWidget {
  const BookingRow({
    super.key,
    required this.booking,
    this.onTap,
    this.showPurpose = false,
  });

  final Booking booking;
  final VoidCallback? onTap;
  final bool showPurpose;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SurfaceBox(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: booking.hall.tint,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(booking.hall.icon, color: booking.hall.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.hall.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: kText,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${booking.date} - ${booking.time}',
                    style: const TextStyle(color: kTextMuted, fontSize: 12),
                  ),
                  if (showPurpose) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Purpose: ${booking.purpose}',
                      style: const TextStyle(color: kTextMuted, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusBadge(booking.status),
          ],
        ),
      ),
    );
  }
}

class MenuRow extends StatelessWidget {
  const MenuRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.color = kPrimary,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SurfaceBox(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color == kPrimary ? kText : color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(color: kTextMuted, fontSize: 12),
                      ),
                  ],
                ),
              ),
              trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        replaceWith(context, const OnboardingScreen());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: kPrimary,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: Colors.white,
                child: Text(
                  'JIHC',
                  style: TextStyle(
                    color: kPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 23,
                  ),
                ),
              ),
              SizedBox(height: 18),
              Text(
                'Hall Booking & Messenger',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Magzhan Samatuly - 090217553070',
                style: TextStyle(color: Color(0xFFB5D4F4)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  final _pages = const [
    _OnboardingPage(
      icon: Icons.event_available,
      title: 'Book any hall instantly',
      text:
          'Choose Sport Hall, Act Hall, or Auditorium and request a slot in a few taps.',
      color: kPrimary,
    ),
    _OnboardingPage(
      icon: Icons.forum,
      title: 'Chat with admins',
      text:
          'Every booking gets a live conversation so updates stay clear and fast.',
      color: Color(0xFF1D9E75),
    ),
    _OnboardingPage(
      icon: Icons.fact_check,
      title: 'Track every request',
      text:
          'Follow pending, approved, and rejected bookings from one clean dashboard.',
      color: Color(0xFF534AB7),
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () =>
                          replaceWith(context, const LoginScreen()),
                      child: const Text('Skip'),
                    ),
                  ),
                  Expanded(
                    child: PageView(
                      controller: _controller,
                      onPageChanged: (value) => setState(() => _page = value),
                      children: _pages,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: _page == index ? 22 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: _page == index
                              ? kPrimary
                              : const Color(0xFFD5DAE1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  AppButton(
                    label: _page == 2 ? 'Get Started' : 'Next',
                    icon: _page == 2 ? Icons.login : Icons.arrow_forward,
                    onPressed: () {
                      if (_page == 2) {
                        replaceWith(context, const LoginScreen());
                      } else {
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Icon(icon, size: 82, color: color),
        ),
        const SizedBox(height: 28),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: kText,
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: kTextMuted, height: 1.45),
        ),
      ],
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _emailLoading = false;
  bool _googleLoading = false;
  String? _errorMessage;

  bool get _isLoading => _emailLoading || _googleLoading;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    setState(() {
      _emailLoading = true;
      _errorMessage = null;
    });

    try {
      await AuthService.instance.signInWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } on AuthException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _emailLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _googleLoading = true;
      _errorMessage = null;
    });

    try {
      await AuthService.instance.signInWithGoogle();
    } on AuthException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _googleLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: AppScroll(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 30),
          Image.asset(
            'assets/images/jihc_logo.png',
            width: 100,
            height: 100,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 20),
          const Text(
            'Welcome back',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sign in to book halls and message admins.',
            textAlign: TextAlign.center,
            style: TextStyle(color: kTextMuted),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _emailController,
            enabled: !_isLoading,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.mail_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            enabled: !_isLoading,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: kError,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 18),
          AppButton(
            label: 'Sign In',
            icon: Icons.login,
            loading: _emailLoading,
            onPressed: _isLoading ? null : _signInWithEmail,
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'Continue with Google',
            icon: Icons.g_mobiledata,
            outline: true,
            loading: _googleLoading,
            onPressed: _isLoading ? null : _signInWithGoogle,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => pushPage(context, const RegisterScreen()),
            child: const Text('Create a student account'),
          ),
        ],
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _studentIdController = TextEditingController(text: identityId);
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _studentIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      await AuthService.instance.registerWithEmail(
        fullName: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on AuthException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Register',
      subtitle: 'JIHC Hall Booking',
      body: AppScroll(
        children: [
          const Text(
            'Create your account',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your student ID connects booking requests to your profile.',
            style: TextStyle(color: kTextMuted),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _nameController,
            enabled: !_loading,
            decoration: const InputDecoration(
              labelText: 'Full name',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            enabled: !_loading,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.mail_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _studentIdController,
            enabled: !_loading,
            decoration: const InputDecoration(
              labelText: 'Student ID',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            enabled: !_loading,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: kError,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 18),
          AppButton(
            label: 'Create Account',
            icon: Icons.person_add_alt_1,
            loading: _loading,
            onPressed: _loading ? null : _register,
          ),
        ],
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      showBack: false,
      title: 'Magzhan',
      subtitle: 'Good morning',
      currentTab: 0,
      actions: [
        IconButton(
          tooltip: 'Notifications',
          icon: const Icon(Icons.notifications_none),
          onPressed: () => pushPage(context, const NotificationsScreen()),
        ),
      ],
      body: AppScroll(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kPrimary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Book a hall for your event',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Sport, Act, and Auditorium slots are available today.',
                        style: TextStyle(color: Color(0xFFB5D4F4)),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Browse halls',
                  onPressed: () => pushPage(context, const HallListScreen()),
                  icon: const Icon(Icons.arrow_forward),
                ),
              ],
            ),
          ),
          SectionTitle(
            'Available Halls',
            trailing: TextButton(
              onPressed: () => pushPage(context, const HallListScreen()),
              child: const Text('View all'),
            ),
          ),
          SizedBox(
            height: 208,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: halls.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) => HallMiniCard(hall: halls[index]),
            ),
          ),
          SectionTitle(
            'Recent Bookings',
            trailing: TextButton(
              onPressed: () => openMainTab(context, 1),
              child: const Text('Manage'),
            ),
          ),
          ...bookings
              .take(2)
              .map(
                (booking) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: BookingRow(
                    booking: booking,
                    onTap: () => pushPage(
                      context,
                      BookingDetailScreen(booking: booking),
                    ),
                  ),
                ),
              ),
          const SectionTitle('Quick Actions'),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Book Hall',
                  icon: Icons.add_circle_outline,
                  onPressed: () => pushPage(context, const HallListScreen()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'Message',
                  icon: Icons.chat_bubble_outline,
                  outline: true,
                  onPressed: () => openMainTab(context, 2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class HallMiniCard extends StatelessWidget {
  const HallMiniCard({super.key, required this.hall});

  final Hall hall;

  @override
  Widget build(BuildContext context) {
    final isBusy = hall.availability.toLowerCase().contains('busy');
    return InkWell(
      onTap: () => pushPage(context, HallDetailScreen(hall: hall)),
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 176,
        child: SurfaceBox(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HallVisual(hall: hall, height: 104, radius: 10),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hall.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${hall.capacity} people',
                      style: const TextStyle(color: kTextMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isBusy ? kErrorSoft : kSuccessSoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isBusy ? 'Busy' : 'Available',
                        style: TextStyle(
                          color: isBusy ? kError : kSuccess,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Notifications',
      body: AppScroll(
        children: [
          _NotificationRow(
            color: kWarning,
            icon: Icons.hourglass_top,
            title: 'Sport Hall request is pending',
            text: 'Admin is reviewing May 30, 2026 at 10:00.',
          ),
          _NotificationRow(
            color: kSuccess,
            icon: Icons.check_circle,
            title: 'Act Hall approved',
            text: 'Your rehearsal booking is ready.',
          ),
          _NotificationRow(
            color: kPrimary,
            icon: Icons.chat_bubble,
            title: 'New admin message',
            text: 'Please confirm your expected participant count.',
          ),
        ],
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.color,
    required this.icon,
    required this.title,
    required this.text,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SurfaceBox(
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(text, style: const TextStyle(color: kTextMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HallListScreen extends StatelessWidget {
  const HallListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Halls',
      subtitle: 'Choose a space',
      currentTab: 1,
      body: AppScroll(
        children: [
          const Text(
            'Browse college halls',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'Each card shows capacity, location, and the next booking status.',
            style: TextStyle(color: kTextMuted),
          ),
          const SizedBox(height: 16),
          ...halls.map(
            (hall) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: HallListCard(hall: hall),
            ),
          ),
        ],
      ),
    );
  }
}

class HallListCard extends StatelessWidget {
  const HallListCard({super.key, required this.hall});

  final Hall hall;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => pushPage(context, HallDetailScreen(hall: hall)),
      borderRadius: BorderRadius.circular(10),
      child: SurfaceBox(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HallVisual(hall: hall, height: 150, radius: 10),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          hall.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Icon(Icons.favorite_border, color: hall.accent),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${hall.location} - Capacity: ${hall.capacity}',
                    style: const TextStyle(color: kTextMuted),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      InfoChip(
                        icon: Icons.groups,
                        label: '${hall.capacity}',
                        color: hall.accent,
                        background: hall.tint,
                      ),
                      for (final feature in hall.features.take(2))
                        InfoChip(
                          icon: Icons.check_circle_outline,
                          label: feature,
                          color: hall.accent,
                          background: hall.tint,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          hall.availability,
                          style: TextStyle(
                            color: hall.availability.contains('Busy')
                                ? kError
                                : kSuccess,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 132,
                        child: AppButton(
                          label: 'Book Now',
                          onPressed: () =>
                              pushPage(context, HallDetailScreen(hall: hall)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HallDetailScreen extends StatelessWidget {
  const HallDetailScreen({super.key, required this.hall});

  final Hall hall;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: hall.name,
      subtitle: 'Hall detail',
      currentTab: 1,
      actions: [
        IconButton(
          tooltip: 'Save hall',
          icon: const Icon(Icons.favorite_border),
          onPressed: () {},
        ),
      ],
      body: AppScroll(
        padding: EdgeInsets.zero,
        children: [
          HallVisual(hall: hall, height: 230, radius: 0),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hall.name,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(hall.location, style: const TextStyle(color: kTextMuted)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    InfoChip(
                      icon: Icons.groups,
                      label: '${hall.capacity} people',
                      color: hall.accent,
                      background: hall.tint,
                    ),
                    for (final feature in hall.features)
                      InfoChip(
                        icon: Icons.done,
                        label: feature,
                        color: hall.accent,
                        background: hall.tint,
                      ),
                  ],
                ),
                const SectionTitle('Description'),
                Text(
                  hall.description,
                  style: const TextStyle(color: kTextMuted, height: 1.45),
                ),
                const SectionTitle('Rules'),
                SurfaceBox(
                  color: hall.tint,
                  borderColor: hall.tint,
                  child: Text(
                    hall.rules,
                    style: TextStyle(
                      color: hall.accent,
                      height: 1.45,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SectionTitle('Next Step'),
                AppButton(
                  label: 'Pick Date',
                  icon: Icons.calendar_month,
                  onPressed: () =>
                      pushPage(context, DatePickerScreen(hall: hall)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DatePickerScreen extends StatefulWidget {
  const DatePickerScreen({super.key, required this.hall});

  final Hall hall;

  @override
  State<DatePickerScreen> createState() => _DatePickerScreenState();
}

class _DatePickerScreenState extends State<DatePickerScreen> {
  int selectedDay = 30;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Pick a Date',
      subtitle: widget.hall.name,
      currentTab: 1,
      body: AppScroll(
        children: [
          SurfaceBox(
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous month',
                      onPressed: () {},
                      icon: const Icon(Icons.chevron_left, color: kPrimary),
                    ),
                    const Expanded(
                      child: Text(
                        'May 2026',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Next month',
                      onPressed: () {},
                      icon: const Icon(Icons.chevron_right, color: kPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const _WeekHeader(),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 35,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                  ),
                  itemBuilder: (context, index) {
                    final day = index - 3;
                    if (day < 1 || day > 31) {
                      return const SizedBox.shrink();
                    }
                    final disabled = day < 29 || day == 31;
                    final isSelected = day == selectedDay;
                    return InkWell(
                      onTap: disabled
                          ? null
                          : () => setState(() => selectedDay = day),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? kPrimary : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$day',
                          style: TextStyle(
                            color: disabled
                                ? const Color(0xFFC8CDD4)
                                : isSelected
                                ? Colors.white
                                : kText,
                            fontWeight: isSelected
                                ? FontWeight.w900
                                : FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SurfaceBox(
            color: kPrimarySoft,
            borderColor: kPrimarySoft,
            child: Row(
              children: [
                const Icon(Icons.event_available, color: kPrimary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Selected: May $selectedDay, 2026',
                    style: const TextStyle(
                      color: kPrimaryDark,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Continue to Time Slots',
            icon: Icons.schedule,
            onPressed: () => pushPage(
              context,
              TimeSlotScreen(
                hall: widget.hall,
                selectedDate: 'May $selectedDay, 2026',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader();

  @override
  Widget build(BuildContext context) {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 7,
      children: [
        for (final day in days)
          Center(
            child: Text(
              day,
              style: const TextStyle(
                color: kTextMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }
}

class TimeSlotScreen extends StatefulWidget {
  const TimeSlotScreen({
    super.key,
    required this.hall,
    required this.selectedDate,
  });

  final Hall hall;
  final String selectedDate;

  @override
  State<TimeSlotScreen> createState() => _TimeSlotScreenState();
}

class _TimeSlotScreenState extends State<TimeSlotScreen> {
  String selectedTime = '10:00-11:00';
  final busySlots = const {'09:00-10:00', '13:00-14:00'};
  final slots = const [
    '09:00-10:00',
    '10:00-11:00',
    '11:00-12:00',
    '12:00-13:00',
    '13:00-14:00',
    '14:00-15:00',
    '15:00-16:00',
    '16:00-17:00',
    '17:00-18:00',
  ];

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Time Slots',
      subtitle: widget.selectedDate,
      currentTab: 1,
      body: AppScroll(
        children: [
          SurfaceBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.hall.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Available slots are shown in blue. Busy slots are disabled.',
                  style: TextStyle(color: kTextMuted),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final slot in slots)
                      _SlotChip(
                        label: slot,
                        selected: selectedTime == slot,
                        disabled: busySlots.contains(slot),
                        onTap: () => setState(() => selectedTime = slot),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Continue to Request',
            icon: Icons.edit_note,
            onPressed: () => pushPage(
              context,
              BookingFormScreen(
                hall: widget.hall,
                selectedDate: widget.selectedDate,
                selectedTime: selectedTime,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.label,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = disabled
        ? const Color(0xFFB8BDC5)
        : selected
        ? Colors.white
        : kPrimary;
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? kPrimary : Colors.white,
          border: Border.all(color: disabled ? kBorder : kPrimary),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class BookingFormScreen extends StatelessWidget {
  const BookingFormScreen({
    super.key,
    required this.hall,
    required this.selectedDate,
    required this.selectedTime,
  });

  final Hall hall;
  final String selectedDate;
  final String selectedTime;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Booking Request',
      subtitle: hall.name,
      currentTab: 1,
      body: AppScroll(
        children: [
          SurfaceBox(
            color: kPrimarySoft,
            borderColor: kPrimarySoft,
            child: Column(
              children: [
                _SummaryLine(label: 'Hall', value: hall.name),
                _SummaryLine(label: 'Date', value: selectedDate),
                _SummaryLine(label: 'Time', value: selectedTime),
                const _SummaryLine(label: 'Status', value: 'Pending review'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const TextField(
            minLines: 5,
            maxLines: 6,
            decoration: InputDecoration(
              labelText: 'Purpose',
              alignLabelWithHint: true,
              hintText: 'Example: Sports event, club meeting, rehearsal...',
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Submit Request',
            icon: Icons.send,
            onPressed: () => pushPage(
              context,
              BookingConfirmedScreen(
                hall: hall,
                selectedDate: selectedDate,
                selectedTime: selectedTime,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: kPrimaryDark,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: kPrimaryDark,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BookingConfirmedScreen extends StatelessWidget {
  const BookingConfirmedScreen({
    super.key,
    required this.hall,
    required this.selectedDate,
    required this.selectedTime,
  });

  final Hall hall;
  final String selectedDate;
  final String selectedTime;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Confirmed',
      subtitle: 'Request submitted',
      currentTab: 1,
      body: AppScroll(
        children: [
          const SizedBox(height: 20),
          const Icon(Icons.check_circle, color: kSuccess, size: 92),
          const SizedBox(height: 14),
          const Text(
            'Booking request sent',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            '${hall.name} on $selectedDate at $selectedTime is now pending admin approval.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: kTextMuted, height: 1.45),
          ),
          const SizedBox(height: 18),
          const SurfaceBox(
            color: kPrimarySoft,
            borderColor: kPrimarySoft,
            child: Column(
              children: [
                _SummaryLine(label: 'Booking ID', value: 'JH-2401'),
                _SummaryLine(label: 'Chat', value: 'Created automatically'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AppButton(
            label: 'Go to Chat',
            icon: Icons.chat_bubble_outline,
            onPressed: () => pushPage(context, const BookingChatScreen()),
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'View My Bookings',
            icon: Icons.calendar_month,
            outline: true,
            onPressed: () => openMainTab(context, 1),
          ),
        ],
      ),
    );
  }
}

class MyBookingsScreen extends StatelessWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: AppScaffold(
        showBack: false,
        title: 'My Bookings',
        currentTab: 1,
        actions: [
          IconButton(
            tooltip: 'Browse halls',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => pushPage(context, const HallListScreen()),
          ),
        ],
        body: Column(
          children: [
            const Material(
              color: Colors.white,
              child: TabBar(
                labelColor: kPrimary,
                unselectedLabelColor: kTextMuted,
                indicatorColor: kPrimary,
                tabs: [
                  Tab(text: 'All'),
                  Tab(text: 'Pending'),
                  Tab(text: 'Approved'),
                  Tab(text: 'Rejected'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _BookingsTab(bookings: bookings),
                  _BookingsTab(
                    bookings: bookings
                        .where((b) => b.status == BookingStatus.pending)
                        .toList(),
                  ),
                  _BookingsTab(
                    bookings: bookings
                        .where((b) => b.status == BookingStatus.approved)
                        .toList(),
                  ),
                  _BookingsTab(
                    bookings: bookings
                        .where((b) => b.status == BookingStatus.rejected)
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingsTab extends StatelessWidget {
  const _BookingsTab({required this.bookings});

  final List<Booking> bookings;

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return const EmptyState(
        icon: Icons.event_busy,
        title: 'No bookings here',
        text: 'Book a hall and your request will appear in this tab.',
      );
    }
    return AppScroll(
      children: [
        for (final booking in bookings)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: BookingRow(
              booking: booking,
              showPurpose: true,
              onTap: () =>
                  pushPage(context, BookingDetailScreen(booking: booking)),
            ),
          ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: kPrimary),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: kTextMuted, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class BookingDetailScreen extends StatelessWidget {
  const BookingDetailScreen({super.key, required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Booking Detail',
      subtitle: booking.id,
      currentTab: 1,
      body: AppScroll(
        children: [
          HallVisual(hall: booking.hall, height: 160),
          const SizedBox(height: 14),
          SurfaceBox(
            color: kPrimarySoft,
            borderColor: kPrimarySoft,
            child: Column(
              children: [
                _SummaryLine(label: 'Hall', value: booking.hall.name),
                _SummaryLine(label: 'Date', value: booking.date),
                _SummaryLine(label: 'Time', value: booking.time),
                _SummaryLine(label: 'Purpose', value: booking.purpose),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      const Text(
                        'Status',
                        style: TextStyle(
                          color: kPrimaryDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      StatusBadge(booking.status),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Open Chat',
                  icon: Icons.chat_bubble_outline,
                  outline: true,
                  onPressed: () => pushPage(context, const BookingChatScreen()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'Cancel',
                  icon: Icons.cancel_outlined,
                  outline: true,
                  color: kError,
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ChatsListScreen extends StatelessWidget {
  const ChatsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      showBack: false,
      title: 'Messages',
      currentTab: 2,
      actions: [
        IconButton(
          tooltip: 'New chat',
          icon: const Icon(Icons.edit_square),
          onPressed: () => pushPage(context, const NewChatScreen()),
        ),
      ],
      floatingActionButton: FloatingActionButton(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        onPressed: () => pushPage(context, const NewChatScreen()),
        child: const Icon(Icons.add_comment),
      ),
      body: AppScroll(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
        children: [
          const TextField(
            decoration: InputDecoration(
              hintText: 'Search chats...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const _ChatSectionLabel('BOOKING CHATS'),
          ChatRow(
            preview: chatPreviews[0],
            onTap: () => pushPage(context, const BookingChatScreen()),
          ),
          ChatRow(
            preview: chatPreviews[1],
            onTap: () => pushPage(context, const BookingChatScreen()),
          ),
          const _ChatSectionLabel('DIRECT'),
          ChatRow(
            preview: chatPreviews[2],
            onTap: () => pushPage(context, const AdminDirectChatScreen()),
          ),
          const _ChatSectionLabel('GROUPS'),
          ChatRow(
            preview: chatPreviews[3],
            onTap: () => pushPage(context, const GroupChatScreen()),
          ),
        ],
      ),
    );
  }
}

class _ChatSectionLabel extends StatelessWidget {
  const _ChatSectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: kPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class ChatRow extends StatelessWidget {
  const ChatRow({super.key, required this.preview, this.onTap});

  final ChatPreview preview;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SurfaceBox(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: preview.color,
                  borderRadius: BorderRadius.circular(
                    preview.isGroup ? 10 : 24,
                  ),
                ),
                child: Icon(preview.icon, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preview.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: kText,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      preview.preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: kTextMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    preview.time,
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 12,
                    ),
                  ),
                  if (preview.unread > 0) ...[
                    const SizedBox(height: 5),
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: kPrimary,
                      child: Text(
                        '${preview.unread}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BookingChatScreen extends StatelessWidget {
  const BookingChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ChatThreadScreen(
      chatId: 'booking-sport-hall',
      title: 'Sport Hall Booking',
      subtitle: 'Pending approval',
      status: BookingStatus.pending,
      systemText: 'Booking submitted - awaiting admin approval.',
    );
  }
}

class AdminDirectChatScreen extends StatelessWidget {
  const AdminDirectChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ChatThreadScreen(
      chatId: 'admin-support',
      title: 'Admin Support',
      subtitle: 'Usually replies fast',
      systemText: 'Direct support chat opened.',
    );
  }
}

class GroupChatScreen extends StatelessWidget {
  const GroupChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ChatThreadScreen(
      chatId: 'event-organizers',
      title: 'Event Organizers',
      subtitle: '12 members',
      systemText: 'Group chat for event organizers.',
    );
  }
}

enum _MessageAction { edit, delete }

class ChatThreadScreen extends StatefulWidget {
  const ChatThreadScreen({
    super.key,
    required this.chatId,
    required this.title,
    required this.subtitle,
    required this.systemText,
    this.status,
  });

  final String chatId;
  final String title;
  final String subtitle;
  final String systemText;
  final BookingStatus? status;

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();

  bool _sendingText = false;
  bool _uploadingImage = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendText() async {
    if (_sendingText) return;

    final text = _messageController.text.trim();
    if (text.isEmpty) {
      _showSnack('Type a message before sending.');
      return;
    }

    _messageController.clear();
    setState(() => _sendingText = true);

    try {
      await ChatService.instance.sendTextMessage(
        chatId: widget.chatId,
        text: text,
      );
    } catch (error) {
      if (!mounted) return;
      _messageController.text = text;
      _messageController.selection = TextSelection.collapsed(
        offset: _messageController.text.length,
      );
      _showSnack(_chatErrorMessage(error));
    } finally {
      if (mounted) setState(() => _sendingText = false);
    }
  }

  Future<void> _openAttachmentOptions() async {
    if (_uploadingImage) return;
    FocusScope.of(context).unfocus();

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Camera'),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Gallery'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (source == null || !mounted) return;
    await _pickAndSendImage(source);
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (image == null || !mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      setState(() => _uploadingImage = true);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Processing image...'),
            duration: Duration(days: 1),
          ),
        );

      await ChatService.instance.sendImageMessage(
        chatId: widget.chatId,
        image: image,
      );
      messenger.hideCurrentSnackBar();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _showSnack(_chatErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _showMessageActions(ChatMessage message) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || message.senderId != currentUserId) return;

    final action = await showModalBottomSheet<_MessageAction>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.isText)
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Edit message'),
                  onTap: () =>
                      Navigator.of(sheetContext).pop(_MessageAction.edit),
                ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: kError),
                title: const Text('Delete message'),
                textColor: kError,
                onTap: () =>
                    Navigator.of(sheetContext).pop(_MessageAction.delete),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) return;
    switch (action) {
      case _MessageAction.edit:
        await _editMessage(message);
      case _MessageAction.delete:
        await _deleteMessage(message);
    }
  }

  Future<void> _editMessage(ChatMessage message) async {
    final controller = TextEditingController(text: message.text);
    final editedText = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit message'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 4,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Message'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isEmpty) return;
                Navigator.of(dialogContext).pop(text);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (editedText == null || editedText == message.text.trim()) return;

    try {
      await ChatService.instance.editTextMessage(
        message: message,
        text: editedText,
      );
    } catch (error) {
      if (mounted) _showSnack(_chatErrorMessage(error));
    }
  }

  Future<void> _deleteMessage(ChatMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete message?'),
          content: const Text('This removes the message from the chat.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kError),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await ChatService.instance.deleteMessage(message);
    } catch (error) {
      if (mounted) _showSnack(_chatErrorMessage(error));
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _chatErrorMessage(Object? error) {
    if (error is AuthException) return error.message;
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return 'Firebase rules blocked this chat action.';
      }
      return error.message ?? 'Chat action failed. Please try again.';
    }
    return 'Chat action failed. Please try again.';
  }

  String _messageTime(BuildContext context, ChatMessage message) {
    return TimeOfDay.fromDateTime(message.displayDate).format(context);
  }

  Widget _buildMessagesList() {
    return Expanded(
      child: StreamBuilder<List<ChatMessage>>(
        stream: ChatService.instance.messagesStream(widget.chatId),
        builder: (context, snapshot) {
          final messages = snapshot.data ?? const <ChatMessage>[];
          final currentUserId = FirebaseAuth.instance.currentUser?.uid;

          if (snapshot.hasData) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _scrollToBottom();
            });
          }

          return SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  children: [
                    Text(
                      widget.systemText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (snapshot.hasError)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          _chatErrorMessage(snapshot.error),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: kError),
                        ),
                      )
                    else if (messages.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Text(
                          'No messages yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: kTextMuted),
                        ),
                      )
                    else
                      ...messages.map((message) {
                        final isMe = message.senderId == currentUserId;
                        return ChatBubble(
                          text: message.text,
                          imageBase64: message.imageBase64.isEmpty
                              ? null
                              : message.imageBase64,
                          time: _messageTime(context, message),
                          isMe: isMe,
                          isEdited: message.isEdited,
                          onLongPress: isMe
                              ? () => _showMessageActions(message)
                              : null,
                        );
                      }),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: widget.title,
      subtitle: widget.subtitle,
      currentTab: 2,
      actions: [
        IconButton(
          tooltip: 'Attach image',
          icon: _uploadingImage
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.attach_file),
          onPressed: _uploadingImage ? null : _openAttachmentOptions,
        ),
      ],
      body: Column(
        children: [
          if (widget.status != null)
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: Center(child: StatusBadge(widget.status!)),
            ),
          _buildMessagesList(),
          ChatInputBar(
            controller: _messageController,
            sending: _sendingText,
            uploading: _uploadingImage,
            onAttach: _openAttachmentOptions,
            onSend: _sendText,
          ),
        ],
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.text,
    required this.time,
    required this.isMe,
    this.imageBase64,
    this.isEdited = false,
    this.onLongPress,
  }) : system = false;

  const ChatBubble.system({super.key, required this.text})
    : time = '',
      isMe = false,
      imageBase64 = null,
      isEdited = false,
      onLongPress = null,
      system = true;

  final String text;
  final String time;
  final bool isMe;
  final String? imageBase64;
  final bool isEdited;
  final VoidCallback? onLongPress;
  final bool system;

  @override
  Widget build(BuildContext context) {
    if (system) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: kSuccess, fontWeight: FontWeight.w800),
        ),
      );
    }
    final resolvedImageBase64 = imageBase64?.trim() ?? '';
    final timeText = isEdited ? '$time (edited)' : time;

    return GestureDetector(
      onLongPress: onLongPress,
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: isMe ? kPrimary : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(isMe ? 14 : 3),
              bottomRight: Radius.circular(isMe ? 3 : 14),
            ),
            border: isMe ? null : Border.all(color: kBorder),
          ),
          child: Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (resolvedImageBase64.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _MemoryChatImage(
                    imageBase64: resolvedImageBase64,
                    isMe: isMe,
                  ),
                ),
                if (text.isNotEmpty) const SizedBox(height: 8),
              ],
              if (text.isNotEmpty)
                Text(
                  text,
                  style: TextStyle(color: isMe ? Colors.white : kText),
                ),
              const SizedBox(height: 3),
              Text(
                timeText,
                style: TextStyle(
                  color: isMe ? const Color(0xFFB5D4F4) : kTextMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemoryChatImage extends StatelessWidget {
  const _MemoryChatImage({required this.imageBase64, required this.isMe});

  final String imageBase64;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    try {
      final imageBytes = base64Decode(imageBase64);
      if (imageBytes.isEmpty) return _BrokenChatImage(isMe: isMe);

      return Image.memory(
        imageBytes,
        width: 240,
        height: 180,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _BrokenChatImage(isMe: isMe);
        },
      );
    } catch (_) {
      return _BrokenChatImage(isMe: isMe);
    }
  }
}

class _BrokenChatImage extends StatelessWidget {
  const _BrokenChatImage({required this.isMe});

  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      height: 180,
      color: isMe ? Colors.white.withValues(alpha: 0.14) : kBackground,
      child: Icon(
        Icons.broken_image_outlined,
        color: isMe ? Colors.white : kTextMuted,
      ),
    );
  }
}

class ChatInputBar extends StatelessWidget {
  const ChatInputBar({
    super.key,
    required this.controller,
    required this.onAttach,
    required this.onSend,
    this.sending = false,
    this.uploading = false,
  });

  final TextEditingController controller;
  final VoidCallback onAttach;
  final VoidCallback onSend;
  final bool sending;
  final bool uploading;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: kBorder)),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Attach',
              icon: uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.attach_file, color: kTextMuted),
              onPressed: uploading ? null : onAttach,
            ),
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !sending,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                minLines: 1,
                maxLines: 4,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  filled: true,
                  fillColor: Color(0xFFF0F2F5),
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.all(Radius.circular(22)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.all(Radius.circular(22)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.all(Radius.circular(22)),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: kPrimary,
              child: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : IconButton(
                      tooltip: 'Send',
                      icon: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: onSend,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class NewChatScreen extends StatelessWidget {
  const NewChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'New Chat',
      subtitle: 'Start a conversation',
      currentTab: 2,
      body: AppScroll(
        children: [
          const TextField(
            decoration: InputDecoration(
              hintText: 'Search students, groups, or admin...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SectionTitle('Suggested'),
          MenuRow(
            icon: Icons.support_agent,
            title: 'Admin Support',
            subtitle: 'Ask questions about bookings',
            onTap: () => pushPage(context, const AdminDirectChatScreen()),
          ),
          MenuRow(
            icon: Icons.sports_basketball,
            title: 'Sport Hall Booking',
            subtitle: 'Continue the active booking thread',
            onTap: () => pushPage(context, const BookingChatScreen()),
          ),
          MenuRow(
            icon: Icons.groups,
            title: 'Event Organizers',
            subtitle: 'Group chat for event planning',
            onTap: () => pushPage(context, const GroupChatScreen()),
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      showBack: false,
      title: 'Profile',
      currentTab: 3,
      body: AppScroll(
        padding: EdgeInsets.zero,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 28, 16, 22),
            color: kPrimary,
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 38,
                  backgroundColor: Colors.white,
                  child: Text(
                    'MS',
                    style: TextStyle(
                      color: kPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  identityName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'ID: $identityId',
                  style: TextStyle(color: Color(0xFFB5D4F4)),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => pushPage(context, const EditProfileScreen()),
                  icon: const Icon(Icons.edit, size: 17),
                  label: const Text('Edit Profile'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Expanded(
                      child: StatCard(number: '5', label: 'Total'),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: StatCard(
                        number: '3',
                        label: 'Approved',
                        color: kSuccess,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: StatCard(
                        number: '1',
                        label: 'Pending',
                        color: kWarning,
                      ),
                    ),
                  ],
                ),
                const _MenuGroupLabel('ACCOUNT'),
                MenuRow(
                  icon: Icons.notifications_none,
                  title: 'Notifications',
                  onTap: () => pushPage(context, const NotificationsScreen()),
                ),
                MenuRow(
                  icon: Icons.calendar_month,
                  title: 'My Bookings',
                  onTap: () => openMainTab(context, 1),
                ),
                MenuRow(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  onTap: () => pushPage(context, const SettingsScreen()),
                ),
                const _MenuGroupLabel('ABOUT'),
                MenuRow(
                  icon: Icons.info_outline,
                  title: 'About App',
                  onTap: () => pushPage(context, const AboutScreen()),
                ),
                MenuRow(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Admin Panel',
                  subtitle: 'Role-gated booking review screens',
                  onTap: () => pushPage(context, const AdminBookingsScreen()),
                ),
                const IdentityCard(),
                const SizedBox(height: 8),
                MenuRow(
                  icon: Icons.logout,
                  title: 'Log Out',
                  color: kError,
                  trailing: const SizedBox.shrink(),
                  onTap: () => signOutAndReturnToLogin(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.number,
    required this.label,
    this.color = kPrimary,
  });

  final String number;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SurfaceBox(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        children: [
          Text(
            number,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(label, style: const TextStyle(color: kTextMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _MenuGroupLabel extends StatelessWidget {
  const _MenuGroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: kTextMuted,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class IdentityCard extends StatelessWidget {
  const IdentityCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 8),
      child: SurfaceBox(
        color: kPrimarySoft,
        borderColor: kPrimarySoft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DEVELOPER IDENTITY',
              style: TextStyle(
                color: kPrimaryDark,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            SizedBox(height: 8),
            Text(
              identityName,
              style: TextStyle(
                color: kPrimaryDark,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Student ID: $identityId',
              style: TextStyle(color: kPrimaryDark),
            ),
            SizedBox(height: 10),
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: kPrimary,
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                  ),
                  child: SizedBox(width: 18, height: 18),
                ),
                SizedBox(width: 8),
                Text(
                  accentLabel,
                  style: TextStyle(
                    color: kPrimaryDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Edit Profile',
      subtitle: 'Account',
      currentTab: 3,
      body: AppScroll(
        children: [
          const Center(
            child: CircleAvatar(
              radius: 46,
              backgroundColor: kPrimary,
              child: Text(
                'MS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Gallery',
                  icon: Icons.photo_library_outlined,
                  outline: true,
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'Camera',
                  icon: Icons.photo_camera_outlined,
                  outline: true,
                  onPressed: () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const TextField(
            controller: null,
            decoration: InputDecoration(
              labelText: 'Full name',
              hintText: identityName,
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          const TextField(
            enabled: false,
            decoration: InputDecoration(
              labelText: 'Student ID',
              hintText: identityId,
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 12),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Email',
              hintText: 'magzhan@student.jihc.kz',
              prefixIcon: Icon(Icons.mail_outline),
            ),
          ),
          const SizedBox(height: 18),
          AppButton(
            label: 'Save Changes',
            icon: Icons.save_outlined,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool notifications = true;
  bool reminders = true;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Settings',
      subtitle: 'Preferences',
      currentTab: 3,
      body: AppScroll(
        children: [
          MenuRow(
            icon: Icons.notifications_active_outlined,
            title: 'Notifications',
            subtitle: 'Booking status and chat alerts',
            trailing: Switch(
              value: notifications,
              activeThumbColor: kPrimary,
              onChanged: (value) => setState(() => notifications = value),
            ),
          ),
          MenuRow(
            icon: Icons.alarm_outlined,
            title: 'Booking Reminders',
            subtitle: 'Remind me before approved events',
            trailing: Switch(
              value: reminders,
              activeThumbColor: kPrimary,
              onChanged: (value) => setState(() => reminders = value),
            ),
          ),
          const SectionTitle('Language'),
          SurfaceBox(
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'en', label: Text('English')),
                      ButtonSegment(value: 'kk', label: Text('Kazakh')),
                    ],
                    selected: const {'en'},
                    onSelectionChanged: (_) {},
                  ),
                ),
              ],
            ),
          ),
          const SectionTitle('Session'),
          AppButton(
            label: 'Log Out',
            icon: Icons.logout,
            color: kError,
            onPressed: () => signOutAndReturnToLogin(context),
          ),
        ],
      ),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'About',
      subtitle: 'Identity',
      currentTab: 3,
      body: AppScroll(
        children: [
          const IdentityCard(),
          const SectionTitle('App'),
          const SurfaceBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AboutLine(
                  label: 'Name',
                  value: 'JIHC Hall Booking & Messenger',
                ),
                _AboutLine(label: 'Version', value: '1.0.0 prototype'),
                _AboutLine(label: 'Theme', value: accentLabel),
                _AboutLine(
                  label: 'Platform',
                  value: 'Flutter + Firebase ready',
                ),
              ],
            ),
          ),
          const SectionTitle('Purpose'),
          const Text(
            'This app helps JIHC students request halls, track booking status, and keep admin communication in one real-time messenger.',
            style: TextStyle(color: kTextMuted, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _AboutLine extends StatelessWidget {
  const _AboutLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: const TextStyle(
                color: kTextMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminBookingsScreen extends StatefulWidget {
  const AdminBookingsScreen({super.key});

  @override
  State<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends State<AdminBookingsScreen> {
  String filter = 'All';

  @override
  Widget build(BuildContext context) {
    final filtered = filter == 'All'
        ? bookings
        : bookings.where((booking) => booking.hall.name == filter).toList();

    return AppScaffold(
      title: 'Admin Bookings',
      subtitle: 'Role gated',
      currentTab: 3,
      body: AppScroll(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final label in ['All', ...halls.map((hall) => hall.name)])
                ChoiceChip(
                  label: Text(label),
                  selected: filter == label,
                  selectedColor: kPrimarySoft,
                  labelStyle: TextStyle(
                    color: filter == label ? kPrimary : kTextMuted,
                    fontWeight: FontWeight.w800,
                  ),
                  onSelected: (_) => setState(() => filter = label),
                ),
            ],
          ),
          const SectionTitle('Requests'),
          for (final booking in filtered)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: BookingRow(
                booking: booking,
                showPurpose: true,
                onTap: () => pushPage(
                  context,
                  AdminBookingActionScreen(booking: booking),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AdminBookingActionScreen extends StatelessWidget {
  const AdminBookingActionScreen({super.key, required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Review Request',
      subtitle: booking.id,
      currentTab: 3,
      body: AppScroll(
        children: [
          SurfaceBox(
            color: kPrimarySoft,
            borderColor: kPrimarySoft,
            child: Column(
              children: [
                _SummaryLine(label: 'Student', value: identityName),
                const _SummaryLine(label: 'Student ID', value: identityId),
                _SummaryLine(label: 'Hall', value: booking.hall.name),
                _SummaryLine(label: 'Date', value: booking.date),
                _SummaryLine(label: 'Time', value: booking.time),
                _SummaryLine(label: 'Purpose', value: booking.purpose),
              ],
            ),
          ),
          const SectionTitle('Admin Action'),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Approve',
                  icon: Icons.check_circle_outline,
                  color: kSuccess,
                  onPressed: () => pushPage(context, const BookingChatScreen()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'Reject',
                  icon: Icons.cancel_outlined,
                  color: kError,
                  onPressed: () => pushPage(context, const BookingChatScreen()),
                ),
              ),
            ],
          ),
          const SectionTitle('Linked Chat'),
          const SurfaceBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ChatBubble.system(
                  text: 'Booking request submitted. Awaiting admin approval.',
                ),
                ChatBubble(
                  text: 'Please review the participant count before approval.',
                  time: '09:38',
                  isMe: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Open Full Chat',
            icon: Icons.chat_bubble_outline,
            outline: true,
            onPressed: () => pushPage(context, const BookingChatScreen()),
          ),
        ],
      ),
    );
  }
}
