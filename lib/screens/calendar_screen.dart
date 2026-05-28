import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/task_service.dart';
import '../services/productivity_engine.dart';
import '../models/productivity_daily_data.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final TaskService _taskService = TaskService();
  final ProductivityEngine _productivityEngine = ProductivityEngine();
  
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime(_focusedDay.year, _focusedDay.month, _focusedDay.day);
  }

  /// Helper to check if two days are the same
  bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Calculates the 42 days grid for the focused month (starting on Monday)
  List<DateTime> _getDaysInMonthGrid(DateTime month) {
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    
    // In Dart, weekday goes from 1 (Monday) to 7 (Sunday).
    // To start the grid on Monday, we find how many days of the previous month to pad.
    // If firstDay is Monday (1), padCount is 0.
    // If firstDay is Tuesday (2), padCount is 1, etc.
    int padCount = firstDayOfMonth.weekday - 1;
    
    // Calculate the start date of our 42-day calendar grid
    final startDate = firstDayOfMonth.subtract(Duration(days: padCount));
    
    return List.generate(42, (index) => startDate.add(Duration(days: index)));
  }

  /// Filters a Firestore list of tasks to only those scheduled on a specific day
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

  /// Returns a Color based on the productivity status (soft pastel colors)
  Color _getProductivityColorByStatus(String status, bool isDark) {
    switch (status.toLowerCase()) {
      case 'excellent':
        return isDark ? const Color(0xFF2A3B5C) : const Color(0xFFDDE7FF);
      case 'productive':
        return isDark ? const Color(0xFF1B4021) : const Color(0xFFDDF6E5);
      case 'average':
        return isDark ? const Color(0xFF55441B) : const Color(0xFFFFF4CC);
      case 'low':
      case 'poor':
        return isDark ? const Color(0xFF5C2626) : const Color(0xFFFFE0E0);
      default:
        return isDark ? Colors.white.withOpacity(0.01) : Colors.transparent;
    }
  }

  /// Returns a complementary dark/light high-contrast text color based on the status
  Color _getProductivityTextColorByStatus(String status, bool isDark) {
    if (isDark) {
      switch (status.toLowerCase()) {
        case 'excellent':
          return const Color(0xFFADC6FF);
        case 'productive':
          return const Color(0xFF81C784);
        case 'average':
          return const Color(0xFFFFD54F);
        case 'low':
        case 'poor':
          return const Color(0xFFE57373);
        default:
          return Colors.white70;
      }
    } else {
      switch (status.toLowerCase()) {
        case 'excellent':
          return const Color(0xFF1E40AF); // premium Notion slate blue
        case 'productive':
          return const Color(0xFF065F46); // premium Forest emerald green
        case 'average':
          return const Color(0xFF854D0E); // premium Golden brown
        case 'low':
        case 'poor':
          return const Color(0xFF991B1B); // premium crimson red
        default:
          return const Color(0xFF6B7280); // Notion style gray
      }
    }
  }

  /// Listens to real-time productivity data stream for the current month
  Stream<Map<String, ProductivityDailyData>> _getMonthlyProductivityStream(DateTime month) {
    final userId = _productivityEngine.userId;
    if (userId == null) return const Stream.empty();
    
    final startStr = "${month.year}-${month.month.toString().padLeft(2, '0')}-01";
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    final endStr = "${month.year}-${month.month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}";
    
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('productivity_data')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: startStr)
        .where(FieldPath.documentId, isLessThanOrEqualTo: endStr)
        .snapshots()
        .map((snapshot) {
          return {
            for (var doc in snapshot.docs)
              doc.id: ProductivityDailyData.fromMap(doc.data())
          };
        });
  }

  /// Opens the custom premium Month & Year Picker Bottom Sheet
  void _showMonthPickerSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    spreadRadius: 5,
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pull bar
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  
                  // Year Selector Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(Icons.chevron_left, color: isDark ? Colors.white70 : Colors.black87),
                        onPressed: () {
                          setModalState(() {
                            _focusedDay = DateTime(_focusedDay.year - 1, _focusedDay.month, 1);
                          });
                          setState(() {});
                        },
                      ),
                      Text(
                        '${_focusedDay.year}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                          letterSpacing: 0.5,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.chevron_right, color: isDark ? Colors.white70 : Colors.black87),
                        onPressed: () {
                          setModalState(() {
                            _focusedDay = DateTime(_focusedDay.year + 1, _focusedDay.month, 1);
                          });
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Months Grid (3x4)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 2.2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      final monthNum = index + 1;
                      final monthAbbr = DateFormat('MMM').format(DateTime(_focusedDay.year, monthNum, 1));
                      final isSelected = _focusedDay.month == monthNum;
                      
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _focusedDay = DateTime(_focusedDay.year, monthNum, 1);
                            _selectedDay = DateTime(_focusedDay.year, monthNum, 1);
                          });
                          Navigator.pop(context);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).primaryColor
                                : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03)),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected 
                                  ? Colors.transparent 
                                  : (isDark ? Colors.white10 : Colors.black12),
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            monthAbbr,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? Colors.white.withOpacity(0.9) : Colors.black87),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  /// Builds a single day cell inside the custom grid, applying horizontal connection logic
  Widget _buildDayCell(
    BuildContext context, 
    DateTime day, 
    int cellIndexInWeek, 
    List<DateTime> weekDays, 
    Map<String, ProductivityDailyData> dataMap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCurrentMonth = day.month == _focusedDay.month;
    
    // Faded render for outside months
    if (!isCurrentMonth) {
      return Expanded(
        child: Container(
          height: isDark ? 48 : 50,
          alignment: Alignment.center,
          child: Text(
            '${day.day.toString().padLeft(2, '0')}',
            style: TextStyle(
              color: isDark ? Colors.white10 : const Color(0xFFD1D5DB),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      );
    }
    
    final dateStr = "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
    final data = dataMap[dateStr];
    final dayType = data?.dayType ?? 'empty';
    final isSelected = isSameDay(_selectedDay, day);
    final isToday = isSameDay(DateTime.now(), day);
    
    // Connection Group classification
    String getGroup(DateTime targetDay) {
      if (targetDay.month != _focusedDay.month) return 'empty';
      final targetStr = "${targetDay.year}-${targetDay.month.toString().padLeft(2, '0')}-${targetDay.day.toString().padLeft(2, '0')}";
      final targetData = dataMap[targetStr];
      if (targetData == null) return 'empty';
      
      final type = targetData.dayType.toLowerCase();
      if (type == 'empty') return 'empty';
      return type;
    }
    
    final currentGroup = getGroup(day);
    bool hasLeftConnection = false;
    bool hasRightConnection = false;
    
    if (currentGroup != 'empty') {
      hasLeftConnection = cellIndexInWeek > 0 && getGroup(weekDays[cellIndexInWeek - 1]) == currentGroup;
      hasRightConnection = cellIndexInWeek < 6 && getGroup(weekDays[cellIndexInWeek + 1]) == currentGroup;
    }
    
    // Dynamic color calculation based on status instead of scores
    Color bgColor;
    Color textColor;
    
    if (data != null && dayType != 'empty') {
      bgColor = _getProductivityColorByStatus(dayType, isDark);
      textColor = _getProductivityTextColorByStatus(dayType, isDark);
    } else {
      bgColor = Colors.transparent;
      textColor = isDark ? Colors.white38 : const Color(0xFF6B7280);
    }
    
    // Selected Day overriding text color
    if (isSelected && !isDark) {
      textColor = const Color(0xFF2563EB);
    }
    
    // Custom margin and border radius for connected pills (999 for elegant pill endpoints)
    final double leftMargin = hasLeftConnection ? 0.0 : 4.0;
    final double rightMargin = hasRightConnection ? 0.0 : 4.0;
    
    BorderRadius borderRadius;
    if (hasLeftConnection && hasRightConnection) {
      borderRadius = BorderRadius.zero;
    } else if (hasLeftConnection && !hasRightConnection) {
      borderRadius = const BorderRadius.horizontal(right: Radius.circular(999));
    } else if (!hasLeftConnection && hasRightConnection) {
      borderRadius = const BorderRadius.horizontal(left: Radius.circular(999));
    } else {
      borderRadius = BorderRadius.circular(999);
    }
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedDay = day;
          });
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: isDark ? 48 : 50, // Slightly taller cell in light mode for airiness
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background Shape
              Positioned.fill(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeInOut,
                  margin: EdgeInsets.only(
                    left: leftMargin,
                    right: rightMargin,
                    top: isDark ? 4 : 3, // slightly thicker/taller pills in light mode
                    bottom: isDark ? 4 : 3,
                  ),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: borderRadius,
                  ),
                ),
              ),
              
              // Selection highlight ring (thin outline ring for dark, elegant custom blue indicator for light)
              if (isSelected)
                Center(
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark 
                          ? Colors.transparent 
                          : (dayType == 'empty' ? const Color(0xFF2563EB).withOpacity(0.08) : Colors.transparent),
                      border: Border.all(
                        color: isDark ? Theme.of(context).primaryColor : const Color(0xFF2563EB),
                        width: isDark ? 1.5 : 2.0,
                      ),
                    ),
                  ),
                ),
              
              // Today indicator dot
              if (isToday && !isSelected)
                Positioned(
                  bottom: 7,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              
              // Day Number Text padded to two-digits (Centered perfectly inside stack)
              Center(
                child: Text(
                  '${day.day.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: isSelected || isToday
                        ? FontWeight.w700
                        : (isDark ? FontWeight.w600 : FontWeight.w500), // lighter premium typography in light mode
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a single dashboard metric card
  /// Redesigned premium Details Card for the selected date
  Widget _buildDayDetailsCard(ProductivityDailyData? data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedStr = DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay ?? _focusedDay);
    
    if (data == null || data.dayType == 'empty') {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E24) : Colors.white,
          borderRadius: BorderRadius.circular(isDark ? 24 : 32), // Premium 30+ radius in light mode
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.15 : 0.05), // opacity 0.05-0.08
              blurRadius: isDark ? 16 : 24, // blur 18-25
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selectedStr,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            const SizedBox(height: 20),
            Icon(Icons.calendar_view_month, size: 44, color: isDark ? Colors.white24 : Colors.black12),
            const SizedBox(height: 12),
            const Text(
              "No Productivity Records",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              "No logs tracked for this day yet. Fill your tasks, habits, or focus mode to map productivity scores automatically!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : Colors.black45,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    Color scoreColor = _getProductivityColorByStatus(data.dayType, isDark);
    Color textColor = _getProductivityTextColorByStatus(data.dayType, isDark);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E24) : Colors.white,
        borderRadius: BorderRadius.circular(isDark ? 24 : 32), // Premium 30+ radius in light mode
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.05), // opacity 0.05-0.08
            blurRadius: isDark ? 16 : 24, // blur 18-25
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header: Date & Streak Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedStr,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Daily Productivity Summary",
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
              if (data.streakGroup.isNotEmpty && data.streakGroup != "0 days")
                Container(
                  padding: EdgeInsets.symmetric(horizontal: isDark ? 12 : 10, vertical: isDark ? 5 : 4),
                  decoration: BoxDecoration(
                    color: isDark ? scoreColor.withOpacity(0.25) : scoreColor.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(20), // smaller cleaner badge pill
                  ),
                  child: Text(
                    "🔥 ${data.streakGroup}",
                    style: TextStyle(
                      color: textColor,
                      fontSize: isDark ? 11 : 10, // cleaner text layout
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          
          SizedBox(height: isDark ? 20 : 24), // more breathing space
          
          // Productivity Score Circular Gauge & Metric row
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                margin: const EdgeInsets.only(right: 16),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: data.productivityScore / 100,
                      strokeWidth: 5,
                      backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                      valueColor: AlwaysStoppedAnimation<Color>(textColor),
                    ),
                    Text(
                      "${data.productivityScore.round()}%",
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Status: ${data.dayType.toUpperCase()}",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Calculated from habits, goals, task ratios, and completed focus sessions today.",
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black45,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
          
          SizedBox(height: isDark ? 20 : 24),
          
          // Dashboard Grid (2x3) - Clean, highly responsive card tiles to prevent RenderFlex overflows
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 2.8,
            crossAxisSpacing: isDark ? 10 : 12, // airy spacing in light mode
            mainAxisSpacing: isDark ? 10 : 12,
            children: [
              _buildMetricTile("Tasks Done", "${data.tasksCompleted} / ${data.tasksTotal}", Icons.check_circle_outline, Colors.blue),
              _buildMetricTile("Habits Kept", "${data.habitsCompleted} / ${data.habitsTotal}", Icons.repeat, Colors.green),
              _buildMetricTile("Goals Achieved", "${data.goalsCompleted} / ${data.goalsTotal}", Icons.emoji_events_outlined, Colors.orange),
              _buildMetricTile("Focus Sessions", "${data.focusSessions}", Icons.timer_outlined, Colors.purple),
              _buildMetricTile("Focus Minutes", "${data.focusMinutes}m", Icons.av_timer, Colors.deepPurple),
              _buildMetricTile("Success Rate", "${data.successRate.round()}%", Icons.trending_up, Colors.teal),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds a single premium responsive dashboard metric tile
  Widget _buildMetricTile(String label, String value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.white, // Elevated card tiles in light mode
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFF1F5F9), // Notion/Linear style clean border
          width: 1,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    color: isDark ? Colors.white30 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Days of the week abbreviations starting from Monday
    final List<String> dowList = ["M", "T", "W", "T", "F", "S", "S"];
    
    // Generate standard 42 days grid
    final gridDays = _getDaysInMonthGrid(_focusedDay);
    
    // Chop 42 grid days into 6 weeks of 7 days
    final List<List<DateTime>> weeks = List.generate(6, (weekIndex) {
      return List.generate(7, (dayIndex) {
        return gridDays[weekIndex * 7 + dayIndex];
      });
    });

    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF5F6FA), // LAYERED SURFACES background #F5F6FA
      body: SafeArea(
        child: StreamBuilder<Map<String, ProductivityDailyData>>(
          stream: _getMonthlyProductivityStream(_focusedDay),
          builder: (context, productivitySnapshot) {
            final dataMap = productivitySnapshot.data ?? {};
            
            final activeSelectedDay = _selectedDay ?? _focusedDay;
            final selectedStr = "${activeSelectedDay.year}-${activeSelectedDay.month.toString().padLeft(2, '0')}-${activeSelectedDay.day.toString().padLeft(2, '0')}";
            final selectedData = dataMap[selectedStr];

            return Column(
              children: [
                // 1. PREMIUM HEADER
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Circular Back Button
                      GestureDetector(
                        onTap: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            Navigator.maybePop(context);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new,
                            size: 15,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                      
                      // Selected Date text
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        child: Text(
                          DateFormat('EEEE, MMM d').format(activeSelectedDay),
                          key: ValueKey(activeSelectedDay),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      
                      // Month & Year Picker Dropdown Button
                      GestureDetector(
                        onTap: () => _showMonthPickerSheet(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                  Icons.calendar_today_rounded,
                                  size: 14,
                                  color: Theme.of(context).primaryColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  DateFormat('MMM yyyy').format(_focusedDay),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.keyboard_arrow_down,
                                  size: 14,
                                  color: isDark ? Colors.white54 : Colors.black54,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
  
                  
                  // 2. DAY-OF-WEEK HEADER
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4), // adjusted bottom padding
                    child: Row(
                      children: dowList.map((dow) {
                        return Expanded(
                          child: Center(
                            child: Text(
                              dow,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white30 : Colors.black38,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  
                  // 3. CUSTOM CALENDAR MONTH MAP (Sleek elevated white rounded container card)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: isDark ? 8 : 12), // elevated spacing
                    child: Container(
                      padding: isDark ? const EdgeInsets.all(12) : const EdgeInsets.all(20), // airy inside margins
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E24) : Colors.white, // elevated card feel
                        borderRadius: BorderRadius.circular(isDark ? 24 : 32),
                        boxShadow: isDark
                            ? []
                            : [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06), // opacity 0.05-0.08
                                  blurRadius: 20, // blur 18-25
                                  offset: const Offset(0, 8),
                                ),
                              ],
                      ),
                      child: Column(
                        children: List.generate(weeks.length, (index) {
                          final week = weeks[index];
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: isDark ? 0 : 2), // vertical airy margins
                            child: Row(
                              children: List.generate(7, (d) {
                                return _buildDayCell(context, week[d], d, week, dataMap);
                              }),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  
                  // 4. DAY PRODUCTIVITY DETAILS CARD & TASKS LIST
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                        _buildDayDetailsCard(selectedData),
                        
                        // Database Empty State Tip
                        if (dataMap.isEmpty)
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Theme.of(context).primaryColor.withOpacity(0.15),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.auto_awesome, color: Theme.of(context).primaryColor, size: 20),
                                    const SizedBox(width: 10),
                                    const Expanded(
                                      child: Text(
                                        "Experience the visual map!",
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  "No records found for this month in Firestore. Complete daily tasks, check off habits, and log focus sessions to automatically map your productivity!",
                                  style: TextStyle(fontSize: 11, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        
                        // Tasks lists for the selected day (live & reactive!)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Tasks Scheduled",
                              style: TextStyle(
                                fontSize: 16, 
                                fontWeight: FontWeight.bold, 
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                        
                        StreamBuilder<QuerySnapshot>(
                          stream: _taskService.getTasks(),
                          builder: (context, taskSnapshot) {
                            if (taskSnapshot.connectionState == ConnectionState.waiting) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                              );
                            }
                            
                            final allTasks = taskSnapshot.data?.docs ?? [];
                            final selectedTasks = _getEventsForDay(activeSelectedDay, allTasks);
                            
                            if (selectedTasks.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(32),
                                alignment: Alignment.center,
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.event_note, 
                                      size: 32, 
                                      color: isDark ? Colors.white10 : Colors.black12,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "No tasks scheduled on this day.",
                                      style: TextStyle(
                                        fontSize: 12, 
                                        color: isDark ? Colors.white38 : Colors.black38,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                              itemCount: selectedTasks.length,
                              itemBuilder: (context, index) {
                                final task = selectedTasks[index];
                                final data = task.data() as Map<String, dynamic>?;
                                final title = data?['title']?.toString() ?? 'Untitled';
                                final isDone = (data?['isDone'] as bool?) ?? false;

                                return Card(
                                  elevation: 0,
                                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                  margin: const EdgeInsets.only(bottom: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                                    ),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                                    leading: GestureDetector(
                                      onTap: () {
                                        _taskService.toggleTask(task.id, !isDone);
                                        // Trigger a local productivity score recalculation if today
                                        if (isSameDay(DateTime.now(), activeSelectedDay)) {
                                          _productivityEngine.generateAndSaveTodaySnapshot();
                                        }
                                      },
                                      child: Icon(
                                        isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                                        color: isDone 
                                            ? Theme.of(context).primaryColor 
                                            : Theme.of(context).primaryColor.withOpacity(0.5),
                                        size: 22,
                                      ),
                                    ),
                                    title: Text(
                                      title,
                                      style: TextStyle(
                                        decoration: isDone ? TextDecoration.lineThrough : null,
                                        color: isDone 
                                            ? (isDark ? Colors.white30 : Colors.grey) 
                                            : (isDark ? Colors.white.withOpacity(0.9) : Colors.black87),
                                        fontSize: 14,
                                        fontWeight: isDone ? FontWeight.normal : FontWeight.w600,
                                      ),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                      onPressed: () {
                                        _taskService.deleteTask(task.id);
                                        // Recalculate today's score if deleted today's task
                                        if (isSameDay(DateTime.now(), activeSelectedDay)) {
                                          _productivityEngine.generateAndSaveTodaySnapshot();
                                        }
                                      },
                                    ),
                                  ),
                                );
                              },
                            );
                          },
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
