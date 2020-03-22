import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide TextStyle;
import 'package:flutter/rendering.dart' hide TextStyle;
import 'package:flutter/widgets.dart' hide TextStyle;

class FlameChart extends LeafRenderObjectWidget {
  const FlameChart(
    this.root, {
    Key key,
    this.lightColor = const Color(0xFFFFEBEE),
    this.darkColor = const Color(0xFFB71C1C),
    this.highlightColor = const Color(0x88FFFF8D),
    this.barHeight = 48,
  })  : assert(root != null),
        assert(lightColor != null),
        assert(darkColor != null),
        assert(highlightColor != null),
        assert(barHeight != null),
        assert(barHeight > 0),
        assert(barHeight != double.nan),
        assert(barHeight != double.infinity),
        super(key: key);

  static const Radius _radius = Radius.circular(2.0);

  final FlameChartNode root;
  final Color lightColor;
  final Color darkColor;
  final Color highlightColor;
  final double barHeight;

  @override
  LeafRenderObjectElement createElement() => _FlameChartElement(this);

  @override
  _FlameChartRenderObject createRenderObject(BuildContext context) {
    return _FlameChartRenderObject(
      root: root,
      lightColor: lightColor,
      darkColor: darkColor,
      highlightColor: highlightColor,
      barHeight: barHeight,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _FlameChartRenderObject renderObject,
  ) {
    renderObject
      ..root = root
      ..lightColor = lightColor
      ..darkColor = darkColor
      ..highlightColor = highlightColor
      ..barHeight = barHeight;
  }
}

class _FlameChartElement extends LeafRenderObjectElement {
  _FlameChartElement(LeafRenderObjectWidget widget) : super(widget);

  @override
  _FlameChartRenderObject get renderObject =>
      super.renderObject as _FlameChartRenderObject;

  void unmount() {
    renderObject.disposeRecognizers();
    super.unmount();
  }
}

class _FlameChartSelectedNode extends RenderBox {
  RRect get highlightRRect => _highlightRRect;
  RRect _highlightRRect;
  set highlightRRect(RRect value) {
    assert(value != null && value.isFinite);
    if (_highlightRRect == value) {
      return;
    }
    _highlightRRect = value;
    markNeedsPaint();
  }

  Color get highlightColor => _highlightColor;
  Color _highlightColor;
  set highlightColor(Color value) {
    assert(value != null);
    if (_highlightColor == value) {
      return;
    }
    _highlightColor = value;
    markNeedsPaint();
  }

  Color get backgroundColor => _backgroundColor;
  Color _backgroundColor;
  set backgroundColor(Color value) {
    assert(value != null);
    if (value == _backgroundColor) {
      return;
    }
    _backgroundColor = value;
    markNeedsPaint();
  }

  String get message => _message;
  String _message;
  set message(String value) {
    assert(value != null);
    if (value == _message) {
      return;
    }
    _message = value;
    markNeedsPaint();
  }

  double get height => _height;
  double _height;
  set height(double value) {
    assert(value != null && value.isFinite && !value.isNegative);
    if (value == _height) {
      return;
    }
    _height = value;
    markNeedsPaint();
  }

  @override
  bool get sizedByParent => true;

  @override
  void performResize() {
    size = constraints.smallest;
    assert(size.isFinite);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(0, size.height - height, size.width, size.height),
        FlameChart._radius,
      ),
      Paint()..color = backgroundColor,
    );

    if (highlightRRect == RRect.zero) {
      return;
    }

    context.canvas.drawRRect(highlightRRect, Paint()..color = highlightColor);

    ParagraphBuilder builder = ParagraphBuilder(
      ParagraphStyle(
        textAlign: TextAlign.center,
        maxLines: 2,
        ellipsis: '…',
      ),
    )
      ..pushStyle(
        TextStyle(
            color: HSLColor.fromColor(backgroundColor).lightness > .7
                ? const Color(0xFF000000)
                : const Color(0xFFFFFFFF),
            fontFamily: 'Courier New'),
      )
      ..addText(message);
    final Paragraph paragraph = builder.build()
      ..layout(ParagraphConstraints(width: size.width - 5));
    context.canvas.drawParagraph(
      paragraph,
      Offset(0, size.height - (height + paragraph.height) / 2),
    );
  }

  void setNode(FlameChartNode node) {
    _highlightRRect = RRect.fromRectAndRadius(
      node._rect,
      FlameChart._radius,
    );
    _message = '${node.path} (${node.value})';
    markNeedsPaint();
  }
}

