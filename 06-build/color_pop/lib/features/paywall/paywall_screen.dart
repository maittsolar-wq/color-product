import 'package:flutter/material.dart';

/// SCR-PAYWALL-001 — UI + navigation ONLY, per DD-009 ("Paywall and
/// Premium states remain in V1 for flow validation"). PASS 6.1 §2 rebuilt
/// the visual content (headline, benefits, stats, two subscription option
/// cards, CTA, footer) to the new spec while keeping this file's original
/// isolated-placeholder architecture from Pass 6 unchanged.
///
/// There is NO RevenueCat/IAP/entitlement logic anywhere in this file.
/// [_handlePurchase] and [_handleRestore] are the ONE isolated, clearly-
/// marked placeholder each — a later Monetization pass replaces exactly
/// these two call sites and nothing else. The weekly/yearly plan toggle
/// below is local UI-only selection state; it never affects what the CTA
/// does.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

enum _PlanOption { weekly, yearly }

class _PaywallScreenState extends State<PaywallScreen> {
  _PlanOption _selected = _PlanOption.weekly;

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
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 220,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFF3E3F7), Color(0xFFFFFFFF)],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: -50,
                      left: -40,
                      child: _blob(160, const Color(0xFFE9C7EE)),
                    ),
                    Positioned(
                      top: -30,
                      right: -50,
                      child: _blob(190, const Color(0xFFD3C3F5)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 28),
              children: [
                _Headline(),
                const SizedBox(height: 22),
                const _BenefitsRow(),
                const SizedBox(height: 24),
                const _StatsRow(),
                const SizedBox(height: 24),
                _PlanCard(
                  selected: _selected == _PlanOption.weekly,
                  title: 'Weekly Access',
                  subtitle: '3 days free trial',
                  price: 'Then \$7.99/Week',
                  onTap: () => setState(() => _selected = _PlanOption.weekly),
                ),
                const SizedBox(height: 12),
                _PlanCard(
                  selected: _selected == _PlanOption.yearly,
                  title: 'Year Access',
                  subtitle: '\$49.99/year',
                  price: 'Then \$0.95/week',
                  onTap: () => setState(() => _selected = _PlanOption.yearly),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C4DFF), Color(0xFFB16CE8)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        key: const Key('paywall-purchase'),
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _handlePurchase(context),
                        child: const Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.workspace_premium, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Start Free Trial',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Try 7 days for free. Cancel anytime.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF777777)),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Privacy Policy', style: TextStyle(fontSize: 11.5, color: Color(0xFF999999))),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text('|', style: TextStyle(fontSize: 11.5, color: Color(0xFFCCCCCC))),
                    ),
                    const Text('Terms of Use', style: TextStyle(fontSize: 11.5, color: Color(0xFF999999))),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text('|', style: TextStyle(fontSize: 11.5, color: Color(0xFFCCCCCC))),
                    ),
                    GestureDetector(
                      key: const Key('paywall-restore'),
                      onTap: () => _handleRestore(context),
                      child: const Text(
                        'Restore',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF999999), decoration: TextDecoration.underline),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: SafeArea(
              child: IconButton(
                key: const Key('paywall-close'),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, size: 20),
                style: IconButton.styleFrom(backgroundColor: Colors.white, shape: const CircleBorder()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _blob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color.withValues(alpha: 0.6), color.withValues(alpha: 0.0)]),
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline();

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: const TextSpan(
        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.22, color: Color(0xFF151515)),
        children: [
          TextSpan(text: 'Unlock '),
          TextSpan(text: 'Premium', style: TextStyle(color: Color(0xFF7C4DFF))),
          TextSpan(text: '\n'),
          TextSpan(text: 'Coloring', style: TextStyle(color: Color(0xFF7C4DFF))),
          TextSpan(text: ' Experience'),
        ],
      ),
    );
  }
}

class _BenefitsRow extends StatelessWidget {
  const _BenefitsRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: _BenefitItem(icon: Icons.tune, color: Color(0xFF7C4DFF), label: 'Advanced\nTools')),
        Expanded(child: _BenefitItem(icon: Icons.high_quality, color: Color(0xFF2F8FE8), label: 'HD\nQuality')),
        Expanded(child: _BenefitItem(icon: Icons.palette, color: Color(0xFFE85FA0), label: 'Unlimited\nColoring')),
      ],
    );
  }
}

class _BenefitItem extends StatelessWidget {
  const _BenefitItem({required this.icon, required this.color, required this.label});

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.12)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF3A3A3C), height: 1.2),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: const Color(0xFFF8F6FC), borderRadius: BorderRadius.circular(16)),
      child: const Row(
        children: [
          Expanded(child: _StatItem(icon: Icons.download_rounded, value: '500K+', label: 'Downloads')),
          _StatDivider(),
          Expanded(child: _StatItem(icon: Icons.star_rounded, value: '4.8/5', label: 'User Rating')),
          _StatDivider(),
          Expanded(child: _StatItem(icon: Icons.favorite_rounded, value: 'Loved by', label: 'Coloring Fans')),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36, color: const Color(0xFFE4DFF0));
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF7C4DFF)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF151515))),
        const SizedBox(height: 2),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.5, color: Color(0xFF8A8A90))),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final String price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFF5F0FF) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? const Color(0xFF7C4DFF) : const Color(0xFFE4E4E7), width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? const Color(0xFF7C4DFF) : const Color(0xFFBBBBBF),
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 12.5, color: Color(0xFF777777))),
                  ],
                ),
              ),
              Text(
                price,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? const Color(0xFF7C4DFF) : const Color(0xFF777777),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
