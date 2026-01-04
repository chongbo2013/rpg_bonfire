import 'package:bonfire/bonfire.dart';

class BCanSee extends Behavior {
  final GameComponent target;
  final double radiusVision;
  final double? visionAngle;
  final double angle;
  final Behavior Function(GameComponent comp) doBehavior;
  final Behavior? doElseBehavior;
  bool? igoneTarget;//忽略target
  bool? onlySeeScreen;//仅看屏屏幕可见
  BCanSee({
    required this.target,
    required this.doBehavior,
    this.radiusVision = 32,
    this.visionAngle,
    this.angle = 3.14159,
    this.doElseBehavior,
    this.igoneTarget =true,
    this.onlySeeScreen =true
  });

  @override
  bool runAction(double dt, GameComponent comp, BonfireGameInterface game) {
    GameComponent? finalTarget = target;
    if (comp is Vision) {
      var see = false;
      if(igoneTarget!){
        //忽略target
        if(comp is Player||comp is Ally){//comp玩家/Ally，查询所有可视范围敌人；

          if(onlySeeScreen!){
            //仅看屏幕可见
            comp.seeComponentType<Enemy>(
              radiusVision: radiusVision,
              visionAngle: visionAngle,
              angle: angle,
              observed: (c) {
                see = true;
                finalTarget = c.first;
              },
            );

          }else{
            //查询所有
            comp.seeComponentType<Enemy>(
              radiusVision: radiusVision,
              visionAngle: visionAngle,
              angle: angle,
              isVisibles: false,
              observed: (c) {
                see = true;
                finalTarget = c.first;
              },
            );

          }


        }else if(comp is Enemy){//comp敌人，查询所有可视范围的玩家
          if(onlySeeScreen!){

            comp.seeComponentType<Player>(
              radiusVision: radiusVision,
              visionAngle: visionAngle,
              angle: angle,
              observed: (c) {
                see = true;
                finalTarget = c.first;
              },
            );

            if(!see){
              comp.seeComponentType<Ally>(
                radiusVision: radiusVision,
                visionAngle: visionAngle,
                angle: angle,
                observed: (c) {
                  see = true;
                  finalTarget = c.first;
                },
              );
            }


          }else{
            //查询所有
            comp.seeComponentType<Player>(
              radiusVision: radiusVision,
              visionAngle: visionAngle,
              angle: angle,
              isVisibles: false,
              observed: (c) {
                see = true;
                finalTarget = c.first;
              },
            );

            if(!see){
              comp.seeComponentType<Ally>(
                radiusVision: radiusVision,
                visionAngle: visionAngle,
                isVisibles: false,
                angle: angle,
                observed: (c) {
                  see = true;
                  finalTarget = c.first;
                },
              );
            }

          }


        }

      }else{
        comp.seeComponent(
          finalTarget,
          radiusVision: radiusVision,
          visionAngle: visionAngle,
          angle: angle,
          observed: (c) {
            see = true;
          },
        );
      }


      if (see) {
        return doBehavior(finalTarget!).runAction(dt, comp, game);
      }
      return doElseBehavior?.runAction(dt, comp, game) ?? true;
    } else {
      return true;
    }
  }
}
