import 'package:flutter/material.dart';
import 'dart:async';
import '../../../core/theme/app_theme.dart';

class MapSearchBar extends StatefulWidget {
  final void Function(String) onSearch;
  final VoidCallback onFilterTap;

  const MapSearchBar({
    super.key,
    required this.onSearch,
    required this.onFilterTap,
  });

  @override
  State<MapSearchBar> createState() => _MapSearchBarState();
}

class _MapSearchBarState extends State<MapSearchBar> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.backgroundCard.withOpacity(0.95),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E293B)),
              boxShadow: const [
                BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: TextField(
              controller: _controller,
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar comercios, categorías...',
                hintStyle: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondaryDark),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.textSecondaryDark, size: 18),
                        onPressed: () {
                          _controller.clear();
                          widget.onSearch('');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                filled: false,
              ),
              onChanged: (value) {
                setState(() {});
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 500), () {
                  widget.onSearch(value);
                });
              },
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: widget.onFilterTap,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.backgroundCard.withOpacity(0.95),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E293B)),
              boxShadow: const [
                BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: const Icon(Icons.tune, color: Colors.white, size: 22),
          ),
        ),
      ],
    );
  }
}
