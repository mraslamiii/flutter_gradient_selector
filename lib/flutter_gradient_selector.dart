import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gradient_selector/alignment_picker.dart';
import 'helpers/localization.dart';
import 'widgets/fgs_color_picker.dart';

enum CornerMode { begin, end, none }

List<Color> colorHistory = [];

///
/// GradientSelector widget
///
///
///
final List<Gradient> defaultGradients = [
  LinearGradient(colors: [Colors.pinkAccent, Colors.pink]),
  LinearGradient(colors: [Colors.pink, Colors.redAccent]),
];
final int defaultGradientsCount = 2;

class GradientSelector extends StatefulWidget {
  const GradientSelector({
    super.key,
    required this.color,
    this.onConfirm,
    this.lang,
    this.history,
    required this.onBackClick,
    this.gradientMode = true,
    this.allowChangeMode = true,
  });

  final dynamic color;
  final Function? onConfirm;
  final GestureTapCallback onBackClick;
  final LocalisationCode? lang;
  final List<Color>? history;
  final bool gradientMode;
  final bool allowChangeMode;

  @override
  State<GradientSelector> createState() => _GradientSelectorState();
}

class _GradientSelectorState extends State<GradientSelector>
    with TickerProviderStateMixin {
  late Gradient gradient;
  late Color color;
  CornerMode _cornerMode = CornerMode.none;
  late GradientProperties properties;
  String _explanation = '';
  bool solidColorMode = true;
  late ItemScrollController scrollController;
  GlobalKey _sampleKey = GlobalKey();
  GlobalKey _linearKey = GlobalKey();
  GlobalKey _sweepKey = GlobalKey();

  int _selectedSavedIndex = -1;
  List<Gradient> savedGradients = [];

  @override
  void initState() {
    super.initState();
    setLocalizationOptions(widget.lang);
    scrollController = ItemScrollController();

    solidColorMode = !widget.gradientMode;

    if (widget.color is Gradient) {
      gradient = widget.color as Gradient;
      color = Colors.amber;
    } else {
      color = widget.color as Color;
      gradient = const LinearGradient(colors: [Colors.green, Colors.amber]);
    }

    properties = GradientProperties.fromGradient(gradient);

    _loadSavedGradients();
  }

  /// Loads the saved gradients from SharedPreferences
  Future<void> _loadSavedGradients() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? savedJsonList = prefs.getStringList("saved_gradients");
    if (savedJsonList != null) {
      setState(() {
        savedGradients = savedJsonList.map((jsonStr) {
          final Map<String, dynamic> jsonMap = jsonDecode(jsonStr);
          return GradientProperties.deserialize(jsonMap) as Gradient;
        }).toList();
      });
    }
  }

  /// Adds a new gradient to savedGradients and saves them in SharedPreferences
  Future<void> _addSavedGradient(Gradient g) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> savedJsonList =
        prefs.getStringList("saved_gradients") ?? [];

    final jsonStr = jsonEncode(GradientProperties.fromGradient(g).serialize());
    savedJsonList.add(jsonStr);

    await prefs.setStringList("saved_gradients", savedJsonList);
    await _loadSavedGradients();
  }

  /// Removes a gradient from savedGradients, ignoring default ones
  Future<void> _removeSavedGradient(int indexInBase) async {
    // indexInBase = index - 1 (since index=0 is Add button)
    // If indexInBase < defaultGradientsCount => it's a default gradient => skip
    if (indexInBase < defaultGradientsCount) {
      // do nothing
      return;
    }

    // Otherwise, remove from savedGradients
    final actualSavedIndex = indexInBase - defaultGradientsCount;
    if (actualSavedIndex >= 0 && actualSavedIndex < savedGradients.length) {
      final prefs = await SharedPreferences.getInstance();
      final List<String> savedJsonList =
          prefs.getStringList("saved_gradients") ?? [];

      // Remove that item from savedJsonList
      savedJsonList.removeAt(actualSavedIndex);

      await prefs.setStringList("saved_gradients", savedJsonList);
      await _loadSavedGradients();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final specif = GradientProperties.getType(gradient).specifications()!;

        return Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(8),
              topLeft: Radius.circular(8),
            ),
            color: Colors.grey.shade900,
          ),
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            children: [
              solidColorMode
                  ? SolidColorPicker(
                      color: color,
                      colorHistory: widget.history,
                      onChange: (value) {
                        color = value;
                        setState(() {});
                      },
                    )
                  : gradientWidget(specif, constraints),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onConfirm?.call(gradient);
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Confirm',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              buildSavedGradientsSection(),
            ],
          ),
        );
      },
    );
  }

  /// Builds the section that shows default gradients + saved gradients
  Widget buildSavedGradientsSection() {
    // Always have two default gradients at the start
    final baseGradients = [
      ...defaultGradients,
      ...savedGradients,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              "Saved Gradients",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ScrollablePositionedList.builder(
              itemScrollController: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              // +1 for the Add button at index=0
              itemCount: baseGradients.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  // The "Add" button
                  return GestureDetector(
                    onTap: () async {
                      try {
                        await _addSavedGradient(gradient);
                        // scroll to the newly added item => baseGradients.length - 1 => last item
                        // But since we have +1 for Add button, the last item index = baseGradients.length
                        scrollController.scrollTo(
                          index: baseGradients.length,
                          curve: Curves.easeIn,
                          duration: const Duration(milliseconds: 300),
                        );
                      } catch (e) {
                        rethrow;
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, color: Colors.grey.shade800),
                      child:
                          const Icon(Icons.add, color: Colors.grey, size: 24),
                    ),
                  );
                }

                // Now, for index >= 1, we show the gradient at baseGradients[index-1]
                final g = baseGradients[index - 1];
                final isSelected = (_selectedSavedIndex == index - 1);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedSavedIndex = index - 1;
                      gradient = g;
                      properties = GradientProperties.fromGradient(g);
                    });
                  },
                  onLongPress: () async {
                    // Attempt to remove if it's a saved gradient (not default)
                    await _removeSavedGradient(index - 1);
                  },
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: g,
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget gradientWidget(
      GradientSpecification specif, BoxConstraints constraints) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
          spacing: 8,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: Text(
                    'Gradient Picker',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 17,
                        color: Colors.white,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: widget.onBackClick,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: Color(0xff3A3A3B), shape: BoxShape.circle),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Color(0xffA4A4AA),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: specif.displayRadius ? 80 : constraints.maxWidth,
                    height: 80,
                    child: AlignmentPicker(
                      key: _sampleKey,
                      alignment: _cornerMode == CornerMode.begin
                          ? properties.begin
                          : _cornerMode == CornerMode.none
                              ? null
                              : properties.end,
                      onChange: (value) {
                        if (_cornerMode == CornerMode.begin) {
                          properties.begin = value;
                        } else {
                          properties.end = value;
                        }
                        upDateGradient();
                      },
                      decoratedChild: Container(
                        decoration: BoxDecoration(
                          gradient: gradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  child: specif.displayRadius
                      ? Slider(
                          activeColor: Colors.grey,
                          thumbColor: Colors.blueGrey,
                          inactiveColor: Colors.black45,
                          value: properties.radius,
                          onChanged: (value) {
                            properties.radius = value;
                            upDateGradient();
                          },
                        )
                      : Container(),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                GestureDetector(
                  key: _linearKey,
                  onTap: () {
                    gradient = GradientType.LinearGradient.get(properties);
                    _explanation = localizationOptions.linearGradient;
                    _cornerMode = CornerMode.none;
                    setState(() {});
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      border: Border.all(
                          width: 3,
                          color: gradient is LinearGradient
                              ? Colors.white
                              : Colors.transparent),
                      borderRadius: BorderRadius.circular(8),
                      gradient: GradientType.LinearGradient.get(properties),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    gradient = GradientType.SweepGradient.get(properties);
                    _explanation = localizationOptions.sweepGradient;
                    _cornerMode = CornerMode.none;
                    setState(() {});
                  },
                  key: _sweepKey,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      border: Border.all(
                          width: 3,
                          color: gradient is SweepGradient
                              ? Colors.white
                              : Colors.transparent),
                      borderRadius: BorderRadius.circular(8),
                      gradient: GradientType.SweepGradient.get(properties),
                    ),
                  ),
                ),
              ],
            ),
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ReorderableListView.builder(
                shrinkWrap: true,
                proxyDecorator:
                    (Widget child, int index, Animation<double> animation) {
                  return Material(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey.withOpacity(0.2),
                      ),
                      child: child,
                    ),
                  );
                },
                itemCount: properties.colors.length,
                itemBuilder: (BuildContext context, int index) {
                  return InkWell(
                    key: ValueKey('${properties.colors[index].value}_$index'),
                    child: colorWidget(
                        index,
                        (index == 0 && _cornerMode == CornerMode.begin) ||
                            (index == properties.colors.length - 1 &&
                                _cornerMode == CornerMode.end),
                        specif,
                        constraints),
                    onTap: () {
                      var val = index == 0 ? CornerMode.begin : CornerMode.end;
                      _cornerMode = val == _cornerMode ? CornerMode.none : val;
                      _explanation = val == CornerMode.none
                          ? ""
                          : val == CornerMode.begin
                              ? localizationOptions.startingPoint
                              : localizationOptions.endPoint;
                      setState(() {});
                    },
                  );
                },
                onReorder: (int oldIndex, int newIndex) {
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  final Color movedColor = properties.colors.removeAt(oldIndex);
                  final double movedStop = properties.stops.removeAt(oldIndex);

                  properties.colors.insert(newIndex, movedColor);
                  properties.stops.insert(newIndex, movedStop);
                  upDateGradient();
                },
              ),
            ),
            WsColorPicker(
              color: Colors.white,
              title: localizationOptions.selectColor,
              onChange: (value) {
                var delta = (properties.stops[1] - properties.stops[0]) / 2;
                properties.colors.insert(1, value);
                properties.stops.insert(1, properties.stops[0] + delta);
                _explanation = localizationOptions.changeColor;
                upDateGradient();
              },
              colorHistory: widget.history,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                alignment: AlignmentDirectional.center,
                child: const Text(
                  "Add Color +",
                  style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ]),
    );
  }

  ///
  /// color tile
  ///
  Widget colorWidget(index, selected, specif, constraints) {
    var alignAjustable = index == 0 ||
        ((index == properties.colors.length - 1) && specif.adjustEnd);
    Widget childContent = Padding(
      key: Key('$index'),
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              width: selected ? 2 : 1,
              color: selected ? Colors.grey : Colors.grey.shade800),
          color: Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            WsColorPicker(
              color: properties.colors[index],
              onChange: (value) {
                properties.colors[index] = value;
                upDateGradient();
              },
              title: localizationOptions.selectColor,
              colorHistory: widget.history,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: index < properties.colors.length - 1
                  ? SliderTheme(
                      data: SliderThemeData(
                          showValueIndicator: ShowValueIndicator.never,
                          overlayShape: SliderComponentShape.noThumb,
                          valueIndicatorShape: SliderComponentShape.noOverlay,
                          activeTrackColor: properties.colors[index],
                          thumbColor: Colors.white,
                          inactiveTrackColor: Colors.grey.shade800),
                      child: Slider(
                        value: properties.stops[index],
                        onChanged: (value) {
                          properties.stops[index] = value;
                          upDateGradient();
                        },
                      ),
                    )
                  : Container(),
            ),
            (index > 0 || properties.colors.length > 2) &&
                    index < properties.colors.length - 1
                ? IconButton(
                    onPressed: () {
                      properties.colors.removeAt(index);
                      properties.stops.removeAt(index);
                      _explanation = "";
                      upDateGradient();
                    },
                    icon: const Icon(
                      Icons.remove_circle_outline_outlined,
                      size: 24,
                    ),
                  )
                : const SizedBox(width: 0),
            alignAjustable
                ? Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Icon(
                      Icons.fit_screen,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                : const SizedBox(width: 0),
          ],
        ),
      ),
    );

    return childContent;
  }

  void upDateGradient() {
    gradient = properties.applyProperties(gradient);
    _sampleKey = GlobalKey();
    _linearKey = GlobalKey();
    _sweepKey = GlobalKey();
    setState(() {});
  }
}

