import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';

void main() {
  runApp(const WineApp());
}

class WineApp extends StatelessWidget {
  const WineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VinoLab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.light(
        primary: const Color(0xFF7B1A2E),
        secondary: const Color(0xFFD4AF37),
        surface: Colors.white,
        background: const Color(0xFFF5F0F2),
        ),
      ),
      home: const WinePredictionScreen(),
    );
  }
}

class GradientBoostingModel {
  /// [CArg, CPr, CTrn, CA, CE, CM, CHA, CAA, CF]
  static double predict(List<double> features) {
    if (features.length != 9) {
      throw Exception("Expected 9 features");
    }

    const List<double> weights = [
      -0.156857,
      0.030231,
      -0.132361,
      -0.022097,
      -0.018851,
      0.030369,
      -0.012552,
      -0.005732,
      0.023363
    ];

    const double bias = 76.766157;

    double score = bias;

    for (int i = 0; i < features.length; i++) {
      score += features[i] * weights[i];
    }

    // мягкое ограничение диапазона
    if (score < 0) score = 0;
    if (score > 100) score = 100;

    return double.parse(score.toStringAsFixed(2));
  }
}

// ──────────────────────────────────────────────
// Главный экран
// ──────────────────────────────────────────────
class WinePredictionScreen extends StatefulWidget {
  const WinePredictionScreen({super.key});

  @override
  State<WinePredictionScreen> createState() => _WinePredictionScreenState();
}

