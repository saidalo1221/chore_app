import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VazifaApp());
}

// ============================================================
// MODELS
// ============================================================

enum ChoreStatus { active, pending }

class Chore {
  final String id;
  String name;
  int reward;
  ChoreStatus status;

  Chore({
    required this.id,
    required this.name,
    required this.reward,
    this.status = ChoreStatus.active,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'reward': reward,
        'status': status.index,
      };

  factory Chore.fromJson(Map<String, dynamic> json) => Chore(
        id: json['id'] as String,
        name: json['name'] as String,
        reward: json['reward'] as int,
        status: ChoreStatus.values[json['status'] as int],
      );
}

// ============================================================
// STATE MANAGEMENT (Provider) + LOCAL PERSISTENCE
// ============================================================

class ChoreProvider extends ChangeNotifier {
  static const String _coinsKey = 'vzm_coins';
  static const String _choresKey = 'vzm_chores';
  static const String _initKey = 'vzm_initialized';

  int _coins = 0;
  List<Chore> _chores = [];
  bool _isLoaded = false;

  int get coins => _coins;
  bool get isLoaded => _isLoaded;

  List<Chore> get activeChores =>
      _chores.where((c) => c.status == ChoreStatus.active).toList();

  List<Chore> get pendingChores =>
      _chores.where((c) => c.status == ChoreStatus.pending).toList();

  ChoreProvider() {
    _load();
  }

  String _generateId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(99999)}';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final bool alreadyInitialized = prefs.getBool(_initKey) ?? false;

    if (!alreadyInitialized) {
      _coins = 20;
      _chores = [
        Chore(id: _generateId(), name: "Krovatni yig'ishtirish", reward: 10),
        Chore(id: _generateId(), name: 'Idishlarni yuvish', reward: 15),
        Chore(id: _generateId(), name: 'Xonani tozalash', reward: 20),
        Chore(id: _generateId(), name: "Kitob o'qish (30 daqiqa)", reward: 15),
      ];
      await prefs.setBool(_initKey, true);
      await _persist(prefs);
    } else {
      _coins = prefs.getInt(_coinsKey) ?? 0;
      final String? choresJson = prefs.getString(_choresKey);
      if (choresJson != null && choresJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(choresJson) as List<dynamic>;
        _chores = decoded
            .map((e) => Chore.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _persist([SharedPreferences? existingPrefs]) async {
    final prefs = existingPrefs ?? await SharedPreferences.getInstance();
    await prefs.setInt(_coinsKey, _coins);
    await prefs.setString(
      _choresKey,
      jsonEncode(_chores.map((c) => c.toJson()).toList()),
    );
  }

  void completeChore(String id) {
    final index = _chores.indexWhere((c) => c.id == id);
    if (index == -1) return;
    _chores[index].status = ChoreStatus.pending;
    _persist();
    notifyListeners();
  }

  void approveChore(String id) {
    final index = _chores.indexWhere((c) => c.id == id);
    if (index == -1) return;
    _coins += _chores[index].reward;
    _chores.removeAt(index);
    _persist();
    notifyListeners();
  }

  void rejectChore(String id) {
    final index = _chores.indexWhere((c) => c.id == id);
    if (index == -1) return;
    _chores[index].status = ChoreStatus.active;
    _persist();
    notifyListeners();
  }

  void addChore(String name, int reward) {
    _chores.add(Chore(id: _generateId(), name: name, reward: reward));
    _persist();
    notifyListeners();
  }

  void deleteChore(String id) {
    _chores.removeWhere((c) => c.id == id);
    _persist();
    notifyListeners();
  }

  bool redeem(int cost) {
    if (_coins < cost) return false;
    _coins -= cost;
    _persist();
    notifyListeners();
    return true;
  }

  void adjustCoins(int delta) {
    _coins = (_coins + delta).clamp(0, 999999);
    _persist();
    notifyListeners();
  }

  void setCoins(int value) {
    _coins = value.clamp(0, 999999);
    _persist();
    notifyListeners();
  }
}

// ============================================================
// APP ROOT + THEME
// ============================================================

class VazifaApp extends StatelessWidget {
  const VazifaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChoreProvider(),
      child: MaterialApp(
        title: 'Vazifa va Mukofotlar',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        home: const HomeScreen(),
      ),
    );
  }

  ThemeData _buildTheme() {
    const deepBlue = Color(0xFF1B4DFF);
    const amber = Color(0xFFFFB300);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: deepBlue,
      brightness: Brightness.dark,
      secondary: amber,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF0A0E1B),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: amber,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1B2340),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1B2340),
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5, color: Colors.white),
        titleLarge: TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 18),
        titleMedium: TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 15),
        bodyMedium: TextStyle(fontWeight: FontWeight.w400, color: Colors.white70),
      ),
    );
  }
}