// ignore: constant_identifier_names
enum GradientType { LinearGradient, RadialGradient, SweepGradient }

extension GradientExtension on GradientType {
  Gradient get(GradientProperties prop) {
    switch (this) {
      case GradientType.LinearGradient:
        return LinearGradient(
            colors: prop.colors,
            stops: prop.stops,
            begin: prop.begin,
            end: prop.end);
      case GradientType.RadialGradient:
        return RadialGradient(
            colors: prop.colors,
            stops: prop.stops,
            center: prop.begin,
            radius: prop.radius);
      case GradientType.SweepGradient:
        return SweepGradient(
            colors: prop.colors, stops: prop.stops, center: prop.begin);
    }
  }

  GradientSpecification? specifications() {
    return gradientSpecificationDictionary[this];
  }

  static Map<GradientType, GradientSpecification>
      gradientSpecificationDictionary = {
    GradientType.LinearGradient: GradientSpecification(),
    GradientType.RadialGradient:
        GradientSpecification(adjustEnd: false, displayRadius: true),
    GradientType.SweepGradient: GradientSpecification(adjustEnd: false)
  };
}

class GradientSpecification {
  bool adjustBegin;
  bool adjustEnd;
  bool displayRadius;

  GradientSpecification(
      {this.adjustBegin = true,
      this.adjustEnd = true,
      this.displayRadius = false});
}

