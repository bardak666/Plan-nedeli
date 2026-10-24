import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PlanNedeliApp());
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('plan_nedeli.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        day_key TEXT NOT NULL,
        date TEXT NOT NULL,
        is_completed INTEGER NOT NULL
      )
    ''');
  }

  Future<int> insertTask(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('tasks', row);
  }

  Future<List<Map<String, dynamic>>> getTasksForDate(String dateStr) async {
    final db = await instance.database;
    return await db.query(
      'tasks',
      where: 'date = ?',
      whereArgs: [dateStr],
    );
  }

  Future<int> updateTaskStatus(int id, int isCompleted) async {
    final db = await instance.database;
    return await db.update(
      'tasks',
      {'is_completed': isCompleted},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteTask(int id) async {
    final db = await instance.database;
    return await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

class PlanNedeliApp extends StatelessWidget {
  const PlanNedeliApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'План недели',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
      ),
      home: const WeeklyDashboardScreen(),
    );
  }
}

class WeeklyDashboardScreen extends StatefulWidget {
  const WeeklyDashboardScreen({super.key});

  @override
  State<WeeklyDashboardScreen> createState() => _WeeklyDashboardScreenState();
}

class _WeeklyDashboardScreenState extends State<WeeklyDashboardScreen> {
  DateTime selectedDate = DateTime.now();

  String get formattedDateStr => DateFormat('yyyy-MM-dd').format(selectedDate);
  String get displayDateStr => DateFormat('EEEE, d MMMM', 'ru_RU').format(selectedDate);

  List<Map<String, dynamic>> tasks = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => isLoading = true);
    final data = await DatabaseHelper.instance.getTasksForDate(formattedDateStr);
    setState(() {
      tasks = data;
      isLoading = false;
    });
  }

  void _addNewTaskDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новая задача на сегодня'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Что нужно сделать?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await DatabaseHelper.instance.insertTask({
                  'title': controller.text.trim(),
                  'day_key': formattedDateStr,
                  'date': formattedDateStr,
                  'is_completed': 0,
                });
                Navigator.pop(context);
                _loadTasks();
              }
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('План недели', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: () {
              setState(() {
                selectedDate = DateTime.now();
              });
              _loadTasks();
            },
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.indigo.withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      selectedDate = selectedDate.subtract(const Duration(days: 1));
                    });
                    _loadTasks();
                  },
                ),
                Column(
                  children: [
                    Text(
                      displayDateStr,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text('100% Оффлайн (SQLite)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      selectedDate = selectedDate.add(const Duration(days: 1));
                    });
                    _loadTasks();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : tasks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.task_alt, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text('На этот день задач нет', style: TextStyle(color: Colors.grey, fontSize: 16)),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _addNewTaskDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('Добавить задачу'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          final isDone = task['is_completed'] == 1;
                          return Dismissible(
                            key: Key(task['id'].toString()),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (_) async {
                              await DatabaseHelper.instance.deleteTask(task['id']);
                              _loadTasks();
                            },
                            child: CheckboxListTile(
                              title: Text(
                                task['title'],
                                style: TextStyle(
                                  decoration: isDone ? TextDecoration.lineThrough : null,
                                  color: isDone ? Colors.grey : Colors.white,
                                ),
                              ),
                              value: isDone,
                              onChanged: (val) async {
                                await DatabaseHelper.instance.updateTaskStatus(
                                  task['id'],
                                  val == true ? 1 : 0,
                                );
                                _loadTasks();
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNewTaskDialog,
        icon: const Icon(Icons.add),
        label: const Text('Задача'),
      ),
    );
  }
}
