import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

const String adminPhoneNumber = '+967770197791';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(const WhatsAppProLiteApp());
}

class WhatsAppProLiteApp extends StatelessWidget {
  const WhatsAppProLiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WhatsApp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF075E54),
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00A884),
          primary: const Color(0xFF00A884),
        ),
      ),
      home: FirebaseAuth.instance.currentUser == null
          ? const PhoneAuthScreen()
          : const MainTabScreen(),
    );
  }
}

// ----------------- 1. شاشات التسجيل والتحقق -----------------
class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  void _sendCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;

    setState(() => _isLoading = true);

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
        _checkUserProfile();
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الإرسال: ${e.message}')),
        );
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() => _isLoading = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OTPScreen(verificationId: verificationId, phone: phone),
          ),
        );
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  void _checkUserProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

    if (mounted) {
      if (doc.exists && doc.data()!.containsKey('name')) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainTabScreen()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SetupProfileScreen()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('أدخل رقم هاتفك', style: TextStyle(color: Color(0xFF00A884), fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Text('سيرسل لك واتساب رسالة نصية (SMS) للتحقق من رقم هاتفك.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14)),
              const SizedBox(height: 30),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textAlign: TextAlign.left,
                decoration: InputDecoration(
                  hintText: '+967 7xx xxx xxx',
                  labelText: 'رقم الهاتف مع رمز الدولة',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00A884), width: 2)),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A884), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                  onPressed: _isLoading ? null : _sendCode,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('التالي', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OTPScreen extends StatefulWidget {
  final String verificationId;
  final String phone;
  const OTPScreen({super.key, required this.verificationId, required this.phone});

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;

  void _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: code,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);

      final uid = FirebaseAuth.instance.currentUser?.uid;
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (mounted) {
        if (doc.exists && doc.data()!.containsKey('name')) {
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainTabScreen()), (route) => false);
        } else {
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const SetupProfileScreen()), (route) => false);
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رمز التحقق غير صحيح!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('التحقق من الرقم'), centerTitle: true, backgroundColor: Colors.white, elevation: 0),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Text('تم إرسال رمز التحقق في رسالة نصية إلى:\n${widget.phone}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 30),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(hintText: '------', border: UnderlineInputBorder()),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A884), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                  onPressed: _isLoading ? null : _verifyCode,
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('تأكيد الدخول', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SetupProfileScreen extends StatefulWidget {
  const SetupProfileScreen({super.key});

  @override
  State<SetupProfileScreen> createState() => _SetupProfileScreenState();
}

class _SetupProfileScreenState extends State<SetupProfileScreen> {
  final _nameController = TextEditingController();
  File? _selectedImage;
  bool _isLoading = false;

  void _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 40);
    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  void _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى كتابة الاسم')));
      return;
    }

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    String photoUrl = '';

    if (_selectedImage != null) {
      final ref = FirebaseStorage.instance.ref().child('user_profiles').child('${user?.uid}.jpg');
      await ref.putFile(_selectedImage!);
      photoUrl = await ref.getDownloadURL();
    }

    await FirebaseFirestore.instance.collection('users').doc(user?.uid).set({
      'uid': user?.uid,
      'name': name,
      'phone': user?.phoneNumber,
      'photoUrl': photoUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainTabScreen()), (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('معلومات الملف الشخصي'), centerTitle: true, backgroundColor: Colors.white, elevation: 0),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Text('الرجاء كتابة اسمك واختيار صورة شخصية', style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 30),
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: const Color(0xFFE9EDEF),
                  backgroundImage: _selectedImage != null ? FileImage(_selectedImage!) : null,
                  child: _selectedImage == null ? const Icon(Icons.add_a_photo, size: 35, color: Colors.grey) : null,
                ),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(hintText: 'اكتب اسمك هنا...', border: UnderlineInputBorder()),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A884), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                  onPressed: _isLoading ? null : _saveProfile,
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('التالي', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------- 2. الشاشة الرئيسية مع التبويبات والخيارات كاملة -----------------
class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const WhatsAppChatsScreen(),
    const StatusTabScreen(),
    const CommunitiesTabScreen(),
    const CallsTabScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: _screens),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) => setState(() => _currentIndex = index),
          indicatorColor: const Color(0xFFD9FDD3),
          backgroundColor: Colors.white,
          elevation: 10,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble, color: Color(0xFF075E54)), label: 'الدردشات'),
            NavigationDestination(icon: Icon(Icons.update), selectedIcon: Icon(Icons.update, color: Color(0xFF075E54)), label: 'التحديثات'),
            NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people, color: Color(0xFF075E54)), label: 'المجتمعات'),
            NavigationDestination(icon: Icon(Icons.call_outlined), selectedIcon: Icon(Icons.call, color: Color(0xFF075E54)), label: 'المكالمات'),
          ],
        ),
      ),
    );
  }
}

