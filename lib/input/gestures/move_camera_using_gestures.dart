import 'package:bonfire/bonfire.dart';
import 'package:flutter/gestures.dart';

/// Mixin used to move camera with gestures (touch or mouse)
mixin MoveCameraUsingGesture on GameComponent {
  int? _activePointerId;
  Vector2 _startPoint = Vector2.zero();
  Vector2 _startCameraPosition = Vector2.zero();

  bool _onlyMouse = false;
  MouseButton _mouseButton = MouseButton.left;

  void setupMoveCameraUsingGesture({
    bool onlyMouse = false,
    MouseButton mouseButton = MouseButton.left,
  }) {
    _mouseButton = mouseButton;
    _onlyMouse = onlyMouse;
  }

  @override
  bool handlerPointerDown(PointerDownEvent event) {
    if (_activePointerId == null) {
      // 验证当前手势是否符合要求（鼠标按钮/设备类型）
      if (_acceptGesture(event, _mouseButton)) {
        _activePointerId = event.pointer;
        _startPoint = event.position.toVector2();
        // 克隆相机位置，避免引用导致的坐标错乱
        _startCameraPosition = gameRef.camera.position.clone();
      }
    }
    return super.handlerPointerDown(event);
  }

  @override
  bool handlerPointerMove(PointerMoveEvent event) {
    // 只处理当前活跃的指针移动事件
    if (event.pointer != _activePointerId || _activePointerId == null) {
      return super.handlerPointerMove(event);
    }
    final distance = _startPoint.distanceTo(event.position.toVector2());
    if (distance > 1) {
      if (_acceptGesture(event, _mouseButton)) {
        final zoom = gameRef.camera.zoom;
        final px = _startPoint.x - event.position.dx;
        final py = _startPoint.y - event.position.dy;
        gameRef.camera.stop();
        gameRef.camera.moveTo(
          _startCameraPosition.translated(
            px / zoom,
            py / zoom,
          ),
        );
      }
    }

    return super.handlerPointerMove(event);
  }

  @override
  bool handlerPointerUp(PointerUpEvent event) {
    // 释放当前活跃指针
    if (event.pointer == _activePointerId) {
      _activePointerId = null;
    }
    return super.handlerPointerUp(event);
  }
  @override
  bool handlerPointerCancel(PointerCancelEvent event) {
    // 指针取消（如超出屏幕）时，同样释放活跃指针
    if (event.pointer == _activePointerId) {
      _activePointerId = null;
    }
    return super.handlerPointerCancel(event);
  }

  bool _acceptGesture(PointerEvent event, MouseButton button) {
    final isMouse = event.kind == PointerDeviceKind.mouse;

    if (_onlyMouse) {
      return event.buttons == button.id && isMouse;
    } else {
      if (isMouse) {
        return event.buttons == button.id;
      }
      return true;
    }
  }

  @override
  bool hasGesture() => true;

  @override
  bool get isVisible => true;
}
