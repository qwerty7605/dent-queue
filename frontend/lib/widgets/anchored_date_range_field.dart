import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AnchoredDateRangeField extends StatefulWidget {
  const AnchoredDateRangeField({
    super.key,
    required this.label,
    required this.placeholder,
    required this.startDate,
    required this.endDate,
    required this.firstDate,
    required this.lastDate,
    required this.onChanged,
    required this.textColor,
    required this.mutedTextColor,
    required this.borderColor,
    required this.fillColor,
    this.prefixIcon = Icons.date_range_outlined,
    this.suffixIcon = Icons.edit_calendar_outlined,
  });

  final String label;
  final String placeholder;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final void Function(DateTime? start, DateTime? end) onChanged;
  final Color textColor;
  final Color mutedTextColor;
  final Color borderColor;
  final Color fillColor;
  final IconData prefixIcon;
  final IconData suffixIcon;

  @override
  State<AnchoredDateRangeField> createState() => _AnchoredDateRangeFieldState();
}

class _AnchoredDateRangeFieldState extends State<AnchoredDateRangeField> {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _fieldKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _toggleOverlay() {
    if (_overlayEntry != null) {
      _removeOverlay();
      return;
    }

    final BuildContext? fieldContext = _fieldKey.currentContext;
    if (fieldContext == null) {
      return;
    }

    final RenderBox renderBox = fieldContext.findRenderObject()! as RenderBox;
    final Size fieldSize = renderBox.size;
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final double overlayWidth = math.min(
      mediaQuery.size.width - 32,
      math.max(fieldSize.width, 560),
    );

