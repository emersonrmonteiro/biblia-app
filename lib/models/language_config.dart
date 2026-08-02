class BibleLanguage {
  final String code;
  final String name;
  final List<BibleTranslation> translations;

  const BibleLanguage({
    required this.code,
    required this.name,
    required this.translations,
  });
}

class BibleTranslation {
  final String id;
  final String name;
  final String abbreviation;
  final bool isLocal;

  const BibleTranslation({
    required this.id,
    required this.name,
    required this.abbreviation,
    this.isLocal = false,
  });
}

class LanguageConfig {
  final BibleTranslation primaryTranslation;
  final BibleTranslation secondaryTranslation;

  const LanguageConfig({
    required this.primaryTranslation,
    required this.secondaryTranslation,
  });
}

const availableLanguages = [
  BibleLanguage(
    code: 'pt',
    name: 'Português',
    translations: [
      BibleTranslation(
        id: 'a-mensagem',
        name: 'A Mensagem',
        abbreviation: 'MSG',
        isLocal: true,
      ),
      BibleTranslation(
        id: 'ARA',
        name: 'Almeida Revista e Atualizada',
        abbreviation: 'ARA',
      ),
      BibleTranslation(
        id: 'NVIPT',
        name: 'Nova Versão Internacional',
        abbreviation: 'NVI',
      ),
      BibleTranslation(
        id: 'NVT',
        name: 'Nova Versão Transformadora',
        abbreviation: 'NVT',
      ),
      BibleTranslation(
        id: 'TB10',
        name: 'Tradução Brasileira',
        abbreviation: 'TB',
      ),
    ],
  ),
  BibleLanguage(
    code: 'en',
    name: 'English',
    translations: [
      BibleTranslation(
        id: 'WEB',
        name: 'World English Bible',
        abbreviation: 'WEB',
      ),
      BibleTranslation(
        id: 'KJV',
        name: 'King James Version',
        abbreviation: 'KJV',
      ),
      BibleTranslation(
        id: 'NIV2011',
        name: 'New International Version',
        abbreviation: 'NIV',
      ),
      BibleTranslation(
        id: 'ESV',
        name: 'English Standard Version',
        abbreviation: 'ESV',
      ),
      BibleTranslation(
        id: 'NLT',
        name: 'New Living Translation',
        abbreviation: 'NLT',
      ),
      BibleTranslation(
        id: 'NASB',
        name: 'New American Standard Bible',
        abbreviation: 'NASB',
      ),
    ],
  ),
];
