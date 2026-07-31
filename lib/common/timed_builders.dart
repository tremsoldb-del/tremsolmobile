import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TimedStreamBuilder<T> extends StatefulWidget {
  const TimedStreamBuilder({
    super.key,
    required this.stream,
    required this.builder,
    this.loading,
    this.onTimeout,
    this.timeout = const Duration(seconds: 15),
  });

  final Stream<T> stream;
  final AsyncWidgetBuilder<T> builder;
  final Widget? loading;
  final Widget Function(BuildContext context)? onTimeout;
  final Duration timeout;

  @override
  State<TimedStreamBuilder<T>> createState() => _TimedStreamBuilderState<T>();
}

class _TimedStreamBuilderState<T> extends State<TimedStreamBuilder<T>> {
  bool _timedOut = false;
  Timer? _timer;

  void _startTimer() {
    _timer?.cancel();
    _timedOut = false;
    _timer = Timer(widget.timeout, () {
      if (mounted) setState(() => _timedOut = true);
    });
  }

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant TimedStreamBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stream != widget.stream) _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: widget.stream,
      builder: (context, snap) {
        if ((snap.hasData || snap.hasError) && _timer?.isActive == true) {
          _timer?.cancel();
        }
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          if (_timedOut && widget.onTimeout != null) {
            return widget.onTimeout!(context);
          }
          return widget.loading ?? const Center(child: CircularProgressIndicator());
        }
        return widget.builder(context, snap);
      },
    );
  }
}

class FirestoreErrorCard extends StatelessWidget {
  const FirestoreErrorCard({super.key, required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    String msg = 'Couldn’t load data.';
    String? indexUrl;

    if (error is FirebaseException) {
      final e = error as FirebaseException;
      if (e.code == 'failed-precondition' && e.message != null) {
        final m = RegExp(r'https[^\s]+').firstMatch(e.message!);
        indexUrl = m?.group(0);
        msg = 'This query needs a Firestore index.';
      } else {
        msg = e.message ?? msg;
      }
    } else if (error.toString().contains('timeout')) {
      msg = 'Taking too long to load. Please retry.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, size: 36),
          const SizedBox(height: 8),
          Text(msg, textAlign: TextAlign.center),
          if (indexUrl != null) ...[
            const SizedBox(height: 8),
            SelectableText(indexUrl, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ]),
      ),
    );
  }
}