    _overlayEntry = OverlayEntry(
      builder: (BuildContext context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _removeOverlay,
                child: const SizedBox.expand(),
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(0, fieldSize.height + 10),
              child: Material(
                color: Colors.transparent,
                child: _AnchoredDateRangePopover(
                  width: overlayWidth,
                  startDate: widget.startDate,
                  endDate: widget.endDate,
                  firstDate: widget.firstDate,
                  lastDate: widget.lastDate,
                  textColor: widget.textColor,
                  mutedTextColor: widget.mutedTextColor,
                  borderColor: widget.borderColor,
                  surfaceColor: widget.fillColor,
                  onCancel: _removeOverlay,
                  onApply: (DateTime? start, DateTime? end) {
                    widget.onChanged(start, end);
                    _removeOverlay();
                  },
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final String? valueText = _formatRange(widget.startDate, widget.endDate);
    final bool hasValue = valueText != null;

    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        key: _fieldKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: widget.mutedTextColor,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: _toggleOverlay,
              borderRadius: BorderRadius.circular(20),
              child: InputDecorator(
                decoration: InputDecoration(
                  hintText: widget.placeholder,
                  filled: true,
                  fillColor: widget.fillColor,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 18,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: widget.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: widget.borderColor),
                  ),
                  prefixIcon: Icon(
                    widget.prefixIcon,
                    size: 16,
                    color: widget.mutedTextColor,
                  ),
                  suffixIcon: Icon(
                    widget.suffixIcon,
                    size: 16,
                    color: widget.textColor,
                  ),
                ),
                child: Text(
                  hasValue ? valueText : widget.placeholder,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: hasValue ? widget.textColor : widget.mutedTextColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _formatRange(DateTime? start, DateTime? end) {
    if (start == null && end == null) {
      return null;
    }

    final DateFormat formatter = DateFormat('MMM d, yyyy');
    if (start != null && end != null) {
      return '${formatter.format(start)} - ${formatter.format(end)}';
    }

    return formatter.format(start ?? end!);
  }
}

class _AnchoredDateRangePopover extends StatefulWidget {
  const _AnchoredDateRangePopover({
    required this.width,
    required this.startDate,
    required this.endDate,
    required this.firstDate,
    required this.lastDate,
    required this.textColor,
    required this.mutedTextColor,
    required this.borderColor,
    required this.surfaceColor,
    required this.onCancel,
    required this.onApply,
  });

  final double width;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final Color textColor;
  final Color mutedTextColor;
  final Color borderColor;
  final Color surfaceColor;
  final VoidCallback onCancel;
  final void Function(DateTime? start, DateTime? end) onApply;

  @override
  State<_AnchoredDateRangePopover> createState() =>
      _AnchoredDateRangePopoverState();
}

class _AnchoredDateRangePopoverState extends State<_AnchoredDateRangePopover> {
  late DateTime _visibleMonth;
  DateTime? _tempStart;
  DateTime? _tempEnd;

  @override
  void initState() {
    super.initState();
    _tempStart = widget.startDate;
    _tempEnd = widget.endDate;
    _visibleMonth = DateTime(
      (widget.startDate ?? DateTime.now()).year,
      (widget.startDate ?? DateTime.now()).month,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool dualMonth = widget.width >= 540;
    final String title = _formatHeaderRange();

    return Container(
      width: widget.width,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: widget.onCancel,
                icon: Icon(Icons.close, color: widget.textColor),
                splashRadius: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filter by date',
                      style: TextStyle(
                        color: widget.mutedTextColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: TextStyle(
                        color: widget.textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _tempStart == null ? null : () {
                  widget.onApply(_tempStart, _tempEnd ?? _tempStart);
                },
                child: const Text('Apply'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          dualMonth
              ? Row(
                  children: [
                    Expanded(child: _buildMonth(_visibleMonth, showPrev: true)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMonth(
                        DateTime(_visibleMonth.year, _visibleMonth.month + 1),
                        showNext: true,
                      ),
                    ),
                  ],
                )
              : _buildMonth(_visibleMonth, showPrev: true, showNext: true),
        ],
      ),
    );
  }

  Widget _buildMonth(
    DateTime month, {
    bool showPrev = false,
    bool showNext = false,
  }) {
    final DateTime firstOfMonth = DateTime(month.year, month.month, 1);
    final DateTime firstGridDay =
        firstOfMonth.subtract(Duration(days: firstOfMonth.weekday % 7));
    final List<DateTime> days = List<DateTime>.generate(
      42,
      (int index) => firstGridDay.add(Duration(days: index)),
    );

    return Column(
      children: [
        Row(
          children: [
            if (showPrev)
              IconButton(
                onPressed: () {
                  setState(() {
                    _visibleMonth = DateTime(
                      _visibleMonth.year,
                      _visibleMonth.month - 1,
                    );
                  });
                },
                icon: const Icon(Icons.chevron_left_rounded),
              )
            else
              const SizedBox(width: 40),
            Expanded(
              child: Text(
                DateFormat('MMM yyyy').format(month),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: widget.textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (showNext)
              IconButton(
                onPressed: () {
                  setState(() {
                    _visibleMonth = DateTime(
                      _visibleMonth.year,
                      _visibleMonth.month + 1,
                    );
                  });
                },
                icon: const Icon(Icons.chevron_right_rounded),
              )
            else
              const SizedBox(width: 40),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: const [
            _WeekDay('S'),
            _WeekDay('M'),
            _WeekDay('T'),
            _WeekDay('W'),
            _WeekDay('T'),
            _WeekDay('F'),
            _WeekDay('S'),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: days.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1.1,
          ),
          itemBuilder: (BuildContext context, int index) {
            final DateTime day = days[index];
            final bool isCurrentMonth = day.month == month.month;
            final bool isDisabled =
                day.isBefore(_dateOnly(widget.firstDate)) ||
                day.isAfter(_dateOnly(widget.lastDate));
            final bool isStart = _isSameDate(day, _tempStart);
            final bool isEnd = _isSameDate(day, _tempEnd);
            final bool inRange = _isInSelectedRange(day);

            Color background = Colors.transparent;
            BoxBorder? border;
            Color textColor = isCurrentMonth
                ? widget.textColor
                : widget.mutedTextColor.withValues(alpha: 0.5);

            if (inRange) {
              background = const Color(0xFFE8EEF9);
            }
            if (isStart || isEnd) {
              background = const Color(0xFF2B5CAA);
              textColor = Colors.white;
            }
            if (_isSameDate(day, DateTime.now()) && !isStart && !isEnd) {
              border = Border.all(color: const Color(0xFFFFA000));
            }

            return InkWell(
              onTap: isDisabled ? null : () => _handleDateTap(day),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(12),
                  border: border,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    color: isDisabled
                        ? widget.mutedTextColor.withValues(alpha: 0.35)
                        : textColor,
                    fontSize: 13,
                    fontWeight: (isStart || isEnd) ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _handleDateTap(DateTime value) {
    final DateTime day = _dateOnly(value);

    setState(() {
      if (_tempStart == null || (_tempStart != null && _tempEnd != null)) {
        _tempStart = day;
        _tempEnd = null;
        return;
      }

      if (day.isBefore(_tempStart!)) {
        _tempStart = day;
        _tempEnd = null;
        return;
      }

      _tempEnd = day;
    });
  }

  bool _isInSelectedRange(DateTime day) {
    if (_tempStart == null || _tempEnd == null) {
      return false;
    }

    final DateTime date = _dateOnly(day);
    return !date.isBefore(_dateOnly(_tempStart!)) &&
        !date.isAfter(_dateOnly(_tempEnd!));
  }

  bool _isSameDate(DateTime date, DateTime? other) {
    if (other == null) {
      return false;
    }
    return date.year == other.year &&
        date.month == other.month &&
        date.day == other.day;
  }

  DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

  String _formatHeaderRange() {
    final DateFormat formatter = DateFormat('MMM d, yyyy');
    if (_tempStart == null && _tempEnd == null) {
      return 'Start Date - End Date';
    }
    if (_tempStart != null && _tempEnd != null) {
      return '${formatter.format(_tempStart!)} - ${formatter.format(_tempEnd!)}';
    }
    return formatter.format(_tempStart!);
  }
}

class _WeekDay extends StatelessWidget {
  const _WeekDay(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF55698F),
          ),
        ),
      ),
    );
  }
}
