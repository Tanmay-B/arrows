import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../services/ad_service.dart';
import '../widgets/ad_banner.dart';
import '../widgets/game_board.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  Future<void> _requestHint(BuildContext context) async {
    final provider = context.read<GameProvider>();
    if (provider.status != GameStatus.playing || provider.isAnimating) return;

    await AdService.instance.showInterstitial(
      onFinished: () {
        if (!context.mounted) return;
        final hinted = context.read<GameProvider>().revealHint();
        if (hinted == null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hint available for this board.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final canHint =
        provider.status == GameStatus.playing && !provider.isAnimating;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 48,
                    child: IconButton(
                      onPressed: provider.canGoBack
                          ? provider.previousLevel
                          : null,
                      icon: const Icon(Icons.arrow_back_rounded),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          children: [
                            Text(
                              'Level ${provider.levelIndex + 1}',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFB07B26),
                                  ),
                            ),
                            ...List.generate(
                              3,
                              (index) => Icon(
                                Icons.water_drop_rounded,
                                size: 18,
                                color: index < provider.lives
                                    ? const Color(0xFF56B8E8)
                                    : colorScheme.outlineVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          provider.level.name,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: IconButton(
                      onPressed: provider.restart,
                      icon: const Icon(Icons.refresh_rounded),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Expanded(
              child: ClipRect(
                child: GameBoard(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _RoundAction(
                        icon: provider.showShapeBackground
                            ? Icons.grid_view_rounded
                            : Icons.grid_off_rounded,
                        label: provider.showShapeBackground
                            ? '${provider.board.arrows.length} left'
                            : 'Show grid',
                        onTap: provider.toggleShapeBackground,
                      ),
                      const SizedBox(width: 28),
                      _RoundAction(
                        icon: Icons.lightbulb_outline_rounded,
                        label: 'Hint',
                        onTap: canHint ? () => _requestHint(context) : null,
                      ),
                    ],
                  ),
                  if (provider.status == GameStatus.won) ...[
                    const SizedBox(height: 16),
                    _WinBanner(
                      isLastLevel:
                          provider.levelIndex >= provider.levelCount - 1,
                      onNext: provider.nextLevel,
                      onRestart: provider.restart,
                    ),
                  ],
                  if (provider.status == GameStatus.lost) ...[
                    const SizedBox(height: 16),
                    _LostBanner(onRestart: provider.restart),
                  ],
                ],
              ),
            ),
            const AdBanner(),
          ],
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Column(
      children: [
        Material(
          color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.6),
          shape: const CircleBorder(),
          elevation: enabled ? 3 : 0,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 58,
              height: 58,
              child: Icon(
                icon,
                color: enabled
                    ? const Color(0xFF66584B)
                    : const Color(0xFF998B7E),
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: enabled ? null : Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

class _WinBanner extends StatelessWidget {
  const _WinBanner({
    required this.isLastLevel,
    required this.onNext,
    required this.onRestart,
  });

  final bool isLastLevel;
  final VoidCallback onNext;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              Icons.emoji_events_rounded,
              color: colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isLastLevel ? 'All levels cleared!' : 'Level cleared!',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: isLastLevel ? onRestart : onNext,
              child: Text(isLastLevel ? 'Replay' : 'Continue'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LostBanner extends StatelessWidget {
  const _LostBanner({required this.onRestart});

  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Expanded(child: Text('No drops left. Try the level again.')),
            TextButton(onPressed: onRestart, child: const Text('Restart')),
          ],
        ),
      ),
    );
  }
}
