class RewardItem {
  final String id;
  final String title;
  final String description;
  final int costCoins;
  final String iconEmoji;
  final String category; // 'Break', 'Treat', 'Entertainment', 'Custom'
  final bool isCustom;
  int timesRedeemed;

  RewardItem({
    required this.id,
    required this.title,
    required this.description,
    required this.costCoins,
    required this.iconEmoji,
    required this.category,
    this.isCustom = false,
    this.timesRedeemed = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'costCoins': costCoins,
    'iconEmoji': iconEmoji,
    'category': category,
    'isCustom': isCustom,
    'timesRedeemed': timesRedeemed,
  };

  factory RewardItem.fromJson(Map<String, dynamic> json) => RewardItem(
    id: json['id']?.toString() ?? '',
    title: json['title']?.toString() ?? 'Reward',
    description: json['description']?.toString() ?? '',
    costCoins: (json['costCoins'] as num?)?.toInt() ?? 0,
    iconEmoji: json['iconEmoji']?.toString() ?? '🎁',
    category: json['category']?.toString() ?? 'Treat',
    isCustom: json['isCustom'] as bool? ?? false,
    timesRedeemed: (json['timesRedeemed'] as num?)?.toInt() ?? 0,
  );
}
