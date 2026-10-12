import 'dart:io';
import 'package:test/test.dart';

void main() {
  group('CLI Executable', () {
    test('cli help flag', () async {
      final res = await Process.run('dart', ['run', 'bin/schemaorg_validate.dart', '--help']);
      expect(res.exitCode, equals(0));
      expect(res.stdout.toString(), contains('Usage: schemaorg_validate [options]'));
    });

    test('cli validate valid file text output', () async {
      final tempFile = File('/tmp/test_valid_product.html');
      tempFile.writeAsStringSync('''<html><head>
        <script type="application/ld+json">{
          "@context": "https://schema.org",
          "@type": "Product",
          "name": "Widget"
        }</script>
      </head></html>''');

      final res = await Process.run('dart', ['run', 'bin/schemaorg_validate.dart', '-f', tempFile.path]);
      expect(res.exitCode, equals(0));
      expect(res.stdout.toString(), contains('schemaorg-validate'));
      expect(res.stdout.toString(), contains('ELIGIBLE'));
    });

    test('cli validate json output format', () async {
      final tempFile = File('/tmp/test_json_fmt.html');
      tempFile.writeAsStringSync('''<html><head>
        <script type="application/ld+json">{
          "@context": "https://schema.org",
          "@type": "Product",
          "name": "Widget"
        }</script>
      </head></html>''');

      final res = await Process.run('dart', ['run', 'bin/schemaorg_validate.dart', '-f', tempFile.path, '--format', 'json']);
      expect(res.exitCode, equals(0));
      expect(res.stdout.toString(), contains('"schema_version"'));
      expect(res.stdout.toString(), contains('"eligibility"'));
    });

    test('cli validate sarif output format', () async {
      final tempFile = File('/tmp/test_sarif_fmt.html');
      tempFile.writeAsStringSync('''<html><head>
        <script type="application/ld+json">{
          "@context": "https://schema.org",
          "@type": "Product",
          "name": "Widget"
        }</script>
      </head></html>''');

      final res = await Process.run('dart', ['run', 'bin/schemaorg_validate.dart', '-f', tempFile.path, '--format', 'sarif']);
      expect(res.exitCode, equals(0));
      expect(res.stdout.toString(), contains('"2.1.0"'));
    });
  });
}