class _FlameChartRenderObject extends RenderBox
    with RenderObjectWithChildMixin<_FlameChartSelectedNode> {
  _FlameChartRenderObject({
    @required FlameChartNode root,
    @required Color lightColor,
    @required Color darkColor,
    @required Color highlightColor,
    @required double barHeight,
  }) {
    _tapGestureRecognizer = TapGestureRecognizer(
      debugOwner: this,
    )..onTap = _tapNode;

    _doubleTapGestureRecognizer = DoubleTapGestureRecognizer(
      debugOwner: this,
    )..onDoubleTap = _selectNode;

    _longPressGestureRecognizer = LongPressGestureRecognizer(
      debugOwner: this,
    )..onLongPress = _selectNode;

    _hoverAnnotation = MouseTrackerAnnotation(onHover: _handleHover);
    FocusManager.instance.addHighlightModeListener(_highlightModeChanged);

    child = _FlameChartSelectedNode()
      ..backgroundColor = Colors.blueGrey
      ..highlightRRect = RRect.zero
      ..highlightColor = highlightColor
      ..height = barHeight;

    this.lightColor = lightColor;
    this.darkColor = darkColor;
    this.barHeight = barHeight;
    this.root = root;
  }

  MouseTrackerAnnotation _hoverAnnotation;

  void _highlightModeChanged(FocusHighlightMode value) {
    // If the highlight mode is traditional, we push a layer when painting.
    // This isn't needed if the highlight mode is touch, since we're not
    // tracking hover events for touch.
    markNeedsPaint();
  }

  void _tapNode() {
    assert(_lastTappedNode != null);
    if (child.highlightRRect?.outerRect == _lastTappedNode._rect) {
      child
        ..message = ''
        ..highlightRRect = RRect.zero;
      return;
    }
    child.setNode(_lastTappedNode);
  }

  void _selectNode() {
    assert(_lastTappedNode != null);
    selectedNode = _lastTappedNode;
  }

  void disposeRecognizers() {
    _tapGestureRecognizer?.dispose();
    _doubleTapGestureRecognizer.dispose();
    _longPressGestureRecognizer?.dispose();
    FocusManager.instance.removeHighlightModeListener(_highlightModeChanged);
  }

  TapGestureRecognizer _tapGestureRecognizer;
  DoubleTapGestureRecognizer _doubleTapGestureRecognizer;
  LongPressGestureRecognizer _longPressGestureRecognizer;

  FlameChartNode get root => _root;
  FlameChartNode _root;
  set root(FlameChartNode value) {
    assert(value != null);
    if (value == _root) {
      return;
    }
    _root = value;
    _selectedNode = value;
    _lastHoverNode = value;
    markNeedsPaint();
  }

  double get barHeight => _barHeight;
  double _barHeight;
  set barHeight(double value) {
    assert(value != null);
    assert(value.isFinite);
    assert(!value.isNegative);
    if (value == _barHeight) {
      return;
    }
    _barHeight = value;
    child.height = value;
    markNeedsPaint();
  }

  Color get lightColor => _lightColor;
  Color _lightColor;
  set lightColor(Color value) {
    assert(value != null);
    if (value == _lightColor) {
      return;
    }
    _lightColor = value;
    markNeedsPaint();
  }

  Color get darkColor => _darkColor;
  Color _darkColor;
  set darkColor(Color value) {
    assert(value != null);
    if (value == _darkColor) {
      return;
    }
    _darkColor = value;
    markNeedsPaint();
  }

  Color get highlightColor => child.highlightColor;
  set highlightColor(Color value) => child.highlightColor = value;

  FlameChartNode get selectedNode => _selectedNode;
  FlameChartNode _selectedNode;
  set selectedNode(FlameChartNode value) {
    assert(value != null);
    if (value == _selectedNode) {
      return;
    }
    _lastTappedNode = null;
    _selectedNode = value;
    _lastHoverNode = value;

    _selectedNode._expandRect(size.width);
    child.highlightRRect = RRect.fromRectAndRadius(
      _selectedNode._rect,
      FlameChart._radius,
    );

    markNeedsPaint();
  }

  @override
  bool get sizedByParent => true;

  @override
  void performResize() {
    Size oldSize;
    if (hasSize) {
      oldSize = size;
    }
    size = constraints.biggest;
    assert(size.isFinite);

    if (oldSize != null) {
      if (oldSize.height != size.height) {
        child.highlightRRect = child.highlightRRect.shift(size - oldSize);
      } else if (oldSize.width != size.width) {
        final RRect currentRect = child.highlightRRect;
        final double ratio = size.width / oldSize.width;
        child.highlightRRect = RRect.fromLTRBAndCorners(
          currentRect.left * ratio,
          currentRect.top,
          currentRect.right * ratio,
          currentRect.bottom,
          topLeft: currentRect.tlRadius,
          topRight: currentRect.trRadius,
          bottomLeft: currentRect.blRadius,
          bottomRight: currentRect.brRadius,
        );
      }
    }
  }

  FlameChartNode _lastTappedNode;

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    assert(debugHandleEvent(event, entry));
    if (event is PointerDownEvent) {
      _doubleTapGestureRecognizer.addPointer(event);
      if (event.kind == PointerDeviceKind.touch) {
        _longPressGestureRecognizer.addPointer(event);
        _tapGestureRecognizer.addPointer(event);
      }
    }
    super.handleEvent(event, entry);
  }

  @override
  bool hitTestSelf(Offset position) {
    _lastTappedNode = selectedNode._findRect(position);
    return _lastTappedNode != null;
  }

  FlameChartNode _lastHoverNode;
  void _handleHover(PointerHoverEvent event) {
    final Offset localPosition = globalToLocal(event.localPosition);
    if (_lastHoverNode._rect.contains(localPosition) ||
        localPosition.dy >= root._rect.bottom) {
      return;
    }
    FlameChartNode searchNode = _lastHoverNode;
    while (localPosition.dy > searchNode._rect.bottom ||
        localPosition.dx > searchNode._rect.right ||
        localPosition.dx < searchNode._rect.left) {
      assert(searchNode.parent != null);
      searchNode = searchNode.parent;
    }
    final FlameChartNode node = searchNode._findRect(localPosition);
    if (node != null) {
      child.setNode(node);
    }
    _lastHoverNode = node ?? _lastHoverNode;
  }

  @override
  void performLayout() {
    child.layout(constraints);
    super.performLayout();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    switch (FocusManager.instance.highlightMode) {
      case FocusHighlightMode.touch:
        _paint(context, offset);
        break;
      case FocusHighlightMode.traditional:
        final AnnotatedRegionLayer<MouseTrackerAnnotation> layer =
            AnnotatedRegionLayer<MouseTrackerAnnotation>(
          _hoverAnnotation,
          size: size,
          offset: offset,
          opaque: true,
        );
        context.pushLayer(layer, _paint, offset);
        break;
    }
  }

  void _paint(PaintingContext context, Offset offset) {
    final double rootWidth = size.width;
    final double top = _paintAncestors(context, selectedNode.ancestors);

    _paintNode(context, selectedNode, 0, rootWidth, top);

    _paintChildren(
      context: context,
      currentLeft: 1,
      parentSize: selectedNode.value,
      children: selectedNode.children,
      topFactor: top + barHeight + 1,
      maxWidth: rootWidth - 1,
    );
    context.paintChild(child, offset);
  }

  void _paintNode(
    PaintingContext context,
    FlameChartNode node,
    double left,
    double width,
    double top,
  ) {
    node._rect = Rect.fromLTWH(left, size.height - top, width, barHeight);
    final double t = node.logValue / root.logValue;
    final Color backgroundColor = Color.lerp(
      lightColor,
      darkColor,
      t,
    );
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(
        node._rect,
        FlameChart._radius,
      ),
      Paint()..color = backgroundColor,
    );
    // Don't bother figuring out the text length if the box will be too small
    // anyway.
    if (width < size.width * .02) {
      return;
    }
    ParagraphBuilder builder = ParagraphBuilder(
      ParagraphStyle(
        textAlign: TextAlign.center,
        maxLines: 2,
        ellipsis: '…',
      ),
    )
      ..pushStyle(
        TextStyle(
            color: HSLColor.fromColor(backgroundColor).lightness > .7
                ? const Color(0xFF000000)
                : const Color(0xFFFFFFFF),
            fontFamily: 'Courier New'),
      )
      ..addText('${node.name}\n(${node.value})');
    final Paragraph paragraph = builder.build()
      ..layout(ParagraphConstraints(width: width - 5));
    context.canvas.drawParagraph(
      paragraph,
      Offset(
        left,
        node._rect.top + (node._rect.height - paragraph.height) / 2,
      ),
    );
  }

  double _paintAncestors(PaintingContext context, List<FlameChartNode> nodes) {
    double top = barHeight * 2 + 1;
    for (FlameChartNode node in nodes.reversed) {
      _paintNode(context, node, 0, size.width, top);
      top += barHeight + 1;
    }
    return top;
  }

  void _paintChildren({
    PaintingContext context,
    double currentLeft,
    int parentSize,
    Iterable<FlameChartNode> children,
    double topFactor,
    double maxWidth,
  }) {
    double left = currentLeft;

    for (FlameChartNode child in children) {
      final width = (child.value / parentSize * maxWidth);
      _paintNode(context, child, left, width, topFactor);

      if (!child.isLeaf) {
        final double factor = width * .001;
        _paintChildren(
          context: context,
          currentLeft: left + factor,
          parentSize: child.value,
          children: child.children,
          topFactor: topFactor + barHeight + 1,
          maxWidth: width - (2 * factor),
        );
      }
      left += width;
    }
  }
}

