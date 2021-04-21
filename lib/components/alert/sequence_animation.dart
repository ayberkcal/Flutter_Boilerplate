import 'package:flutter/material.dart';

class _AnimationInformation {
  _AnimationInformation({
    required this.animatable,
    required this.from,
    required this.to,
    required this.curve,
    required this.tag,
  });

  final Animatable animatable;
  final Duration from;
  final Duration to;
  final Curve curve;
  final Object tag;
}

class SequenceAnimationBuilder {
  List<_AnimationInformation> _animations = [];
  SequenceAnimationBuilder addAnimatable({
    required Animatable animatable,
    required Duration from,
    required Duration to,
    Curve curve: Curves.linear,
    required Object tag,
  }) {
    assert(to >= from);
    _animations.add(new _AnimationInformation(animatable: animatable, from: from, to: to, curve: curve, tag: tag));
    return this;
  }
  SequenceAnimation animate(AnimationController controller) {
    int longestTimeMicro = 0;
    _animations.forEach((info) {
      int micro = info.to.inMicroseconds;
      if (micro > longestTimeMicro) {
        longestTimeMicro = micro;
      }
    });
    controller.duration = new Duration(microseconds: longestTimeMicro);
    Map<Object, Animatable> animatables = {};
    Map<Object, double> begins = {};
    Map<Object, double> ends = {};

    _animations.forEach((info) {
      assert(info.to.inMicroseconds <= longestTimeMicro);

      double begin = info.from.inMicroseconds / longestTimeMicro;
      double end = info.to.inMicroseconds / longestTimeMicro;
      Interval intervalCurve = new Interval(begin, end, curve: info.curve);
      if (animatables[info.tag] == null) {
        animatables[info.tag] = IntervalAnimatable.chainCurve(info.animatable, intervalCurve);
        begins[info.tag] = begin;
        ends[info.tag] = end;
      } else {
        assert(
            ends[info.tag]! <= begin,
            "When animating the same property you need to: \n"
            "a) Have them not overlap \n"
            "b) Add them in an ordered fashion");
        animatables[info.tag] = new IntervalAnimatable(
          animatable: animatables[info.tag]!,
          defaultAnimatable: IntervalAnimatable.chainCurve(info.animatable, intervalCurve),
          begin: begins[info.tag]!,
          end: ends[info.tag]!,
        );
        ends[info.tag] = end;
      }
    });

    Map<Object, Animation> result = {};

    animatables.forEach((tag, animInfo) {
      result[tag] = animInfo.animate(controller);
    });

    return new SequenceAnimation._internal(result);
  }
}

class SequenceAnimation {
  final Map<Object, Animation> _animations;
  SequenceAnimation._internal(this._animations);
  Animation operator [](Object key) {
    assert(_animations.containsKey(key), "There was no animatable with the key: $key");
    return _animations[key]!;
  }
}
class IntervalAnimatable<T> extends Animatable<T> {
  IntervalAnimatable({
    required this.animatable,
    required this.defaultAnimatable,
    required this.begin,
    required this.end,
  });

  final Animatable animatable;
  final Animatable defaultAnimatable;
  final double begin;
  final double end;
  static Animatable chainCurve(Animatable parent, Interval interval) {
    return parent.chain(new CurveTween(curve: interval));
  }
  @override
  T transform(double t) {
    if (t >= begin && t <= end) {
      return animatable.transform(t);
    } else {
      return defaultAnimatable.transform(t);
    }
  }
}
