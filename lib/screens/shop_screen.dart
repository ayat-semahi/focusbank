import 'package:flutter/material.dart';
import '../models/reward_item.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Entertainment', 'Treat', 'Break', 'Custom'];

  void _showAddCustomRewardDialog() {
    final titleController = TextEditingController();
    final costController = TextEditingController(text: '30');
    final emojiController = TextEditingController(text: '🎁');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppTheme.surfaceBorder),
        ),
        title: const Text(
          'Create Custom Reward',
          style: TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Reward Title (e.g. 1hr Video Games)',
                  labelStyle: TextStyle(color: AppTheme.textMuted),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.primaryGold),
                  ),
                ),
                style: const TextStyle(color: AppTheme.textWhite),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: costController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cost in FocusCoins (e.g. 50)',
                  labelStyle: TextStyle(color: AppTheme.textMuted),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.primaryGold),
                  ),
                ),
                style: const TextStyle(color: AppTheme.textWhite),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emojiController,
                decoration: const InputDecoration(
                  labelText: 'Emoji Icon (e.g. 🍕 or 🎮)',
                  labelStyle: TextStyle(color: AppTheme.textMuted),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.primaryGold),
                  ),
                ),
                style: const TextStyle(color: AppTheme.textWhite),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              final title = titleController.text.trim();
              if (title.isNotEmpty) {
                final parsedCost = int.tryParse(costController.text.trim()) ?? 30;
                final cost = parsedCost <= 0 ? 1 : parsedCost;
                AppState.instance.addCustomReward(
                  title: title,
                  description: 'Personal custom reward',
                  costCoins: cost,
                  emoji: emojiController.text.trim(),
                  category: 'Custom',
                );
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add to Shop'),
          ),
        ],
      ),
    );
  }

  void _redeemReward(RewardItem reward) {
    final state = AppState.instance;
    if (state.balance < reward.costCoins) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.withdrawRed,
          content: Text(
            'Insufficient FocusCoins! You need ${reward.costCoins - state.balance} more coins.',
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppTheme.primaryGold, width: 1.5),
        ),
        title: Row(
          children: [
            Text(reward.iconEmoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 8),
            const Text(
              'Redeem Reward?',
              style: TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Spend ${reward.costCoins} FocusCoins to claim "${reward.title}"?\n\nThis will be logged in your passbook.',
          style: const TextStyle(color: AppTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Saving', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final success = state.redeemReward(reward);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppTheme.surfaceCard,
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle, color: AppTheme.depositGreen),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Enjoy! "${reward.title}" redeemed for ${reward.costCoins} FC.',
                            style: const TextStyle(color: AppTheme.textWhite),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            },
            child: const Text('Confirm & Spend'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final state = AppState.instance;
        final filteredRewards = _selectedCategory == 'All'
            ? state.rewards
            : state.rewards.where((r) => r.category == _selectedCategory).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Rewards Shop'),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.monetization_on, color: AppTheme.primaryGold, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '${state.balance} FC',
                      style: const TextStyle(
                        color: AppTheme.goldLight,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _showAddCustomRewardDialog,
            backgroundColor: AppTheme.primaryGold,
            foregroundColor: Colors.black,
            icon: const Icon(Icons.add),
            label: const Text('Custom Reward', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Pills
                SizedBox(
                  height: 48,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final isSelected = cat == _selectedCategory;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          selectedColor: AppTheme.primaryGold,
                          backgroundColor: AppTheme.surfaceCard,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.black : AppTheme.textMuted,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          onSelected: (_) {
                            setState(() => _selectedCategory = cat);
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),

                // Rewards Grid
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.85,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: filteredRewards.length,
                    itemBuilder: (context, index) {
                      final item = filteredRewards[index];
                      final canAfford = state.balance >= item.costCoins;

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceCard,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: item.isCustom
                                ? AppTheme.primaryGold.withValues(alpha: 0.4)
                                : AppTheme.surfaceBorder,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(item.iconEmoji, style: const TextStyle(fontSize: 28)),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (item.timesRedeemed > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.surfaceBorder,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '×${item.timesRedeemed}',
                                          style: const TextStyle(
                                            color: AppTheme.textMuted,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    if (item.isCustom) ...[
                                      const SizedBox(width: 4),
                                      InkWell(
                                        onTap: () => state.deleteCustomReward(item.id),
                                        borderRadius: BorderRadius.circular(8),
                                        child: const Padding(
                                          padding: EdgeInsets.all(2),
                                          child: Icon(
                                            Icons.delete_outline,
                                            size: 16,
                                            color: AppTheme.textMuted,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              item.title,
                              style: const TextStyle(
                                color: AppTheme.textWhite,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.description,
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Spacer(),
                            // Bottom Action: Cost & Button
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${item.costCoins} FC',
                                  style: const TextStyle(
                                    color: AppTheme.primaryGold,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                InkWell(
                                  onTap: () => _redeemReward(item),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: canAfford
                                          ? AppTheme.primaryGold
                                          : AppTheme.surfaceBorder,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      canAfford ? 'Redeem' : 'Locked',
                                      style: TextStyle(
                                        color: canAfford ? Colors.black : AppTheme.textDim,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
