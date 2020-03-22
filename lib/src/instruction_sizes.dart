import 'package:meta/meta.dart';
import 'flame_chart.dart';

FlameChartNode parseSymbols(List<dynamic> symbols) {
  final iter = symbols.cast<Map<String, dynamic>>().map(Symbol.fromMap);
  final FlameChartNode root = FlameChartNode('root');
  FlameChartNode currentParent = root;
  for (Symbol symbol in iter) {
    FlameChartNode parentReset = currentParent;
    for (String pathPart in symbol.parts.take(symbol.parts.length - 1)) {
      currentParent = currentParent.childByName(pathPart) ??
          currentParent.addChild(FlameChartNode(pathPart));
    }
    // TODO: this shouldn't be necessary, https://github.com/dart-lang/sdk/issues/41137
    String leafName = symbol.parts.last;
    int duplicates = 0;
    while (currentParent.childByName(leafName) != null) {
      duplicates += 1;
      leafName = '${symbol.parts.last}_$duplicates';
    }
    currentParent.addChild(
      FlameChartNode(leafName, value: symbol.size),
    );
    currentParent = parentReset;
  }
  return root;
}

class Symbol {
  const Symbol({
    @required this.name,
    @required this.size,
    this.libraryUri,
    this.className,
  })  : assert(name != null),
        assert(size != null);

  static Symbol fromMap(Map<String, dynamic> json) {
    return Symbol(
      name: (json['n'] as String).replaceAll('[Optimized] ', ''),
      size: json['s'] as int,
      className: json['c'] as String,
      libraryUri: json['l'] as String,
    );
  }

  final String name;
  final int size;
  final String libraryUri;
  final String className;

  List<String> get parts {
    return <String>[
      if (libraryUri != null) ...libraryUri.split('/') else '@stubs',
      if (className != null && className.isNotEmpty) className,
      name,
    ];
  }
}
