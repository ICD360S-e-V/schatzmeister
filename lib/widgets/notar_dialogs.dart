import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../l10n/app_localizations.dart';

/// Shows a dialog to edit notar data
Future<bool> showEditNotarDialog({
  required BuildContext context,
  required Map<String, dynamic> data,
  required ApiService apiService,
}) async {
  final l = AppLocalizations.of(context);
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController(text: data['name'] ?? '');
  final name2Controller = TextEditingController(text: data['name2'] ?? '');
  final strasseController = TextEditingController(text: data['strasse'] ?? '');
  final hausnummerController = TextEditingController(text: data['hausnummer'] ?? '');
  final plzController = TextEditingController(text: data['plz'] ?? '');
  final ortController = TextEditingController(text: data['ort'] ?? '');
  final telefonController = TextEditingController(text: data['telefon'] ?? '');
  final faxController = TextEditingController(text: data['fax'] ?? '');
  final emailController = TextEditingController(text: data['email'] ?? '');
  final websiteController = TextEditingController(text: data['website'] ?? '');
  final notizenController = TextEditingController(text: data['notizen'] ?? '');

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.edit, color: Colors.orange),
          const SizedBox(width: 8),
          Text(l.editNotarData),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: '${l.name} *',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.person),
                  ),
                  validator: (v) => v?.isEmpty ?? true ? l.requiredField : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: name2Controller,
                  decoration: InputDecoration(
                    labelText: l.additionalName,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(l.addressLabel, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: strasseController,
                        decoration: InputDecoration(
                          labelText: l.street,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: hausnummerController,
                        decoration: InputDecoration(
                          labelText: l.houseNumber,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: TextFormField(
                        controller: plzController,
                        decoration: InputDecoration(
                          labelText: l.postalCode,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: ortController,
                        decoration: InputDecoration(
                          labelText: l.city,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(l.contactLabel, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: telefonController,
                  decoration: InputDecoration(
                    labelText: l.phone,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: faxController,
                  decoration: InputDecoration(
                    labelText: l.faxLabel,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.fax),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: l.email,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: websiteController,
                  decoration: InputDecoration(
                    labelText: l.websiteLabel,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.language),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                TextFormField(
                  controller: notizenController,
                  decoration: InputDecoration(
                    labelText: l.notes,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.notes),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.cancel),
        ),
        ElevatedButton(
          onPressed: () async {
            if (formKey.currentState?.validate() ?? false) {
              final navigator = Navigator.of(context);
              final updateResult = await apiService.updateVereinverwaltung({
                'id': data['id'],
                'name': nameController.text,
                'name2': name2Controller.text,
                'strasse': strasseController.text,
                'hausnummer': hausnummerController.text,
                'plz': plzController.text,
                'ort': ortController.text,
                'telefon': telefonController.text,
                'fax': faxController.text,
                'email': emailController.text,
                'website': websiteController.text,
                'notizen': notizenController.text,
              });
              navigator.pop(updateResult['success'] == true);
            }
          },
          child: Text(l.save),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Shows a dialog to add a new Rechnung
Future<bool> showAddRechnungDialog({
  required BuildContext context,
  required int notarId,
  required ApiService apiService,
}) async {
  final l = AppLocalizations.of(context);
  final formKey = GlobalKey<FormState>();
  final rechnungsnummerController = TextEditingController();
  final betragController = TextEditingController();
  final beschreibungController = TextEditingController();
  DateTime selectedDate = DateTime.now();
  bool bezahlt = false;

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: Colors.blue),
            const SizedBox(width: 8),
            Text(l.newInvoice),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: rechnungsnummerController,
                    decoration: InputDecoration(
                      labelText: l.invoiceNumber,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => v?.isEmpty ?? true ? l.requiredField : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: betragController,
                    decoration: InputDecoration(
                      labelText: l.amountEuro,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) => v?.isEmpty ?? true ? l.requiredField : null,
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.date),
                    subtitle: Text('${selectedDate.day}.${selectedDate.month}.${selectedDate.year}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        setDialogState(() => selectedDate = date);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: beschreibungController,
                    decoration: InputDecoration(
                      labelText: l.description,
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.paidCheckbox),
                    value: bezahlt,
                    onChanged: (v) => setDialogState(() => bezahlt = v ?? false),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                final navigator = Navigator.of(context);
                final createResult = await apiService.createNotarRechnung({
                  'notar_id': notarId,
                  'rechnungsnummer': rechnungsnummerController.text,
                  'datum': '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                  'betrag': double.tryParse(betragController.text) ?? 0,
                  'beschreibung': beschreibungController.text,
                  'bezahlt': bezahlt,
                });
                navigator.pop(createResult['success'] == true);
              }
            },
            child: Text(l.save),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}

/// Shows a dialog to add a new Besuch
Future<bool> showAddBesuchDialog({
  required BuildContext context,
  required int notarId,
  required ApiService apiService,
}) async {
  final l = AppLocalizations.of(context);
  final formKey = GlobalKey<FormState>();
  final zweckController = TextEditingController();
  final teilnehmerController = TextEditingController();
  final notizenController = TextEditingController();
  DateTime selectedDate = DateTime.now();
  TimeOfDay? selectedTime;
  String status = 'geplant';

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.calendar_today, color: Colors.green),
            const SizedBox(width: 8),
            Text(l.newVisit),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: zweckController,
                    decoration: InputDecoration(
                      labelText: l.purposeOccasion,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => v?.isEmpty ?? true ? l.requiredField : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l.date),
                          subtitle: Text('${selectedDate.day}.${selectedDate.month}.${selectedDate.year}'),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (date != null) {
                              setDialogState(() => selectedDate = date);
                            }
                          },
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l.time),
                          subtitle: Text(selectedTime != null
                              ? '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}'
                              : l.notSetTime),
                          trailing: const Icon(Icons.access_time),
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: selectedTime ?? TimeOfDay.now(),
                            );
                            if (time != null) {
                              setDialogState(() => selectedTime = time);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: teilnehmerController,
                    decoration: InputDecoration(
                      labelText: l.participantsLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: notizenController,
                    decoration: InputDecoration(
                      labelText: l.notes,
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: InputDecoration(
                      labelText: l.status,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(value: 'geplant', child: Text(l.plannedStatus)),
                      DropdownMenuItem(value: 'abgeschlossen', child: Text(l.completedStatus)),
                      DropdownMenuItem(value: 'abgesagt', child: Text(l.cancelledStatusNotar)),
                    ],
                    onChanged: (v) => setDialogState(() => status = v ?? 'geplant'),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                final navigator = Navigator.of(context);
                final createResult = await apiService.createNotarBesuch({
                  'notar_id': notarId,
                  'datum': '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                  'uhrzeit': selectedTime != null
                      ? '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}:00'
                      : null,
                  'zweck': zweckController.text,
                  'teilnehmer': teilnehmerController.text,
                  'notizen': notizenController.text,
                  'status': status,
                });
                navigator.pop(createResult['success'] == true);
              }
            },
            child: Text(l.save),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}

/// Shows a dialog to add a new Dokument
Future<bool> showAddDokumentDialog({
  required BuildContext context,
  required int notarId,
  required ApiService apiService,
}) async {
  final l = AppLocalizations.of(context);
  final formKey = GlobalKey<FormState>();
  final titelController = TextEditingController();
  final beschreibungController = TextEditingController();
  final urkundennummerController = TextEditingController();
  DateTime selectedDate = DateTime.now();
  String typ = 'sonstiges';

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.folder_open, color: Colors.purple),
            const SizedBox(width: 8),
            Text(l.newDocument),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titelController,
                    decoration: InputDecoration(
                      labelText: l.titleRequired2,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => v?.isEmpty ?? true ? l.requiredField : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: typ,
                    decoration: InputDecoration(
                      labelText: l.documentTypeLabel,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(value: 'urkunde', child: Text(l.documentUrkunde)),
                      DropdownMenuItem(value: 'vollmacht', child: Text(l.documentVollmacht)),
                      DropdownMenuItem(value: 'satzung', child: Text(l.documentSatzung)),
                      DropdownMenuItem(value: 'protokoll', child: Text(l.documentProtokoll)),
                      DropdownMenuItem(value: 'antrag', child: Text(l.documentAntrag)),
                      DropdownMenuItem(value: 'sonstiges', child: Text(l.documentSonstiges)),
                    ],
                    onChanged: (v) => setDialogState(() => typ = v ?? 'sonstiges'),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.date),
                    subtitle: Text('${selectedDate.day}.${selectedDate.month}.${selectedDate.year}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        setDialogState(() => selectedDate = date);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: urkundennummerController,
                    decoration: InputDecoration(
                      labelText: l.deedNumber,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: beschreibungController,
                    decoration: InputDecoration(
                      labelText: l.description,
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                final navigator = Navigator.of(context);
                final createResult = await apiService.createNotarDokument({
                  'notar_id': notarId,
                  'titel': titelController.text,
                  'typ': typ,
                  'datum': '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                  'beschreibung': beschreibungController.text,
                  'urkundennummer': urkundennummerController.text,
                });
                navigator.pop(createResult['success'] == true);
              }
            },
            child: Text(l.save),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}

/// Shows a detail dialog for an existing Aufgabe (edit, delete, toggle status)
Future<bool> showAufgabeDetailDialog({
  required BuildContext context,
  required Map<String, dynamic> aufgabe,
  required ApiService apiService,
}) async {
  final l = AppLocalizations.of(context);
  final formKey = GlobalKey<FormState>();
  final beschreibungController = TextEditingController(text: aufgabe['beschreibung'] ?? '');
  final notizenController = TextEditingController(text: aufgabe['notizen'] ?? '');

  // Parse existing date
  DateTime selectedDate = DateTime.now();
  if (aufgabe['datum'] != null) {
    try {
      selectedDate = DateTime.parse(aufgabe['datum']);
    } catch (_) {}
  }

  // Parse existing time
  TimeOfDay? selectedTime;
  if (aufgabe['uhrzeit'] != null && aufgabe['uhrzeit'].toString().isNotEmpty) {
    final parts = aufgabe['uhrzeit'].toString().split(':');
    if (parts.length >= 2) {
      selectedTime = TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 0,
        minute: int.tryParse(parts[1]) ?? 0,
      );
    }
  }

  String status = aufgabe['status'] ?? 'offen';
  bool changed = false;

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Row(
          children: [
            Icon(
              status == 'erledigt' ? Icons.check_circle : Icons.task_alt,
              color: status == 'erledigt' ? Colors.green : Colors.deepOrange,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(l.editTask)),
            // Delete button
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: l.delete,
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l.deleteTask),
                    content: Text(l.taskDeleteConfirm(aufgabe['beschreibung'] ?? '')),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(l.cancel),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(l.delete, style: const TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  if (!context.mounted) return;
                  final navigator = Navigator.of(context);
                  await apiService.deleteNotarAufgabe(aufgabe['id']);
                  navigator.pop(true);
                }
              },
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Status toggle button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: Icon(
                        status == 'erledigt' ? Icons.undo : Icons.check_circle,
                        color: status == 'erledigt' ? Colors.orange : Colors.green,
                      ),
                      label: Text(
                        status == 'erledigt' ? l.markAsOpen : l.markAsCompleted,
                        style: TextStyle(
                          color: status == 'erledigt' ? Colors.orange : Colors.green,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: status == 'erledigt' ? Colors.orange : Colors.green,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        setDialogState(() {
                          status = status == 'erledigt' ? 'offen' : 'erledigt';
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: beschreibungController,
                    decoration: InputDecoration(
                      labelText: l.descriptionRequired,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => v?.isEmpty ?? true ? l.requiredField : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l.date),
                          subtitle: Text('${selectedDate.day}.${selectedDate.month}.${selectedDate.year}'),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (date != null) {
                              setDialogState(() => selectedDate = date);
                            }
                          },
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l.time),
                          subtitle: Text(selectedTime != null
                              ? '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}'
                              : l.notSetTime),
                          trailing: const Icon(Icons.access_time),
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: selectedTime ?? TimeOfDay.now(),
                            );
                            if (time != null) {
                              setDialogState(() => selectedTime = time);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: notizenController,
                    decoration: InputDecoration(
                      labelText: l.notes,
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, changed),
            child: Text(l.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                final navigator = Navigator.of(context);
                final updateResult = await apiService.updateNotarAufgabe({
                  'id': aufgabe['id'],
                  'beschreibung': beschreibungController.text,
                  'datum': '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                  'uhrzeit': selectedTime != null
                      ? '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}:00'
                      : null,
                  'status': status,
                  'notizen': notizenController.text,
                });
                navigator.pop(updateResult['success'] == true);
              }
            },
            child: Text(l.save),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}

/// Shows a dialog to add a new Aufgabe
Future<bool> showAddAufgabeDialog({
  required BuildContext context,
  required int notarId,
  required ApiService apiService,
}) async {
  final l = AppLocalizations.of(context);
  final formKey = GlobalKey<FormState>();
  final beschreibungController = TextEditingController();
  final notizenController = TextEditingController();
  DateTime selectedDate = DateTime.now();
  TimeOfDay? selectedTime;
  String status = 'offen';

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.task_alt, color: Colors.deepOrange),
            const SizedBox(width: 8),
            Text(l.newTask),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: beschreibungController,
                    decoration: InputDecoration(
                      labelText: l.descriptionRequired,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => v?.isEmpty ?? true ? l.requiredField : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l.date),
                          subtitle: Text('${selectedDate.day}.${selectedDate.month}.${selectedDate.year}'),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (date != null) {
                              setDialogState(() => selectedDate = date);
                            }
                          },
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l.time),
                          subtitle: Text(selectedTime != null
                              ? '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}'
                              : l.notSetTime),
                          trailing: const Icon(Icons.access_time),
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: selectedTime ?? TimeOfDay.now(),
                            );
                            if (time != null) {
                              setDialogState(() => selectedTime = time);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: InputDecoration(
                      labelText: l.status,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(value: 'offen', child: Text(l.statusOpenNotar)),
                      DropdownMenuItem(value: 'erledigt', child: Text(l.statusCompletedNotar)),
                    ],
                    onChanged: (v) => setDialogState(() => status = v ?? 'offen'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: notizenController,
                    decoration: InputDecoration(
                      labelText: l.notes,
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                final navigator = Navigator.of(context);
                final createResult = await apiService.createNotarAufgabe({
                  'notar_id': notarId,
                  'datum': '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                  'uhrzeit': selectedTime != null
                      ? '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}:00'
                      : null,
                  'beschreibung': beschreibungController.text,
                  'status': status,
                  'notizen': notizenController.text,
                });
                navigator.pop(createResult['success'] == true);
              }
            },
            child: Text(l.save),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}

/// Shows a dialog to add a new Zahlung
Future<bool> showAddZahlungDialog({
  required BuildContext context,
  required int notarId,
  required ApiService apiService,
}) async {
  final l = AppLocalizations.of(context);
  final formKey = GlobalKey<FormState>();
  final betragController = TextEditingController();
  final verwendungszweckController = TextEditingController();
  final notizenController = TextEditingController();
  DateTime selectedDate = DateTime.now();
  String zahlungsart = 'ueberweisung';

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.euro, color: Colors.teal),
            const SizedBox(width: 8),
            Text(l.newPayment),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: betragController,
                    decoration: InputDecoration(
                      labelText: l.amountEuro,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) => v?.isEmpty ?? true ? l.requiredField : null,
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.date),
                    subtitle: Text('${selectedDate.day}.${selectedDate.month}.${selectedDate.year}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        setDialogState(() => selectedDate = date);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: zahlungsart,
                    decoration: InputDecoration(
                      labelText: l.paymentType,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(value: 'ueberweisung', child: Text(l.paymentTransfer)),
                      DropdownMenuItem(value: 'bar', child: Text(l.paymentCash)),
                      DropdownMenuItem(value: 'lastschrift', child: Text(l.paymentDirectDebit)),
                      DropdownMenuItem(value: 'karte', child: Text(l.paymentCard)),
                    ],
                    onChanged: (v) => setDialogState(() => zahlungsart = v ?? 'ueberweisung'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: verwendungszweckController,
                    decoration: InputDecoration(
                      labelText: l.purposeLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: notizenController,
                    decoration: InputDecoration(
                      labelText: l.notes,
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                final navigator = Navigator.of(context);
                final createResult = await apiService.createNotarZahlung({
                  'notar_id': notarId,
                  'datum': '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                  'betrag': double.tryParse(betragController.text) ?? 0,
                  'zahlungsart': zahlungsart,
                  'verwendungszweck': verwendungszweckController.text,
                  'notizen': notizenController.text,
                });
                navigator.pop(createResult['success'] == true);
              }
            },
            child: Text(l.save),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}
