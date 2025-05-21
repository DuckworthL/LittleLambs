import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/children_provider.dart';
import '../models/child.dart';

class ManageChildrenScreen extends StatelessWidget {
  const ManageChildrenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Children'),
      ),
      body: const ChildrenList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddChildDialog(context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddChildDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const ChildFormDialog(
        title: 'Add New Child',
      ),
    );
  }
}

class ChildrenList extends StatelessWidget {
  const ChildrenList({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ChildrenProvider>(
      builder: (ctx, childrenData, _) {
        final children = childrenData.children;

        if (children.isEmpty) {
          return const Center(
            child: Text('No children added yet. Add some!'),
          );
        }

        return ListView.builder(
          itemCount: children.length,
          itemBuilder: (ctx, i) => ChildListItem(child: children[i]),
        );
      },
    );
  }
}

class ChildListItem extends StatelessWidget {
  final Child child;

  const ChildListItem({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(
            child.name.substring(0, 1).toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(child.name),
        subtitle: Text('${child.age} years old • ${child.groupName}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                _showEditChildDialog(context);
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              color: Colors.red,
              onPressed: () {
                _confirmDelete(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditChildDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => ChildFormDialog(
        title: 'Edit Child',
        child: child,
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to remove ${child.name}?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Provider.of<ChildrenProvider>(context, listen: false)
                  .deleteChild(child.id!);
              Navigator.of(ctx).pop();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class ChildFormDialog extends StatefulWidget {
  final String title;
  final Child? child;

  const ChildFormDialog({
    super.key,
    required this.title,
    this.child,
  });

  @override
  State<ChildFormDialog> createState() => _ChildFormDialogState();
}

class _ChildFormDialogState extends State<ChildFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _notesController = TextEditingController();
  final _groupController = TextEditingController();
  late String _selectedGroup;
  List<String> _existingGroups = [];

  @override
  void initState() {
    super.initState();

    // Initialize with existing child data if editing
    if (widget.child != null) {
      _nameController.text = widget.child!.name;
      _ageController.text = widget.child!.age.toString();
      _notesController.text = widget.child!.notes ?? '';
      _selectedGroup = widget.child!.groupName;
    } else {
      _selectedGroup = '';
    }

    // Get existing groups
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    final childrenProvider =
        Provider.of<ChildrenProvider>(context, listen: false);
    _existingGroups = childrenProvider.groups;

    if (_selectedGroup.isEmpty && _existingGroups.isNotEmpty) {
      _selectedGroup = _existingGroups.first;
    }

    setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _notesController.dispose();
    _groupController.dispose();
    super.dispose();
  }

  Future<void> _saveChild() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final childrenProvider =
        Provider.of<ChildrenProvider>(context, listen: false);

    // Use selected group or create a new one
    final groupName =
        _selectedGroup.isEmpty ? _groupController.text : _selectedGroup;

    final child = Child(
      id: widget.child?.id,
      name: _nameController.text.trim(),
      age: int.parse(_ageController.text.trim()),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      groupName: groupName,
    );

    if (widget.child == null) {
      await childrenProvider.addChild(child);
    } else {
      await childrenProvider.updateChild(child);
    }

    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
                textCapitalization: TextCapitalization.words,
              ),
              TextFormField(
                controller: _ageController,
                decoration: const InputDecoration(labelText: 'Age'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter age';
                  }
                  if (int.tryParse(value) == null || int.parse(value) <= 0) {
                    return 'Please enter a valid age';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'Allergies, special needs, etc.',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 20),

              // Group selection
              if (_existingGroups.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  value: _selectedGroup.isEmpty ? null : _selectedGroup,
                  decoration: const InputDecoration(
                    labelText: 'Select Group',
                  ),
                  items: [
                    ..._existingGroups.map((group) => DropdownMenuItem(
                          value: group,
                          child: Text(group),
                        )),
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Create new group...'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedGroup = value ?? '';
                    });
                  },
                ),
              ],

              if (_selectedGroup.isEmpty) ...[
                const SizedBox(height: 10),
                TextFormField(
                  controller: _groupController,
                  decoration: const InputDecoration(
                    labelText: 'New Group Name',
                    hintText: 'e.g. Toddlers, Pre-K, Elementary',
                  ),
                  validator: (value) {
                    if (_selectedGroup.isEmpty &&
                        (value == null || value.trim().isEmpty)) {
                      return 'Please enter a group name';
                    }
                    return null;
                  },
                  textCapitalization: TextCapitalization.words,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveChild,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
