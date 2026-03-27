import 'package:flutter/material.dart';
import '../core/models/member.dart';

class MemberAvatar extends StatelessWidget {
  final Member member;
  final double size;

  const MemberAvatar({super.key, required this.member, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: member.color,
      child: Text(
        member.displayInitial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