// ----------------- 3. شاشة الدردشات والإعدادات -----------------
class WhatsAppChatsScreen extends StatelessWidget {
  const WhatsAppChatsScreen({super.key});

  void _openSupportChat(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final supportChatId = 'support_$uid';

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final userName = userDoc.data()?['name'] ?? 'مستخدم';

    await FirebaseFirestore.instance.collection('support_chats').doc(supportChatId).set({
      'userId': uid,
      'userName': userName,
      'lastMessage': 'طلب دعم فني',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(chatId: supportChatId, name: 'الدعم الفني والخدمات', isSupport: true),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPhone = FirebaseAuth.instance.currentUser?.phoneNumber;
    final bool isAdmin = currentPhone == adminPhoneNumber;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('واتساب', style: TextStyle(color: Color(0xFF00A884), fontSize: 25, fontWeight: FontWeight.bold)),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings, color: Color(0xFF075E54)),
              tooltip: 'لوحة تحكم المشرف',
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportAdminDashboard()));
              },
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            onSelected: (value) async {
              if (value == 'settings') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              } else if (value == 'logout') {
                await FirebaseAuth.instance.signOut();
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const PhoneAuthScreen()), (route) => false);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'group', child: Text('مجموعة جديدة')),
              const PopupMenuItem(value: 'devices', child: Text('الأجهزة المرتبطة')),
              const PopupMenuItem(value: 'starred', child: Text('الرسائل المميزة بنجمة')),
              const PopupMenuItem(value: 'settings', child: Text('الإعدادات')),
              const PopupMenuItem(value: 'logout', child: Text('تسجيل الخروج')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFFF0F2F5),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFF00A884),
                  child: Icon(Icons.headset_mic, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('فريق الدعم الفني', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('رقم المساعدة: +967770197791', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A884)),
                  onPressed: () => _openSupportChat(context),
                  child: const Text('مراسلة', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('chats').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;

                if (docs.isEmpty) return const Center(child: Text('لا توجد محادثات'));

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 25,
                        backgroundColor: const Color(0xFF00A884),
                        backgroundImage: data['photoUrl'] != null && data['photoUrl'].toString().isNotEmpty ? NetworkImage(data['photoUrl']) : null,
                        child: data['photoUrl'] == null || data['photoUrl'].toString().isEmpty ? Text((data['name'] ?? 'U')[0], style: const TextStyle(color: Colors.white)) : null,
                      ),
                      title: Text(data['name'] ?? 'مستخدم', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(data['lastMessage'] ?? 'اضغط للدردشة...', maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatDetailScreen(chatId: docs[index].id, name: data['name'] ?? 'مستخدم'),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------- 4. شاشة الدردشة الكاملة (نصوص، صور، وتسجيل صوتي حي) -----------------
class ChatDetailScreen extends StatefulWidget {
  final String chatId;
  final String name;
  final bool isSupport;
  const ChatDetailScreen({super.key, required this.chatId, required this.name, this.isSupport = false});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _controller = TextEditingController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isRecording = false;
  String? _currentlyPlayingUrl;

  void _sendMessage({String? text, String? imageUrl, String? audioUrl}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final collectionName = widget.isSupport ? 'support_chats' : 'chats';

    final messageData = {
      'senderId': uid,
      'text': text,
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
      'type': audioUrl != null ? 'audio' : (imageUrl != null ? 'image' : 'text'),
      'timestamp': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance.collection(collectionName).doc(widget.chatId).collection('messages').add(messageData);

    String lastMsg = text ?? (imageUrl != null ? '📷 صورة' : '🎤 مقطع صوتي');
    await FirebaseFirestore.instance.collection(collectionName).doc(widget.chatId).set({
      'name': widget.name,
      'lastMessage': lastMsg,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _sendTextMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    _sendMessage(text: text);
  }

  void _sendImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (picked != null) {
      final ref = FirebaseStorage.instance.ref().child('chat_images').child('${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(File(picked.path));
      final url = await ref.getDownloadURL();
      _sendMessage(imageUrl: url);
    }
  }

  void _toggleRecording() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      if (path != null) {
        final ref = FirebaseStorage.instance.ref().child('chat_audio').child('${DateTime.now().millisecondsSinceEpoch}.m4a');
        await ref.putFile(File(path));
        final url = await ref.getDownloadURL();
        _sendMessage(audioUrl: url);
      }
    } else {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final filePath = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(), path: filePath);
        setState(() => _isRecording = true);
      }
    }
  }

  void _playAudio(String url) async {
    if (_currentlyPlayingUrl == url) {
      await _audioPlayer.stop();
      setState(() => _currentlyPlayingUrl = null);
    } else {
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));
      setState(() => _currentlyPlayingUrl = url);
    }
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final collectionName = widget.isSupport ? 'support_chats' : 'chats';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFE5DDD5),
        appBar: AppBar(
          backgroundColor: const Color(0xFF075E54),
          title: Text(widget.name, style: const TextStyle(color: Colors.white, fontSize: 18)),
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
          actions: [
            IconButton(icon: const Icon(Icons.videocam, color: Colors.white), onPressed: () {}),
            IconButton(icon: const Icon(Icons.call, color: Colors.white), onPressed: () {}),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection(collectionName).doc(widget.chatId).collection('messages').orderBy('timestamp', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final messages = snapshot.data!.docs;

                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(10),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index].data() as Map<String, dynamic>;
                      bool isMe = msg['senderId'] == uid;
                      String type = msg['type'] ?? 'text';

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isMe ? const Color(0xFFE7FFDB) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: type == 'image'
                              ? Image.network(msg['imageUrl'], width: 200, height: 200, fit: BoxFit.cover)
                              : type == 'audio'
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(_currentlyPlayingUrl == msg['audioUrl'] ? Icons.pause : Icons.play_arrow, color: const Color(0xFF075E54)),
                                          onPressed: () => _playAudio(msg['audioUrl']),
                                        ),
                                        const Text('مقطع صوتي', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ],
                                    )
                                  : Text(msg['text'] ?? '', style: const TextStyle(fontSize: 15)),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.white,
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.attach_file, color: Colors.grey), onPressed: _sendImage),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: _isRecording ? 'جاري التسجيل...' : 'اكتب رسالة...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(_isRecording ? Icons.stop : Icons.mic, color: _isRecording ? Colors.red : const Color(0xFF00A884)),
                    onPressed: _toggleRecording,
                  ),
                  IconButton(icon: const Icon(Icons.send, color: Color(0xFF00A884)), onPressed: _sendTextMessage),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------- 5. التحديثات (الحالات) -----------------
