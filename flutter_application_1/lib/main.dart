import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Advanced Missile Dodge Game',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  static const double playerSize = 50;
  static const double gameSpeed = 60;

  late double playerX;
  late double playerY;
  late Size screenSize;
  List<Missile> missiles = [];
  List<PowerUp> powerUps = [];
  List<PlayerMissile> playerMissiles = [];
  int score = 0;
  bool gameOver = false;
  double difficulty = 1;
  bool isInvincible = false;
  int survivedTime = 0;
  int missilesDodged = 0;
  Boss? currentBoss;
  int upgradePOWER = 0;
  int upgradeAGILITY = 0;
  int upgradeLUCK = 0;

  late AnimationController _playerAnimationController;
  late Animation<double> _playerAnimation;
  List<Star> stars = [];

  @override
  void initState() {
    super.initState();
    _playerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _playerAnimation = Tween<double>(begin: 1, end: 1.2).animate(_playerAnimationController);
    startGame();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    screenSize = MediaQuery.of(context).size;
    _generateStars();
  }

  @override
  void dispose() {
    _playerAnimationController.dispose();
    super.dispose();
  }

  void startGame() {
    playerX = 0;
    playerY = 0;
    missiles.clear();
    powerUps.clear();
    playerMissiles.clear();
    score = 0;
    gameOver = false;
    difficulty = 1;
    isInvincible = false;
    survivedTime = 0;
    missilesDodged = 0;
    currentBoss = null;
    upgradePOWER = 0;
    upgradeAGILITY = 0;
    upgradeLUCK = 0;

    Timer.periodic(Duration(milliseconds: (1000 / gameSpeed).round()), (timer) {
      if (gameOver) {
        timer.cancel();
        return;
      }
      updateGame();
    });

    Timer.periodic(Duration(seconds: 1), (timer) {
      if (gameOver) {
        timer.cancel();
        return;
      }
      survivedTime++;
    });
  }

  void updateGame() {
    if (mounted) {
      setState(() {
        for (var missile in missiles) {
          missile.move();
        }

        for (var powerUp in powerUps) {
          powerUp.move();
        }

        for (var playerMissile in playerMissiles) {
          playerMissile.move();
        }

        missiles.removeWhere((missile) {
          if (missile.isOffScreen()) {
            missilesDodged++;
            return true;
          }
          return false;
        });
        powerUps.removeWhere((powerUp) => powerUp.isOffScreen());
        playerMissiles.removeWhere((playerMissile) => playerMissile.isOffScreen());

        if (Random().nextInt(max(20 - difficulty.round(), 5)) == 0) {
          missiles.add(Missile.random(screenSize, difficulty));
        }

        if (Random().nextInt(500 - upgradeLUCK * 50) == 0) {
          powerUps.add(PowerUp.random(screenSize));
        }

        if (!isInvincible) {
          for (var missile in missiles) {
            if (missile.checkCollision(playerX, playerY, playerSize)) {
              gameOver = true;
              break;
            }
          }
        }

        powerUps.removeWhere((powerUp) {
          if (powerUp.checkCollision(playerX, playerY, playerSize)) {
            applyPowerUp(powerUp.type);
            return true;
          }
          return false;
        });

        if (currentBoss != null) {
          currentBoss!.update();
          if (currentBoss!.checkCollision(playerX, playerY, playerSize)) {
            if (!isInvincible) {
              gameOver = true;
            }
          }
          // Damage boss with player missiles
          playerMissiles.removeWhere((playerMissile) {
            if (playerMissile.checkCollision(currentBoss!.x, currentBoss!.y, currentBoss!.size)) {
              currentBoss!.health -= 1 + upgradePOWER;
              if (currentBoss!.health <= 0) {
                score += 1000;
                currentBoss = null;
              }
              return true;
            }
            return false;
          });
        }

        score++;
        if (score % 500 == 0) {
          spawnBoss();
        }

        difficulty = 1 + (survivedTime / 60) + (missilesDodged / 100);
      });
    }
  }

  void spawnBoss() {
    setState(() {
      currentBoss = Boss(screenSize, difficulty);
    });
  }

  void applyPowerUp(PowerUpType type) {
    switch (type) {
      case PowerUpType.invincibility:
        isInvincible = true;
        _playerAnimationController.repeat(reverse: true);
        Future.delayed(Duration(seconds: 5), () {
          isInvincible = false;
          _playerAnimationController.stop();
          _playerAnimationController.reset();
        });
        break;
      case PowerUpType.clearScreen:
        missiles.clear();
        score += 100;
        break;
      case PowerUpType.speedBoost:
        upgradeAGILITY += 2;
        Future.delayed(Duration(seconds: 10), () {
          upgradeAGILITY = max(0, upgradeAGILITY - 2);
        });
        break;
      case PowerUpType.scoreMultiplier:
        score *= 2;
        break;
    }
  }

  void movePlayer(double dx, double dy) {
    setState(() {
      playerX += dx * (1 + upgradeAGILITY * 0.1);
      playerY += dy * (1 + upgradeAGILITY * 0.1);

      playerX = playerX.clamp(0, screenSize.width - playerSize);
      playerY = playerY.clamp(0, screenSize.height - playerSize);
    });
  }

  void shootMissile() {
    setState(() {
      playerMissiles.add(PlayerMissile(playerX + playerSize / 2, playerY));
    });
  }

  void upgrade(String stat) {
    if (score < 100) return;  // 업그레이드 비용 체크

    setState(() {
      score -= 100;  // 업그레이드 비용
      switch (stat) {
        case 'POWER':
          upgradePOWER++;
          break;
        case 'AGILITY':
          upgradeAGILITY++;
          break;
        case 'LUCK':
          upgradeLUCK++;
          break;
      }
    });
  }

  void _generateStars() {
    final random = Random();
    for (int i = 0; i < 100; i++) {
      stars.add(Star(
        random.nextDouble() * screenSize.width,
        random.nextDouble() * screenSize.height,
        random.nextDouble() * 2 + 1,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKey: (RawKeyEvent event) {
        if (event is RawKeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            movePlayer(-5, 0);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            movePlayer(5, 0);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            movePlayer(0, -5);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            movePlayer(0, 5);
          } else if (event.logicalKey == LogicalKeyboardKey.space) {
            shootMissile();
          }
        }
      },
      child: Scaffold(
        body: GestureDetector(
          onPanUpdate: (details) {
            if (!gameOver) {
              movePlayer(details.delta.dx, details.delta.dy);
            }
          },
          child: Container(
            color: Colors.black,
            child: Stack(
              children: [
                ...stars.map((star) => star.build()).toList(),
                Positioned(
                  left: playerX,
                  top: playerY,
                  child: AnimatedBuilder(
                    animation: _playerAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _playerAnimation.value,
                        child: Container(
                          width: playerSize,
                          height: playerSize,
                          decoration: BoxDecoration(
                            color: isInvincible ? Colors.yellow : Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                ...missiles.map((missile) => missile.build()).toList(),
                ...powerUps.map((powerUp) => powerUp.build()).toList(),
                ...playerMissiles.map((playerMissile) => playerMissile.build()).toList(),
                if (currentBoss != null) currentBoss!.build(),
                Positioned(
                  top: 50,
                  right: 20,
                  child: Text(
                    'Score: $score\nDifficulty: ${difficulty.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                Positioned(
                  top: 50,
                  left: 20,
                  child: Column(
                    children: [
                      UpgradeButton(
                        label: 'POWER',
                        level: upgradePOWER,
                        onPressed: () => upgrade('POWER'),
                        cost: 100,
                        canAfford: score >= 100,
                      ),
                      UpgradeButton(
                        label: 'AGILITY',
                        level: upgradeAGILITY,
                        onPressed: () => upgrade('AGILITY'),
                        cost: 100,
                        canAfford: score >= 100,
                      ),
                      UpgradeButton(
                        label: 'LUCK',
                        level: upgradeLUCK,
                        onPressed: () => upgrade('LUCK'),
                        cost: 100,
                        canAfford: score >= 100,
                      ),
                    ],
                  ),
                ),
                if (gameOver)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Game Over',
                          style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        SizedBox(height: 20),
                        ElevatedButton(
                          child: Text('Restart'),
                          onPressed: () {
                            setState(() {
                              startGame();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum MissileType { straight, sine, spiral }

class Missile {
  double x;
  double y;
  double dx;
  double dy;
  final double size;
  final Color color;
  final MissileType type;

  Missile(this.x, this.y, this.dx, this.dy, this.size, this.color, this.type);

  factory Missile.random(Size screenSize, double difficulty) {
    final random = Random();
    double x, y, dx, dy;
    double size = random.nextDouble() * 10 + 10;  // Size between 10 and 20
    Color color;
    MissileType type = MissileType.values[random.nextInt(MissileType.values.length)];

    if (random.nextBool()) {
      x = random.nextDouble() * screenSize.width;
      y = random.nextBool() ? -size : screenSize.height + size;
      dx = (random.nextDouble() - 0.5) * 5 * difficulty / 5;
      dy = y > 0 ? -5 * difficulty / 5 : 5 * difficulty / 5;
    } else {
      x = random.nextBool() ? -size : screenSize.width + size;
      y = random.nextDouble() * screenSize.height;
      dx = x > 0 ? -5 * difficulty / 5 : 5 * difficulty / 5;
      dy = (random.nextDouble() - 0.5) * 5 * difficulty / 5;
    }

    double speed = sqrt(dx * dx + dy * dy);
    if (speed < 3) {
      color = Colors.green;
    } else if (speed < 6) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }

    return Missile(x, y, dx, dy, size, color, type);
  }

  void move() {
    switch (type) {
      case MissileType.straight:
        x += dx;
        y += dy;
        break;
      case MissileType.sine:
        x += dx;
        y += dy + sin(x / 50) * 2;
        break;
      case MissileType.spiral:
        double angle = atan2(dy, dx);
        angle += 0.1;
        double speed = sqrt(dx * dx + dy * dy);
        dx = cos(angle) * speed;
        dy = sin(angle) * speed;
        x += dx;
        y += dy;
        break;
    }
  }

  bool isOffScreen() {
    return x < -size || x > 1000 + size || y < -size || y > 1000 + size;
  }

  bool checkCollision(double playerX, double playerY, double playerSize) {
    return (x - playerX).abs() < (size + playerSize) / 3 &&
           (y - playerY).abs() < (size + playerSize) / 3;
  }

  Widget build() {
    return Positioned(
      left: x,
      top: y,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class PlayerMissile {
  double x;
  double y;
  final double size = 10;
  final double speed = -10;

  PlayerMissile(this.x, this.y);

  void move() {
    y += speed;
  }

  bool isOffScreen() {
    return y < -size;
  }

  bool checkCollision(double bossX, double bossY, double bossSize) {
    return (x - bossX).abs() < (size + bossSize) / 2 &&
           (y - bossY).abs() < (size + bossSize) / 2;
  }

  Widget build() {
    return Positioned(
      left: x,
      top: y,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

enum PowerUpType { invincibility, clearScreen, speedBoost, scoreMultiplier }

class PowerUp {
  double x;
  double y;
  final PowerUpType type;
  static const size = 30.0;

  PowerUp(this.x, this.y, this.type);

  factory PowerUp.random(Size screenSize) {
    final random = Random();
    return PowerUp(
      random.nextDouble() * screenSize.width,
      random.nextDouble() * screenSize.height,
      PowerUpType.values[random.nextInt(PowerUpType.values.length)]
    );
  }

  void move() {
    // Power-ups don't move in this version, but you could add movement here
  }

  bool isOffScreen() {
    return false;  // Power-ups don't go off screen in this version
  }

  bool checkCollision(double playerX, double playerY, double playerSize) {
    return (x - playerX).abs() < (size + playerSize) / 2 &&
           (y - playerY).abs() < (size + playerSize) / 2;
  }

  Widget build() {
    return Positioned(
      left: x,
      top: y,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _getColorForType(type),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Color _getColorForType(PowerUpType type) {
    switch (type) {
      case PowerUpType.invincibility:
        return Colors.yellow;
      case PowerUpType.clearScreen:
        return Colors.purple;
      case PowerUpType.speedBoost:
        return Colors.green;
      case PowerUpType.scoreMultiplier:
        return Colors.orange;
    }
  }
}

class Boss {
  double x;
  double y;
  double dx;
  double dy;
  final double size;
  final double difficulty;
  int health;

  Boss(Size screenSize, this.difficulty)
      : x = screenSize.width / 2,
        y = -100,
        size = 100,
        dx = 2,
        dy = 1,
        health = (10 * difficulty).round();

  void update() {
    x += dx;
    y += dy;

    if (x < 0 || x > 1000 - size) {
      dx = -dx;
    }

    if (y > 200) {
      dy = 0;
    }
  }

  bool checkCollision(double playerX, double playerY, double playerSize) {
    return (x - playerX).abs() < (size + playerSize) / 2 &&
           (y - playerY).abs() < (size + playerSize) / 2;
  }

  Widget build() {
    return Positioned(
      left: x,
      top: y,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.red,
          shape: BoxShape.rectangle,
        ),
        child: Center(
          child: Text(
            'BOSS\nHP: $health',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class Star {
  double x;
  double y;
  double size;

  Star(this.x, this.y, this.size);

  Widget build() {
    return Positioned(
      left: x,
      top: y,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class UpgradeButton extends StatelessWidget {
  final String label;
  final int level;
  final VoidCallback onPressed;
  final int cost;
  final bool canAfford;

  const UpgradeButton({
    required this.label,
    required this.level,
    required this.onPressed,
    required this.cost,
    required this.canAfford,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: ElevatedButton(
        child: Text('$label (Lv.$level) - Cost: $cost'),
        onPressed: canAfford ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: canAfford ? Colors.blue : Colors.grey,
        ),
      ),
    );
  }
}
