import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FirestoreCollectionBackupPage extends StatefulWidget {
  const FirestoreCollectionBackupPage({super.key});

  @override
  State<FirestoreCollectionBackupPage> createState() =>
      _FirestoreCollectionBackupPageState();
}

class _FirestoreCollectionBackupPageState
    extends State<FirestoreCollectionBackupPage> {
  static const String _backupMetadataCollection = 'collectionBackups';
  static const int _readPageSize = 400;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _collectionController = TextEditingController();

  bool _checkingCollection = false;
  bool _creatingBackup = false;

  String? _checkedCollection;
  int? _documentCount;
  int _copiedDocumentCount = 0;
  String? _lastBackupId;
  String? _errorMessage;

  @override
  void dispose() {
    _collectionController.dispose();
    super.dispose();
  }

  String? _validateCollectionName(String rawValue) {
    final name = rawValue.trim();

    if (name.isEmpty) {
      return 'Enter a Firestore collection name.';
    }

    if (name.contains('/')) {
      return 'Enter a top-level collection name without slashes.';
    }

    if (name == '.' || name == '..') {
      return 'This is not a valid collection name.';
    }

    if (name == _backupMetadataCollection) {
      return 'The backup collection cannot back up itself.';
    }

    return null;
  }

  void _resetPreview() {
    if (_checkedCollection == null &&
        _documentCount == null &&
        _errorMessage == null) {
      return;
    }

    setState(() {
      _checkedCollection = null;
      _documentCount = null;
      _copiedDocumentCount = 0;
      _lastBackupId = null;
      _errorMessage = null;
    });
  }

  Future<void> _checkCollection() async {
    final collectionName = _collectionController.text.trim();
    final validationError = _validateCollectionName(collectionName);

    if (validationError != null) {
      setState(() => _errorMessage = validationError);
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _checkingCollection = true;
      _checkedCollection = null;
      _documentCount = null;
      _copiedDocumentCount = 0;
      _lastBackupId = null;
      _errorMessage = null;
    });

    try {
      final count = await _countCollectionDocuments(collectionName);

      if (!mounted) return;

      setState(() {
        _checkedCollection = collectionName;
        _documentCount = count;
      });
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _firebaseMessage(
          error,
          fallback: 'The collection could not be read.',
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'The collection could not be checked: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _checkingCollection = false);
      }
    }
  }

  Future<int> _countCollectionDocuments(String collectionName) async {
    QueryDocumentSnapshot<Map<String, dynamic>>? lastDocument;
    var count = 0;

    while (true) {
      Query<Map<String, dynamic>> query = _firestore
          .collection(collectionName)
          .orderBy(FieldPath.documentId)
          .limit(_readPageSize);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final page = await query.get();
      count += page.docs.length;

      if (page.docs.length < _readPageSize) {
        break;
      }

      lastDocument = page.docs.last;
    }

    return count;
  }

  Future<void> _createBackup() async {
    final collectionName = _collectionController.text.trim();
    final validationError = _validateCollectionName(collectionName);

    if (validationError != null) {
      setState(() => _errorMessage = validationError);
      return;
    }

    if (_checkedCollection != collectionName || _documentCount == null) {
      setState(() {
        _errorMessage = 'Check this collection before creating its backup.';
      });
      return;
    }

    if (_documentCount == 0) {
      setState(() {
        _errorMessage = 'The collection is empty, so there is nothing to back up.';
      });
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Create collection backup?'),
          content: Text(
            'This will copy $_documentCount top-level documents from '
            '"$collectionName" into a timestamped backup. Subcollections '
            'inside those documents are not included.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.backup_outlined),
              label: const Text('Create Backup'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _errorMessage = 'Your session has expired. Sign in again.');
      return;
    }

    final createdAt = DateTime.now().toUtc();
    final backupId = _buildBackupId(collectionName, createdAt);
    final metadataReference = _firestore
        .collection(_backupMetadataCollection)
        .doc(backupId);

    setState(() {
      _creatingBackup = true;
      _copiedDocumentCount = 0;
      _lastBackupId = null;
      _errorMessage = null;
    });

    try {
      await metadataReference.set({
        'backupId': backupId,
        'sourceCollection': collectionName,
        'status': 'running',
        'createdAt': FieldValue.serverTimestamp(),
        'createdAtClientUtc': Timestamp.fromDate(createdAt),
        'createdByUid': user.uid,
        'createdByEmail': user.email,
        'expectedDocumentCount': _documentCount,
        'copiedDocumentCount': 0,
        'includesSubcollections': false,
        'formatVersion': 1,
      });

      QueryDocumentSnapshot<Map<String, dynamic>>? lastDocument;
      var copied = 0;

      while (true) {
        Query<Map<String, dynamic>> query = _firestore
            .collection(collectionName)
            .orderBy(FieldPath.documentId)
            .limit(_readPageSize);

        if (lastDocument != null) {
          query = query.startAfterDocument(lastDocument);
        }

        final sourcePage = await query.get();
        if (sourcePage.docs.isEmpty) break;

        final batch = _firestore.batch();
        final backupDocuments = metadataReference.collection('documents');

        for (final sourceDocument in sourcePage.docs) {
          // The original document ID and data are preserved exactly. Metadata
          // is kept on the parent backup document to avoid changing source data.
          batch.set(
            backupDocuments.doc(sourceDocument.id),
            sourceDocument.data(),
          );
        }

        copied += sourcePage.docs.length;

        batch.set(
          metadataReference,
          {
            'copiedDocumentCount': copied,
            'lastProgressAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        await batch.commit();

        if (!mounted) return;
        setState(() => _copiedDocumentCount = copied);

        if (sourcePage.docs.length < _readPageSize) {
          break;
        }

        lastDocument = sourcePage.docs.last;
      }

      await metadataReference.set({
        'status': 'completed',
        'copiedDocumentCount': copied,
        'completedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      setState(() {
        _copiedDocumentCount = copied;
        _lastBackupId = backupId;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Backup completed: $copied documents copied successfully.',
          ),
        ),
      );
    } on FirebaseException catch (error) {
      await _markBackupFailed(metadataReference, error);

      if (!mounted) return;
      setState(() {
        _errorMessage = _firebaseMessage(
          error,
          fallback: 'The backup could not be completed.',
        );
      });
    } catch (error) {
      await _markBackupFailed(metadataReference, error);

      if (!mounted) return;
      setState(() {
        _errorMessage = 'The backup could not be completed: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _creatingBackup = false);
      }
    }
  }

  Future<void> _markBackupFailed(
    DocumentReference<Map<String, dynamic>> metadataReference,
    Object error,
  ) async {
    try {
      final message = error.toString();
      await metadataReference.set({
        'status': 'failed',
        'copiedDocumentCount': _copiedDocumentCount,
        'failedAt': FieldValue.serverTimestamp(),
        'failureMessage': message.length > 500
            ? message.substring(0, 500)
            : message,
      }, SetOptions(merge: true));
    } catch (_) {
      // Preserve the original backup error when failure metadata cannot be set.
    }
  }

  String _buildBackupId(String collectionName, DateTime utcDateTime) {
    final safeCollectionName = collectionName.replaceAll(
      RegExp(r'[^A-Za-z0-9_-]'),
      '_',
    );
    final timestamp = utcDateTime
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');

    return '${safeCollectionName}_$timestamp';
  }

  String _firebaseMessage(
    FirebaseException error, {
    required String fallback,
  }) {
    switch (error.code) {
      case 'permission-denied':
        return 'Permission denied. Confirm that your account and Firestore '
            'rules allow database backups.';
      case 'unavailable':
        return 'Firestore is temporarily unavailable. Check your connection '
            'and try again.';
      case 'resource-exhausted':
        return 'Firestore limits were reached while creating the backup. '
            'Try again after checking your Firebase usage.';
      default:
        return '$fallback (${error.code})';
    }
  }

  double? get _backupProgress {
    final total = _documentCount;
    if (!_creatingBackup || total == null || total <= 0) return null;
    return (_copiedDocumentCount / total).clamp(0.0, 1.0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firestore Collection Backup'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildIntroductionCard(),
            const SizedBox(height: 16),
            TextField(
              controller: _collectionController,
              enabled: !_creatingBackup,
              autocorrect: false,
              textCapitalization: TextCapitalization.none,
              onChanged: (_) => _resetPreview(),
              onSubmitted: (_) {
                if (!_checkingCollection && !_creatingBackup) {
                  _checkCollection();
                }
              },
              decoration: const InputDecoration(
                labelText: 'Collection name',
                hintText: 'Example: ordersitems',
                prefixIcon: Icon(Icons.storage_outlined),
                border: OutlineInputBorder(),
                helperText: 'Enter one top-level Firestore collection name.',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _checkingCollection || _creatingBackup
                  ? null
                  : _checkCollection,
              icon: _checkingCollection
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: Text(
                _checkingCollection ? 'Checking Collection…' : 'Check Collection',
              ),
            ),
            if (_checkedCollection != null && _documentCount != null) ...[
              const SizedBox(height: 16),
              _buildCollectionSummary(),
            ],
            if (_creatingBackup) ...[
              const SizedBox(height: 16),
              _buildProgressCard(),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              _buildErrorCard(_errorMessage!),
            ],
            if (_lastBackupId != null) ...[
              const SizedBox(height: 16),
              _buildSuccessCard(_lastBackupId!),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _canStartBackup ? _createBackup : null,
              icon: const Icon(Icons.backup_outlined),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Create Collection Backup'),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Recent backups',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildRecentBackups(),
          ],
        ),
      ),
    );
  }

  bool get _canStartBackup {
    final collectionName = _collectionController.text.trim();
    return !_checkingCollection &&
        !_creatingBackup &&
        _checkedCollection == collectionName &&
        (_documentCount ?? 0) > 0;
  }

  Widget _buildIntroductionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.shield_outlined),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Back up before testing',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'The tool creates a read-only-style snapshot under '
              'collectionBackups/{backupId}/documents while preserving every '
              'top-level document ID and its data.',
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Important: Firestore subcollections are separate collections '
                'and are not included by this page.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionSummary() {
    final count = _documentCount ?? 0;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Text(count > 999 ? '999+' : count.toString()),
        ),
        title: Text(_checkedCollection!),
        subtitle: Text(
          count == 1 ? '1 document found' : '$count documents found',
        ),
        trailing: const Icon(Icons.check_circle, color: Colors.green),
      ),
    );
  }

  Widget _buildProgressCard() {
    final total = _documentCount ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Copying $_copiedDocumentCount of $total documents…',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: _backupProgress),
            const SizedBox(height: 8),
            const Text('Do not close this page until the backup completes.'),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.errorContainer,
      child: ListTile(
        leading: Icon(Icons.error_outline, color: colors.onErrorContainer),
        title: Text(
          'Backup action failed',
          style: TextStyle(
            color: colors.onErrorContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          message,
          style: TextStyle(color: colors.onErrorContainer),
        ),
      ),
    );
  }

  Widget _buildSuccessCard(String backupId) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.primaryContainer,
      child: ListTile(
        leading: Icon(Icons.verified_outlined, color: colors.onPrimaryContainer),
        title: Text(
          'Backup completed',
          style: TextStyle(
            color: colors.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: SelectableText(
          '$_backupMetadataCollection/$backupId',
          style: TextStyle(color: colors.onPrimaryContainer),
        ),
      ),
    );
  }

  Widget _buildRecentBackups() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection(_backupMetadataCollection)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Recent backups cannot be loaded. Check Firestore permissions.',
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final documents = snapshot.data?.docs ?? const [];
        if (documents.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No collection backups have been created yet.'),
            ),
          );
        }

        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var index = 0; index < documents.length; index++) ...[
                _buildBackupTile(documents[index]),
                if (index < documents.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildBackupTile(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final status = data['status']?.toString() ?? 'unknown';
    final copied = _asInt(data['copiedDocumentCount']);
    final expected = _asInt(data['expectedDocumentCount']);
    final source = data['sourceCollection']?.toString() ?? 'Unknown collection';
    final createdAt = data['createdAt'] as Timestamp?;

    IconData statusIcon;
    if (status == 'completed') {
      statusIcon = Icons.check_circle_outline;
    } else if (status == 'failed') {
      statusIcon = Icons.error_outline;
    } else {
      statusIcon = Icons.sync;
    }

    return ListTile(
      leading: Icon(statusIcon),
      title: Text(source),
      subtitle: Text(
        '${_formatTimestamp(createdAt)} • $copied/$expected documents • $status',
      ),
      isThreeLine: false,
    );
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Time pending';

    final date = timestamp.toDate().toLocal();
    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${date.year}-${twoDigits(date.month)}-${twoDigits(date.day)} '
        '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  }
}
