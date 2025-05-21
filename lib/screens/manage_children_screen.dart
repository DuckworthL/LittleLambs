import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/children_provider.dart';
import '../models/child.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

class ManageChildrenScreen extends StatefulWidget {
  const ManageChildrenScreen({super.key});

  @override
  State<ManageChildrenScreen> createState() => _ManageChildrenScreenState();
}

class _ManageChildrenScreenState extends State<ManageChildrenScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  TabController? _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadChildren();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadChildren() async {
    setState(() => _isLoading = true);

    final childrenProvider =
        Provider.of<ChildrenProvider>(context, listen: false);
    await childrenProvider.fetchAndSetChildren();

    _tabController?.dispose();
    if (childrenProvider.groups.isNotEmpty) {
      _tabController = TabController(
        length: childrenProvider.groups.length + 1, // +1 for "All" tab
        vsync: this,
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final childrenProvider = Provider.of<ChildrenProvider>(context);
    final allGroups = ['All', ...childrenProvider.groups];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search children...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                  border: InputBorder.none,
                ),
                style: const TextStyle(color: Colors.white),
              )
            : const Text('Manage Children'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                }
              });
            },
          ),
        ],
        bottom: _isLoading
            ? null
            : (allGroups.length > 1 && _tabController != null)
                ? PreferredSize(
                    preferredSize: const Size.fromHeight(48),
                    child: Container(
                      height: 40,
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        labelColor: AppColors.primary,
                        unselectedLabelColor: Colors.white,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontWeight: FontWeight.normal,
                          fontSize: 12,
                        ),
                        tabs:
                            allGroups.map((group) => Tab(text: group)).toList(),
                      ),
                    ),
                  )
                : null,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : childrenProvider.children.isEmpty
              ? _EmptyChildrenState()
              : _tabController == null
                  ? const Center(child: Text('Error initializing tabs'))
                  : Column(
                      children: [
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              // "All" tab
                              _buildChildrenList(
                                childrenProvider.children
                                    .where((child) =>
                                        _searchQuery.isEmpty ||
                                        child.name.toLowerCase().contains(
                                            _searchQuery.toLowerCase()))
                                    .toList(),
                              ),
                              // Group-specific tabs
                              ...childrenProvider.groups.map((group) {
                                return _buildChildrenList(
                                  childrenProvider
                                      .getChildrenByGroup(group)
                                      .where((child) =>
                                          _searchQuery.isEmpty ||
                                          child.name.toLowerCase().contains(
                                              _searchQuery.toLowerCase()))
                                      .toList(),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddChildDialog(),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildChildrenList(List<Child> children) {
    if (children.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _searchQuery.isNotEmpty
                    ? Icons.search_off
                    : Icons.people_outline,
                size: 60,
                color: AppColors.textLight,
              ),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isNotEmpty
                    ? 'No children found matching "$_searchQuery"'
                    : 'No children in this group',
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              if (_searchQuery.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    _searchController.clear();
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear search'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: children.length,
      itemBuilder: (ctx, i) => ChildItem(
        child: children[i],
        onEdit: () => _showEditChildDialog(children[i]),
        onDelete: () => _confirmDeleteChild(children[i]),
      ),
    );
  }

  void _showAddChildDialog() {
    showDialog(
      context: context,
      builder: (ctx) => const ChildForm(
        title: 'Add Child',
        confirmLabel: 'Add',
      ),
    );
  }

  void _showEditChildDialog(Child child) {
    showDialog(
      context: context,
      builder: (ctx) => ChildForm(
        title: 'Edit Child',
        confirmLabel: 'Save',
        child: child,
      ),
    );
  }

  void _confirmDeleteChild(Child child) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Delete Child'),
        content: Text(
            'Are you sure you want to delete ${child.name}?\n\nThis will also remove all attendance and points records for this child.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await Provider.of<ChildrenProvider>(context, listen: false)
                  .deleteChild(child.id!);

              // ignore: use_build_context_synchronously
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${child.name} has been deleted'),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  margin: const EdgeInsets.all(16),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _EmptyChildrenState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.people_outline,
              size: 80,
              color: AppColors.textLight,
            ),
            const SizedBox(height: 24),
            const Text(
              'No Children Yet',
              style: AppTextStyles.heading2,
            ),
            const SizedBox(height: 12),
            const Text(
              'Start by adding children to the app',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => const ChildForm(
                    title: 'Add Child',
                    confirmLabel: 'Add',
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add First Child'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChildItem extends StatelessWidget {
  final Child child;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ChildItem({
    super.key,
    required this.child,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary,
                child: Text(
                  child.name.isNotEmpty ? child.name[0].toUpperCase() : 'C',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Child info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            child.groupName,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Age: ${child.age}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    if (child.notes != null && child.notes!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          child.notes!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              // Actions
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: onEdit,
                    color: AppColors.primary,
                    iconSize: 20,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                    tooltip: 'Edit',
                  ),
                  const SizedBox(height: 4),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: onDelete,
                    color: AppColors.error,
                    iconSize: 20,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                    tooltip: 'Delete',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChildForm extends StatefulWidget {
  final String title;
  final String confirmLabel;
  final Child? child;

  const ChildForm({
    super.key,
    required this.title,
    required this.confirmLabel,
    this.child,
  });

  @override
  State<ChildForm> createState() => _ChildFormState();
}

class _ChildFormState extends State<ChildForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _notesController = TextEditingController();
  String? _selectedGroup;
  final _newGroupController = TextEditingController();
  bool _isAddingNewGroup = false;

  @override
  void initState() {
    super.initState();

    if (widget.child != null) {
      _nameController.text = widget.child!.name;
      _ageController.text = widget.child!.age.toString();
      if (widget.child!.notes != null) {
        _notesController.text = widget.child!.notes!;
      }
      _selectedGroup = widget.child!.groupName;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _notesController.dispose();
    _newGroupController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final childrenProvider = Provider.of<ChildrenProvider>(context);
    final groups = childrenProvider.groups;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Text(
        widget.title,
        style: AppTextStyles.heading3,
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name field
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.primary),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Age field
                TextFormField(
                  controller: _ageController,
                  decoration: const InputDecoration(
                    labelText: 'Age',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.primary),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an age';
                    }
                    final age = int.tryParse(value);
                    if (age == null || age <= 0) {
                      return 'Please enter a valid age';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Group field
                if (!_isAddingNewGroup) ...[
                  DropdownButtonFormField<String>(
                    value: _selectedGroup,
                    decoration: const InputDecoration(
                      labelText: 'Group',
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.primary),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a group';
                      }
                      return null;
                    },
                    items: [
                      ...groups.map(
                        (group) => DropdownMenuItem(
                          value: group,
                          child: Text(group),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedGroup = value;
                      });
                    },
                  ),

                  // Add new group option
                  if (groups.isEmpty || groups.isNotEmpty)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _isAddingNewGroup = true;
                        });
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add New Group'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        alignment: Alignment.centerLeft,
                      ),
                    ),
                ] else ...[
                  // New group input field
                  TextFormField(
                    controller: _newGroupController,
                    decoration: InputDecoration(
                      labelText: 'New Group Name',
                      labelStyle: const TextStyle(color: AppColors.textSecondary),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.primary),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.cancel, size: 18),
                        onPressed: () {
                          setState(() {
                            _isAddingNewGroup = false;
                            _newGroupController.clear();
                          });
                        },
                      ),
                    ),
                    validator: _isAddingNewGroup
                        ? (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a group name';
                            }
                            if (groups.contains(value)) {
                              return 'This group already exists';
                            }
                            return null;
                          }
                        : null,
                    onChanged: (value) {
                      _selectedGroup = value;
                    },
                  ),
                ],
                const SizedBox(height: 16),

                // Notes field
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.primary),
                    ),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              _saveChild(context);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }

  void _saveChild(BuildContext context) async {
    final childrenProvider =
        Provider.of<ChildrenProvider>(context, listen: false);

    // Determine the final group name
    final groupName =
        _isAddingNewGroup ? _newGroupController.text.trim() : _selectedGroup!;

    final child = Child(
      id: widget.child?.id,
      name: _nameController.text.trim(),
      age: int.parse(_ageController.text.trim()),
      notes: _notesController.text.trim(),
      groupName: groupName,
    );

    try {
      if (widget.child == null) {
        // Add new child
        await childrenProvider.addChild(child);
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${child.name} added successfully'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      } else {
        // Update existing child
        await childrenProvider.updateChild(child);
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${child.name} updated successfully'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }

      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }
}
