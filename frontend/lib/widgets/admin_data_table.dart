import 'package:flutter/material.dart';

class AdminDataTable extends StatelessWidget {
  const AdminDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.minWidth,
    this.columnSpacing = 28,
    this.horizontalMargin = 20,
    this.contentPadding = const EdgeInsets.fromLTRB(20, 12, 20, 20),
    this.headingRowHeight = 60,
    this.dataRowMinHeight = 72,
    this.dataRowMaxHeight = 84,
  });

  final List<DataColumn> columns;
  final List<DataRow> rows;
  final double? minWidth;
  final double columnSpacing;
  final double horizontalMargin;
  final EdgeInsetsGeometry contentPadding;
  final double headingRowHeight;
  final double dataRowMinHeight;
  final double dataRowMaxHeight;

  static const Color _headingBackgroundColor = Color(0xFFF4F8F4);
  static const Color _headingTextColor = Color(0xFF29412B);
  static const Color _bodyTextColor = Color(0xFF334155);
  static const Color _borderColor = Color(0xFFE6ECE6);
  static const Color _stripedRowColor = Color(0xFFFBFDFC);

  static Widget headerLabel(
    String label, {
    double? width,
    Alignment alignment = Alignment.centerLeft,
  }) {
    final Widget text = Text(
      label.toUpperCase(),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.65,
        color: _headingTextColor,
      ),
    );

    return _wrapCell(text, width: width, alignment: alignment);
  }

  static Widget cellText(
    String text, {
    double? width,
    Alignment alignment = Alignment.centerLeft,
    int maxLines = 1,
    FontWeight fontWeight = FontWeight.w600,
    Color color = _bodyTextColor,
  }) {
    final Widget label = Text(
      text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 14,
        height: 1.35,
        fontWeight: fontWeight,
        color: color,
      ),
    );

    return _wrapCell(label, width: width, alignment: alignment);
  }

  static WidgetStateProperty<Color?> rowColor(int index) {
    return WidgetStateProperty.resolveWith((Set<WidgetState> states) {
      if (states.contains(WidgetState.selected)) {
        return const Color(0xFFEFF5EF);
      }

      return index.isEven ? Colors.white : _stripedRowColor;
    });
  }

  static Widget _wrapCell(
    Widget child, {
    double? width,
    required Alignment alignment,
  }) {
    Widget content = Align(alignment: alignment, child: child);

    if (width != null) {
      content = SizedBox(width: width, child: content);
    }

    return content;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: minWidth ?? 0),
          child: Padding(
            padding: contentPadding,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: DataTableTheme(
                data: const DataTableThemeData(
                  headingRowColor: WidgetStatePropertyAll<Color>(
                    _headingBackgroundColor,
                  ),
                  headingTextStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.65,
                    color: _headingTextColor,
                  ),
                  dataTextStyle: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: _bodyTextColor,
                  ),
                  dividerThickness: 0.75,
                ),
                child: DataTable(
                  headingRowHeight: headingRowHeight,
                  dataRowMinHeight: dataRowMinHeight,
                  dataRowMaxHeight: dataRowMaxHeight,
                  horizontalMargin: horizontalMargin,
                  columnSpacing: columnSpacing,
                  border: TableBorder.all(
                    color: _borderColor,
                    width: 0.75,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  columns: columns,
                  rows: rows,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
