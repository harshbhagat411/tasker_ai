import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/task_service.dart';

import 'package:intl/intl.dart';

class DiagonalStripePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  DiagonalStripePainter({required this.color, this.strokeWidth = 1.5});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..isAntiAlias = true;

    for (double i = -size.height; i < size.width; i += 6) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final TaskService _taskService = TaskService();
  
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  List<QueryDocumentSnapshot> _getEventsForDay(DateTime day, List<QueryDocumentSnapshot> allTasks) {
    return allTasks.where((task) {
      final data = task.data() as Map<String, dynamic>?;
      if (data != null && data['dueDate'] is Timestamp) {
        final taskDate = (data['dueDate'] as Timestamp).toDate();
        return isSameDay(taskDate, day);
      }
      return false;
    }).toList();
  }

  bool _isPast(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return day.isBefore(today);
  }

  Widget _buildCell(DateTime day, {bool isOutside = false, bool isSelected = false, bool isToday = false}) {
    final isWeekend = day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
    final isPastDay = _isPast(day);
    
    final cellColor = isSelected ? const Color(0xFF0D47A1) : (isToday ? const Color(0xFFE0F2F1) : const Color(0xFFD6DFE8)); 
    final stripeColor = Colors.grey.withOpacity(0.2);
    final borderColor = Colors.transparent;

    Widget dayNumberText = Padding(
      padding: const EdgeInsets.all(4.0),
      child: Align(
        alignment: Alignment.topCenter,
        child: Text('${day.day}', style: TextStyle(color: isSelected ? Colors.white : ((isPastDay || isOutside) ? Colors.grey[400] : Colors.black87), fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );

    Widget innerContent;

    if (isPastDay || isOutside) {
      innerContent = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CustomPaint(
          painter: DiagonalStripePainter(color: stripeColor),
          child: dayNumberText,
        ),
      );
    } else if (isWeekend) {
      innerContent = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Expanded(
              child: Container(
                color: cellColor,
                child: dayNumberText,
              ),
            ),
            Expanded(
              child: Container(
                color: Colors.white,
                child: CustomPaint(
                  painter: DiagonalStripePainter(color: stripeColor),
                  child: Container(),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      innerContent = Container(
        decoration: BoxDecoration(
          color: cellColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: dayNumberText,
      );
    }

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: innerContent,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F1ED), // Light warm beige from the image
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: _taskService.getTasks(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text("Error loading tasks"));
            }

            final allTasks = snapshot.data?.docs ?? [];
            final selectedTasks = _getEventsForDay(_selectedDay ?? _focusedDay, allTasks);

            return Column(
              children: [
                // Custom Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(fontSize: 34, height: 1.1, letterSpacing: -0.5),
                          children: [
                            TextSpan(text: "Track Your\n", style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black)),
                            TextSpan(text: "Schedule", style: TextStyle(fontWeight: FontWeight.w400, color: Colors.black45)),
                          ]
                        )
                      ),
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _focusedDay,
                            firstDate: DateTime.utc(2000, 1, 1),
                            lastDate: DateTime.utc(2100, 12, 31),
                            initialDatePickerMode: DatePickerMode.year,
                          );
                          if (picked != null) {
                            setState(() {
                              _focusedDay = picked;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black12),
                            borderRadius: BorderRadius.circular(24),
                            color: Colors.white.withOpacity(0.5),
                          ),
                          child: Row(
                            children: [
                              Text(DateFormat('MMM, yyyy').format(_focusedDay), style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
                              const SizedBox(width: 6),
                              const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.black45),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Calendar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: TableCalendar(
                    firstDay: DateTime.utc(2000, 1, 1),
                    lastDay: DateTime.utc(2100, 12, 31),
                    focusedDay: _focusedDay,
                    rowHeight: 65,
                    daysOfWeekHeight: 40,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    onPageChanged: (focusedDay) {
                      setState(() => _focusedDay = focusedDay);
                    },
                    eventLoader: (day) => _getEventsForDay(day, allTasks),
                    headerVisible: false, // We built our own header
                    calendarBuilders: CalendarBuilders(
                      defaultBuilder: (context, day, focusedDay) => _buildCell(day),
                      outsideBuilder: (context, day, focusedDay) => _buildCell(day, isOutside: true),
                      todayBuilder: (context, day, focusedDay) => _buildCell(day, isToday: true),
                      selectedBuilder: (context, day, focusedDay) => _buildCell(day, isSelected: true),
                      markerBuilder: (context, day, events) {
                        if (events.isNotEmpty) {
                          return Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF0D47A1),
                                shape: BoxShape.circle,
                              ),
                            ),
                          );
                        }
                        return null;
                      },
                      dowBuilder: (context, day) {
                        final text = DateFormat.E().format(day);
                        final isWeekend = day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
                        return Center(
                          child: Text(
                            text,
                            style: TextStyle(
                              color: isWeekend ? Colors.amber.shade600 : Colors.black45,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Tasks for the selected day
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                          child: Text(
                            _selectedDay != null ? DateFormat('EEEE, MMMM d').format(_selectedDay!) : "Tasks",
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ),
                        Expanded(
                          child: selectedTasks.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.event_busy, size: 48, color: Colors.grey.shade300),
                                      const SizedBox(height: 12),
                                      Text("No tasks scheduled", style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  itemCount: selectedTasks.length,
                                  itemBuilder: (context, index) {
                                    final task = selectedTasks[index];
                                    final data = task.data() as Map<String, dynamic>?;
                                    final title = data?['title']?.toString() ?? 'Untitled';
                                    final isDone = (data?['isDone'] as bool?) ?? false;

                                    return Card(
                                      elevation: 0,
                                      color: const Color(0xFFF8F9FA),
                                      margin: const EdgeInsets.only(bottom: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide(color: Colors.grey.shade200),
                                      ),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                        leading: Icon(
                                          isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                                          color: isDone ? const Color(0xFF0D47A1) : const Color(0xFF0D47A1).withOpacity(0.5),
                                        ),
                                        title: Text(
                                          title,
                                          style: TextStyle(
                                            decoration: isDone ? TextDecoration.lineThrough : null,
                                            color: isDone ? Colors.grey : Colors.black87,
                                            fontWeight: isDone ? FontWeight.normal : FontWeight.w600,
                                          ),
                                        ),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                          onPressed: () => _taskService.deleteTask(task.id),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
