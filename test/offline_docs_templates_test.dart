import 'package:moarch/src/templates/misc/offline_docs_templates.dart';
import 'package:moarch/src/utils/scaffold_catalog.dart';
import 'package:test/test.dart';

void main() {
  group('docs/OFFLINE_FIRST.md', () {
    test('a cache-only project gets the read path and nothing of sync', () {
      final doc = OfflineDocsTemplates.doc();

      expect(doc, startsWith('# Offline-first, explained'));
      expect(doc, contains('## Reading: `fetchAll` and `watchAll`'));
      expect(doc, contains('**Writes** still need a connection'));
      for (final sync in ['PendingWrites', 'SyncService', 'workmanager']) {
        expect(doc, isNot(contains(sync)), reason: sync);
      }
    });

    test(
      'a synced project gets the write path, the drain and the background',
      () {
        final doc = OfflineDocsTemplates.doc(withSync: true);

        expect(doc, startsWith('# Offline-first and sync, explained'));
        for (final section in [
          '### `PendingWrites`: the outbox',
          '## Writing: apply now, send later',
          '## Sending: `SyncService.drain()`',
          '## After a sync: the server wins',
          '## Background sync (workmanager)',
        ]) {
          expect(doc, contains(section), reason: section);
        }
      },
    );

    test('the screen section follows the stack', () {
      expect(
        OfflineDocsTemplates.doc(),
        contains('`refresh()` on the notifier'),
      );
      final bloc = OfflineDocsTemplates.doc(bloc: true);
      expect(bloc, contains('emit.forEach('));
      expect(bloc, isNot(contains('ref.onDispose')));
    });

    test('sign-in clears only when the auth feature does it', () {
      final withAuth = OfflineDocsTemplates.doc(
        withSync: true,
        withAuthFeature: true,
      );
      // Its own table row, not glued to the one before.
      expect(withAuth, contains('| The same. |\n| Sign-in | cache + queue |'));
      expect(withAuth, contains('the generated `AuthRepositoryImpl` calls'));

      final withoutAuth = OfflineDocsTemplates.doc();
      expect(withoutAuth, isNot(contains('| Sign-in |')));
      expect(withoutAuth, contains('Call `getIt<LocalCache>().clearAll()`'));
    });

    test('code samples keep their dollar signs', () {
      expect(
        OfflineDocsTemplates.doc(withSync: true),
        contains(r"SyncRequest.put('${ApiConstants.orders}/${item.id}'"),
      );
    });

    test('is a catalog entry, so update can refresh it', () {
      expect(
        {for (final s in ScaffoldCatalog.all) s.name: s.path}['offline-doc'],
        'docs/OFFLINE_FIRST.md',
      );
    });
  });
}