// ============================================================
// SHARED WIDGETS
// ============================================================

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? const Color(0xFF141A2E),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: child,
    );
  }
}

class TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const TapScale({super.key, required this.child, this.onTap});

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale> {
  double _scale = 1.0;

  void _setScale(double value) => setState(() => _scale = value);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _setScale(0.96),
      onTapUp: (_) => _setScale(1.0),
      onTapCancel: () => _setScale(1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleLarge);
  }
}

class EmptyState extends StatelessWidget {
  final String text;
  const EmptyState({required this.text, super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          text,
          style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 14),
        ),
      ),
    );
  }
}

// ============================================================
// HOME SCREEN (KID VIEW)
// ============================================================

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ChoreProvider>(
      builder: (context, provider, _) {
        if (!provider.isLoaded) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Vazifa va Mukofotlar',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 24,
                              letterSpacing: -0.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        TapScale(
                          onTap: () => showDialog(
                            context: context,
                            builder: (_) => const PinDialog(),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.admin_panel_settings_outlined,
                                  size: 17,
                                  color: Theme.of(context).colorScheme.secondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Admin paneli',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.secondary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  sliver: SliverToBoxAdapter(child: CoinCard(coins: provider.coins)),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  sliver: SliverToBoxAdapter(child: const SectionTitle("Vazifalar ro'yxati")),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: provider.activeChores.isEmpty
                      ? const SliverToBoxAdapter(
                          child: EmptyState(text: "Hozircha vazifalar yo'q"),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final chore = provider.activeChores[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: ChoreCard(chore: chore),
                              );
                            },
                            childCount: provider.activeChores.length,
                          ),
                        ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  sliver: SliverToBoxAdapter(child: const SectionTitle("O'yin vaqtini sotib olish")),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  sliver: SliverToBoxAdapter(child: const RedeemGrid()),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CoinCard extends StatelessWidget {
  final int coins;
  const CoinCard({required this.coins, super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, const Color(0xFF0B1740)],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(0.35),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mavjud tangalar:',
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('🪙', style: TextStyle(fontSize: 34)),
              const SizedBox(width: 10),
              Text(
                '$coins',
                style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Text(
                  'Tanga',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ChoreCard extends StatelessWidget {
  final Chore chore;
  const ChoreCard({required this.chore, super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: scheme.secondary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.checklist_rtl_rounded, color: scheme.secondary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(chore.name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '+${chore.reward} Tanga',
                  style: TextStyle(
                    color: scheme.secondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TapScale(
            onTap: () {
              context.read<ChoreProvider>().completeChore(chore.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tasdiqlash uchun admin ga yuborildi!')),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: scheme.secondary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Bajarildi!',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RedeemItemData {
  final String title;
  final int cost;
  final IconData icon;
  const RedeemItemData(this.title, this.cost, this.icon);
}

class RedeemGrid extends StatelessWidget {
  const RedeemGrid({super.key});

  static const List<RedeemItemData> items = [
    RedeemItemData('10 daqiqa Kompyuter', 10, Icons.computer_rounded),
    RedeemItemData('15 daqiqa Telefon', 10, Icons.smartphone_rounded),
    RedeemItemData('20 daqiqa Planshet', 10, Icons.tablet_mac_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: RedeemCard(item: item),
            ),
          )
          .toList(),
    );
  }
}

class RedeemCard extends StatelessWidget {
  final RedeemItemData item;
  const RedeemCard({required this.item, super.key});

  void _handleTap(BuildContext context) {
    final provider = context.read<ChoreProvider>();
    final success = provider.redeem(item.cost);

    if (success) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: const Color(0xFF141A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 44)),
                const SizedBox(height: 16),
                const Text(
                  "Vaqt sotib olindi! Akangga ko'rsat.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Yopish'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tangalar yetarli emas!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TapScale(
      onTap: () => _handleTap(context),
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(18, 14, 16, 14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: scheme.primary.withOpacity(0.28),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(item.icon, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(item.title, style: Theme.of(context).textTheme.titleMedium),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: scheme.secondary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🪙', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 5),
                  Text(
                    '${item.cost}',
                    style: TextStyle(color: scheme.secondary, fontWeight: FontWeight.w800),
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

// ============================================================
// PIN DIALOG
// ============================================================

class PinDialog extends StatefulWidget {
  const PinDialog({super.key});

  @override
  State<PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<PinDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  static const String _correctPin = '1234';

  void _submit() {
    if (_controller.text.trim() == _correctPin) {
      Navigator.of(context).pop();
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
      );
    } else {
      setState(() => _error = 'Xato parol');
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF141A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.lock_outline_rounded, color: Colors.white70, size: 30),
            const SizedBox(height: 14),
            const Text(
              'Admin parolini kiriting',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              obscureText: true,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 10, color: Colors.white),
              decoration: InputDecoration(
                hintText: '••••',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                errorText: _error,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Bekor qilish', style: TextStyle(color: Colors.white70)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submit,
                    child: const Text('Kirish'),
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

// ============================================================
// ADMIN PANEL
// ============================================================

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin paneli'),
        backgroundColor: const Color(0xFF0A0E1B),
      ),
      body: Consumer<ChoreProvider>(
        builder: (context, provider, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              const SectionTitle('Tasdiqlash kutilmoqda'),
              const SizedBox(height: 12),
              if (provider.pendingChores.isEmpty)
                const EmptyState(text: "Tasdiqlash kutilayotgan vazifalar yo'q")
              else
                ...provider.pendingChores.map(
                  (chore) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: PendingChoreCard(chore: chore),
                  ),
                ),
              const SizedBox(height: 30),
              const SectionTitle("Yangi vazifa qo'shish"),
              const SizedBox(height: 12),
              const AddChoreForm(),
              const SizedBox(height: 30),
              const SectionTitle('Tangalarni sozlash'),
              const SizedBox(height: 12),
              CoinAdjustPanel(coins: provider.coins),
              const SizedBox(height: 30),
              const SectionTitle('Barcha faol vazifalar'),
              const SizedBox(height: 12),
              if (provider.activeChores.isEmpty)
                const EmptyState(text: "Faol vazifalar yo'q")
              else
                ...provider.activeChores.map(
                  (chore) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ManageChoreCard(chore: chore),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class PendingChoreCard extends StatelessWidget {
  final Chore chore;
  const PendingChoreCard({required this.chore, super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(chore.name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '+${chore.reward} Tanga',
                  style: TextStyle(color: scheme.secondary, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ],
            ),
          ),
          TapScale(
            onTap: () => context.read<ChoreProvider>().approveChore(chore.id),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 32),
            ),
          ),
          const SizedBox(width: 6),
          TapScale(
            onTap: () => context.read<ChoreProvider>().rejectChore(chore.id),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 32),
            ),
          ),
        ],
      ),
    );
  }
}

class ManageChoreCard extends StatelessWidget {
  final Chore chore;
  const ManageChoreCard({required this.chore, super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(chore.name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '+${chore.reward} Tanga',
                  style: TextStyle(color: scheme.secondary, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ],
            ),
          ),
          TapScale(
            onTap: () {
              context.read<ChoreProvider>().deleteChore(chore.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Vazifa o'chirildi")),
              );
            },
            child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 26),
          ),
        ],
      ),
    );
  }
}

class AddChoreForm extends StatefulWidget {
  const AddChoreForm({super.key});

  @override
  State<AddChoreForm> createState() => _AddChoreFormState();
}

class _AddChoreFormState extends State<AddChoreForm> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _rewardController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _rewardController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final reward = int.tryParse(_rewardController.text.trim());

    if (name.isEmpty) {
      setState(() => _error = 'Vazifa nomini kiriting');
      return;
    }
    if (reward == null || reward <= 0) {
      setState(() => _error = "To'g'ri tanga miqdorini kiriting");
      return;
    }

    context.read<ChoreProvider>().addChore(name, reward);
    _nameController.clear();
    _rewardController.clear();
    setState(() => _error = null);
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Yangi vazifa qo'shildi!")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Vazifa nomi'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _rewardController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Tanga miqdori'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              child: const Text("Vazifani qo'shish"),
            ),
          ),
        ],
      ),
    );
  }
}

class CoinAdjustPanel extends StatefulWidget {
  final int coins;
  const CoinAdjustPanel({required this.coins, super.key});

  @override
  State<CoinAdjustPanel> createState() => _CoinAdjustPanelState();
}

class _CoinAdjustPanelState extends State<CoinAdjustPanel> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.coins}');
  }

  @override
  void didUpdateWidget(covariant CoinAdjustPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coins != widget.coins) {
      _controller.text = '${widget.coins}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AdjustButton(label: '-10', onTap: () => context.read<ChoreProvider>().adjustCoins(-10)),
              AdjustButton(label: '-5', onTap: () => context.read<ChoreProvider>().adjustCoins(-5)),
              AdjustButton(label: '+5', onTap: () => context.read<ChoreProvider>().adjustCoins(5)),
              AdjustButton(label: '+10', onTap: () => context.read<ChoreProvider>().adjustCoins(10)),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            "Balansni to'g'ridan-to'g'ri o'zgartirish",
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Yangi balans'),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  final value = int.tryParse(_controller.text.trim());
                  if (value != null) {
                    context.read<ChoreProvider>().setCoins(value);
                    FocusScope.of(context).unfocus();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Balans yangilandi!')),
                    );
                  }
                },
                child: const Text('Saqlash'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AdjustButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const AdjustButton({required this.label, required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TapScale(
      onTap: onTap,
      child: Container(
        width: 66,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: scheme.primary.withOpacity(0.28),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 14),
        ),
      ),
    );
  }
}
