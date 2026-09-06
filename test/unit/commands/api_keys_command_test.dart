import 'package:test/test.dart';
import 'package:ulink_cli/commands/api_keys_command.dart';

void main() {
  group('ApiKeysCommand', () {
    // These paths short-circuit before any network call, so a dummy base URL
    // is fine — no request is issued.
    final command = ApiKeysCommand(baseUrl: 'http://localhost:0');

    test('help prints usage and exits 0', () async {
      final result = await command.run(ApiKeysOptions(action: 'list', help: true));
      expect(result.exitCode, 0);
    });

    test('create without a name exits 2', () async {
      final result = await command.run(ApiKeysOptions(action: 'create'));
      expect(result.exitCode, 2);
    });

    test('create with a blank name exits 2', () async {
      final result =
          await command.run(ApiKeysOptions(action: 'create', name: '   '));
      expect(result.exitCode, 2);
    });

    test('revoke without a key id exits 2', () async {
      final result = await command.run(ApiKeysOptions(action: 'revoke'));
      expect(result.exitCode, 2);
    });

    test('unknown action exits 2', () async {
      final result = await command.run(ApiKeysOptions(action: 'bogus'));
      expect(result.exitCode, 2);
    });
  });
}
