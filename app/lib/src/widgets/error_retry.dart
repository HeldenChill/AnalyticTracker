import 'package:flutter/material.dart';
import '../api_client.dart';

class ErrorRetry extends StatelessWidget {
  const ErrorRetry({
    super.key,
    required this.error,
    required this.onRetry,
    this.inline = false,
  });

  final Object error;
  final VoidCallback onRetry;
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final is404 =
        error is ApiException && (error as ApiException).statusCode == 404;
    final message = error.toString();
    const guidance =
        'This endpoint is unavailable. Restart the server with the current project version.';

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          inline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(
          message,
          textAlign: inline ? TextAlign.start : TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: inline ? theme.colorScheme.error : null,
          ),
          softWrap: true,
        ),
        if (is404) ...[
          const SizedBox(height: 6),
          Text(
            guidance,
            textAlign: inline ? TextAlign.start : TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            softWrap: true,
          ),
        ],
        const SizedBox(height: 12),
        inline
            ? OutlinedButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              )
            : FilledButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
      ],
    );

    if (inline) {
      return Card(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.2),
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: content,
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: content,
      ),
    );
  }
}
