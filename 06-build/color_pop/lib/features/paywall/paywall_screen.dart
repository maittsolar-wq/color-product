import 'package:flutter/material.dart';

/// SCR-PAYWALL-001 (PASS 6) — UI + navigation ONLY, per DD-009 ("Paywall
/// and Premium states remain in V1 for flow validation"). Content/layout
/// matches the locked prototype's concrete SCR-PAYWALL-001 exactly (close,
/// premium visual, value proposition, benefits, offer, CTA, restore,
/// legal — ui-spec.md §13), styled with this app's existing purple accent
/// rather than the prototype's generic black `.primary` button, per Pass
/// 6's explicit "match existing Color Pop visual language."
///
/// There is NO RevenueCat/IAP/entitlement logic anywhere in this file.
/// [_handlePurchase] and [_handleRestore] are the ONE isolated, clearly-
/// marked placeholder each — a later Monetization pass replaces exactly
/// these two call sites and nothing else; no subscription business logic
/// is spread anywhere else in the widget tree.
class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  /// PASS 6 §9 — visually functional, but performs NO purchase. Never
  /// claims success, never grants PRO. Swap point for RevenueCat later.
  void _handlePurchase(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text("Purchases aren't available yet."),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  /// PASS 6 §10 — visually functional, but performs NO restoration. Never
  /// fakes a restored state. Swap point for RevenueCat later.
  void _handleRestore(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text("Restore isn't available yet."),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(24, 70, 24, 32),
              children: [
                Container(
                  width: 86,
                  height: 86,
                  margin: const EdgeInsets.only(bottom: 16),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF151515)),
                  child: const Icon(Icons.star_rounded, color: Colors.white, size: 40),
                ),
                const Text(
                  'COLORING PREMIUM',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w600, color: Color(0xFF7A7A7A)),
                ),
                const SizedBox(height: 6),
                const Text(
                  'More pages. More tools. No ads.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800, height: 1.12),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Unlock the full relaxing coloring experience.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Color(0xFF777777)),
                ),
                const SizedBox(height: 22),
                const _BenefitRow(title: 'Premium artwork', subtitle: 'Unlock all premium drawings.'),
                const _BenefitRow(title: 'No ads', subtitle: 'Color without interruptions.'),
                const _BenefitRow(title: 'Extra tools', subtitle: 'More brushes and effects.'),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: const Color(0xFFF0ECFF), borderRadius: BorderRadius.circular(16)),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('7-day free trial', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      SizedBox(height: 3),
                      Text('Then \$X.XX / week', style: TextStyle(fontSize: 12, color: Color(0xFF777777))),
                    ],
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('paywall-purchase'),
                    onPressed: () => _handlePurchase(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7C4DFF),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: const Text('Start Free Trial', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white)),
                  ),
                ),
                Center(
                  child: TextButton(
                    key: const Key('paywall-restore'),
                    onPressed: () => _handleRestore(context),
                    child: const Text(
                      'Restore Purchase',
                      style: TextStyle(color: Color(0xFF151515), decoration: TextDecoration.underline, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text('Terms · Privacy', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Color(0xFF999999))),
              ],
            ),
            Positioned(
              left: 0,
              top: 0,
              child: IconButton(
                key: const Key('paywall-close'),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, size: 20),
                style: IconButton.styleFrom(backgroundColor: const Color(0xFFF5F5F6), shape: const CircleBorder()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 25,
            height: 25,
            alignment: Alignment.center,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE8F5EA)),
            child: const Icon(Icons.check, size: 15, color: Color(0xFF168B2D)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12.5, color: Color(0xFF777777))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
