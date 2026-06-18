import 'dart:convert'; // NEW: For JSON encoding/decoding
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart'; // NEW: For local storage

// ── 1. ENTRY POINT ──────────────────────────────────
void main() => runApp(const TideApp());

// ── 2. DESIGN TOKENS (your S01 Figma colours) ───────
class TideColors {
  static const primary = Color(0xFF5A8FB0);
  static const ink = Color(0xFF1A1A1A);
  static const inkMuted = Color(0xFF6B6B6B);
  static const surface = Color(0xFFFCFAF3);
  static const card = Color(0xFFFFFFFF);
  static const border = Color(0xFFEFE9D8);
  static const priHigh = Color(0xFFC76A55);
  static const priMed = Color(0xFFC9A23A);
  static const priLow = Color(0xFF7A9165);

  static const catWork = Color(0xFF5C6BC0);
  static const catPersonal = Color(0xFF66BB6A);
  static const catStudy = Color(0xFFFFA726);
}

// ── 3. DATA MODEL ───────────────────────────────────
class Task {
  final String title;
  final String priority;
  final String category;
  bool isDone;

  Task({
    required this.title,
    this.priority = 'med',
    this.category = 'Personal',
    this.isDone = false,
  });

  Color get priorityColor {
    if (priority == 'high') return TideColors.priHigh;
    if (priority == 'low') return TideColors.priLow;
    return TideColors.priMed;
  }

  Color get categoryColor {
    if (category == 'Work') return TideColors.catWork;
    if (category == 'Study') return TideColors.catStudy;
    return TideColors.catPersonal;
  }

  // NEW: Convert a Task into a Map for JSON storage
  Map<String, dynamic> toJson() => {
        'title': title,
        'priority': priority,
        'category': category,
        'isDone': isDone,
      };

  // NEW: Create a Task from a JSON Map
  factory Task.fromJson(Map<String, dynamic> json) => Task(
        title: json['title'],
        priority: json['priority'],
        category: json['category'],
        isDone: json['isDone'],
      );
}

// ── 4. ROOT APP WIDGET ──────────────────────────────
class TideApp extends StatelessWidget {
  const TideApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          scaffoldBackgroundColor: TideColors.surface,
          textTheme: GoogleFonts.plusJakartaSansTextTheme(
            Theme.of(context).textTheme,
          ),
        ),
        home: const HomeScreen(),
      );
}

