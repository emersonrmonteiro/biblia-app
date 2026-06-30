class BibleVersion {
  final String id;
  final String name;
  final String abbreviation;
  final String assetPath;

  const BibleVersion({
    required this.id,
    required this.name,
    required this.abbreviation,
    required this.assetPath,
  });
}

const List<BibleVersion> availableVersions = [
  BibleVersion(
    id: 'a-mensagem',
    name: 'A Mensagem',
    abbreviation: 'MSG',
    assetPath: 'assets/versoes/a-mensagem',
  ),
  // Para adicionar uma nova versão, basta incluir aqui e colocar
  // os arquivos JSON na pasta assets/versoes/<id>/
  // BibleVersion(
  //   id: 'nvi',
  //   name: 'Nova Versão Internacional',
  //   abbreviation: 'NVI',
  //   assetPath: 'assets/versoes/nvi',
  // ),
];
