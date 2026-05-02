import 'package:flutter/material.dart';

import '../services/device_identity_service.dart';


class IdentitySetupDialog extends StatefulWidget {
  const IdentitySetupDialog({super.key});

  static Future<void> showIfNeeded(BuildContext context) async {
    final ready = await DeviceIdentityService.instance.isSetUp();
    if (ready) return;
    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const IdentitySetupDialog(),
    );
  }

  @override
  State<IdentitySetupDialog> createState() => _IdentitySetupDialogState();
}

class _IdentitySetupDialogState extends State<IdentitySetupDialog> {
  final _controller = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nickname = _controller.text.trim();
    if (nickname.isEmpty) {
      setState(() => _error = 'Enter a nickname to continue.');
      return;
    }
    if (nickname.length < 2) {
      setState(() => _error = 'Nickname must be at least 2 characters.');
      return;
    }

    setState(() { _saving = true; _error = null; });

    try {
      await DeviceIdentityService.instance.setupIdentity(nickname);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() { _saving = false; _error = 'Something went wrong.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F1118),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose a nickname',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This is used for unique ratings. It is not public.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF9EA3AD),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLength: 24,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                hintText: 'e.g. alex',
                counterText: '',
                filled: true,
                fillColor: const Color(0xFF161A23),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF222734)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF222734)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF4A5568)),
                ),
                hintStyle: const TextStyle(color: Color(0xFF4A4F5A)),
              ),
              style: const TextStyle(fontSize: 15, color: Colors.white),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(fontSize: 12.5, color: Color(0xFFFCA5A5)),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: const Color(0xFF1C2028),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  _saving ? 'Saving...' : 'Continue',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