class FlameChartNode {
  FlameChartNode(
    this.name, {
    int value = 0,
  })  : assert(name != null),
        assert(value != null),
        _children = <String, FlameChartNode>{},
        _value = value;

  /// The human friendly identifier for this node.
  final String name;

  /// The path of this node from root, separated by '/'.code
  String get path {
    if (parent == null) {
      return '/';
    }
    if (parent.parent == null) {
      return name;
    }
    final String ancestorPath = ancestors.reversed
        .skip(1)
        .map((FlameChartNode node) => node.name)
        .join('/');
    return '$ancestorPath/$name';
  }

  int _value;
  int get value {
    _value ??= children.fold(
      0,
      (int accumulator, FlameChartNode node) => accumulator + node.value,
    );
    return _value;
  }

  double _logValue;
  int _oldLogBasis;
  double get logValue {
    if (_oldLogBasis == value) {
      return _logValue;
    }
    _oldLogBasis = value;
    _logValue = math.log(value);
    return _logValue;
  }

  Rect _rect = Rect.zero;

  FlameChartNode _parent;
  FlameChartNode get parent => _parent;

  final Map<String, FlameChartNode> _children;

  Iterable<FlameChartNode> get children => _children.values;

  FlameChartNode childByName(String name) => _children[name];

  FlameChartNode addChild(FlameChartNode child) {
    assert(child.parent == null);
    assert(!_children.containsKey(child.name),
        'Cannot add duplicate child key ${child.name}');

    child._parent = this;
    _children[child.name] = child;
    FlameChartNode ancestor = this;
    while (ancestor != null) {
      ancestor._value += child.value;
      ancestor = ancestor.parent;
    }
    return child;
  }

