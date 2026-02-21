import 'dart:math';

import 'package:bonfire/bonfire.dart';
import 'package:flutter/widgets.dart';

/// Animated component used like range attack.
class FlyingAttackGameObject extends AnimatedGameObject
    with Movement, CanNotSeen, BlockMovementCollision {
  final dynamic id;
  Future<SpriteAnimation>? animationDestroy;
  final Direction? direction;
  final double damage;
  final AttackOriginEnum attackFrom;
  final bool withDecorationCollision;
  final VoidCallback? onDestroy;
  final bool enabledDiagonal;
  final Vector2? destroySize;
  double _cosAngle = 0;
  double _senAngle = 0;
  bool onlyVisible = true;
  ShapeHitbox? collision;

  // 新增：可碰撞的物体数量（默认1）
  final int attachCount;
  // 新增：剩余可碰撞次数（核心计数变量）
  int _remainingAttachCount;

  FlyingAttackGameObject({
    required super.position,
    required super.size,
    required super.animation,
    super.angle = 0,
    this.direction,
    this.id,
    this.animationDestroy,
    this.destroySize,
    double speed = 150,
    this.damage = 1,
    this.onlyVisible =true,
    this.attackFrom = AttackOriginEnum.ENEMY,
    this.withDecorationCollision = true,
    this.onDestroy,
    this.enabledDiagonal = true,
    super.lightingConfig,
    this.collision,
    // 新增参数：默认值1，指定可碰撞的物体数量
    this.attachCount = 1,
  }) : _remainingAttachCount = attachCount { // 初始化剩余可碰撞次数
    this.speed = speed;

    _cosAngle = cos(angle);
    _senAngle = sin(angle);

    if (direction != null) {
      moveFromDirection(direction!, enabledDiagonal: enabledDiagonal);
    } else {
      moveFromAngle(angle);
    }
  }

  FlyingAttackGameObject.byDirection({
    required super.position,
    required super.size,
    required super.animation,
    required this.direction,
    this.id,
    this.animationDestroy,
    this.destroySize,
    double speed = 150,
    this.onlyVisible =true,
    this.damage = 1,
    this.attackFrom = AttackOriginEnum.ENEMY,
    this.withDecorationCollision = true,
    this.onDestroy,
    this.enabledDiagonal = true,
    super.lightingConfig,
    this.collision,
    // 新增参数：默认值1
    this.attachCount = 1,
  }) : _remainingAttachCount = attachCount { // 初始化剩余可碰撞次数
    this.speed = speed;
    moveFromDirection(direction!, enabledDiagonal: enabledDiagonal);
  }

  FlyingAttackGameObject.byAngle({
    required super.position,
    required super.size,
    required super.animation,
    required super.angle,
    this.id,
    this.animationDestroy,
    this.destroySize,
    double speed = 150,
    this.damage = 1,
    this.onlyVisible =true,
    this.attackFrom = AttackOriginEnum.ENEMY,
    this.withDecorationCollision = true,
    this.onDestroy,
    this.enabledDiagonal = true,
    this.enableVerifyByTime = false,
    super.lightingConfig,
    this.collision,
    // 新增参数：默认值1
    this.attachCount = 1,
  }) : direction = null, _remainingAttachCount = attachCount { // 初始化剩余可碰撞次数
    this.speed = speed;

    _cosAngle = cos(angle);
    _senAngle = sin(angle);

    moveFromAngle(angle);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _verifyExistInWorld(dt);
    // print('_verifyExistInWorld');
  }

  @override
  bool onComponentTypeCheck(PositionComponent other) {
    if (other is Sensor) {
      return false;
    }

    if(other is FlyingAttackGameObject /*&& other.attackFrom == attackFrom*/){
      return false;
    }

    if (!withDecorationCollision && other is GameDecoration) {
      return false;
    }

    return super.onComponentTypeCheck(other);
  }

  // 核心修改：添加碰撞次数限制逻辑
  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {



    // 2. Sensor 不消耗碰撞次数，直接返回（保持原逻辑）
    if (other is Sensor) {
      return;
    }

    if(other is FlyingAttackGameObject /*&& other.attackFrom == attackFrom*/){
      return ;
    }

    // 1. 剩余可碰撞次数 <= 0 时，直接返回，不处理任何碰撞逻辑
    if (_remainingAttachCount <= 0) {
      return;
    }

    // 3. 处理 Attackable 伤害逻辑（保持原逻辑）
    if (other is Attackable) {
      if (!other.checkCanReceiveDamage(attackFrom)) {
        return;
      }

      if (animationDestroy == null) {
        print('flying onCollision=${animationDestroy}');
        other.handleAttack(attackFrom, damage, id);
      }
    }

    // 4. 消耗一次可碰撞次数（仅有效碰撞才消耗）
    _remainingAttachCount--;

    // 5. 执行销毁逻辑（原逻辑保留）
    _destroyObject();

    super.onCollision(intersectionPoints, other);
  }

  void _destroyObject() {
    if (isRemoving || isRemoved) {
      return;
    }
    removeAll(children);
    removeFromParent();
    if (animationDestroy != null) {
      final currentDirection = direction;
      if (currentDirection != null) {
        _destroyByDirection(currentDirection);
      } else {
        _destroyByAngle();
      }
    }
    onDestroy?.call();
  }

  bool enableVerifyByTime = false;//判断超过5s则移除
  double totalVerifyTime = 0;
  int verifyTimeValue = 5;
  void _verifyExistInWorld(double dt) {
    totalVerifyTime+=dt;
    // print('totalVerifyTime={$totalVerifyTime}');
    if (checkInterval('checkCanSee', 1000, dt) && !isRemoving) {
      if(enableVerifyByTime){

        if(totalVerifyTime>=verifyTimeValue){
          removeFromParent();
        }
      }else {
        final canSee = gameRef.camera.canSee(this);
        if (!canSee) {
          removeFromParent();
        }
      }
    }
  }

  void _destroyByDirection(Direction direction) {
    Vector2 positionDestroy;

    final double biggerSide = max(width, height);
    var addCenterX = 0.0;
    var addCenterY = 0.0;

    const divisionFactor = 2.0;

    if (destroySize != null) {
      addCenterX = (size.x - destroySize!.x) / divisionFactor;
      addCenterY = (size.y - destroySize!.y) / divisionFactor;
    }
    switch (direction) {
      case Direction.left:
        positionDestroy = Vector2(
          left - (biggerSide / divisionFactor) + addCenterX,
          top + addCenterY,
        );
        break;
      case Direction.right:
        positionDestroy = Vector2(
          left + (biggerSide / divisionFactor) + addCenterX,
          top + addCenterY,
        );
        break;
      case Direction.up:
        positionDestroy = Vector2(
          left + addCenterX,
          top - (biggerSide / divisionFactor) + addCenterY,
        );
        break;
      case Direction.down:
        positionDestroy = Vector2(
          left + addCenterX,
          top + (biggerSide / divisionFactor) + addCenterY,
        );
        break;
      case Direction.upLeft:
        positionDestroy = Vector2(
          left - (biggerSide / divisionFactor) + addCenterX,
          top - (biggerSide / divisionFactor) + addCenterY,
        );
        break;
      case Direction.upRight:
        positionDestroy = Vector2(
          left + (biggerSide / divisionFactor) + addCenterX,
          top - (biggerSide / divisionFactor) + addCenterY,
        );
        break;
      case Direction.downLeft:
        positionDestroy = Vector2(
          left - (biggerSide / divisionFactor) + addCenterX,
          top + (biggerSide / divisionFactor) + addCenterY,
        );
        break;
      case Direction.downRight:
        positionDestroy = Vector2(
          left + (biggerSide / divisionFactor) + addCenterX,
          top + (biggerSide / divisionFactor) + addCenterY,
        );
        break;
    }

    if (hasGameRef) {
      final innerSize = destroySize ?? size;
      gameRef.add(
        AnimatedGameObject(
          animation: animationDestroy,
          position: positionDestroy,
          size: innerSize,
          lightingConfig: lightingConfig,
          loop: false,
          renderAboveComponents: true,
        ),
      );
      _applyDestroyDamage(
        Rect.fromLTWH(
          positionDestroy.x,
          positionDestroy.y,
          innerSize.x,
          innerSize.y,
        ),
      );
    }
  }

  void _destroyByAngle() {
    final nextX = (width / 2) * _cosAngle;
    final nextY = (height / 2) * _senAngle;

    final innerSize = destroySize ?? size;
    final rect = rectCollision;
    final diffBase = Offset(
      rect.center.dx + nextX,
      rect.center.dy + nextY,
    ) -
        rect.center;

    final positionDestroy = center.translated(diffBase.dx, diffBase.dy);

    if (hasGameRef) {
      gameRef.add(
        AnimatedGameObject(
          animation: animationDestroy,
          position: Rect.fromCenter(
            center: positionDestroy.toOffset(),
            width: innerSize.x,
            height: innerSize.y,
          ).positionVector2,
          lightingConfig: lightingConfig,
          size: innerSize,
          loop: false,
          renderAboveComponents: true,
        ),
      );
      _applyDestroyDamage(
        Rect.fromLTWH(
          positionDestroy.x,
          positionDestroy.y,
          innerSize.x,
          innerSize.y,
        ),
      );
    }
  }

  void _applyDestroyDamage(Rect rectPosition) {
    gameRef.add(
      DamageHitbox(
        id: id,
        attachCount: attachCount,
        onlyVisible: onlyVisible,
        position: rectPosition.positionVector2,
        damage: damage,
        origin: attackFrom,
        size: rectPosition.size.toVector2(),
      ),
    );
  }

  @override
  bool onBlockMovement(Set<Vector2> intersectionPoints, GameComponent other) {
    return false;
  }

  @override
  void onMount() {
    anchor = Anchor.center;
    super.onMount();
  }

  @override
  Future<void> onLoad() {
    add(collision ?? RectangleHitbox(size: size, isSolid: true));
    return super.onLoad();
  }
}