import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/theme/app_theme.dart';

class SocialAuthButton extends StatelessWidget {
  final String provider;
  final String iconPath;
  final VoidCallback onPressed;

  const SocialAuthButton({
    super.key,
    required this.provider,
    required this.iconPath,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.backgroundSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1E293B)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              iconPath,
              width: 22,
              height: 22,
            ),
            const SizedBox(width: 10),
            Text(
              provider,
              style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
