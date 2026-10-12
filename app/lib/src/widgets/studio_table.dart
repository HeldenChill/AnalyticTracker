import 'package:flutter/material.dart';

class StudioColumn {
  const StudioColumn(
    this.label, {
    this.width = 160,
    this.numeric = false,
    this.onSort,
  });

  final String label;
  final double width;
  final bool numeric;
  final void Function(int columnIndex, bool ascending)? onSort;
}

class StudioRow {
  const StudioRow(
    this.cells, {
    this.selected = false,
    this.onSelectChanged,
  });

  final List<Widget> cells;
  final bool selected;
  final ValueChanged<bool?>? onSelectChanged;
}

class StudioTextCell extends StatelessWidget {
  const StudioTextCell(
    this.text, {
    super.key,
    this.width,
    this.numeric = false,
    this.style,
  });

  final String text;
  final double? width;
  final bool numeric;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final inherited = DefaultTextStyle.of(context).style;
    final effectiveStyle = style == null ? inherited : inherited.merge(style);
    if (numeric) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: effectiveStyle),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.maybeLocaleOf(context),
        maxLines: 1,
      )..layout();
      final measured = painter.width.ceilToDouble() + 1;
      painter.dispose();
      final minimum = width ?? 0;
      return SizedBox(
        width: measured > minimum ? measured : minimum,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            text,
            style: effectiveStyle,
            softWrap: false,
            maxLines: 1,
            textAlign: TextAlign.right,
          ),
        ),
      );
    }
    final cell = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        softWrap: true,
        maxLines: null,
        textAlign: TextAlign.left,
        style: style,
      ),
    );
    if (width != null) {
      return SizedBox(
        width: width,
        child: cell,
      );
    }
    return cell;
  }
}

class StudioTable extends StatefulWidget {
  const StudioTable({
    super.key,
    required this.columns,
    required this.rows,
    this.sortColumnIndex,
    this.sortAscending = true,
    this.emptyMessage = 'No rows in this range',
  });

  final List<StudioColumn> columns;
  final List<StudioRow> rows;
  final int? sortColumnIndex;
  final bool sortAscending;
  final String emptyMessage;

  @override
  State<StudioTable> createState() => _StudioTableState();
}

class _StudioTableState extends State<StudioTable> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    assert(() {
      for (final r in widget.rows) {
        if (r.cells.length != widget.columns.length) {
          throw FlutterError(
            'StudioTable row has ${r.cells.length} cells, expected ${widget.columns.length}.',
          );
        }
      }
      return true;
    }());

    if (widget.rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            widget.emptyMessage,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final tableTheme = DataTableTheme.of(context);
    final baseStyle = tableTheme.headingTextStyle ??
        theme.dataTableTheme.headingTextStyle ?? theme.textTheme.titleSmall!;
    final headingStyle = DefaultTextStyle.of(context).style.merge(baseStyle);
    var headingHeight = tableTheme.headingRowHeight ??
        theme.dataTableTheme.headingRowHeight ?? 56.0;
    for (final column in widget.columns) {
      final painter = TextPainter(
        text: TextSpan(text: column.label, style: headingStyle),
        textDirection: Directionality.of(context),
        textAlign: column.numeric ? TextAlign.right : TextAlign.left,
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.maybeLocaleOf(context),
      )..layout(maxWidth: column.width);
      final needed = painter.height.ceilToDouble() + 16;
      if (needed > headingHeight) headingHeight = needed;
      painter.dispose();
    }

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        child: DataTable(
          sortColumnIndex: widget.sortColumnIndex,
          sortAscending: widget.sortAscending,
          headingTextStyle: headingStyle,
          headingRowHeight: headingHeight,
          dataRowMinHeight: 48,
          dataRowMaxHeight: double.infinity,
          columns: [
            for (var i = 0; i < widget.columns.length; i++)
              DataColumn(
                label: SizedBox(
                  width: widget.columns[i].width,
                  child: Text(
                    widget.columns[i].label,
                    style: headingStyle,
                    softWrap: true,
                    textAlign: widget.columns[i].numeric
                        ? TextAlign.right
                        : TextAlign.left,
                  ),
                ),
                numeric: widget.columns[i].numeric,
                onSort: widget.columns[i].onSort,
              ),
          ],
          rows: [
            for (final row in widget.rows)
              DataRow(
                selected: row.selected,
                onSelectChanged: row.onSelectChanged,
                cells: [
                  for (var c = 0; c < row.cells.length; c++)
                    DataCell(
                      c < widget.columns.length
                          ? _buildCell(widget.columns[c], row.cells[c])
                          : row.cells[c],
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(StudioColumn column, Widget cell) {
    if (column.numeric) {
      return ConstrainedBox(
        constraints: BoxConstraints(minWidth: column.width),
        child: cell,
      );
    }
    if (cell is StudioTextCell && cell.width == null) {
      return SizedBox(width: column.width, child: cell);
    }
    return cell;
  }
}
