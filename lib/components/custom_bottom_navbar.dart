import 'package:flutter/material.dart';

const Color mainColor = Color(0xFFFF6F61);

class CustomBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      // Bottom system inset (gesture-nav bar / home indicator) varies by
      // device — without SafeArea the fixed padding below left content
      // sitting under that inset, getting clipped/squished by the system UI
      // on devices with a taller inset than others.
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
          child: Row(
            children: [
              _buildBarItem(
                context,
                index: 0,
                iconPath: "assets/images/navbar/home.png",
                label: "Home",
                isActive: currentIndex == 0,
              ),
              _buildBarItem(
                context,
                index: 1,
                iconPath: "assets/images/navbar/circle.png",
                label: "Contacts",
                isActive: currentIndex == 1,
              ),
              _buildBarItem(
                context,
                index: 2,
                iconPath: "assets/images/navbar/map.png",
                label: "Map",
                isActive: currentIndex == 2,
              ),
              _buildBarItem(
                context,
                index: 3,
                iconPath: "assets/images/navbar/profile.png",
                label: "Profile",
                isActive: currentIndex == 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBarItem(
    BuildContext context, {
    required int index,
    required String iconPath,
    required String label,
    required bool isActive,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: isActive ? 50 : 40,
          padding: EdgeInsets.symmetric(
            horizontal: isActive ? 12 : 4,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: isActive ? mainColor.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(50),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              IconTheme(
                data: IconThemeData(
                  color: isActive ? mainColor : Colors.grey,
                ),
                child: Image.asset(
                  iconPath,
                  color: isActive ? mainColor : Colors.grey,
                  width: 24,
                  height: 24,
                ),
              ),
              if (isActive) const SizedBox(width: 6),
              if (isActive)
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: mainColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
