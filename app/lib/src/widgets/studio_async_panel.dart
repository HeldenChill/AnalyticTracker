import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'error_retry.dart';

class StudioAsyncPanel<T> extends StatefulWidget {
  const StudioAsyncPanel({
    super.key,
    required this.queryKey,
    required this.value,
    required this.builder,
    required this.onRetry,
    this.loading,
  });

  final Object queryKey;
  final AsyncValue<T> value;
  final Widget Function(T) builder;
  final VoidCallback onRetry;
  final Widget? loading;

  @override
  State<StudioAsyncPanel<T>> createState() => _StudioAsyncPanelState<T>();
}

class _StudioAsyncPanelState<T> extends State<StudioAsyncPanel<T>> {
  late Object _cacheKey;
  T? _lastSuccess;
  bool _hasSuccess = false;

  @override
  void initState() {
    super.initState();
    _cacheKey = widget.queryKey;
    _acceptIncoming(widget.value);
  }

  @override
  void didUpdateWidget(covariant StudioAsyncPanel<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_cacheKey != widget.queryKey) {
      _cacheKey = widget.queryKey;
      _lastSuccess = null;
      _hasSuccess = false;
    }
    _acceptIncoming(widget.value);
  }

  void _acceptIncoming(AsyncValue<T> incoming) {
    if (!incoming.isLoading && !incoming.hasError && incoming is AsyncData<T>) {
      _lastSuccess = incoming.value;
      _hasSuccess = true;
    }
  }

  Widget _buildCachedContent(BuildContext context, AsyncValue<T> incoming) {
    final Widget notice;
    if (incoming.isLoading) {
      notice = Align(
        alignment: Alignment.centerRight,
        child: Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 6),
                Text(
                  'Updating',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      );
    } else if (incoming.hasError) {
      notice = ErrorRetry(
        error: incoming.error!,
        onRetry: widget.onRetry,
        inline: true,
      );
    } else {
      notice = const SizedBox.shrink();
    }

    final content = KeyedSubtree(
      key: ValueKey(widget.queryKey),
      child: widget.builder(_lastSuccess as T),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final bounded = constraints.maxHeight.isFinite;
        return Column(
          mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            notice,
            if (bounded) Expanded(child: content) else content,
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final incoming = widget.value;

    if (_hasSuccess) return _buildCachedContent(context, incoming);
    if (incoming.isLoading) {
      return widget.loading ?? const Center(child: CircularProgressIndicator());
    }
    if (incoming.hasError) {
      return ErrorRetry(error: incoming.error!, onRetry: widget.onRetry);
    }
    return widget.loading ?? const Center(child: CircularProgressIndicator());
  }
}
