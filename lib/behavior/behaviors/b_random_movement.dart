import 'package:bonfire/bonfire.dart';
class BRandomMovement extends Behavior {
  final double? speed;
  final double maxDistance;
  final double minDistance;
  final int timeKeepStopped;
  final bool checkDirectionWithRayCast;
  final bool updateAngle;
  final RandomMovementDirections allowDirections;
  final Vector2? targetCenter;
  final double targetCenterDistance;
  BRandomMovement({
    this.speed,
    this.maxDistance = 50,
    this.minDistance = 25,
    this.timeKeepStopped = 2000,
    this.checkDirectionWithRayCast = false,
    this.updateAngle = false,
    this.allowDirections = RandomMovementDirections.all,
     this.targetCenter,
    this.targetCenterDistance = 60,
    super.id,
  });
  @override
  bool runAction(double dt, GameComponent comp, BonfireGameInterface game) {
    if (comp is RandomMovement) {
      comp.runRandomMovement(
        dt,
        speed: speed,
        maxDistance: maxDistance,
        minDistance: minDistance,
        checkDirectionWithRayCast: checkDirectionWithRayCast,
        timeKeepStopped: timeKeepStopped,
        updateAngle: updateAngle,
        directions: allowDirections,
        targetCenter: targetCenter,
        targetCenterDistance: targetCenterDistance
      );
    }
    return true;
  }
}
