import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../widgets/game_board.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: provider.restart,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      Expanded(
                        child: Text(
                          'Level ${provider.levelIndex + 1}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFB07B26),
                              ),
                        ),
                      ),
                      IconButton(
                        onPressed: provider.restart,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      3,
                      (index) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Icon(
                          Icons.water_drop_rounded,
                          size: 25,
                          color: index < provider.lives
                              ? const Color(0xFF56B8E8)
                              : colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    provider.level.name,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Expanded(
              child: ClipRect(
                child: GameBoard(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
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
                        onTap: () {},
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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 3,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 58,
              height: 58,
              child: Icon(icon, color: const Color(0xFF66584B)),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
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
