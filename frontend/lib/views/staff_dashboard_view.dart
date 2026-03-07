import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/token_storage.dart';
import '../services/appointment_service.dart';
import '../services/base_service.dart';

class StaffDashboardView extends StatefulWidget {
  const StaffDashboardView({
    super.key,
    required this.userInfo,
    required this.tokenStorage,
    required this.onLogout,
    required this.loggingOut,
  });

  final Map<String, dynamic>? userInfo;
  final TokenStorage tokenStorage;
  final VoidCallback onLogout;
  final bool loggingOut;

  @override
  State<StaffDashboardView> createState() => _StaffDashboardViewState();
}

class _StaffDashboardViewState extends State<StaffDashboardView> {
  late final AppointmentService _appointmentService;
  late DateTime _selectedDate;
  List<Map<String, dynamic>> _appointments = [];
  bool _loading = true;
  int? _updatingAppointmentId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    final apiClient = ApiClient(tokenStorage: widget.tokenStorage);
    final baseService = BaseService(apiClient);
    _appointmentService = AppointmentService(baseService);
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await _appointmentService.getAdminAppointmentsByDate(
        _formatDate(_selectedDate),
      );
      if (!mounted) return;
      setState(() {
        _appointments = list;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load appointments.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;
    setState(() {
      _selectedDate = picked;
    });
    await _loadAppointments();
  }

  Future<void> _confirmStatusUpdate({
    required int appointmentId,
    required String actionLabel,
    required String targetStatus,
    required String successMessage,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('$actionLabel Appointment'),
          content: Text(
            'Are you sure you want to $actionLabel this appointment?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _updatingAppointmentId = appointmentId;
    });

    try {
      await _appointmentService.updateAdminAppointmentStatus(
        appointmentId,
        targetStatus,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
      await _loadAppointments();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update appointment status.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingAppointmentId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.userInfo?['name']?.toString() ?? 'Staff';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Appointments'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadAppointments,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: widget.loggingOut ? null : widget.onLogout,
            icon: widget.loggingOut
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 420;

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, $name',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(_formatDate(_selectedDate)),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Welcome, $name',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(_formatDate(_selectedDate)),
                    ),
                  ],
                );
              },
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(
              child: Center(
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else if (_appointments.isEmpty)
            const Expanded(
              child: Center(child: Text('No appointments for selected date.')),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: _appointments.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final appointment = _appointments[index];
                  return _buildAppointmentCard(appointment);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    final int id = (appointment['id'] as num).toInt();
    final String patientName =
        appointment['patient_name']?.toString() ?? 'Unknown Patient';
    final String serviceType =
        appointment['service_type']?.toString() ?? 'Unknown Service';
    final String time = appointment['time']?.toString() ?? '--:--';
    final int queueNumber = (appointment['queue_number'] as num?)?.toInt() ?? 0;
    final String normalizedStatus = _normalizeStatus(
      appointment['status']?.toString() ?? '',
    );
    final String displayStatus = _displayStatus(normalizedStatus);
    final bool isUpdating = _updatingAppointmentId == id;

    final bool showApprove = normalizedStatus == 'pending';
    final bool showComplete =
        normalizedStatus == 'approved' || normalizedStatus == 'confirmed';
    final bool showCancel = showApprove || showComplete;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 380;

        Widget buildActionButtons() {
          if (!showApprove && !showComplete && !showCancel) {
            return const SizedBox.shrink();
          }

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showApprove)
                  FilledButton(
                    onPressed: isUpdating
                        ? null
                        : () => _confirmStatusUpdate(
                            appointmentId: id,
                            actionLabel: 'Approve',
                            targetStatus: 'approved',
                            successMessage:
                                'Appointment approved successfully.',
                          ),
                    child: const Text('Approve'),
                  ),
                if (showApprove && (showComplete || showCancel))
                  const SizedBox(height: 8),
                if (showComplete)
                  FilledButton(
                    onPressed: isUpdating
                        ? null
                        : () => _confirmStatusUpdate(
                            appointmentId: id,
                            actionLabel: 'Complete',
                            targetStatus: 'completed',
                            successMessage:
                                'Appointment completed successfully.',
                          ),
                    child: const Text('Complete'),
                  ),
                if (showComplete && showCancel) const SizedBox(height: 8),
                if (showCancel)
                  OutlinedButton(
                    onPressed: isUpdating
                        ? null
                        : () => _confirmStatusUpdate(
                            appointmentId: id,
                            actionLabel: 'Cancel',
                            targetStatus: 'cancelled',
                            successMessage:
                                'Appointment cancelled successfully.',
                          ),
                    child: const Text('Cancel'),
                  ),
              ],
            );
          }

          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (showApprove)
                FilledButton(
                  onPressed: isUpdating
                      ? null
                      : () => _confirmStatusUpdate(
                          appointmentId: id,
                          actionLabel: 'Approve',
                          targetStatus: 'approved',
                          successMessage: 'Appointment approved successfully.',
                        ),
                  child: const Text('Approve'),
                ),
              if (showComplete)
                FilledButton(
                  onPressed: isUpdating
                      ? null
                      : () => _confirmStatusUpdate(
                          appointmentId: id,
                          actionLabel: 'Complete',
                          targetStatus: 'completed',
                          successMessage: 'Appointment completed successfully.',
                        ),
                  child: const Text('Complete'),
                ),
              if (showCancel)
                OutlinedButton(
                  onPressed: isUpdating
                      ? null
                      : () => _confirmStatusUpdate(
                          appointmentId: id,
                          actionLabel: 'Cancel',
                          targetStatus: 'cancelled',
                          successMessage: 'Appointment cancelled successfully.',
                        ),
                  child: const Text('Cancel'),
                ),
            ],
          );
        }

        return Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isCompact) ...[
                  Text(
                    'Queue #$queueNumber',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  _statusChip(displayStatus, normalizedStatus),
                ] else ...[
                  Row(
                    children: [
                      Text(
                        'Queue #$queueNumber',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      _statusChip(displayStatus, normalizedStatus),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  patientName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$serviceType • $time',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (showApprove || showComplete || showCancel) ...[
                  const SizedBox(height: 12),
                  buildActionButtons(),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statusChip(String label, String normalizedStatus) {
    Color background;
    Color textColor;

    switch (normalizedStatus) {
      case 'approved':
      case 'confirmed':
        background = const Color(0xFFE3F2FD);
        textColor = const Color(0xFF1565C0);
        break;
      case 'completed':
        background = const Color(0xFFE8F5E9);
        textColor = const Color(0xFF2E7D32);
        break;
      case 'cancelled':
        background = const Color(0xFFFFEBEE);
        textColor = const Color(0xFFC62828);
        break;
      default:
        background = const Color(0xFFFFF8E1);
        textColor = const Color(0xFFE65100);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  String _normalizeStatus(String value) {
    return value.trim().toLowerCase();
  }

  String _displayStatus(String normalizedStatus) {
    if (normalizedStatus == 'confirmed' || normalizedStatus == 'approved') {
      return 'Approved';
    }
    if (normalizedStatus.isEmpty) return 'Unknown';
    return normalizedStatus[0].toUpperCase() + normalizedStatus.substring(1);
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
