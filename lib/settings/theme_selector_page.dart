import 'package:flutter/material.dart';

import '../services/reading_preferences_service.dart';
import '../themes/themes.dart';

class ThemeSettingsPage extends StatefulWidget {
  final String selectedThemeName;
  final bool isDarkMode;
  final double initialFontSize;
  final void Function(String themeName, bool isDark, double fontSize) onApply;

  const ThemeSettingsPage({
    super.key,
    required this.selectedThemeName,
    required this.isDarkMode,
    required this.initialFontSize,
    required this.onApply,
  });

  @override
  State<ThemeSettingsPage> createState() => _ThemeSettingsPageState();
}

class _ThemeSettingsPageState extends State<ThemeSettingsPage> {
  late String _selectedThemeName;
  late bool _isDarkMode;
  late double _fontSize;
  bool _showDualLanguage = false;

  @override
  void initState() {
    super.initState();
    _selectedThemeName = widget.selectedThemeName;
    _isDarkMode = widget.isDarkMode;
    _fontSize = widget.initialFontSize;
    _loadDualLanguagePref();
  }

  Future<void> _loadDualLanguagePref() async {
    final value = await ReadingPreferencesService.getShowDualLanguage();
    if (mounted) setState(() => _showDualLanguage = value);
  }

  Future<void> _onApply() async {
    await ReadingPreferencesService.setShowDualLanguage(_showDualLanguage);
    widget.onApply(_selectedThemeName, _isDarkMode, _fontSize);
  }

  @override
  Widget build(BuildContext context) {
    final selectedTheme = appThemes.firstWhere(
      (t) => t.name == _selectedThemeName,
      orElse: () => appThemes[0],
    );
    final previewTheme = _isDarkMode ? selectedTheme.dark : selectedTheme.light;
    final secondaryFontSize = _fontSize - 2;

    return Scaffold(
      appBar: AppBar(title: const Text('Aparência')),
      body: Column(
        children: [
          // ── Dark mode ──────────────────────────────────────────────────────
          SwitchListTile(
            title: const Text('Tema Escuro'),
            value: _isDarkMode,
            onChanged: (val) => setState(() => _isDarkMode = val),
          ),

          // ── Theme color list ───────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              itemCount: appThemes.length,
              itemBuilder: (_, index) {
                final theme = appThemes[index];
                final isSelected = theme.name == _selectedThemeName;
                return ListTile(
                  leading: CircleAvatar(backgroundColor: theme.color),
                  title: Text(theme.name),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () => setState(() => _selectedThemeName = theme.name),
                );
              },
            ),
          ),

          const Divider(height: 1),

          // ── Font size ──────────────────────────────────────────────────────
          ListTile(
            title: const Text('Tamanho da Fonte'),
            subtitle: Slider(
              min: 12,
              max: 24,
              divisions: 6,
              value: _fontSize,
              label: '${_fontSize.toStringAsFixed(0)} px',
              onChanged: (val) => setState(() => _fontSize = val),
            ),
          ),

          // ── Dual language toggle ───────────────────────────────────────────
          SwitchListTile(
            secondary: const Icon(Icons.translate_rounded),
            title: const Text('Exibir versículo duplo'),
            subtitle: const Text(
              'Mostra o versículo secundário abaixo de cada versículo',
            ),
            value: _showDualLanguage,
            onChanged: (val) => setState(() => _showDualLanguage = val),
          ),

          const SizedBox(height: 8),

          // ── Preview ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Prévia',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: previewTheme.cardColor,
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(2, 2),
                ),
              ],
            ),
            child: Theme(
              data: previewTheme,
              child: Builder(
                builder: (ctx) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Primary verse preview
                    Text(
                      '1 No princípio, Deus criou os céus e a terra.',
                      style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                        fontSize: _fontSize,
                        height: 1.8,
                      ),
                      textAlign: TextAlign.justify,
                    ),
                    // Secondary verse preview (only when toggle is on)
                    if (_showDualLanguage) ...[
                      const SizedBox(height: 4),
                      Text(
                        'In the beginning God created the heavens and the earth.',
                        style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                          fontSize: secondaryFontSize,
                          height: 1.6,
                          fontStyle: FontStyle.italic,
                          color: Theme.of(
                            ctx,
                          ).colorScheme.onSurface.withAlpha(140),
                        ),
                        textAlign: TextAlign.justify,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // ── Apply button ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _onApply,
                child: const Text('Aplicar'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
