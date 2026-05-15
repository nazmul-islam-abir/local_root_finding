import 'package:flutter/material.dart';

class SearchBarWidget extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onChanged;
  final Function() onMapStylePressed;
  final VoidCallback? onClearPressed;

  const SearchBarWidget({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onMapStylePressed,
    this.onClearPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 500),
      child: Row(
        children: [
          Expanded(
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(30),
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: "Search destinations...",
                  hintStyle: const TextStyle(fontSize: 14),
                  prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                  suffixIcon: controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: onClearPressed,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 40),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                ),
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.map, color: Colors.blue, size: 20),
              onPressed: onMapStylePressed,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
          ),
        ],
      ),
    );
  }
}