class _WinePredictionScreenState extends State<WinePredictionScreen>
    with TickerProviderStateMixin {

  final List<Map<String, String>> _fields = [
    {'label': 'CArg', 'hint': 'Аргинин',                    'unit': 'мг/л'},
    {'label': 'CPr',  'hint': 'Пролин',                     'unit': 'мг/л'},
    {'label': 'CTrn', 'hint': 'Треонин',                    'unit': 'мг/л'},
    {'label': 'CA',   'hint': 'Ацетальдегид',               'unit': 'мг/л'},
    {'label': 'CE',   'hint': 'Этилацетат',                 'unit': 'мг/л'},
    {'label': 'CM',   'hint': 'Метанол',                    'unit': 'мг/л'},
    {'label': 'CHA',  'hint': 'Высшие спирты',              'unit': 'мг/л'},
    {'label': 'CAA',  'hint': 'Уксусная кислота',           'unit': 'мг/л'},
    {'label': 'CF',   'hint': 'Фурфурол',                   'unit': 'мг/л'},
  ];

  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;

  double? _result;
  bool _hasError = false;
  String _errorMessage = '';

  late AnimationController _resultController;
  late Animation<double> _resultAnimation;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  // Цвета темы
  static const Color kWine       = Color(0xFF7B1A2E);
  static const Color kGold       = Color(0xFFB8962E);
  static const Color kBg         = Color(0xFFF5F0F2);
  static const Color kCard       = Colors.white;
  static const Color kTextDark   = Color(0xFF1A0A10);
  static const Color kTextMid    = Color(0xFF5A3A44);
  static const Color kTextLight  = Color(0xFF9A7A84);
  static const Color kBorder     = Color(0xFFD4B8C0);

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(9, (_) => TextEditingController());
    _focusNodes  = List.generate(9, (_) => FocusNode());

    _resultController = AnimationController(
      duration: const Duration(milliseconds: 700), vsync: this);
    _resultAnimation = CurvedAnimation(
      parent: _resultController, curve: Curves.easeOutBack);

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400), vsync: this);
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn));
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes)  f.dispose();
    _resultController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _predict() {
    FocusScope.of(context).unfocus();
    for (int i = 0; i < _controllers.length; i++) {
      final text = _controllers[i].text.trim();
      if (text.isEmpty) {
        _showError('Поле «${_fields[i]['label']}» (${_fields[i]['hint']}) не заполнено');
        return;
      }
      final value = double.tryParse(text.replaceAll(',', '.'));
      if (value == null) {
        _showError('Поле «${_fields[i]['label']}» содержит некорректное значение.\nВведите число, например: 12.5');
        return;
      }
      if (value < 0) {
        _showError('Поле «${_fields[i]['label']}» не может быть отрицательным');
        return;
      }
    }

    final features = _controllers
        .map((c) => double.parse(c.text.trim().replaceAll(',', '.')))
        .toList();
    final score = GradientBoostingModel.predict(features);

    setState(() { _result = score; _hasError = false; _errorMessage = ''; });
    _resultController.forward(from: 0);
  }

  void _showError(String message) {
    setState(() { _hasError = true; _errorMessage = message; _result = null; });
    _shakeController.forward(from: 0);
  }

  void _reset() {
    for (final c in _controllers) c.clear();
    setState(() { _result = null; _hasError = false; _errorMessage = ''; });
    _resultController.reset();
    FocusScope.of(context).unfocus();
  }

  Color _scoreColor(double s) {
    if (s >= 85) return const Color(0xFFB8962E);
    if (s >= 70) return const Color(0xFF6A3A9B);
    if (s >= 55) return const Color(0xFF7B1A2E);
    return const Color(0xFF757575);
  }

  String _scoreLabel(double s) {
    if (s >= 90) return 'Выдающееся';
    if (s >= 85) return 'Отличное';
    if (s >= 80) return 'Очень хорошее';
    if (s >= 70) return 'Хорошее';
    if (s >= 60) return 'Удовлетворительное';
    return 'Ординарное';
  }

  String _scoreEmoji(double s) {
    if (s >= 85) return '🏆';
    if (s >= 70) return '🍷';
    if (s >= 55) return '🍇';
    return '📊';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: CustomScrollView(
        slivers: [
          // ── Шапка ──
          SliverAppBar(
            expandedHeight: 170,
            pinned: true,
            backgroundColor: kWine,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF9B2D45), Color(0xFF5A0F1E)],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.15),
                          border: Border.all(color: kGold, width: 2),
                        ),
                        child: const Center(
                          child: Text('🍷', style: TextStyle(fontSize: 30)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'VinoLab',
                        style: TextStyle(
                          color: Color(0xFFFFD88A),
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Анализ качества вина • Градиентный бустинг',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Тело ──
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // Заголовок секции
                _sectionHeader('ХИМИЧЕСКИЙ СОСТАВ ВИНА'),
                const SizedBox(height: 12),

                // 9 полей — по одному в строку для крупного отображения
                ...List.generate(9, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildInputField(i),
                )),

                const SizedBox(height: 8),

                // Кнопка ПРОГНОЗ
                _buildPredictButton(),
                const SizedBox(height: 10),

                // Кнопка СБРОСИТЬ
                _buildResetButton(),
                const SizedBox(height: 20),

                // Ошибка
                if (_hasError) _buildErrorCard(),

                // Результат
                if (_result != null) _buildResultCard(),

                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Row(
      children: [
        Container(width: 4, height: 18, color: kWine,
          margin: const EdgeInsets.only(right: 10)),
        Text(text, style: const TextStyle(
          color: kTextMid, fontSize: 13,
          fontWeight: FontWeight.w700, letterSpacing: 1.5)),
      ],
    );
  }

  Widget _buildInputField(int i) {
    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder, width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Метка слева
          Container(
            width: 54,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_fields[i]['label']!,
                  style: const TextStyle(
                    color: kWine, fontSize: 16,
                    fontWeight: FontWeight.w800)),
                Text(_fields[i]['unit']!,
                  style: const TextStyle(
                    color: kTextLight, fontSize: 11)),
              ],
            ),
          ),
          // Разделитель
          Container(width: 1, height: 36, color: kBorder,
            margin: const EdgeInsets.symmetric(horizontal: 12)),
          // Поле ввода
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_fields[i]['hint']!,
                  style: const TextStyle(
                    color: kTextLight, fontSize: 11)),
                TextField(
                  controller: _controllers[i],
                  focusNode: _focusNodes[i],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
                  ],
                  style: const TextStyle(
                    color: kTextDark, fontSize: 18,
                    fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    hintStyle: TextStyle(color: kBorder, fontSize: 18),
                    isDense: true,
                    contentPadding: EdgeInsets.only(top: 2),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) {
                    if (i < 8) FocusScope.of(context).requestFocus(_focusNodes[i + 1]);
                    else _predict();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _predict,
        style: ElevatedButton.styleFrom(
          backgroundColor: kWine,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: kWine.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🍷', style: TextStyle(fontSize: 22)),
            SizedBox(width: 12),
            Text('ПРОГНОЗ',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
                color: Color(0xFFFFD88A),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildResetButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: _reset,
        style: OutlinedButton.styleFrom(
          foregroundColor: kWine,
          side: const BorderSide(color: kWine, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.refresh_rounded, size: 20),
            SizedBox(width: 8),
            Text('СБРОСИТЬ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) => Transform.translate(
        offset: Offset(sin(_shakeAnimation.value * pi * 6) * 7, 0),
        child: child,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0F0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade300, width: 1.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(_errorMessage,
                style: TextStyle(
                  color: Colors.red.shade800,
                  fontSize: 15, height: 1.4,
                  fontWeight: FontWeight.w500,
                )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final score = _result!;
    final color = _scoreColor(score);
    final label = _scoreLabel(score);
    final emoji = _scoreEmoji(score);

    return ScaleTransition(
      scale: _resultAnimation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5), width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 20, spreadRadius: 2),
          ],
        ),
        child: Column(
          children: [
            Text('РЕЗУЛЬТАТ АНАЛИЗА',
              style: TextStyle(
                color: kTextLight, fontSize: 13,
                letterSpacing: 2.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),

            // Большой балл
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 36)),
                const SizedBox(width: 10),
                Text(score.toStringAsFixed(1),
                  style: TextStyle(
                    color: color, fontSize: 72,
                    fontWeight: FontWeight.w300,
                    letterSpacing: -2, height: 1)),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(' / 100',
                    style: TextStyle(
                      color: color.withOpacity(0.6),
                      fontSize: 20, fontWeight: FontWeight.w400)),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Бейдж категории
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: color.withOpacity(0.4), width: 1.5),
              ),
              child: Text(label.toUpperCase(),
                style: TextStyle(
                  color: color, fontSize: 15,
                  letterSpacing: 2, fontWeight: FontWeight.w800)),
            ),

            const SizedBox(height: 22),
            Divider(color: color.withOpacity(0.2), thickness: 1),
            const SizedBox(height: 14),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0', style: TextStyle(color: kTextLight, fontSize: 12)),
                Text('100 баллов',
                style: TextStyle(color: kTextLight, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: score / 100,
                backgroundColor: color.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 10,
              ),
            ),

            const SizedBox(height: 18),
            Text('Метод: Градиентный бустинг (Gradient Boosting)',
              style: TextStyle(
              color: kTextLight, fontSize: 12, letterSpacing: 0.3)),
          ],
        ),
      ),
    );
  }
}
