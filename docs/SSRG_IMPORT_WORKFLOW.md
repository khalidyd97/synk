# SSRG import

Open the SSRG importer and choose a folder, ZIP, or multiple files. Scanning and media preparation run on workers. Review each song before importing: edit its title, artist and game, choose audio and artwork, and select difficulties and key counts. Warnings require acknowledgment; invalid charts are excluded with reasons. Native Files dialogs also support the iOS picker, although this route has not been tested on an iPhone.

## Existing songs

Audio content hashes identify songs. **Add missing** keeps existing difficulties. **Replace unchanged imported** only replaces charts whose complete saved bytes match their recorded import baseline and which have no draft. Charts from older imports without a baseline remain protected. **Skip** leaves the song alone. Custom backgrounds are also protected from replacement.

## Fidelity and validation

Imported charts retain source ticks, record order, header metadata, and an exact copy of their original chart file under `ssrg_sources`. Unknown playable records, incompatible lane grids, ambiguous long-note timing, and notes past the decoded audio duration are reported instead of silently discarded or trimmed. Single long heads and orphan connectors are explicitly reported when represented as taps. Presentation files with unsupported tempo changes need correction before import.

## Storage and recovery

Preparation uses private `.ssrg_import` staging. The main thread checks the reviewed source hashes, existing file hashes, library snapshot and drafts before committing each song. Journaled backups restore interrupted commits when the importer next opens. Recovery preserves files changed after the interrupted operation and blocks further imports if manual attention is needed. Keep the journal and backups when recovery reports a conflict.

Cancel stops queued work and discards uncommitted preparation; completed songs stay imported. Failed and canceled songs can be retried. Batch results are saved under `import_reports` and can also be exported with **Save report**.

ZIP inspection rejects unsafe paths, encrypted or split archives, ZIP64, symbolic links and conflicting names. Limits are 10,000 entries, 150 MB per extracted file and 1 GB total. Chart validation additionally limits individual chart files to 16 MB. Nested archives are not expanded.

## Verification

The importer has parser/archive, transaction/recovery and graphical review-wizard tests. Integration coverage includes source changes after review, retry, cancellation before commit, protected edits/drafts, adding missing difficulties, retained original bytes, ZIP review and report export. Actual source charts were also checked against decoded audio without importing into the user's library.
