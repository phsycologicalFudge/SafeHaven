import 'package:flutter/material.dart';

import '../../services/ratings/rating_service.dart';
import '../../services/store_service.dart';

class RatingSheet extends StatefulWidget {
  const RatingSheet({super.key, required this.app});

  final PublicStoreApp app;

  static Future<void> show(BuildContext context, PublicStoreApp app) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1118),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => RatingSheet(app: app),
    );
  }

  @override
  State<RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<RatingSheet> {
  int _selected = 0;
  bool _submitting = false;
  RatingResult? _result;

  Future<void> _submit() async {
    if (_selected == 0 || _submitting) return;
    setState(() => _submitting = true);

    final result = await RatingService.instance.submitRating(
      packageName: widget.app.packageName,
      rating: _selected,
    );

    if (mounted) setState(() { _submitting = false; _result = result; });

    if (result == RatingResult.ok && mounted) {
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF3A3F4A),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              widget.app.name,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap a star to rate this app',
              style: TextStyle(fontSize: 13, color: Color(0xFF9EA3AD)),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final star = i + 1;
                return GestureDetector(
                  onTap: _result == null
                      ? () => setState(() => _selected = star)
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      star <= _selected
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 44,
                      color: star <= _selected
                          ? Colors.white
                          : const Color(0xFF3A3F4A),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            if (_result != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  _resultMessage(_result!),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: _result == RatingResult.ok
                        ? const Color(0xFF86EFAC)
                        : const Color(0xFFFCA5A5),
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                onPressed: _selected > 0 && !_submitting && _result == null
                    ? _submit
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: const Color(0xFF1C2028),
                  disabledForegroundColor: const Color(0xFF8B909B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  _submitting ? 'Submitting...' : 'Submit rating',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _resultMessage(RatingResult result) {
    switch (result) {
      case RatingResult.ok:
        return 'Thanks for your rating!';
      case RatingResult.alreadyRated:
        return 'You\'ve already rated this app.';
      case RatingResult.rateLimited:
        return 'Too many ratings submitted. Try again later.';
      case RatingResult.notFound:
        return 'App not found.';
      case RatingResult.error:
        return 'Something went wrong. Please try again.';
    }
  }
}
