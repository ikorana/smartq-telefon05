import 'package:flutter/material.dart';

class RotatingRefreshIcon extends StatefulWidget {
  final Color? color;
  final double size;

  const RotatingRefreshIcon({super.key, this.color, this.size = 24});

  @override
  State<RotatingRefreshIcon> createState() => _RotatingRefreshIconState();
}

class _RotatingRefreshIconState extends State<RotatingRefreshIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Icon(
        Icons.refresh,
        color: widget.color ?? Theme.of(context).colorScheme.primary,
        size: widget.size,
      ),
    );
  }
}
