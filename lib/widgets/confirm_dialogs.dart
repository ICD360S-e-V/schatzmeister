import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/user.dart';

String _statusLabel(BuildContext context, String status) {
  final l = AppLocalizations.of(context);
  switch (status) {
    case 'active':
      return l.active;
    case 'suspended':
      return l.suspended;
    case 'gekuendigt':
      return l.terminated;
    default:
      return status;
  }
}

/// Shows a confirmation dialog for changing user status
/// Returns true if confirmed, false otherwise
Future<bool> showStatusChangeDialog({
  required BuildContext context,
  required User user,
  required String newStatus,
}) async {
  final l = AppLocalizations.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.changeStatus),
      content: Text(
        l.changeStatusConfirm(user.name, _statusLabel(context, newStatus)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.cancel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: newStatus == 'active'
                ? Colors.green
                : newStatus == 'suspended'
                    ? Colors.orange
                    : newStatus == 'gekuendigt'
                        ? Colors.brown
                        : Colors.red,
          ),
          child: Text(l.confirm),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Shows a confirmation dialog for deleting a user
/// Returns true if confirmed, false otherwise
Future<bool> showDeleteUserDialog({
  required BuildContext context,
  required User user,
}) async {
  final l = AppLocalizations.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.deleteUser),
      content: Text(
        l.deleteUserConfirm(user.name, user.mitgliedernummer),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.cancel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: Text(l.delete),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Shows a generic confirmation dialog
/// Returns true if confirmed, false otherwise
Future<bool> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String content,
  String? cancelText,
  String? confirmText,
  Color? confirmColor,
}) async {
  final l = AppLocalizations.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelText ?? l.cancel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: confirmColor != null
              ? ElevatedButton.styleFrom(backgroundColor: confirmColor)
              : null,
          child: Text(confirmText ?? l.confirm),
        ),
      ],
    ),
  );
  return result ?? false;
}
