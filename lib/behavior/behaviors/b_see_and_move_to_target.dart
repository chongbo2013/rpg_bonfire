import 'package:bonfire/bonfire.dart';

class BSeeAndMoveToTarget extends Behavior {
  final GameComponent target;
  final double radiusVision;
  final double? visionAngle;
  final void Function(double dt, GameComponent target) onClose;
  final Behavior? doElseBehavior;
  final double distance;
  final MovementAxis movementAxis;
  bool? igoneTarget;//忽略target
  bool? onlySeeScreen;//仅看屏屏幕可见
  BSeeAndMoveToTarget({
    required this.target,
    required this.onClose,
    this.radiusVision = 32,
    this.movementAxis = MovementAxis.all,
    this.visionAngle,
    this.doElseBehavior,
    this.distance = 5,
    this.igoneTarget =true,
    this.onlySeeScreen =true,
    super.id,
  });
  @override
  bool runAction(double dt, GameComponent comp, BonfireGameInterface game) {
    return BCanSee(
      target: target,
      radiusVision: radiusVision,
      visionAngle: visionAngle,
      igoneTarget: igoneTarget,
      onlySeeScreen: onlySeeScreen,
      doElseBehavior: BCustom(
        behavior: (dt, comp, game) {
          if (comp is Movement && doElseBehavior == null) {
            comp.stopMove();
          }
          return doElseBehavior?.runAction(dt, comp, game) ?? true;
        },
      ),
      doBehavior: (target) {
        return BCondition(
          condition: (_, comp, game) => comp.isCloseTo(
            target,
            distance: distance,
          ),
          doBehavior: BAction(
            action: (dt, comp, game) {
              if (comp is Movement) {
                comp.stopMove();
              }
              if(comp is Movement) {
                final playerDirection = comp.getDirectionToTarget(
                  target,
                );
                comp.lastDirection = playerDirection;
                if (comp.lastDirection.isHorizontal) {
                  comp.lastDirectionHorizontal = comp.lastDirection;
                }
              }
              // print('comp'+target.toString());
              onClose(dt, target);
              //发送子弹
            },
          ),
          doElseBehavior: BMoveToComponent(
            movementAxis: movementAxis,
            target: target,
            margin: distance,
          ),
        );
      },
    ).runAction(dt, comp, game);
  }
}
