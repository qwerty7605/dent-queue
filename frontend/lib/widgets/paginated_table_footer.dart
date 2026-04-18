import 'package:flutter/material.dart';

class PaginatedTableFooter extends StatelessWidget {
  const PaginatedTableFooter({
    super.key,
    required this.loadedItemCount,
    required this.totalItemCount,
    required this.itemLabel,
    required this.hasMorePages,
    required this.isLoadingMore,
    required this.onLoadMore,
    this.loadMoreButtonKey,
  });

  final int loadedItemCount;
  final int totalItemCount;
  final String itemLabel;
  final bool hasMorePages;
  final bool isLoadingMore;
  final VoidCallback? onLoadMore;
  final Key? loadMoreButtonKey;

  @override
  Widget build(BuildContext context) {
    final bool allItemsLoaded =
        totalItemCount == 0 || loadedItemCount >= totalItemCount;
    final String summary = allItemsLoaded
        ? 'Showing all $totalItemCount $itemLabel'
        : 'Showing $loadedItemCount of $totalItemCount $itemLabel';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            summary,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF5E6C63),
            ),
          ),
          if (hasMorePages)
            FilledButton.icon(
              key: loadMoreButtonKey,
              onPressed: isLoadingMore ? null : onLoadMore,
              icon: isLoadingMore
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.expand_more),
              label: Text(isLoadingMore ? 'Loading...' : 'Load More'),
            ),
        ],
      ),
    );
  }
}
