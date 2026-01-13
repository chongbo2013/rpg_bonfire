import 'dart:ui';

import 'package:bonfire/bonfire.dart';

class DamageHitbox extends GameComponent {
  final double damage;
  final Duration duration;
  final Duration damageInterval;
  final AttackOriginEnum origin;
  final int attachCount;
  final dynamic id;
  final void Function(Attackable attackable)? onDamage;

  final Paint _paint = Paint()..color = Sensor.color;

  DamageHitbox({
    required Vector2 position,
    required this.damage,
    required this.origin,
    required Vector2 size,
    this.id,
    double angle = 0,
    this.onDamage,
    Anchor anchor = Anchor.center,
    this.damageInterval = const Duration(seconds: 1),
    this.duration = const Duration(milliseconds: 200),
    this.attachCount = 1,
  }) {
    this.angle = angle;
    this.anchor = anchor;
    this.size = size;
    this.position = position;
  }

  @override
  void update(double dt) {
    if (checkInterval(
          'onRemove',
          duration.inMilliseconds,
          dt,
          firstCheckIsTrue: false,
        ) &&
        !isRemoving) {
      removeFromParent();
    }

    if (checkInterval(
          'doDamage',
          damageInterval.inMilliseconds,
          dt,
        ) &&
        !isRemoving) {
      int attackIndex = 0;
      gameRef
          .attackables(onlyVisible: true)
          .where((a) => a.rectAttackable().overlaps(toAbsoluteRect()))
          .forEach((attackable) {
            if(attackIndex<attachCount) {
              final receiveDamage = attackable.handleAttack(origin, damage, id);
              if (receiveDamage) {
                onDamage?.call(attackable);
              }
              attackIndex+=1;
            }
      });
    }

    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    if (gameRef.showCollisionArea) {
      canvas.drawRect(
        size.toRect(),
        _paint,
      );
    }
    super.render(canvas);
  }
}
