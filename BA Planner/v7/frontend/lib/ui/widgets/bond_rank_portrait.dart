import 'package:flutter/material.dart';

const defaultStudentPortraitBackgroundAsset =
    'assets/studio_features/square.png';
const blueStudentPortraitBackgroundAsset =
    'assets/student_bond_backgrounds/square_blue.png';
const yellowStudentPortraitBackgroundAsset =
    'assets/student_bond_backgrounds/square_yellow.png';
const purpleStudentPortraitBackgroundAsset =
    'assets/student_bond_backgrounds/square_purple.png';

String bondRankPortraitBackgroundAsset(int? bondRank) {
  if (bondRank != null && bondRank >= 100) {
    return purpleStudentPortraitBackgroundAsset;
  }
  if (bondRank != null && bondRank >= 50) {
    return yellowStudentPortraitBackgroundAsset;
  }
  if (bondRank != null && bondRank >= 20) {
    return blueStudentPortraitBackgroundAsset;
  }
  return defaultStudentPortraitBackgroundAsset;
}

class BondRankPortrait extends StatelessWidget {
  const BondRankPortrait({
    super.key,
    required this.portraitAsset,
    required this.bondRank,
    this.clipRadius = 4,
  });

  final String portraitAsset;
  final int? bondRank;
  final double clipRadius;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(clipRadius),
    child: Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        Image.asset(
          bondRankPortraitBackgroundAsset(bondRank),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
        ),
        FractionallySizedBox(
          widthFactor: 0.98,
          heightFactor: 0.98,
          child: Image.asset(
            portraitAsset,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ],
    ),
  );
}
