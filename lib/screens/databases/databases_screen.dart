import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/api_client.dart';
import '../../providers/databases_provider.dart';

class DatabasesScreen extends StatefulWidget {
  const DatabasesScreen({super.key});

  @override
  State<DatabasesScreen> createState() => _DatabasesScreenState();
}

class _DatabasesScreenState extends State<DatabasesScreen> {
  AppDatabase? _selectedDb;
  bool _generating = false;
  final TextEditingController _promptCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';

  Future<void> _generate() async {
    if (_promptCtrl.text.trim().isEmpty) return;
    setState(() => _generating = true);
    try {
      final result = await ApiClient.post('/api/database/generate', {
        'description': _promptCtrl.text.trim(),
      });
      final db = await context.read<DatabasesProvider>().createDatabase(result);
      setState(() {
        _selectedDb = db;
        _promptCtrl.clear();
      });
    } catch (e) {
      _showSnack('Failed to generate database: $e');
    } finally {
      setState(() => _generating = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 13, color: Colors.white)),
      backgroundColor: const Color(0xFF111111),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final dbProvider = context.watch<DatabasesProvider>();
    final databases = dbProvider.databases;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        title: _selectedDb == null
            ? const Text('Databases')
            : Row(children: [
                GestureDetector(
                  onTap: () => setState(() => _selectedDb = null),
                  child: const Icon(Icons.arrow_back_ios_new,
                      size: 16, color: AppColors.foreground),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_selectedDb!.name,
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: _selectedDb == null
          ? _DatabaseList(
              databases: databases,
              promptCtrl: _promptCtrl,
              generating: _generating,
              onGenerate: _generate,
              onSelect: (db) => setState(() => _selectedDb = db),
              onDelete: (db) async {
                await context.read<DatabasesProvider>().deleteDatabase(db.id);
              },
            )
          : _TableView(
              db: _selectedDb!,
              search: _search,
              searchCtrl: _searchCtrl,
              onSearchChanged: (v) => setState(() => _search = v),
            ),
    );
  }
}

class _DatabaseList extends StatelessWidget {
  final List<AppDatabase> databases;
  final TextEditingController promptCtrl;
  final bool generating;
  final VoidCallback onGenerate;
  final ValueChanged<AppDatabase> onSelect;
  final ValueChanged<AppDatabase> onDelete;

  const _DatabaseList({
    required this.databases,
    required this.promptCtrl,
    required this.generating,
    required this.onGenerate,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Prompt bar
        Container(
          padding: const EdgeInsets.all(AppConstants.spacingMD),
          decoration: const BoxDecoration(
            color: AppColors.bgSurface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: promptCtrl,
                  onSubmitted: (_) => onGenerate(),
                  style: const TextStyle(fontSize: 14, color: AppColors.foreground),
                  decoration: InputDecoration(
                    hintText: 'Describe a database — e.g. startup tracker...',
                    hintStyle: const TextStyle(fontSize: 13, color: AppColors.mutedLight),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                      borderSide: const BorderSide(color: AppColors.foreground),
                    ),
                    filled: true,
                    fillColor: AppColors.bgSurfaceHover,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: generating ? null : onGenerate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.foreground,
                    borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                  ),
                  child: generating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
                        )
                      : const Text('Build',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
        // List
        Expanded(
          child: databases.isEmpty
              ? _EmptyState(onPrompt: (p) {
                  promptCtrl.text = p;
                })
              : ListView.separated(
                  padding: const EdgeInsets.all(AppConstants.spacingMD),
                  itemCount: databases.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppConstants.spacingSM),
                  itemBuilder: (_, i) {
                    final db = databases[i];
                    return _DbTile(
                      db: db,
                      onTap: () => onSelect(db),
                      onDelete: () => onDelete(db),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _DbTile extends StatelessWidget {
  final AppDatabase db;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _DbTile({required this.db, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.table_chart_outlined, size: 18, color: AppColors.mutedLight),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(db.name,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.foreground)),
                  const SizedBox(height: 2),
                  Text('${db.columns.length} columns',
                      style: const TextStyle(fontSize: 11, color: AppColors.mutedLight)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.mutedLight),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete database?'),
                    content: Text('Delete "${db.name}" and all records?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () { Navigator.pop(context); onDelete(); },
                        child: const Text('Delete', style: TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TableView extends StatelessWidget {
  final AppDatabase db;
  final String search;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearchChanged;

  const _TableView({
    required this.db,
    required this.search,
    required this.searchCtrl,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: const BoxDecoration(
            color: AppColors.bgSurface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: TextField(
            controller: searchCtrl,
            onChanged: onSearchChanged,
            style: const TextStyle(fontSize: 13, color: AppColors.foreground),
            decoration: InputDecoration(
              hintText: 'Filter records...',
              prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.muted),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                borderSide: const BorderSide(color: AppColors.foreground),
              ),
              filled: true,
              fillColor: AppColors.bgSurfaceHover,
            ),
          ),
        ),
        // Table
        Expanded(
          child: StreamBuilder<List<DbRecord>>(
            stream: context.read<DatabasesProvider>().recordsStream(db.id),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.muted));
              }
              final allRecords = snap.data ?? [];
              final records = search.isEmpty
                  ? allRecords
                  : allRecords.where((r) {
                      final vals = r.properties.values.map((v) => v.toString().toLowerCase());
                      return vals.any((v) => v.contains(search.toLowerCase()));
                    }).toList();

              if (db.columns.isEmpty) {
                return const Center(
                    child: Text('No columns defined.',
                        style: TextStyle(fontSize: 14, color: AppColors.muted)));
              }

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row
                      Container(
                        color: AppColors.bgSurfaceHover,
                        child: Row(
                          children: [
                            _HeaderCell('#', width: 40),
                            ...db.columns.map((col) => _HeaderCell(col.name)),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // Data rows
                      ...records.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final record = entry.value;
                        return Column(
                          children: [
                            _DataRow(
                              index: idx + 1,
                              record: record,
                              columns: db.columns,
                              dbId: db.id,
                            ),
                            const Divider(height: 1),
                          ],
                        );
                      }),
                      // Add row button
                      GestureDetector(
                        onTap: () => context.read<DatabasesProvider>().addRecord(db.id, db.columns),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: const [
                              Icon(Icons.add, size: 14, color: AppColors.muted),
                              SizedBox(width: 6),
                              Text('Add row',
                                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final double width;

  const _HeaderCell(this.label, {this.width = 140});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.mutedLight,
          letterSpacing: 0.8,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final int index;
  final DbRecord record;
  final List<DbColumn> columns;
  final String dbId;

  const _DataRow({
    required this.index,
    required this.record,
    required this.columns,
    required this.dbId,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: AppColors.border)),
          ),
          child: Text(
            index.toString().padLeft(2, '0'),
            style: const TextStyle(
                fontSize: 10, color: AppColors.mutedLight, fontFamily: 'monospace'),
          ),
        ),
        ...columns.map((col) {
          final value = record.properties[col.key];
          return _EditableCell(
            value: value,
            column: col,
            onChanged: (newVal) {
              context.read<DatabasesProvider>().updateCell(
                dbId,
                record.id,
                record.properties,
                col.key,
                newVal,
                columns.isNotEmpty ? columns[0].key : '',
              );
            },
          );
        }),
      ],
    );
  }
}

class _EditableCell extends StatefulWidget {
  final dynamic value;
  final DbColumn column;
  final ValueChanged<dynamic> onChanged;

  const _EditableCell({
    required this.value,
    required this.column,
    required this.onChanged,
  });

  @override
  State<_EditableCell> createState() => _EditableCellState();
}

class _EditableCellState extends State<_EditableCell> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.value != null ? widget.value.toString() : '');
  }

  @override
  void didUpdateWidget(_EditableCell old) {
    super.didUpdateWidget(old);
    final newText = widget.value != null ? widget.value.toString() : '';
    if (_ctrl.text != newText && !_ctrl.selection.isValid) {
      _ctrl.text = newText;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const cellWidth = 140.0;
    const decoration = BoxDecoration(
      border: Border(right: BorderSide(color: AppColors.border)),
    );

    if (widget.column.type == 'checkbox') {
      return Container(
        width: cellWidth,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: decoration,
        child: Checkbox(
          value: widget.value == true,
          onChanged: (v) => widget.onChanged(v),
          activeColor: AppColors.foreground,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }

    if (widget.column.type == 'select' && widget.column.options.isNotEmpty) {
      return Container(
        width: cellWidth,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: decoration,
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: widget.column.options.contains(widget.value?.toString())
                ? widget.value?.toString()
                : null,
            hint: const Text('—',
                style: TextStyle(fontSize: 12, color: AppColors.mutedLight)),
            isExpanded: true,
            items: widget.column.options
                .map((o) => DropdownMenuItem(
                      value: o,
                      child: Text(o,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.foreground)),
                    ))
                .toList(),
            onChanged: (v) => widget.onChanged(v),
            style: const TextStyle(fontSize: 12, color: AppColors.foreground),
          ),
        ),
      );
    }

    return Container(
      width: cellWidth,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: decoration,
      child: TextField(
        controller: _ctrl,
        onSubmitted: widget.onChanged,
        keyboardType: widget.column.type == 'number'
            ? TextInputType.number
            : widget.column.type == 'date'
                ? TextInputType.datetime
                : TextInputType.text,
        style: const TextStyle(fontSize: 12, color: AppColors.foreground),
        decoration: const InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          fillColor: Colors.transparent,
          filled: true,
          contentPadding: EdgeInsets.zero,
          isDense: true,
          hintText: '—',
          hintStyle: TextStyle(fontSize: 12, color: AppColors.mutedLight),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ValueChanged<String> onPrompt;

  const _EmptyState({required this.onPrompt});

  static const _examples = [
    'Startup product launch tracker',
    '30-day corporate diet protocol',
    'Content strategy calendar',
    'E-commerce inventory system',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingLG),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.table_chart_outlined, size: 36, color: AppColors.mutedLight),
          const SizedBox(height: 16),
          const Text('Structured Data Engine',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.foreground)),
          const SizedBox(height: 6),
          const Text(
            'Describe any dataset in plain language. AI will build\nthe schema and populate it with sample data.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _examples
                .map((ex) => GestureDetector(
                      onTap: () => onPrompt(ex),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(ex,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.foregroundMuted)),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}