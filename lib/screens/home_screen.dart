import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/task_service.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TaskService _taskService = TaskService();
  final AuthService _authService = AuthService();

  final TextEditingController _taskController = TextEditingController();

  String _searchQuery = '';
  String _filter = 'All'; // 'All', 'Completed', 'Pending'
  String _selectedPriority = 'low';

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return "${months[date.month - 1]} ${date.day}, ${date.year}";
  }

  void _showTaskDialog({String? taskId, String? currentTitle, String? currentPriority, DateTime? currentDueDate}) {
    if (currentTitle != null) {
      _taskController.text = currentTitle;
      _selectedPriority = currentPriority ?? 'low';
    } else {
      _taskController.clear();
      _selectedPriority = 'low';
    }
    
    DateTime? tempDate = currentDueDate;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(taskId == null ? "Add Task" : "Edit Task"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _taskController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: "Enter task details...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (taskId == null) ...[
                      const Padding(
                        padding: EdgeInsets.only(left: 4.0, bottom: 8.0),
                        child: Text("Priority", style: TextStyle(fontSize: 14, color: Colors.black54)),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: ['High', 'Medium', 'Low'].map((priority) {
                          final value = priority.toLowerCase();
                          final isSelected = _selectedPriority == value;
                          return ChoiceChip(
                            label: Text(priority),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setDialogState(() => _selectedPriority = value);
                              }
                            },
                            selectedColor: _getPriorityColor(value).withOpacity(0.2),
                            side: BorderSide(
                              color: isSelected ? _getPriorityColor(value) : Colors.grey[300]!,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            labelStyle: TextStyle(
                              color: isSelected ? _getPriorityColor(value) : Colors.black87,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 20, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tempDate == null ? "No due date" : _formatDate(tempDate!),
                              style: TextStyle(color: tempDate == null ? Colors.grey : Colors.black87),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: tempDate ?? DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setDialogState(() => tempDate = picked);
                              }
                            },
                            child: const Text("Select"),
                          )
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final title = _taskController.text.trim();
                    if (title.isEmpty) return;

                    if (taskId == null) {
                      await _taskService.addTask(title, priority: _selectedPriority, dueDate: tempDate);
                    } else {
                      await _taskService.updateTaskTitle(taskId, title);
                    }
                    
                    if (mounted) Navigator.pop(context);
                  },
                  child: Text(taskId == null ? "Add" : "Save"),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Tasker", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () async {
              await _authService.logout();
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          )
        ],
      ),
      body: Column(
        children: [
          // 🔹 Search & Filter Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search tasks...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Pending', 'Completed'].map((filter) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(filter),
                          selected: _filter == filter,
                          onSelected: (selected) {
                            if (selected) setState(() => _filter = filter);
                          },
                          selectedColor: Colors.blueAccent.withOpacity(0.2),
                          labelStyle: TextStyle(
                            color: _filter == filter ? Colors.blueAccent : Colors.black87,
                            fontWeight: _filter == filter ? FontWeight.bold : FontWeight.normal,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // 🔹 Task List Section
          Expanded(
            child: StreamBuilder(
              stream: _taskService.getTasks(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text("Error loading tasks"));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState("No tasks yet", "Tap + to add a new task");
                }

                // 🔹 Apply filters
                var tasks = snapshot.data!.docs.where((task) {
                  final data = task.data() as Map<String, dynamic>?;
                  
                  // Safely read fields with null-safe access and default values
                  final bool isDone = (data?['isDone'] as bool?) ?? false;
                  final String title = data?['title']?.toString() ?? '';

                  // Search filter
                  if (_searchQuery.isNotEmpty && !title.toLowerCase().contains(_searchQuery.toLowerCase())) {
                    return false;
                  }

                  // Status filter
                  if (_filter == 'Completed' && !isDone) return false;
                  if (_filter == 'Pending' && isDone) return false;

                  return true;
                }).toList();

                if (tasks.isEmpty) {
                  return _buildEmptyState("No matching tasks found", "Try different filters or search terms");
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    final data = task.data() as Map<String, dynamic>?;
                    
                    // Handle missing fields safely with null-aware operators
                    final bool isDone = (data?['isDone'] as bool?) ?? false;
                    final String title = data?['title']?.toString() ?? 'Untitled Task';
                    final String priority = data?['priority']?.toString() ?? 'low';
                    
                    DateTime? dueDate;
                    if (data != null && data['dueDate'] is Timestamp) {
                      dueDate = (data['dueDate'] as Timestamp).toDate();
                    }

                    return Card(
                      elevation: 2,
                      shadowColor: Colors.black12,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _showTaskDialog(
                          taskId: task.id, 
                          currentTitle: title, 
                          currentPriority: priority,
                          currentDueDate: dueDate,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              Checkbox(
                                value: isDone,
                                activeColor: Colors.blueAccent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                onChanged: (value) {
                                  if (value != null) {
                                    _taskService.toggleTask(task.id, value);
                                  }
                                },
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: isDone ? FontWeight.normal : FontWeight.w600,
                                        decoration: isDone ? TextDecoration.lineThrough : TextDecoration.none,
                                        color: isDone ? Colors.grey : Colors.black87,
                                      ),
                                    ),
                                    if (dueDate != null) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.calendar_today, size: 12, color: isDone ? Colors.grey : Colors.blueGrey),
                                          const SizedBox(width: 4),
                                          Text(
                                            _formatDate(dueDate),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDone ? Colors.grey : Colors.blueGrey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: _getPriorityColor(priority),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          priority.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: _getPriorityColor(priority),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent),
                                onPressed: () => _showTaskDialog(
                                  taskId: task.id, 
                                  currentTitle: title, 
                                  currentPriority: priority,
                                  currentDueDate: dueDate,
                                ),
                                tooltip: 'Edit task',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                onPressed: () => _taskService.deleteTask(task.id),
                                tooltip: 'Delete task',
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTaskDialog(),
        backgroundColor: Colors.blueAccent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add Task", style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.task_alt, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(fontSize: 18, color: Colors.grey[500]),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}