class GradientProperties {
  List<Color> colors;
  List<double> stops;
  AlignmentGeometry begin;
  AlignmentGeometry end;
  double radius;
  int? typeIndex;

  GradientProperties({
    colors,
    stops,
    this.begin = Alignment.centerLeft,
    this.end = Alignment.centerRight,
    this.radius = 0.5,
  })  : colors = colors ??= [Colors.pink, Colors.blue],
        stops = stops ?? [0, 1];

  static fromGradient(Gradient g) {
    var p =
        GradientProperties(colors: List<Color>.from(g.colors), stops: g.stops);
    p.typeIndex = GradientType.SweepGradient.index;
    if (g is LinearGradient) {
      p.typeIndex = GradientType.LinearGradient.index;
      p.begin = g.begin;
      p.end = g.end;
    } else if (g is RadialGradient) {
      p.typeIndex = GradientType.RadialGradient.index;
      p.begin = g.center;
      p.radius = g.radius;
    }
    return p;
  }

  static GradientType getType(Gradient g) {
    GradientType type = g is LinearGradient
        ? GradientType.LinearGradient
        : g is RadialGradient
            ? GradientType.RadialGradient
            : GradientType.SweepGradient;
    return type;
  }

  applyProperties(Gradient g) {
    return getType(g).get(this);
  }

