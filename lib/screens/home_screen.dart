import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/task_service.dart';
import '../services/auth_service.dart';

enum SortType {
  priority,
  createdDate,
  dueDate,
}

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
  SortType _selectedSortType = SortType.createdDate;
  bool _isAscending = false;

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
                        fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2A2A2A) : Colors.grey[100],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                        padding: EdgeInsets.only(left: 4.0, bottom: 8.0),
                        child: Text("Priority", style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyMedium?.color)),
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
                            selectedColor: const Color(0xFF0D47A1),
                            backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2A2A2A) : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(color: isSelected ? const Color(0xFF0D47A1) : Colors.grey[300]!),
                            ),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
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
                    backgroundColor: const Color(0xFF0D47A1),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final title = _taskController.text.trim();
                    if (title.isEmpty) return;

                    if (taskId == null) {
                      await _taskService.addTask(title, priority: _selectedPriority, dueDate: tempDate);
                    } else {
                      await _taskService.updateTask(taskId, title, priority: _selectedPriority, dueDate: tempDate);
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

  Color _getPriorityBackgroundColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.orange.shade200; // Yellow/Orange
      case 'medium':
        return Colors.blue.shade100; // Blue
      case 'low':
      default:
        return Colors.green.shade100; // Green
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? "User";
    final displayName = email.split('@').first;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : "?";

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SECTION 1: Header
                StreamBuilder<DocumentSnapshot>(
                  stream: user != null ? FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots() : null,
                  builder: (context, snapshot) {
                    String displayStr = email.split('@').first;
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data = snapshot.data!.data() as Map<String, dynamic>?;
                      displayStr = data?['displayName']?.toString() ?? data?['name']?.toString() ?? displayStr;
                    }
                    final currentInitial = displayStr.isNotEmpty ? displayStr[0].toUpperCase() : "?";

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: const Color(0xFF0D47A1),
                              child: Text(currentInitial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Hey 👋", style: TextStyle(color: Colors.grey, fontSize: 14)),
                                Text(displayStr, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(context).textTheme.bodyLarge?.color)),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => setState(() => _isAscending = !_isAscending),
                              icon: Icon(_isAscending ? Icons.arrow_upward : Icons.arrow_downward, color: Theme.of(context).textTheme.bodyLarge?.color),
                              tooltip: _isAscending ? 'Ascending' : 'Descending',
                            ),
                            PopupMenuButton<SortType>(
                              icon: Icon(Icons.sort, color: Theme.of(context).textTheme.bodyLarge?.color),
                              tooltip: 'Sort by',
                              onSelected: (option) => setState(() => _selectedSortType = option),
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: SortType.priority, child: Text('Priority')),
                                const PopupMenuItem(value: SortType.createdDate, child: Text('Created Date')),
                                const PopupMenuItem(value: SortType.dueDate, child: Text('Due Date')),
                              ],
                            ),
                          ],
                        )
                      ],
                    );
                  }
                ),
                const SizedBox(height: 30),

                // SECTION 2: Title
                Text("Tasker", style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                Text("Manage your tasks", style: TextStyle(fontSize: 16, color: Theme.of(context).textTheme.bodyMedium?.color)),
                const SizedBox(height: 24),

                // SECTION 3: Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search tasks...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(left: 12.0, right: 8.0),
                        child: Icon(Icons.search, color: Color(0xFF0D47A1)),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // SECTION 4: Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Today', 'Completed'].map((filter) {
                      final isSelected = _filter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: ChoiceChip(
                          label: Text(filter),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) setState(() => _filter = filter);
                          },
                          selectedColor: const Color(0xFF0D47A1),
                          backgroundColor: Theme.of(context).cardColor,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: isSelected ? const Color(0xFF0D47A1) : Colors.grey[300]!),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),

                // Task Stream
                StreamBuilder<QuerySnapshot>(
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

                    // Base tasks applied with global Search filter
                    var baseTasks = snapshot.data!.docs.where((task) {
                      final data = task.data() as Map<String, dynamic>?;
                      final String title = data?['title']?.toString() ?? '';
                      if (_searchQuery.isNotEmpty && !title.toLowerCase().contains(_searchQuery.toLowerCase())) {
                        return false;
                      }
                      return true;
                    }).toList();

                    // Apply Sorting logic to baseTasks
                    baseTasks.sort((a, b) {
                      final dataA = a.data() as Map<String, dynamic>?;
                      final dataB = b.data() as Map<String, dynamic>?;

                      switch (_selectedSortType) {
                        case SortType.priority:
                          final pA = dataA?['priority']?.toString() ?? 'low';
                          final pB = dataB?['priority']?.toString() ?? 'low';
                          
                          int valA = pA == 'high' ? 3 : (pA == 'medium' ? 2 : 1);
                          int valB = pB == 'high' ? 3 : (pB == 'medium' ? 2 : 1);
                          
                          int cmp = _isAscending ? valA.compareTo(valB) : valB.compareTo(valA);
                          
                          if (cmp == 0) {
                            final tA = dataA?['createdAt'] as Timestamp?;
                            final tB = dataB?['createdAt'] as Timestamp?;
                            if (tA == null && tB == null) return 0;
                            if (tA == null) return 1;
                            if (tB == null) return -1;
                            return tB.compareTo(tA);
                          }
                          return cmp;
                              
                        case SortType.createdDate:
                          final tA = dataA?['createdAt'] as Timestamp?;
                          final tB = dataB?['createdAt'] as Timestamp?;
                          
                          if (tA == null && tB == null) return 0;
                          if (tA == null) return 1;
                          if (tB == null) return -1;
                          
                          return _isAscending ? tA.compareTo(tB) : tB.compareTo(tA);
                              
                        case SortType.dueDate:
                          final dA = dataA?['dueDate'] as Timestamp?;
                          final dB = dataB?['dueDate'] as Timestamp?;
                          
                          if (dA == null && dB == null) return 0;
                          if (dA == null) return 1;
                          if (dB == null) return -1;
                          
                          return _isAscending ? dA.compareTo(dB) : dB.compareTo(dB);
                      }
                    });

                    // Derive Horizontal Tasks (High Priority or Today, not completed)
                    var horizontalTasks = baseTasks.where((task) {
                       final data = task.data() as Map<String, dynamic>?;
                       final String priority = data?['priority']?.toString() ?? 'low';
                       final bool isDone = (data?['isDone'] as bool?) ?? false;
                       if (isDone) return false;
                       
                       DateTime? dueDate;
                       if (data != null && data['dueDate'] is Timestamp) {
                         dueDate = (data['dueDate'] as Timestamp).toDate();
                       }
                       
                       bool isToday = false;
                       if (dueDate != null) {
                         final now = DateTime.now();
                         if (dueDate.year == now.year && dueDate.month == now.month && dueDate.day == now.day) {
                           isToday = true;
                         }
                       }
                       
                       return priority == 'high' || isToday;
                    }).toList();

                    // Derive Vertical Tasks based on Filter
                    var verticalTasks = baseTasks.where((task) {
                      final data = task.data() as Map<String, dynamic>?;
                      final bool isDone = (data?['isDone'] as bool?) ?? false;
                      
                      DateTime? dueDate;
                      if (data != null && data['dueDate'] is Timestamp) {
                        dueDate = (data['dueDate'] as Timestamp).toDate();
                      }

                      if (_filter == 'Completed' && !isDone) return false;
                      if (_filter == 'All' && isDone) return false; // Show pending mostly in All
                      if (_filter == 'Today') {
                         if (dueDate == null) return false;
                         final now = DateTime.now();
                         if (dueDate.year != now.year || dueDate.month != now.month || dueDate.day != now.day) return false;
                      }

                      return true;
                    }).toList();
                    
                    // If filter is all, we just show all pending
                    if (_filter == 'All') {
                      verticalTasks = baseTasks.where((task) => !((task.data() as Map<String, dynamic>?)?['isDone'] ?? false)).toList();
                    }

                    if (horizontalTasks.isEmpty && verticalTasks.isEmpty) {
                      return _buildEmptyState("No matching tasks", "Try changing filters");
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // SECTION 5: Horizontal Task Cards
                        if (horizontalTasks.isNotEmpty && _filter != 'Completed') ...[
                          Text("Priority & Today", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 160,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: horizontalTasks.length,
                              itemBuilder: (context, index) {
                                final task = horizontalTasks[index];
                                final data = task.data() as Map<String, dynamic>?;
                                final String title = data?['title']?.toString() ?? 'Untitled Task';
                                final String priority = data?['priority']?.toString() ?? 'low';
                                
                                DateTime? dueDate;
                                if (data != null && data['dueDate'] is Timestamp) {
                                  dueDate = (data['dueDate'] as Timestamp).toDate();
                                }
                                
                                return Container(
                                  width: 240,
                                  margin: const EdgeInsets.only(right: 16, bottom: 8),
                                  decoration: BoxDecoration(
                                    color: _getPriorityBackgroundColor(priority),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black12, blurRadius: 12, offset: const Offset(0, 6)),
                                    ]
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    child: Padding(
                                      padding: const EdgeInsets.all(20.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withOpacity(0.6),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  priority.toUpperCase(), 
                                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)
                                                ),
                                              ),
                                              SizedBox(
                                                width: 24,
                                                height: 24,
                                                child: Stack(
                                                  fit: StackFit.expand,
                                                  children: [
                                                    CircularProgressIndicator(
                                                      value: 0.4, // placeholder for visual flair
                                                      strokeWidth: 3,
                                                      backgroundColor: Colors.white.withOpacity(0.5),
                                                      color: Colors.black87,
                                                    ),
                                                    const Center(
                                                      child: Icon(Icons.show_chart, size: 12, color: Colors.black87),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Expanded(
                                            child: Text(
                                              title,
                                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (dueDate != null) ...[
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                const Icon(Icons.access_time, size: 16, color: Colors.black54),
                                                const SizedBox(width: 6),
                                                Text(
                                                  _formatDate(dueDate), 
                                                  style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w600)
                                                ),
                                              ],
                                            )
                                          ]
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 30),
                        ],

                        // SECTION 6: "My Tasks" title
                        if (verticalTasks.isNotEmpty) ...[
                          Text("My Tasks", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                          const SizedBox(height: 16),

                          // SECTION 7: Vertical list
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: verticalTasks.length,
                            itemBuilder: (context, index) {
                              final task = verticalTasks[index];
                              final data = task.data() as Map<String, dynamic>?;
                              
                              final bool isDone = (data?['isDone'] as bool?) ?? false;
                              final String title = data?['title']?.toString() ?? 'Untitled Task';
                              final String priority = data?['priority']?.toString() ?? 'low';
                              
                              DateTime? dueDate;
                              if (data != null && data['dueDate'] is Timestamp) {
                                dueDate = (data['dueDate'] as Timestamp).toDate();
                              }

                              return Card(
                                elevation: 0,
                                color: Theme.of(context).cardColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                margin: const EdgeInsets.only(bottom: 12),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          value: isDone,
                                          activeColor: const Color(0xFF0D47A1),
                                          side: BorderSide(color: isDone ? Colors.transparent : (Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade500 : const Color(0xFF0D47A1).withOpacity(0.5)), width: 2),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(6),
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
                                                  color: isDone ? Colors.grey : Theme.of(context).textTheme.bodyLarge?.color,
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
                                          icon: const Icon(Icons.edit_outlined, color: Color(0xFF0D47A1)),
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
                          )
                        ]
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTaskDialog(),
        backgroundColor: const Color(0xFF0D47A1),
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
            style: TextStyle(fontSize: 18, color: Theme.of(context).textTheme.bodyMedium?.color),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodySmall?.color),
          ),
        ],
      ),
    );
  }
}
