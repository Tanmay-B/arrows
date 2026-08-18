import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../services/ad_service.dart';
import '../widgets/ad_banner.dart';
import '../widgets/game_board.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final ConfettiController _confettiController;
  int? _celebratedSession;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

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

  Future<void> _showWinDialog(GameProvider provider) async {
    final isLastLevel = !provider.hasNextLevel;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Consumer<GameProvider>(
          builder: (context, provider, _) {
            final nextReady = provider.isNextLevelReady;

            return AlertDialog(
              icon: const Icon(Icons.emoji_events_rounded),
              title: const Text('Level Cleared!'),
              content: Text(
                isLastLevel
                    ? 'You cleared every board. Play again from the start?'
                    : 'Great job! Continue to the next board or replay this one.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    provider.restart();
                  },
                  child: const Text('Replay'),
                ),
                if (!isLastLevel)
                  FilledButton(
                    onPressed: nextReady
                        ? () async {
                            Navigator.of(dialogContext).pop();
                            await context
                                .read<GameProvider>()
                                .continueToNextLevel();
                          }
                        : null,
                    child: nextReady
                        ? const Text('Next Board')
                        : const SizedBox(
                            width: 110,
                            height: 20,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text('Loading...'),
                              ],
                            ),
                          ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  void _handleLevelWin(GameProvider provider) {
    if (provider.status != GameStatus.won) return;
    if (_celebratedSession == provider.boardSession) return;

    _celebratedSession = provider.boardSession;
    _confettiController.play();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showWinDialog(context.read<GameProvider>());
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    _handleLevelWin(provider);

    final colorScheme = Theme.of(context).colorScheme;
    final canHint =
        provider.status == GameStatus.playing && !provider.isAnimating;

    return Stack(
      children: [
        Scaffold(
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
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            emissionFrequency: 0.08,
            numberOfParticles: 24,
            maxBlastForce: 28,
            minBlastForce: 12,
            gravity: 0.2,
            colors: const [
              Color(0xFFB07B26),
              Color(0xFF56B8E8),
              Color(0xFF7BC67E),
              Color(0xFFE8A756),
              Color(0xFF9B7EDE),
            ],
          ),
        ),
        if (provider.isLoadingLevel)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.35),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Preparing next board...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
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