  Map<String, dynamic> serialize() {
    return {
      "type": typeIndex,
      "begin": contract(begin),
      "end": contract(end),
      "radius": radius,
      "colors": colors.map((c) => c.colorToString()).toList(),
      "stops": stops,
    };
  }

  String contract(dynamic v) {
    return v.toString().split('.')[1];
  }

  static deserialize(Map<String, dynamic> s) {
    var type = GradientType.values[s["type"]];
    List<Color> colors =
        s["colors"].map<Color>((c) => Color(int.parse(c, radix: 16))).toList();
    List<double> stops = [];
    for (num v in s["stops"]) {
      stops.add(v.toDouble());
    }
    var prop = GradientProperties(
      begin: getAlignment(s["begin"]),
      end: getAlignment(s["end"]),
      radius: s["radius"].toDouble(),
      colors: colors,
      stops: stops,
    );
    return type.get(prop);
  }

  static getAlignment(value) {
    switch (value) {
      case "bottomCenter":
        return Alignment.bottomCenter;
      case "bottomLeft":
        return Alignment.bottomLeft;
      case "bottomRight":
        return Alignment.bottomRight;
      case "center":
        return Alignment.center;
      case "centerLeft":
        return Alignment.centerLeft;
      case "centerRight":
        return Alignment.centerRight;
      case "topCenter":
        return Alignment.topCenter;
      case "topLeft":
        return Alignment.topLeft;
      case "topRight":
        return Alignment.topRight;
    }
  }
}

extension ColorExtension on Color {
  String colorToString() {
    return value.toRadixString(16).padLeft(8, '0');
  }
}