class StatusTabScreen extends StatelessWidget {
  const StatusTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التحديثات'), backgroundColor: Colors.white, elevation: 0),
      body: ListView(
        children: [
          ListTile(
            leading: Stack(
              children: [
                const CircleAvatar(radius: 25, backgroundColor: Colors.grey, child: Icon(Icons.person, color: Colors.white)),
                Positioned(bottom: 0, right: 0, child: CircleAvatar(radius: 10, backgroundColor: const Color(0xFF00A884), child: const Icon(Icons.add, size: 15, color: Colors.white))),
              ],
            ),
            title: const Text('حالاتي', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('انقر لإضافة تحديث حالة'),
          ),
          const Padding(
            padding: EdgeInsets.all(12.0),
            child: Text('التحديثات الحديثة', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ----------------- 6. المجتمعات والمكالمات والإعدادات -----------------
class CommunitiesTabScreen extends StatelessWidget {
  const CommunitiesTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المجتمعات'), backgroundColor: Colors.white, elevation: 0),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A884)),
              onPressed: () {},
              child: const Text('إنشاء مجتمع جديد', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class CallsTabScreen extends StatelessWidget {
  const CallsTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المكالمات'), backgroundColor: Colors.white, elevation: 0),
      body: const Center(child: Text('لا توجد سجلات مكالمات حالياً')),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الإعدادات'), backgroundColor: const Color(0xFF075E54), foregroundColor: Colors.white),
        body: ListView(
          children: const [
            ListTile(leading: Icon(Icons.key), title: Text('الحساب'), subtitle: Text('الإشعارات والأمان وتغيير الرقم')),
            ListTile(leading: Icon(Icons.lock), title: Text('الخصوصية'), subtitle: Text('حظر جهات الاتصال والرسائل الاختفائية')),
            ListTile(leading: Icon(Icons.chat), title: Text('الدردشات'), subtitle: Text('المظهر والخلفية وسجل الدردشات')),
            ListTile(leading: Icon(Icons.notifications), title: Text('الإشعارات'), subtitle: Text('نغمات الرسائل والمجموعات')),
            ListTile(leading: Icon(Icons.data_usage), title: Text('التخزين والبيانات'), subtitle: Text('استخدام الشبكة والتنزيل التلقائي')),
            ListTile(leading: Icon(Icons.help_outline), title: Text('المساعدة'), subtitle: Text('مركز المساعدة واتصل بنا')),
          ],
        ),
      ),
    );
  }
}

// ----------------- 7. لوحة تحكم المشرف المحمية بالكامل -----------------
class SupportAdminDashboard extends StatelessWidget {
  const SupportAdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final currentPhone = FirebaseAuth.instance.currentUser?.phoneNumber;

    if (currentPhone != adminPhoneNumber) {
      return Scaffold(
        appBar: AppBar(title: const Text('غير مصرح')),
        body: const Center(child: Text('عذراً، لا تملك الصلاحيات الكافية لدخول هذه اللوحة!')),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF075E54),
            title: const Text('لوحة تحكم الأمان والدعم', style: TextStyle(color: Colors.white)),
            bottom: const TabBar(
              indicatorColor: Colors.white,
              tabs: [
                Tab(text: 'طلبات الدعم', icon: Icon(Icons.support_agent, color: Colors.white)),
                Tab(text: 'مراقبة المحادثات', icon: Icon(Icons.security, color: Colors.white)),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('support_chats').orderBy('updatedAt', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final docs = snapshot.data!.docs;

                  if (docs.isEmpty) return const Center(child: Text('لا توجد طلبات دعم حالياً'));

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      return ListTile(
                        leading: const CircleAvatar(backgroundColor: Color(0xFF00A884), child: Icon(Icons.person, color: Colors.white)),
                        title: Text(data['userName'] ?? 'مستخدم'),
                        subtitle: Text(data['lastMessage'] ?? 'رسالة دعم'),
                        trailing: const Icon(Icons.chat, color: Color(0xFF00A884)),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatDetailScreen(chatId: docs[index].id, name: 'الرد على: ${data['userName']}', isSupport: true),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('chats').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final docs = snapshot.data!.docs;

                  if (docs.isEmpty) return const Center(child: Text('لا توجد محادثات لمراقبتها'));

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      return ListTile(
                        leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.remove_red_eye, color: Colors.white)),
                        title: Text(data['name'] ?? 'محادثة عامة'),
                        subtitle: Text('آخر رسالة: ${data['lastMessage'] ?? ''}'),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatDetailScreen(chatId: docs[index].id, name: 'مراقبة: ${data['name']}'),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
