import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../services/termin_service.dart';
import '../services/ticket_service.dart';
import '../models/user.dart';

// Create Termin Dialog
class CreateTerminDialog extends StatefulWidget {
  final TerminService terminService;
  final List<User> users;
  final List<Ticket> tickets;
  final VoidCallback onTerminCreated;

  const CreateTerminDialog({
    super.key,
    required this.terminService,
    required this.users,
    required this.tickets,
    required this.onTerminCreated,
  });

  @override
  State<CreateTerminDialog> createState() => _CreateTerminDialogState();
}

class _CreateTerminDialogState extends State<CreateTerminDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _durationController = TextEditingController(text: '60');

  String _category = 'vorstandssitzung';
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 18, minute: 0);
  Set<int> _selectedParticipants = {};
  int? _selectedTicketId;
  bool _isCreating = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _createTermin() async {
    if (!_formKey.currentState!.validate()) return;

    final l = AppLocalizations.of(context);

    if (_selectedParticipants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.atLeastOneParticipant),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validare ore permise: 08:00-12:00 și 14:00-18:00
    final hour = _selectedTime.hour;
    final isValidTime = (hour >= 8 && hour <= 11) || (hour >= 14 && hour <= 17);

    if (!isValidTime) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l.terminTimeRestriction,
            textAlign: TextAlign.center,
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    final terminDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    try {
      final result = await widget.terminService.createTermin(
        title: _titleController.text.trim(),
        category: _category,
        description: _descriptionController.text.trim(),
        terminDate: terminDate,
        durationMinutes: int.parse(_durationController.text),
        location: _locationController.text.trim(),
        participantIds: _selectedParticipants.toList(),
        ticketId: _selectedTicketId,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.terminCreatedSuccess),
            backgroundColor: Colors.green,
          ),
        );
        widget.onTerminCreated();
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.errorMessage(result['message'])),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.errorMessage('$e')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 700,
        height: 700,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade700,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    l.newTermin,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category
                      DropdownButtonFormField<String>(
                        initialValue: _category,
                        decoration: InputDecoration(
                          labelText: l.categoryRequired,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.category),
                        ),
                        items: [
                          DropdownMenuItem(value: 'vorstandssitzung', child: Text(l.boardMeeting)),
                          DropdownMenuItem(value: 'mitgliederversammlung', child: Text(l.generalAssembly)),
                          DropdownMenuItem(value: 'schulung', child: Text(l.training)),
                          DropdownMenuItem(value: 'sonstiges', child: Text(l.other)),
                        ],
                        onChanged: (value) => setState(() => _category = value!),
                      ),
                      const SizedBox(height: 16),
                      // Title
                      TextFormField(
                        controller: _titleController,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: l.titleRequired,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.title),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? l.titleIsRequired : null,
                      ),
                      const SizedBox(height: 16),
                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: l.description,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.description),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      // Date and Time
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                  locale: const Locale('de', 'DE'),
                                );
                                if (date != null) setState(() => _selectedDate = date);
                              },
                              icon: const Icon(Icons.calendar_today),
                              label: Text(DateFormat('dd.MM.yyyy').format(_selectedDate)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    final time = await showTimePicker(
                                      context: context,
                                      initialTime: _selectedTime,
                                    );
                                    if (time != null) setState(() => _selectedTime = time);
                                  },
                                  icon: const Icon(Icons.access_time),
                                  label: Text(_selectedTime.format(context)),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '08:00-12:00 & 14:00-18:00',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Duration and Location
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _durationController,
                              decoration: InputDecoration(
                                labelText: l.durationMinutes,
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.timer),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v == null || v.isEmpty) return l.required;
                                final num = int.tryParse(v);
                                if (num == null || num < 15 || num > 480) {
                                  return '15-480 Min.';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _locationController,
                              decoration: InputDecoration(
                                labelText: l.locationRequired,
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.location_on),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? l.locationIsRequired : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Participants
                      Text(
                        l.participantsSelected(_selectedParticipants.length),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _selectedParticipants = widget.users.map((u) => u.id).toSet();
                              });
                            },
                            icon: const Icon(Icons.check_box),
                            label: Text(l.selectAll),
                          ),
                          TextButton.icon(
                            onPressed: () => setState(() => _selectedParticipants.clear()),
                            icon: const Icon(Icons.check_box_outline_blank),
                            label: Text(l.selectNone),
                          ),
                        ],
                      ),
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView(
                          children: widget.users.map((user) {
                            final isSelected = _selectedParticipants.contains(user.id);
                            return CheckboxListTile(
                              value: isSelected,
                              title: Text('${user.name} (${user.mitgliedernummer})'),
                              subtitle: Text(user.role),
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _selectedParticipants.add(user.id);
                                  } else {
                                    _selectedParticipants.remove(user.id);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Linked Ticket (optional)
                      DropdownButtonFormField<int?>(
                        initialValue: _selectedTicketId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: l.linkedTicketOptional,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.link),
                        ),
                        items: [
                          DropdownMenuItem(value: null, child: Text(l.noTicketLinked)),
                          ...widget.tickets
                              .where((t) => t.status == 'open' || t.status == 'in_progress')
                              .map((ticket) => DropdownMenuItem(
                                    value: ticket.id,
                                    child: Text(
                                      '#${ticket.id} - ${ticket.subject}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  )),
                        ],
                        onChanged: (value) => setState(() => _selectedTicketId = value),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l.cancel),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isCreating ? null : _createTermin,
                    icon: _isCreating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check),
                    label: Text(l.createTermin),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Edit Termin Dialog
class EditTerminDialog extends StatefulWidget {
  final Termin termin;
  final TerminService terminService;
  final List<User> users;
  final List<Ticket> tickets;
  final VoidCallback onTerminUpdated;

  const EditTerminDialog({
    super.key,
    required this.termin,
    required this.terminService,
    required this.users,
    required this.tickets,
    required this.onTerminUpdated,
  });

  @override
  State<EditTerminDialog> createState() => _EditTerminDialogState();
}

class _EditTerminDialogState extends State<EditTerminDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;
  late TextEditingController _durationController;

  late String _category;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late int? _selectedTicketId;
  bool _isUpdating = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.termin.title);
    _descriptionController = TextEditingController(text: widget.termin.description);
    _locationController = TextEditingController(text: widget.termin.location);
    _durationController = TextEditingController(text: widget.termin.durationMinutes.toString());
    _category = widget.termin.category;
    _selectedDate = widget.termin.terminDate;
    _selectedTime = TimeOfDay.fromDateTime(widget.termin.terminDate);
    _selectedTicketId = widget.termin.ticketId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _updateTermin() async {
    if (!_formKey.currentState!.validate()) return;

    final l = AppLocalizations.of(context);

    final hour = _selectedTime.hour;
    final isValidTime = (hour >= 8 && hour <= 11) || (hour >= 14 && hour <= 17);
    if (!isValidTime) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.terminTimeRestriction), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isUpdating = true);

    final terminDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _selectedTime.hour, _selectedTime.minute);

    try {
      final result = await widget.terminService.updateTermin(
        terminId: widget.termin.id,
        title: _titleController.text.trim(),
        category: _category,
        description: _descriptionController.text.trim(),
        terminDate: terminDate,
        durationMinutes: int.parse(_durationController.text),
        location: _locationController.text.trim(),
        ticketId: _selectedTicketId,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.terminUpdated), backgroundColor: Colors.green),
        );
        widget.onTerminUpdated();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.errorMessage(result['message'])), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.errorMessage('$e')), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _deleteTermin() async {
    final l = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteTermin),
        content: Text(l.deleteTerminConfirm(widget.termin.title)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l.delete),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);

    try {
      final result = await widget.terminService.deleteTermin(widget.termin.id);

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.terminDeleted), backgroundColor: Colors.green),
        );
        widget.onTerminUpdated();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.errorMessage(result['message'])), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.errorMessage('$e')), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 650,
        height: 550,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.termin.categoryColor,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(l.editTermin, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _category,
                        decoration: InputDecoration(labelText: l.category, border: const OutlineInputBorder()),
                        items: [
                          DropdownMenuItem(value: 'vorstandssitzung', child: Text(l.boardMeeting)),
                          DropdownMenuItem(value: 'mitgliederversammlung', child: Text(l.generalAssembly)),
                          DropdownMenuItem(value: 'schulung', child: Text(l.training)),
                          DropdownMenuItem(value: 'sonstiges', child: Text(l.other)),
                        ],
                        onChanged: (value) => setState(() => _category = value!),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(controller: _titleController, autofocus: true, decoration: InputDecoration(labelText: l.title, border: const OutlineInputBorder()), validator: (v) => v?.trim().isEmpty ?? true ? l.required : null),
                      const SizedBox(height: 16),
                      TextFormField(controller: _descriptionController, decoration: InputDecoration(labelText: l.description, border: const OutlineInputBorder()), maxLines: 2),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: OutlinedButton.icon(onPressed: () async { final d = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365))); if (d != null) setState(() => _selectedDate = d); }, icon: const Icon(Icons.calendar_today), label: Text(DateFormat('dd.MM.yyyy').format(_selectedDate)))),
                          const SizedBox(width: 12),
                          Expanded(child: OutlinedButton.icon(onPressed: () async { final t = await showTimePicker(context: context, initialTime: _selectedTime); if (t != null) setState(() => _selectedTime = t); }, icon: const Icon(Icons.access_time), label: Text(_selectedTime.format(context)))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: TextFormField(controller: _durationController, decoration: InputDecoration(labelText: l.durationMinutes, border: const OutlineInputBorder()), keyboardType: TextInputType.number)),
                          const SizedBox(width: 12),
                          Expanded(flex: 2, child: TextFormField(controller: _locationController, decoration: InputDecoration(labelText: l.locationRequired, border: const OutlineInputBorder()))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade300))),
              child: Row(
                children: [
                  ElevatedButton.icon(onPressed: _isDeleting || _isUpdating ? null : _deleteTermin, icon: const Icon(Icons.delete), label: Text(l.delete), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white)),
                  const Spacer(),
                  TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(onPressed: _isUpdating || _isDeleting ? null : _updateTermin, icon: _isUpdating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check), label: Text(l.save), style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
