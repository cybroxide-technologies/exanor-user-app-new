class ReferAndEarnData {
  final bool enabled;
  final String title;
  final String description;
  final List<ReferralBenefit> benefits;
  final TermsAndConditions termsAndConditions;

  ReferAndEarnData({
    required this.enabled,
    required this.title,
    required this.description,
    required this.benefits,
    required this.termsAndConditions,
  });

  factory ReferAndEarnData.fromJson(Map<String, dynamic> json) {
    var referData = json['refer_and_earn'] ?? json;
    return ReferAndEarnData(
      enabled: referData['enabled'] ?? false,
      title: referData['title'] ?? 'Refer & Earn Rewards',
      description: referData['description'] ?? '',
      benefits:
          (referData['benefits'] as List<dynamic>?)
              ?.map((e) => ReferralBenefit.fromJson(e))
              .toList() ??
          [],
      termsAndConditions: TermsAndConditions.fromJson(
        referData['terms_and_conditions'] ?? {},
      ),
    );
  }

  // Default fallback data
  factory ReferAndEarnData.defaults() {
    return ReferAndEarnData(
      enabled: true,
      title: "Refer & Earn Rewards",
      description:
          "Invite your friends to Exanor and earn exciting rewards when they sign up and place their first order.",
      benefits: [
        ReferralBenefit(
          iconType: "material",
          iconName: "account_balance_wallet",
          title: "Earn ₹100 per referral",
          subtitle:
              "Wallet credit after your friend completes their first order.",
        ),
        ReferralBenefit(
          iconType: "material",
          iconName: "card_giftcard",
          title: "Friend gets ₹50",
          subtitle: "Welcome bonus on signup using your code.",
        ),
        ReferralBenefit(
          iconType: "material",
          iconName: "groups",
          title: "Unlimited referrals",
          subtitle: "Refer as many friends as you want.",
        ),
        ReferralBenefit(
          iconType: "material",
          iconName: "schedule",
          title: "Fast rewards",
          subtitle: "Rewards credited within 24 hours.",
        ),
      ],
      termsAndConditions: TermsAndConditions(
        title: "Terms & Conditions",
        points: [
          "Referral reward is credited only after the referred user completes their first order.",
          "Rewards are added to the in-app wallet and cannot be withdrawn.",
          "Self-referrals or misuse will result in disqualification.",
          "Exanor may modify or discontinue the program at any time.",
          "All rewards are subject to verification.",
        ],
      ),
    );
  }
}

class ReferralBenefit {
  final String iconType;
  final String iconName;
  final String title;
  final String subtitle;

  ReferralBenefit({
    required this.iconType,
    required this.iconName,
    required this.title,
    required this.subtitle,
  });

  factory ReferralBenefit.fromJson(Map<String, dynamic> json) {
    return ReferralBenefit(
      iconType: json['icon']?['type'] ?? 'material',
      iconName: json['icon']?['name'] ?? 'star',
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
    );
  }
}

class TermsAndConditions {
  final String title;
  final List<String> points;

  TermsAndConditions({required this.title, required this.points});

  factory TermsAndConditions.fromJson(Map<String, dynamic> json) {
    return TermsAndConditions(
      title: json['title'] ?? 'Terms & Conditions',
      points:
          (json['points'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}
