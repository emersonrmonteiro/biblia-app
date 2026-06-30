import 'package:flutter/material.dart';

import '../themes/themes.dart';

class ThemeSettingsPage extends StatefulWidget {
  final String selectedThemeName;
  final bool isDarkMode;
  final void Function(String themeName, bool isDark, double fontSize) onApply;

  const ThemeSettingsPage({
    super.key,
    required this.selectedThemeName,
    required this.isDarkMode,
    required this.onApply,
  });

  @override
  State<ThemeSettingsPage> createState() => _ThemeSettingsPageState();
}

class _ThemeSettingsPageState extends State<ThemeSettingsPage> {
  late String _selectedThemeName;
  late bool _isDarkMode;
  double _fontSize = 16.0;

  @override
  void initState() {
    super.initState();
    _selectedThemeName = widget.selectedThemeName;
    _isDarkMode = widget.isDarkMode;
  }

  @override
  Widget build(BuildContext context) {
    final selectedTheme = appThemes.firstWhere(
      (t) => t.name == _selectedThemeName,
      orElse: () => appThemes[0],
    );
    final previewTheme = _isDarkMode ? selectedTheme.dark : selectedTheme.light;

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações de Tema')),
      body: Column(
        children: [
          SwitchListTile(
            title: const Text('Tema Escuro'),
            value: _isDarkMode,
            onChanged: (val) => setState(() => _isDarkMode = val),
          ),
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
          const SizedBox(height: 10),
          Text('Prévia', style: Theme.of(context).textTheme.titleMedium),
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: previewTheme.cardColor,
              boxShadow: [
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
                builder: (context) => Text(
                  'No princípio, Deus criou os céus e a terra. A terra era sem forma e vazia.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: _fontSize),
                  textAlign: TextAlign.justify,
                ),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () =>
                widget.onApply(_selectedThemeName, _isDarkMode, _fontSize),
            child: const Text('Aplicar'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
