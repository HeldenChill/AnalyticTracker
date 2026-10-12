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
    final cell = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        softWrap: !numeric,
        maxLines: numeric ? 1 : null,
        textAlign: numeric ? TextAlign.right : TextAlign.left,
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

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        child: DataTable(
          sortColumnIndex: widget.sortColumnIndex,
          sortAscending: widget.sortAscending,
          dataRowMinHeight: 48,
          dataRowMaxHeight: double.infinity,
          columns: [
            for (var i = 0; i < widget.columns.length; i++)
              DataColumn(
                label: SizedBox(
                  width: widget.columns[i].width,
                  child: Text(
                    widget.columns[i].label,
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
                      c < widget.columns.length &&
                              row.cells[c] is StudioTextCell &&
                              (row.cells[c] as StudioTextCell).width == null
                          ? SizedBox(
                              width: widget.columns[c].width,
                              child: row.cells[c],
                            )
                          : row.cells[c],
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
