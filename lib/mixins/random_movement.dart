import 'dart:math';

import 'package:bonfire/bonfire.dart';

class RandomMovementDirections {
  final List<Direction> values;

  int get length => values.length;

  const RandomMovementDirections({required this.values});

  static const RandomMovementDirections all = RandomMovementDirections(
    values: Direction.values,
  );

  static const RandomMovementDirections vertically = RandomMovementDirections(
    values: [Direction.up, Direction.down],
  );

  static const RandomMovementDirections horizontally = RandomMovementDirections(
    values: [Direction.left, Direction.right],
  );

  static const RandomMovementDirections withoutDiagonal =
  RandomMovementDirections(
    values: [
      Direction.left,
      Direction.right,
      Direction.up,
      Direction.down,
    ],
  );
}

/// Mixin responsible for adding random movement like enemy
/// walking through the scene（超出中心点范围自动返回，永不停止漫游）
mixin RandomMovement on Movement {
  // ignore: constant_identifier_names
  static const _KEY_INTERVAL_KEEP_STOPPED = 'INTERVAL_RANDOM_MOVEMENT';

  Function(Direction direction)? _onStartMove;
  Function()? _onStopMove;

  late Random _random;

  double? _distanceToArrived;
  Direction _currentDirection = Direction.left;
  Vector2 _originPosition = Vector2.zero();
  double _travelledDistance = 0;

  // 漫游区域限制
  ShapeHitbox? randomMovementArea;

  /// 核心漫游方法（在update中调用）
  /// [targetCenter] 漫游中心点
  /// [targetCenterDistance] 中心点最大漫游半径（>0生效）
  void runRandomMovement(
      double dt, {
        double? speed,
        double maxDistance = 50,
        double minDistance = 25,
        int timeKeepStopped = 2000, // 随机停留时间（毫秒）
        bool updateAngle = false,
        bool checkDirectionWithRayCast = false,
        RandomMovementDirections directions = RandomMovementDirections.all,
        Function(Direction direction)? onStartMove,
        Function()? onStopMove,
        Vector2? targetCenter,
        double targetCenterDistance = 60,
      }) {
    _onStartMove = onStartMove;
    _onStopMove = onStopMove;

    // 1. 核心判定：是否超出中心点范围
    final hasCenterRestriction = targetCenter != null && targetCenterDistance > 0;
    bool isOutOfRange = false;
    double currentDistanceToCenter = 0;
    if (hasCenterRestriction) {
      currentDistanceToCenter = absoluteCenter.distanceTo(targetCenter);
      isOutOfRange = currentDistanceToCenter > targetCenterDistance;
    }

    // 2. 超出范围时：立即中断当前移动，强制生成返回目标（跳过所有间隔）
    if (isOutOfRange && _distanceToArrived != null) {
      _resetMovementState(); // 仅重置状态，不停止移动
    }

    // 3. 生成移动目标（超出范围时跳过间隔检查）
    if (_distanceToArrived == null) {
      bool canGenerateTarget = false;
      // 超出范围：无视间隔，立即生成
      if (isOutOfRange) {
        canGenerateTarget = true;
      }
      // 范围内：按间隔生成
      else {
        canGenerateTarget = checkInterval(_KEY_INTERVAL_KEEP_STOPPED, timeKeepStopped, dt);
      }

      if (canGenerateTarget) {
        final target = _getTarget(
          minDistance: minDistance,
          maxDistance: maxDistance,
          checkDirectionWithRayCast: checkDirectionWithRayCast,
          directions: directions,
          targetCenter: targetCenter,
          targetCenterDistance: targetCenterDistance,
          currentDistanceToCenter: currentDistanceToCenter,
        );

        // 强制保证生成有效目标（永不返回null）
        if (target != null) {
          _currentDirection = target.direction;
          _distanceToArrived = target.distance;
          _originPosition = absoluteCenter.clone();
          _travelledDistance = 0;
          _onStartMove?.call(_currentDirection);
        }
      }
    }

    // 4. 执行移动（只要有目标就移动，永不停止）
    if (_distanceToArrived != null) {
      _travelledDistance = absoluteCenter.distanceTo(_originPosition);
      final isCanMove = canMove(_currentDirection, displacement: speed ?? this.speed);

      // 移动距离达标/无法移动：仅重置状态，不停止漫游
      if (_travelledDistance >= _distanceToArrived! || !isCanMove) {
        _resetMovementState();
        return;
      }

      // 执行移动（确保持续移动）
      moveFromDirection(_currentDirection, speed: speed ?? this.speed);
      if (updateAngle) {
        angle = _currentDirection.toRadians();
      }
    }
  }

  /// 仅重置移动状态，不停止漫游（关键修复：移除stopMove）
  void _resetMovementState() {
    _onStopMove?.call();
    _distanceToArrived = null;
    _originPosition = Vector2.zero();
    _travelledDistance = 0;
    // 移除stopMove()！避免角色停止移动
  }

  /// 彻底停止移动（仅在碰撞等极端情况使用）
  void _stopMovementCompletely() {
    _resetMovementState();
    stopMove();
  }

  @override
  void correctPositionFromCollision(Vector2 position) {
    super.correctPositionFromCollision(position);
    // 仅在非跳跃垂直碰撞时停止（避免误触发）
    if (this is Jumper) {
      if (this is BlockMovementCollision) {
        final isVertical = (this as BlockMovementCollision)
            .lastCollisionData
            ?.direction
            .isVertical ==
            true;
        if (isVertical) return;
      }
    }
    _resetMovementState(); // 碰撞后仅重置状态，不停止漫游
  }

  @override
  void onMount() {
    _random = Random(Random().nextInt(1000));
    super.onMount();
  }

  /// 生成移动目标（强制返回有效目标）
  _RandomPositionTarget? _getTarget({
    required double minDistance,
    required double maxDistance,
    required bool checkDirectionWithRayCast,
    required RandomMovementDirections directions,
    required Vector2? targetCenter,
    required double targetCenterDistance,
    required double currentDistanceToCenter,
  }) {
    final hasCenterRestriction = targetCenter != null && targetCenterDistance > 0;

    // 1. 超出范围：强制生成返回中心点的目标
    if (hasCenterRestriction && currentDistanceToCenter > targetCenterDistance) {
      return _generateBackToCenterTarget(
        center: targetCenter,
        centerRange: targetCenterDistance,
        currentDistance: currentDistanceToCenter,
        minDistance: minDistance,
        directions: directions,
        checkRayCast: checkDirectionWithRayCast,
      );
    }

    // 2. 范围内：生成随机漫游目标
    for (int i = 0; i < 20; i++) { // 减少尝试次数，提升性能
      final direction = _getRandomDirection(directions);
      final distance = _getRandomDistance(minDistance, maxDistance);

      // 计算该方向的最大有效距离（不超出中心点范围）
      double validMaxDistance = distance;
      if (hasCenterRestriction) {
        validMaxDistance = _getMaxValidDistance(
          currentPos: absoluteCenter,
          center: targetCenter,
          centerRange: targetCenterDistance,
          direction: direction,
          maxDistance: maxDistance,
        );
      }

      if (validMaxDistance < minDistance) continue;

      // 最终移动距离
      final finalDistance = min(distance, validMaxDistance);
      final targetPos = absoluteCenter + direction.toVector2() * finalDistance;

      // 检测是否可移动
      if (_isTargetValid(
        targetPos: targetPos,
        direction: direction,
        distance: finalDistance,
        checkRayCast: checkDirectionWithRayCast,
      )) {
        return _RandomPositionTarget(
          position: targetPos,
          direction: direction,
          distance: finalDistance,
        );
      }
    }

    // 兜底：生成朝向中心点的短距离目标（确保永不返回null）
    return _generateFallbackTarget(
      center: targetCenter,
      minDistance: minDistance,
      directions: directions,
    );
  }

  /// 生成返回中心点的强制目标（超出范围时）
  _RandomPositionTarget _generateBackToCenterTarget({
    required Vector2 center,
    required double centerRange,
    required double currentDistance,
    required double minDistance,
    required RandomMovementDirections directions,
    required bool checkRayCast,
  }) {
    // 计算朝向中心点的方向（确保在允许的方向列表中）
    final direction = _getDirectionToCenter(absoluteCenter, center, directions.values);
    // print('d='+direction.toString());
    // 计算需要移动的距离（至少回到范围内，最小1像素）
    final requiredDistance = max(1.0, currentDistance - centerRange + 5); // +5确保回到范围内
    final finalDistance = max(minDistance, requiredDistance);

    // 强制返回目标（无视检测，确保移动）
    return _RandomPositionTarget(
      position: absoluteCenter + direction.toVector2() * finalDistance,
      direction: direction,
      distance: finalDistance,
    );
  }

  /// 生成兜底目标（确保永不返回null）
  _RandomPositionTarget _generateFallbackTarget({
    required Vector2? center,
    required double minDistance,
    required RandomMovementDirections directions,
  }) {
    Direction direction = directions.values.first;
    // 有中心点：朝向中心点
    if (center != null) {
      direction = _getDirectionToCenter(absoluteCenter, center, directions.values);
    }
    // 无中心点：随机方向
    else {
      direction = _getRandomDirection(directions);
    }

    return _RandomPositionTarget(
      position: absoluteCenter + direction.toVector2() * minDistance,
      direction: direction,
      distance: minDistance,
    );
  }

  /// 检查目标是否有效
  bool _isTargetValid({
    required Vector2 targetPos,
    required Direction direction,
    required double distance,
    required bool checkRayCast,
  }) {
    // 区域检测
    if (randomMovementArea != null && !randomMovementArea!.containsPoint(targetPos)) {
      return false;
    }

    // 射线检测
    if (checkRayCast && !canMove(direction, displacement: distance)) {
      return false;
    }

    return true;
  }

  /// 计算方向上的最大有效距离（不超出中心点范围）
  double _getMaxValidDistance({
    required Vector2 currentPos,
    required Vector2 center,
    required double centerRange,
    required Direction direction,
    required double maxDistance,
  }) {
    final dirVec = direction.toVector2();
    final dx = currentPos.x - center.x;
    final dy = currentPos.y - center.y;

    // 简化计算：直接计算该方向到范围边界的距离
    final t = (centerRange * centerRange - dx * dx - dy * dy) /
        (2 * (dirVec.x * dx + dirVec.y * dy));
    if (t <= 0) return maxDistance;

    final maxValid = sqrt(dx * dx + dy * dy + 2 * t * (dirVec.x * dx + dirVec.y * dy) + t * t);
    return min(maxValid, maxDistance);
  }Direction _getDirectionToCenter(
      Vector2 currentPos,
      Vector2 targetCenter,
      List<Direction> allowedDirections,
      ) {
    final dx = targetCenter.x - currentPos.x;
    final dy = targetCenter.y - currentPos.y;

    // 1. 先确定「朝向目标的核心方向」（优先要校验的target方向）
    Direction targetPrimaryDir;
    if (dx.abs() > dy.abs()) {
      targetPrimaryDir = dx > 0 ? Direction.right : Direction.left;
    } else {
      targetPrimaryDir = dy > 0 ? Direction.down : Direction.up;
    }

    // 2. 构建候选方向列表（核心优化：把target方向放在最优先位置）
    List<Direction> candidates = [
      targetPrimaryDir, // 第一优先级：朝向目标的核心方向（优先校验）
    ];

    // 第二优先级：辅方向（次要轴，原有逻辑）
    if (dx.abs() > dy.abs()) {
      candidates.add(dy > 0 ? Direction.down : Direction.up);
    } else {
      candidates.add(dx > 0 ? Direction.right : Direction.left);
    }

    // 第三优先级：所有剩余允许的方向（兜底，去重）
    candidates.addAll(allowedDirections.where((dir) => !candidates.contains(dir)));

    // 3. 遍历候选方向，选择「允许且可移动」的第一个方向（优先target方向）
    for (final dir in candidates) {
      if (allowedDirections.contains(dir) && canMove(dir)) {
        return dir;
      }
    }

    // 终极兜底：即使所有方向都不可移动，也返回第一个允许的方向
    return allowedDirections.first;
  }

  /// 获取随机方向
  Direction _getRandomDirection(RandomMovementDirections directions) {
    return directions.values[_random.nextInt(directions.values.length)];
  }

  /// 获取随机距离
  double _getRandomDistance(double min, double max) {
    return min + _random.nextDouble() * (max - min);
  }
}

class _RandomPositionTarget {
  final Vector2 position;
  final Direction direction;
  final double distance;

  _RandomPositionTarget({
    required this.position,
    required this.direction,
    required this.distance,
  });
}