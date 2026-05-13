import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/app_theme.dart';
import '../../theme/font_catalog.dart';

const Color _slate400 = Color(0xFF94A3B8);
const Color _slate800 = Color(0xFF1E293B);

/// 환경 설정: 테마 엔진 커스텀
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppThemeNotifier>(
      builder: (BuildContext context, AppThemeNotifier notifier, _) {
        final AppThemeData theme = notifier.theme;
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 48),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 220, maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: 16),
                _ThemeCard(
                  theme: theme,
                  onThemeChanged: (AppThemeData t) => notifier.setTheme(t),
                  onPrimaryChanged: (Color c) => notifier.updatePrimary(c),
                  onBgChanged: (Color c) => notifier.updateBg(c),
                  onRadiusChanged: (double r) => notifier.updateRadius(r),
                  onFontFamilyChanged: (String f) => notifier.updateFontFamily(f),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.theme,
    required this.onThemeChanged,
    required this.onPrimaryChanged,
    required this.onBgChanged,
    required this.onRadiusChanged,
    required this.onFontFamilyChanged,
  });

  final AppThemeData theme;
  final void Function(AppThemeData) onThemeChanged;
  final void Function(Color) onPrimaryChanged;
  final void Function(Color) onBgChanged;
  final void Function(double) onRadiusChanged;
  final void Function(String) onFontFamilyChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(theme.radius),
        border: Border.all(color: Colors.white.withOpacity(0.5)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(theme.radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _buildHeader(context),
                const SizedBox(height: 32),
                _buildSignatureSection(context),
                const SizedBox(height: 32),
                _buildLightSection(context),
                const SizedBox(height: 32),
                _buildFontSection(context),
                const SizedBox(height: 32),
                _buildCustomSection(context),
                const SizedBox(height: 32),
                _buildRadiusSection(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.palette_outlined, size: 48, color: theme.primary),
            const SizedBox(width: 16),
            Text(
              '시스템 색상 설정',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: theme.primary,
                letterSpacing: -0.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSignatureSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 8,
              height: 32,
              decoration: BoxDecoration(
                color: theme.primary,
                borderRadius: BorderRadius.circular(4),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: theme.primary.withOpacity(0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '시스템 시그니처 테마',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _slate800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: ThemePresets.signature.map((ThemePresetItem p) {
            final bool selected = theme.primary.value == p.data.primary.value;
            return SizedBox(
              width: 200,
              height: 130,
              child: _PresetCard(
                name: p.name,
                preset: p.data,
                selected: selected,
                onTap: () => onThemeChanged(p.data),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLightSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.wb_sunny_outlined, size: 28, color: Colors.orange.shade400),
            const SizedBox(width: 12),
            Text(
              '라이트 & 화이트 에디션',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _slate800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: ThemePresets.light.map((ThemePresetItem p) {
            final bool selected = theme.bg.value == p.data.bg.value;
            return SizedBox(
              width: 200,
              height: 130,
              child: _PresetCard(
                name: p.name,
                preset: p.data,
                selected: selected,
                onTap: () => onThemeChanged(p.data),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFontSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.font_download_outlined, size: 26, color: theme.primary),
              const SizedBox(width: 12),
              const Text(
                '폰트 설정',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _slate800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FontPickerPanel(
            theme: theme,
            onFontFamilyChanged: onFontFamilyChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildCustomSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 8,
                height: 32,
                decoration: BoxDecoration(
                  color: _slate400,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '포인트 색상',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _slate800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _ColorPickerRow(
            label: '포인트 색상',
            color: theme.primary,
            onChanged: onPrimaryChanged,
          ),
          const SizedBox(height: 12),
          _ColorPickerRow(
            label: '시스템 배경색',
            color: theme.bg,
            onChanged: onBgChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildRadiusSection(BuildContext context) {
    const List<double> radiusOptions = <double>[0, 16, 32, 64];
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 8,
                height: 32,
                decoration: BoxDecoration(
                  color: _slate400,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '인터페이스 굴곡',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _slate800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: radiusOptions.map((double r) {
              final bool selected = (theme.radius - r).abs() < 1;
              return SizedBox(
                width: 80,
                child: Material(
                    color: selected ? Colors.black : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => onRadiusChanged(r),
                      child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      alignment: Alignment.center,
                      child: Text(
                        '${r.toInt()}px',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: selected ? Colors.white : _slate400,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

}

class _FontPickerPanel extends StatefulWidget {
  const _FontPickerPanel({
    required this.theme,
    required this.onFontFamilyChanged,
  });

  final AppThemeData theme;
  final void Function(String) onFontFamilyChanged;

  @override
  State<_FontPickerPanel> createState() => _FontPickerPanelState();
}

class _FontPickerPanelState extends State<_FontPickerPanel> {
  final TextEditingController _ctrl = TextEditingController(text: '테스트 문구');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: _ctrl,
          maxLength: 30,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          buildCounter: (
            BuildContext context, {
            required int currentLength,
            required bool isFocused,
            required int? maxLength,
          }) {
            return const SizedBox.shrink();
          },
          maxLines: 1,
          decoration: const InputDecoration(
            labelText: '테스트 문구',
          ),
          onChanged: (_) {
            if (!mounted) return;
            setState(() {});
          },
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<FontCatalogItem>>(
          future: FontCatalog.loadItems(),
          builder: (BuildContext context, AsyncSnapshot<List<FontCatalogItem>> snap) {
            if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '폰트 목록을 불러오는 중…',
                  style: TextStyle(color: _slate400),
                ),
              );
            }
            final List<FontCatalogItem> items = snap.data ??
                const <FontCatalogItem>[
                  FontCatalogItem(family: 'NotoSansKR', label: '고딕체'),
                ];
            final String current =
                widget.theme.fontFamily.trim().isEmpty ? 'NotoSansKR' : widget.theme.fontFamily.trim();
            final String selected = items.any((FontCatalogItem e) => e.family == current)
                ? current
                : 'NotoSansKR';

            final String sample = _ctrl.text;

            final List<Widget> radios = <Widget>[];
            for (final FontCatalogItem item in items) {
              final TextStyle rowStyle = TextStyle(
                fontFamily: item.family,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: _slate800,
              );

              radios.add(
                RadioListTile<String>(
                  value: item.family,
                  groupValue: selected,
                  onChanged: (String? v) {
                    if (v == null) return;
                    widget.onFontFamilyChanged(v);
                  },
                  contentPadding: EdgeInsets.zero,
                  visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                  title: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          item.label,
                          style: rowStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          sample,
                          style: rowStyle.copyWith(fontWeight: FontWeight.w800),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
              radios.add(const Divider(height: 1));
            }
            if (radios.isNotEmpty) radios.removeLast();

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: radios,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.name,
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final AppThemeData preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? preset.primary.withOpacity(0.08)
          : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(40),
      child: InkWell(
        borderRadius: BorderRadius.circular(40),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: selected ? preset.primary : const Color(0xFFE2E8F0),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Row(
                children: <Widget>[
                  _ColorSwatch(color: preset.primary),
                  const SizedBox(width: 12),
                  _ColorSwatch(color: preset.sidebar),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: _slate800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}

class _ColorPickerRow extends StatelessWidget {
  const _ColorPickerRow({
    required this.label,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final Color color;
  final void Function(Color) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _slate800,
            ),
          ),
          GestureDetector(
            onTap: () async {
              // Flutter Web에서는 color picker가 제한적. input type=color 시뮬레이션
              // 간단히 색상 선택 다이얼로그 표시
              final Color? picked = await showDialog<Color>(
                context: context,
                builder: (BuildContext ctx) => _SimpleColorPicker(
                  initialColor: color,
                  onPick: (Color c) => Navigator.of(ctx).pop(c),
                ),
              );
              if (picked != null) onChanged(picked);
            },
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
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

/// 간단한 색상 선택 다이얼로그 (웹 호환)
class _SimpleColorPicker extends StatefulWidget {
  const _SimpleColorPicker({
    required this.initialColor,
    required this.onPick,
  });

  final Color initialColor;
  final void Function(Color) onPick;

  @override
  State<_SimpleColorPicker> createState() => _SimpleColorPickerState();
}

class _SimpleColorPickerState extends State<_SimpleColorPicker> {
  late Color _color;

  static const List<Color> _presets = <Color>[
    Color(0xFFFFFFFF),
    Color(0xFF1E3A8A),
    Color(0xFF059669),
    Color(0xFF7C3AED),
    Color(0xFF0284C7),
    Color(0xFFDB2777),
    Color(0xFF1E293B),
    Color(0xFFEA580C),
    Color(0xFF0F172A),
  ];

  static const String _kCustomColorsPrefKey = 'settings.custom_point_colors';
  static const int _kCustomColorsMax = 5;
  List<Color> _custom = <Color>[];
  bool _loaded = false;

  int _r = 0;
  int _g = 0;
  int _b = 0;

  @override
  void initState() {
    super.initState();
    _color = widget.initialColor;
    _r = _color.red;
    _g = _color.green;
    _b = _color.blue;
    _loadCustom();
  }

  Future<void> _loadCustom() async {
    try {
      final SharedPreferences sp = await SharedPreferences.getInstance();
      final List<String> raw =
          sp.getStringList(_kCustomColorsPrefKey) ?? <String>[];
      final List<Color> out = <Color>[];
      for (final String s in raw) {
        final int? v = int.tryParse(s);
        if (v == null) continue;
        out.add(Color(v));
      }
      if (!mounted) return;
      setState(() {
        _custom = out.take(_kCustomColorsMax).toList();
        _loaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loaded = true);
    }
  }

  Future<void> _saveCustom() async {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    final List<String> raw =
        _custom.take(_kCustomColorsMax).map((Color c) => '${c.value}').toList();
    await sp.setStringList(_kCustomColorsPrefKey, raw);
  }

  Future<void> _addCustom(Color c) async {
    final List<Color> next = <Color>[
      c,
      ..._custom.where((Color e) => e.value != c.value),
    ];
    _custom = next.take(_kCustomColorsMax).toList();
    await _saveCustom();
    if (mounted) {
      setState(() {});
    }
  }

  void _syncRgbFromColor(Color c) {
    _r = c.red;
    _g = c.green;
    _b = c.blue;
  }

  void _setRgb(int r, int g, int b) {
    final Color next = Color.fromARGB(255, r, g, b);
    setState(() {
      _color = next;
      _r = r;
      _g = g;
      _b = b;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('색상 선택'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '기본색상',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _presets.map((Color c) {
              final bool selected = _color.value == c.value;
              return GestureDetector(
                onTap: () {
                  setState(() => _color = c);
                  _syncRgbFromColor(c);
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? Colors.black : Colors.grey,
                      width: selected ? 3 : 1,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '커스텀색상',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (!_loaded)
            const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_custom.isEmpty)
            Text(
              '저장된 커스텀 색상이 없습니다.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _custom.map((Color c) {
                final bool selected = _color.value == c.value;
                return GestureDetector(
                  onTap: () {
                    setState(() => _color = c);
                    _syncRgbFromColor(c);
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? Colors.black : Colors.grey,
                        width: selected ? 3 : 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '직접 선택',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade400),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '#${_color.value.toRadixString(16).padLeft(8, '0').toUpperCase()}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _addCustom(_color),
                      child: const Text('커스텀에 저장'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _RgbSlider(
                  label: 'R',
                  value: _r,
                  color: Colors.red,
                  onChanged: (int v) => _setRgb(v, _g, _b),
                ),
                _RgbSlider(
                  label: 'G',
                  value: _g,
                  color: Colors.green,
                  onChanged: (int v) => _setRgb(_r, v, _b),
                ),
                _RgbSlider(
                  label: 'B',
                  value: _b,
                  color: Colors.blue,
                  onChanged: (int v) => _setRgb(_r, _g, v),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => widget.onPick(_color),
          child: const Text('적용'),
        ),
      ],
    );
  }
}

class _RgbSlider extends StatelessWidget {
  const _RgbSlider({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final int value;
  final Color color;
  final void Function(int v) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 20,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        Expanded(
          child: Slider(
            min: 0,
            max: 255,
            divisions: 255,
            value: value.toDouble(),
            activeColor: color,
            onChanged: (double v) => onChanged(v.round().clamp(0, 255)),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            '$value',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ),
      ],
    );
  }
}
