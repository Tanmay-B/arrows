import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../services/ad_service.dart';
import '../widgets/ad_banner.dart';
import '../widgets/game_board.dart';
import 'home_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final ConfettiController _confettiController;
  int? _celebratedSession;
  int? _shownLostGeneration;

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

  Widget _buildConfettiOverlay() {
    return IgnorePointer(
      child: Align(
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
    );
  }

  Future<void> _goToNextBoard() async {
    final provider = context.read<GameProvider>();
    await AdService.instance.showInterstitial();
    if (!mounted) return;
    await provider.continueToNextLevel();
  }

  Future<void> _showWinDialog(GameProvider provider) async {
    final isLastLevel = !provider.hasNextLevel;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Stack(
          children: [
            Center(
              child: Consumer<GameProvider>(
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
                                  await _goToNextBoard();
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
              ),
            ),
            Positioned.fill(child: _buildConfettiOverlay()),
          ],
        );
      },
    );
  }

  void _handleLevelWin(GameProvider provider) {
    if (provider.status != GameStatus.won) return;
    if (_celebratedSession == provider.boardSession) return;

    _celebratedSession = provider.boardSession;
    _confettiController.play();
    AdService.instance.preloadInterstitial();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showWinDialog(context.read<GameProvider>());
    });
  }

  Future<void> _showLostDialog(GameProvider provider) async {
    AdService.instance.preloadRewarded();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          icon: Icon(
            Icons.water_drop_outlined,
            color: Theme.of(dialogContext).colorScheme.primary,
          ),
          title: const Text('No drops left'),
          content: const Text(
            'Watch an ad to earn another drop and keep going, or restart '
            'the level from the beginning.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                provider.restart();
              },
              child: const Text('Restart'),
            ),
            FilledButton.icon(
              onPressed: () async {
                final navigator = Navigator.of(dialogContext);
                final messenger = ScaffoldMessenger.of(context);
                final rewarded = await AdService.instance.showRewardedAd(
                  onRewardEarned: provider.restoreLifeFromAd,
                );
                if (!mounted) return;
                if (rewarded) {
                  navigator.pop();
                  return;
                }
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Ad unavailable right now. Try again or restart.',
                    ),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.play_circle_outline_rounded),
              label: const Text('Watch ad for drop'),
            ),
          ],
        );
      },
    );
  }

  void _handleLevelLost(GameProvider provider) {
    if (provider.status != GameStatus.lost) return;
    if (_shownLostGeneration == provider.lossGeneration) return;

    _shownLostGeneration = provider.lossGeneration;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showLostDialog(context.read<GameProvider>());
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    _handleLevelWin(provider);
    _handleLevelLost(provider);

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
                          onPressed: () {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute<void>(
                                builder: (_) => const HomeScreen(),
                              ),
                              (route) => false,
                            );
                          },
                          icon: const Icon(Icons.home_rounded),
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
                    ],
                  ),
                ),
                const AdBanner(),
              ],
            ),
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
