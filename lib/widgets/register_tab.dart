import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';

final _log = LoggerService();

class RegisterTab extends StatefulWidget {
  final ApiService apiService;
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;
  final Function(String mitgliedernummer) onRegisterSuccess;
  final ValueChanged<bool> onLoadingChanged;
  final ValueChanged<String?> onErrorChanged;
  final ValueChanged<String?> onSuccessChanged;

  const RegisterTab({
    super.key,
    required this.apiService,
    required this.isLoading,
    this.errorMessage,
    this.successMessage,
    required this.onRegisterSuccess,
    required this.onLoadingChanged,
    required this.onErrorChanged,
    required this.onSuccessChanged,
  });

  @override
  State<RegisterTab> createState() => _RegisterTabState();
}

class _RegisterTabState extends State<RegisterTab> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _recoveryCodeController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _recoveryCodeController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final l = AppLocalizations.of(context);
    if (_passwordController.text != _confirmPasswordController.text) {
      widget.onErrorChanged(l.passwordsDoNotMatch);
      return;
    }
    _log.info('Register: Attempting registration for ${_emailController.text.trim()}', tag: 'AUTH');

    widget.onLoadingChanged(true);
    widget.onErrorChanged(null);
    widget.onSuccessChanged(null);

    try {
      final result = await widget.apiService.register(
        _emailController.text.trim(),
        _passwordController.text,
        _nameController.text.trim(),
        _recoveryCodeController.text.trim(),
      );
      _log.debug('Register: API response success=${result['success']}', tag: 'AUTH');

      if (result['success'] == true) {
        final user = result['user'];
        final mitgliedernummer = user['mitgliedernummer'];
        _log.info('Register: Success! Benutzernummer=$mitgliedernummer', tag: 'AUTH');

        widget.onSuccessChanged(
          l.registrationSuccess(mitgliedernummer)
        );

        // Clear form
        _nameController.clear();
        _emailController.clear();
        _passwordController.clear();
        _confirmPasswordController.clear();
        _recoveryCodeController.clear();

        // Redirect to login tab after 10 seconds
        Future.delayed(const Duration(seconds: 10), () {
          if (mounted) {
            widget.onRegisterSuccess(mitgliedernummer);
          }
        });
      } else {
        _log.warning('Register: Failed - ${result['message']}', tag: 'AUTH');
        widget.onErrorChanged(result['message'] ?? l.registrationFailed);
      }
    } catch (e) {
      _log.error('Register: Exception - $e', tag: 'AUTH');
      widget.onErrorChanged(l.connectionErrorWith('$e'));
    } finally {
      widget.onLoadingChanged(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Error/Success message
            if (widget.errorMessage != null)
              _buildMessageBox(widget.errorMessage!, isError: true),
            if (widget.successMessage != null)
              _buildMessageBox(widget.successMessage!, isError: false),

            // Name field
            TextFormField(
              controller: _nameController,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-ZäöüÄÖÜß\s\-]')),
              ],
              decoration: InputDecoration(
                labelText: l.firstAndLastName,
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l.pleaseEnterFirstAndLastName;
                }
                if (value.length < 2) {
                  return l.nameMin2Chars;
                }
                if (!RegExp(r'^[a-zA-ZäöüÄÖÜß\s\-]+$').hasMatch(value)) {
                  return l.onlyLettersAndHyphen;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Email field
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: l.emailAddress,
                prefixIcon: const Icon(Icons.email),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l.pleaseEnterEmail;
                }
                if (!value.contains('@')) {
                  return l.pleaseEnterValidEmail;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Password field
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: l.password,
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l.pleaseEnterPasswordField;
                }
                if (value.length < 6) {
                  return l.passwordMin6Chars;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Confirm Password field
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              decoration: InputDecoration(
                labelText: l.confirmPassword,
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l.pleaseConfirmPassword;
                }
                if (value != _passwordController.text) {
                  return l.passwordsDoNotMatch;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Recovery Code field
            TextFormField(
              controller: _recoveryCodeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                labelText: l.recoveryCode,
                prefixIcon: const Icon(Icons.security),
                helperText: l.recoveryCodeHelper,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l.pleaseEnterRecoveryCodeField;
                }
                if (!RegExp(r'^\d{6}$').hasMatch(value)) {
                  return l.codeMust6Digits;
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Register button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: widget.isLoading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4a90d9),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: widget.isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        l.register,
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBox(String message, {required bool isError}) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isError ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isError ? Colors.red.shade200 : Colors.green.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? Colors.red.shade700 : Colors.green.shade700,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isError ? Colors.red.shade700 : Colors.green.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
