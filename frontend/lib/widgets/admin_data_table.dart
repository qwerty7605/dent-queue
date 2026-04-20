import 'dart:math' as math;

import 'package:flutter/material.dart';

class AdminDataTable extends StatefulWidget {
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
    this.enableVerticalScroll = true,
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
  final bool enableVerticalScroll;

  static const Color _headingBackgroundColor = Color(0xFFF5F7FB);
  static const Color _headingTextColor = Color(0xFF142036);
  static const Color _bodyTextColor = Color(0xFF334155);
  static const Color _borderColor = Color(0xFFE1E7F5);
  static const Color _stripedRowColor = Color(0xFFFAFBFF);

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
        return const Color(0xFFEBF0FF);
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
  State<AdminDataTable> createState() => _AdminDataTableState();
}

class _AdminDataTableState extends State<AdminDataTable> {
  late final ScrollController _verticalController;
  late final ScrollController _horizontalController;

  @override
  void initState() {
    super.initState();
    _verticalController = ScrollController();
    _horizontalController = ScrollController();
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double resolvedMinWidth = math.max(
          widget.minWidth ?? 0,
          constraints.maxWidth,
        );

        return Scrollbar(
          controller: _horizontalController,
          thumbVisibility: false,
          trackVisibility: false,
          notificationPredicate: (ScrollNotification notification) =>
              notification.metrics.axis == Axis.horizontal,
          child: SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: resolvedMinWidth),
              child: widget.enableVerticalScroll
                  ? Scrollbar(
                      controller: _verticalController,
                      thumbVisibility: false,
                      trackVisibility: false,
                      notificationPredicate: (ScrollNotification notification) =>
                          notification.metrics.axis == Axis.vertical,
                      child: SingleChildScrollView(
                        controller: _verticalController,
                        child: _buildTable(),
                      ),
                    )
                  : _buildTable(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTable() {
    return Padding(
      padding: widget.contentPadding,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: DataTableTheme(
          data: const DataTableThemeData(
            headingRowColor: WidgetStatePropertyAll<Color>(
              AdminDataTable._headingBackgroundColor,
            ),
            headingTextStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.65,
              color: AdminDataTable._headingTextColor,
            ),
            dataTextStyle: TextStyle(
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: AdminDataTable._bodyTextColor,
            ),
            dividerThickness: 0.75,
          ),
          child: DataTable(
            headingRowHeight: widget.headingRowHeight,
            dataRowMinHeight: widget.dataRowMinHeight,
            dataRowMaxHeight: widget.dataRowMaxHeight,
            horizontalMargin: widget.horizontalMargin,
            columnSpacing: widget.columnSpacing,
            border: TableBorder.all(
              color: AdminDataTable._borderColor,
              width: 0.75,
              borderRadius: BorderRadius.circular(16),
            ),
            columns: widget.columns,
            rows: widget.rows,
          ),
        ),
      ),
    );
  }
}