// ── 5. HOME SCREEN WIDGET ───────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Master task list (starts empty, loads from storage)
  List<Task> tasks = [];
  bool _isLoading = true; // NEW: Track loading state

  String _searchQuery = '';
  String _selectedPriority = 'all';
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _loadTasks(); // NEW: Load tasks when app starts
  }

  // NEW: Load tasks from SharedPreferences
  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? tasksJson = prefs.getString('tide_tasks');

    if (tasksJson != null) {
      final List<dynamic> decodedList = jsonDecode(tasksJson);
      setState(() {
        tasks = decodedList.map((item) => Task.fromJson(item)).toList();
      });
    } else {
      // Load default tasks if opening for the very first time
      setState(() {
        tasks = [
          Task(
              title: 'Submit DBMS assignment',
              priority: 'high',
              category: 'Study'),
          Task(title: 'Call Amma 6 PM', category: 'Personal'),
          Task(title: 'Gym — leg day', priority: 'low', category: 'Personal'),
          Task(title: 'Review Figma prototype', isDone: true, category: 'Work'),
        ];
      });
      _saveTasks();
    }

    setState(() => _isLoading = false);
  }

  // NEW: Save tasks to SharedPreferences
  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedList =
        jsonEncode(tasks.map((task) => task.toJson()).toList());
    await prefs.setString('tide_tasks', encodedList);
  }

  // UPDATED: Toggle status and save
  void _toggle(Task t) {
    setState(() => t.isDone = !t.isDone);
    _saveTasks();
  }

  // UPDATED: Add new task and save
  void _add(String title, String priority, String category) {
    if (title.trim().isEmpty) return;
    setState(() {
      tasks.add(
          Task(title: title.trim(), priority: priority, category: category));
    });
    _saveTasks();
  }

  void _openSheet() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: TideColors.card,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (_) => AddTaskSheet(onAdd: _add),
      );

  @override
  Widget build(BuildContext context) {
    // If we are still loading data from storage, show a loader
    if (_isLoading) {
      return const Scaffold(
        body:
            Center(child: CircularProgressIndicator(color: TideColors.primary)),
      );
    }

    final totalTasks = tasks.length;
    final completedTasks = tasks.where((t) => t.isDone).length;
    final remaining = totalTasks - completedTasks;
    final completionRatio = totalTasks > 0 ? completedTasks / totalTasks : 0.0;

    // Real-time filtering pipeline (Search -> Priority -> Category)
    final filteredTasks = tasks.where((task) {
      final matchesSearch =
          task.title.toLowerCase().contains(_searchQuery.toLowerCase());

      bool matchesPriority = true;
      if (_selectedPriority == 'done') {
        matchesPriority = task.isDone;
      } else if (_selectedPriority != 'all') {
        matchesPriority = !task.isDone && task.priority == _selectedPriority;
      }

      bool matchesCategory = true;
      if (_selectedCategory != 'All') {
        matchesCategory = task.category == _selectedCategory;
      }

      return matchesSearch && matchesPriority && matchesCategory;
    }).toList();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Good evening 👋',
                  style: TextStyle(fontSize: 14, color: TideColors.inkMuted)),
              const Text('Today',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: TideColors.ink)),
              Text('$remaining tasks remaining',
                  style: const TextStyle(color: TideColors.inkMuted)),
              const SizedBox(height: 16),

              // ── COMPLETION PROGRESS BAR ──────────────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Progress',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: TideColors.inkMuted)),
                      Text('${(completionRatio * 100).toInt()}%',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: TideColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: completionRatio,
                      backgroundColor: TideColors.border,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          TideColors.primary),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── SEARCH BAR (Triggers real-time UI rebuild via onChanged) ─
              TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search tasks...',
                  prefixIcon:
                      const Icon(Icons.search, color: TideColors.inkMuted),
                  filled: true,
                  fillColor: TideColors.card,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: TideColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: TideColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── CATEGORY CHIPS ───────────────────────────────────────────
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', 'Work', 'Personal', 'Study'].map((cat) {
                    final isSelected = _selectedCategory == cat;
                    Color chipColor = TideColors.primary;
                    if (cat == 'Work') chipColor = TideColors.catWork;
                    if (cat == 'Personal') chipColor = TideColors.catPersonal;
                    if (cat == 'Study') chipColor = TideColors.catStudy;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        selectedColor: chipColor,
                        backgroundColor: TideColors.card,
                        side: BorderSide(
                            color: isSelected ? chipColor : TideColors.border),
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color:
                              isSelected ? Colors.white : TideColors.inkMuted,
                        ),
                        onSelected: (_) =>
                            setState(() => _selectedCategory = cat),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),

              // ── PRIORITY DROPDOWN ────────────────────────────────────────
              Row(
                children: [
                  const Text('Priority:',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: TideColors.inkMuted)),
                  const SizedBox(width: 8),
                  Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: TideColors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: TideColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedPriority,
                        icon: const Icon(Icons.filter_list,
                            size: 16, color: TideColors.inkMuted),
                        borderRadius: BorderRadius.circular(12),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: TideColors.ink,
                          fontFamily: 'Plus Jakarta Sans',
                        ),
                        items: ['all', 'high', 'med', 'low', 'done']
                            .map((p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(p.toUpperCase()),
                                ))
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _selectedPriority = val!),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── TASK LIST ────────────────────────────────────────────────
              Expanded(
                child: filteredTasks.isEmpty
                    ? const Center(
                        child: Text('No tasks found',
                            style: TextStyle(color: TideColors.inkMuted)))
                    : ListView(
                        children: filteredTasks
                            .map((t) =>
                                TaskCard(task: t, onTap: () => _toggle(t)))
                            .toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openSheet,
        backgroundColor: TideColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// ── 6a. TASKCARD ────────────────────────────────────
class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onTap;
  const TaskCard({super.key, required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TideColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: TideColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: TideColors.primary, width: 2),
                  color: task.isDone ? TideColors.priLow : Colors.transparent,
                ),
                child: task.isDone
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: task.isDone
                              ? TideColors.inkMuted
                              : TideColors.ink,
                          decoration: task.isDone
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        )),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: task.categoryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        task.category.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: task.categoryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: task.priorityColor)),
            ],
          ),
        ),
      );
}

// ── 6b. ADDTASKSHEET ────────────────────────────────
class AddTaskSheet extends StatefulWidget {
  final void Function(String, String, String) onAdd;
  const AddTaskSheet({super.key, required this.onAdd});
  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  final _c = TextEditingController();
  String _priority = 'med';
  String _category = 'Personal';

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('New task',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(
                  controller: _c,
                  autofocus: true,
                  decoration: InputDecoration(
                      hintText: 'What needs doing?',
                      filled: true,
                      fillColor: TideColors.surface,
                      border: OutlineInputBorder(
                          borderSide: BorderSide.none,
                          borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 16),
              const Text('Category',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: TideColors.inkMuted)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: TideColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: TideColors.border),
                  ),
                ),
                items: ['Work', 'Personal', 'Study']
                    .map((cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(cat,
                              style: const TextStyle(color: TideColors.ink)),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => _category = val!),
                icon: const Icon(Icons.keyboard_arrow_down,
                    color: TideColors.inkMuted),
              ),
              const SizedBox(height: 16),
              const Text('Priority',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: TideColors.inkMuted)),
              const SizedBox(height: 8),
              Row(
                  children: ['high', 'med', 'low'].map((p) {
                final sel = _priority == p;
                return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                        label: Text(p.toUpperCase()),
                        selected: sel,
                        selectedColor: TideColors.primary,
                        backgroundColor: TideColors.surface,
                        side: BorderSide(
                            color:
                                sel ? TideColors.primary : TideColors.border),
                        labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: sel ? Colors.white : TideColors.inkMuted),
                        onSelected: (_) => setState(() => _priority = p)));
              }).toList()),
              const SizedBox(height: 32),
              SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: TideColors.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 16)),
                      onPressed: () {
                        widget.onAdd(_c.text, _priority, _category);
                        Navigator.pop(context);
                      },
                      child: const Text('Save Task',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)))),
            ]),
      );
}
