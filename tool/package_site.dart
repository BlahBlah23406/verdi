// Packages the existing Flutter web release alongside the public landing page.
import 'dart:io';

void copyTree(Directory source, Directory destination) {
  destination.createSync(recursive: true);
  for (final entity in source.listSync()) {
    final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
    final target = '${destination.path}/$name';
    if (entity is Directory) {
      copyTree(entity, Directory(target));
    } else if (entity is File) {
      entity.copySync(target);
    }
  }
}

void main() {
  if (!File('build/web/main.dart.js').existsSync()) {
    stderr.writeln(
      'Run flutter build web --release --base-href /verdi/app/ first.',
    );
    exitCode = 1;
    return;
  }
  final output = Directory('build/site');
  if (output.existsSync()) output.deleteSync(recursive: true);
  copyTree(Directory('site'), output);
  copyTree(Directory('build/web'), Directory('build/site/app'));
  copyTree(Directory('examples'), Directory('build/site/examples'));
  File('docs/PITCH_DECK.html').copySync('build/site/pitch-deck.html');
  File('build/site/.nojekyll').writeAsStringSync('');
  stdout.writeln(
    'Packaged landing page, deck, examples and Flutter app in build/site.',
  );
}
