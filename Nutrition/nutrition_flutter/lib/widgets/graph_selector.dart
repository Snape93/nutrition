import 'package:flutter/material.dart';
import '../models/graph_models.dart';

/// Professional graph selector widget with modern chip design
class GraphSelector extends StatefulWidget {
  final List<GraphType> availableTypes;
  final GraphType selectedType;
  final Function(GraphType) onTypeSelected;
  final bool showAddButton;
  final String? userGender;

  const GraphSelector({
    super.key,
    required this.availableTypes,
    required this.selectedType,
    required this.onTypeSelected,
    this.showAddButton = true,
    this.userGender,
  });

  @override
  State<GraphSelector> createState() => _GraphSelectorState();
}

class _GraphSelectorState extends State<GraphSelector>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Use WidgetsBinding to ensure the animation starts after the frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount:
              widget.availableTypes.length + (widget.showAddButton ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == widget.availableTypes.length && widget.showAddButton) {
              return _buildAddButton();
            }

            final type = widget.availableTypes[index];
            final isSelected = type == widget.selectedType;
            final metadata = GraphMetadata.fromType(type, widget.userGender);

            return _buildMetricChip(
              type: type,
              metadata: metadata,
              isSelected: isSelected,
            );
          },
        ),
      ),
    );
  }

  Widget _buildMetricChip({
    required GraphType type,
    required GraphMetadata metadata,
    required bool isSelected,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onTypeSelected(type),
          borderRadius: BorderRadius.circular(28),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color:
                  isSelected
                      ? metadata.color.withValues(alpha: 0.1)
                      : ProfessionalColors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isSelected ? metadata.color : ProfessionalColors.outline,
                width: isSelected ? 2 : 1,
              ),
              boxShadow:
                  isSelected
                      ? [
                        BoxShadow(
                          color: metadata.color.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                      : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  metadata.icon,
                  size: 20,
                  color:
                      isSelected
                          ? metadata.color
                          : ProfessionalColors.onSurface.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 8),
                Text(
                  metadata.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color:
                        isSelected
                            ? metadata.color
                            : ProfessionalColors.onSurface,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.check_circle, size: 16, color: metadata.color),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAddMetricDialog(),
          borderRadius: BorderRadius.circular(28),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: ProfessionalColors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: ProfessionalColors.outline, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add,
                  size: 20,
                  color: ProfessionalColors.onSurface.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 8),
                Text(
                  'Add Metric',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: ProfessionalColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddMetricDialog() {
    showDialog(
      context: context,
      builder:
          (context) => _AddMetricDialog(
            availableTypes: widget.availableTypes,
            onTypeSelected: (type) {
              Navigator.of(context).pop();
              widget.onTypeSelected(type);
            },
            userGender: widget.userGender,
          ),
    );
  }
}

/// Dialog for adding new metrics
class _AddMetricDialog extends StatelessWidget {
  final List<GraphType> availableTypes;
  final Function(GraphType) onTypeSelected;
  final String? userGender;

  const _AddMetricDialog({
    required this.availableTypes,
    required this.onTypeSelected,
    this.userGender,
  });

  @override
  Widget build(BuildContext context) {
    final allTypes = GraphType.values;
    final availableToAdd =
        allTypes.where((type) => !availableTypes.contains(type)).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ProfessionalColors.background,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.add_chart,
                    color: ProfessionalColors.info,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Add Metric',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: ProfessionalColors.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    color: ProfessionalColors.onSurface.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child:
                  availableToAdd.isEmpty
                      ? _buildEmptyState()
                      : _buildMetricList(availableToAdd),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 48,
            color: ProfessionalColors.success.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
            'All metrics added',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: ProfessionalColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You have added all available metrics to your dashboard.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: ProfessionalColors.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricList(List<GraphType> types) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: types.length,
      itemBuilder: (context, index) {
        final type = types[index];
        final metadata = GraphMetadata.fromType(type, userGender);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onTypeSelected(type),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: metadata.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(metadata.icon, color: metadata.color, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          metadata.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: ProfessionalColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          metadata.subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: ProfessionalColors.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: ProfessionalColors.onSurface.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