  FlameChartNode removeChild(FlameChartNode child) {
    final FlameChartNode node = _children.remove(child.name);
    if (node != null) {
      _value -= node.value;
      node._parent = null;
    }
    return node;
  }

  List<FlameChartNode> get ancestors {
    List<FlameChartNode> nodes = <FlameChartNode>[];
    FlameChartNode current = this;
    while (current.parent != null) {
      nodes.add(current.parent);
      current = current.parent;
    }
    return nodes;
  }

  bool get isLeaf => _children.isEmpty;

  Iterable<FlameChartNode> get siblings {
    List<FlameChartNode> result = <FlameChartNode>[];
    if (parent == null) {
      return result;
    }
    for (FlameChartNode sibling in parent.children) {
      if (sibling != this) {
        result.add(sibling);
      }
    }
    return result;
  }

  void _expandRect(double width) {
    for (FlameChartNode sibling in siblings) {
      sibling._rect = Rect.zero;
    }
    _rect = Rect.fromLTRB(
      0,
      _rect.top,
      width,
      _rect.bottom,
    );
  }

  FlameChartNode _findRect(Offset offset) {
    if (_rect.contains(offset)) {
      return this;
    }
    if (offset.dy >= _rect.bottom) {
      for (FlameChartNode ancestor in ancestors) {
        if (ancestor._rect.contains(offset)) {
          return ancestor;
        }
      }
    } else if (offset.dy < _rect.top) {
      for (FlameChartNode child in children) {
        FlameChartNode value = child._findRect(offset);
        if (value != null) {
          return value;
        }
      }
    }
    return null;
  }

  @override
  String toString() => 'Node($name, $value, $_rect)';
}
