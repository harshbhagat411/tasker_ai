import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../services/productivity_engine.dart';
import '../models/productivity_daily_data.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> with SingleTickerProviderStateMixin {
  final ProductivityEngine _productivityEngine = ProductivityEngine();
  
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<int, ProductivityDailyData> _monthData = {};
  bool _isLoading = false;
  
  // Animation Controller for smooth transitions
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime(_focusedDay.year, _focusedDay.month, _focusedDay.day);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadMonthData(_focusedDay);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadMonthData(DateTime month) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    
    try {
      final data = await _productivityEngine.getMonthlyProductivity(month);
      final Map<int, ProductivityDailyData> tempMap = {};
      for (var item in data) {
        tempMap[item.date.day] = item;
      }
      
      if (mounted) {
        setState(() {
          _monthData = tempMap;
          _isLoading = false;
        });
        _fadeController.forward(from: 0.0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      debugPrint("Error loading monthly productivity: $e");
    }
  }

  // Developer/Demo helper to seed fake calendar data
  Future<void> _seedSampleData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    setState(() => _isLoading = true);
    
    final random = Random();
    final today = DateTime.now();
    final isCurrentMonth = _focusedDay.month == today.month && _focusedDay.year == today.year;
    final daysToSeed = isCurrentMonth ? today.day : DateTime(_focusedDay.year, _focusedDay.month + 1, 0).day;
    
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    for (int d = 1; d <= daysToSeed; d++) {
      final date = DateTime(_focusedDay.year, _focusedDay.month, d);
      final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      
      // Bias towards excellent and good days to demonstrate streaks
      final rand = random.nextDouble();
      String type;
      double score;
      
      if (rand < 0.35) {
        type = 'excellent';
        score = 90.0 + random.nextInt(11);
      } else if (rand < 0.70) {
        type = 'good';
        score = 70.0 + random.nextInt(20);
      } else if (rand < 0.85) {
        type = 'average';
        score = 40.0 + random.nextInt(30);
      } else if (rand < 0.95) {
        type = 'poor';
        score = 15.0 + random.nextInt(25);
      } else {
        type = 'empty';
        score = 0.0;
      }

      final tasksTotal = 3 + random.nextInt(5);
      final tasksCompleted = type == 'excellent' 
          ? tasksTotal 
          : (type == 'good' ? tasksTotal - 1 : random.nextInt(tasksTotal + 1));
      
      final habitsTotal = 3 + random.nextInt(4);
      final habitsCompleted = type == 'excellent' 
          ? habitsTotal 
          : (type == 'good' ? habitsTotal - 1 : random.nextInt(habitsTotal + 1));
      
      final focusMinutes = type == 'excellent' 
          ? 60 + random.nextInt(60) 
          : (type == 'good' ? 40 + random.nextInt(20) : random.nextInt(30));
          
      final data = ProductivityDailyData(
        date: date,
        tasksCompleted: tasksCompleted,
        tasksTotal: tasksTotal,
        habitsCompleted: habitsCompleted,
        habitsTotal: habitsTotal,
        focusMinutes: focusMinutes,
        focusSessions: focusMinutes ~/ 25,
        productivityScore: score,
        successRate: 50.0 + random.nextInt(45),
        dayType: type,
        streakGroup: 'Seed',
      );

      final docRef = firestore
          .collection('users')
          .doc(user.uid)
          .collection('productivity_data')
          .doc(dateStr);
          
      batch.set(docRef, data.toMap());
    }

    await batch.commit();
    await _loadMonthData(_focusedDay);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Successfully seeded productivity data for ${DateFormat('MMMM yyyy').format(_focusedDay)}!"),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // Force calculate/save snapshot for today
  Future<void> _syncToday() async {
    setState(() => _isLoading = true);
    try {
      await _productivityEngine.generateAndSaveTodaySnapshot();
      await _loadMonthData(_focusedDay);
      if (mounted) {
        setState(() {
          final now = DateTime.now();
          _selectedDay = DateTime(now.year, now.month, now.day);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Today's productivity snapshot calculated and synced!"),
            backgroundColor: Colors.indigo,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to sync today: $e")),
        );
      }
    }
  }

  // Build grid data for custom calendar
  List<DateTime?> _buildGridDays(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final startOffset = firstDay.weekday == 7 ? 0 : firstDay.weekday; // Sunday is 0, Mon is 1, etc.
    
    final List<DateTime?> grid = [];
    
    // Add padded days before first day
    for (int i = 0; i < startOffset; i++) {
      grid.add(null);
    }
    
    // Add month days
    for (int d = 1; d <= daysInMonth; d++) {
      grid.add(DateTime(month.year, month.month, d));
    }
    
    // Pad end of month to form a perfect grid
    while (grid.length % 7 != 0) {
      grid.add(null);
    }
    
    return grid;
  }

  bool _isProductive(DateTime? date) {
    if (date == null) return false;
    final dayData = _monthData[date.day];
    if (dayData == null) return false;
    return dayData.dayType == 'excellent' || dayData.dayType == 'good';
  }

  // Color mapping based on rating
  Color _getDayColor(String type, bool isDark) {
    switch (type) {
      case 'excellent':
        return isDark ? const Color(0xFF283593) : const Color(0xFFDCE2FC);
      case 'good':
        return isDark ? const Color(0xFF1B5E20) : const Color(0xFFE2F4E6);
      case 'average':
        return isDark ? const Color(0xFFFBC02D).withOpacity(0.2) : const Color(0xFFFFF8D6);
      case 'poor':
        return isDark ? const Color(0xFFB71C1C).withOpacity(0.2) : const Color(0xFFFFE5E5);
      default:
        return Colors.transparent;
    }
  }

  Color _getDayTextColor(String type, bool isDark) {
    switch (type) {
      case 'excellent':
        return isDark ? const Color(0xFFC5CAE9) : const Color(0xFF3B59B6);
      case 'good':
        return isDark ? const Color(0xFFA5D6A7) : const Color(0xFF2E7D32);
      case 'average':
        return isDark ? const Color(0xFFFFF59D) : const Color(0xFFB78103);
      case 'poor':
        return isDark ? const Color(0xFFEF9A9A) : const Color(0xFFC62828);
      default:
        return isDark ? Colors.white60 : Colors.black87;
    }
  }

  void _showMonthPicker(BuildContext context) {
    int pickerYear = _focusedDay.year;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Container(
              height: MediaQuery.of(context).size.height * 0.48,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  )
                ]
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios, size: 18),
                          onPressed: () {
                            setModalState(() {
                              pickerYear--;
                            });
                          },
                        ),
                        Text(
                          "$pickerYear",
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_ios, size: 18),
                          onPressed: () {
                            setModalState(() {
                              pickerYear++;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 8),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 1.45,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: 12,
                      itemBuilder: (context, index) {
                        final monthName = DateFormat('MMMM').format(DateTime(2026, index + 1, 1));
                        final isSelected = _focusedDay.month == index + 1 && _focusedDay.year == pickerYear;
                        
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _focusedDay = DateTime(pickerYear, index + 1, 1);
                              // Keep selection in the same day if possible, or fall back to 1st
                              final targetDay = _selectedDay != null ? min(_selectedDay!.day, DateTime(pickerYear, index + 2, 0).day) : 1;
                              _selectedDay = DateTime(pickerYear, index + 1, targetDay);
                            });
                            _loadMonthData(_focusedDay);
                            Navigator.pop(context);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? Theme.of(context).primaryColor 
                                  : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F6FA)),
                              borderRadius: BorderRadius.circular(16),
                              border: isSelected 
                                  ? null 
                                  : Border.all(color: Colors.transparent),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              monthName.substring(0, 3).toUpperCase(),
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                  color: isSelected 
                                      ? Colors.white 
                                      : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gridDays = _buildGridDays(_focusedDay);
    final selectedDayData = _selectedDay != null ? _monthData[_selectedDay!.day] : null;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FD),
      body: SafeArea(
        child: Column(
          children: [
            // 1. PREMIUM HEADER
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Row(
                children: [
                  // Left: Circular Back Button
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF222222) : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 16),
                      color: isDark ? Colors.white.withOpacity(0.8) : Colors.black87,
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          // Try navigation or feedback
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Swipe to navigate to other screens or tabs!"),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  
                  // Center: Selected Date
                  Expanded(
                    child: Center(
                      child: Text(
                        _selectedDay == null
                            ? DateFormat('MMMM yyyy').format(_focusedDay)
                            : DateFormat('EEEE, MMM d').format(_selectedDay!),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                          color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  
                  // Right: Calendar/Month Picker Button
                  GestureDetector(
                    onTap: () => _showMonthPicker(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF222222) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            DateFormat('MMM yyyy').format(_focusedDay),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // 2. MAIN MAP CARD
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      // Weekday Headers
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((day) {
                            return Expanded(
                              child: Center(
                                child: Text(
                                  day,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white38 : Colors.black38,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      
                      // Monthly Custom Productivity Map (Grid)
                      _isLoading
                          ? SizedBox(
                              height: 280,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            )
                          : FadeTransition(
                              opacity: _fadeController,
                              child: GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 7,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 0, // 0 spacing for connected streaks
                                ),
                                itemCount: gridDays.length,
                                itemBuilder: (context, index) {
                                  final dayDate = gridDays[index];
                                  if (dayDate == null) {
                                    return const SizedBox.shrink();
                                  }
                                  
                                  final dayNum = dayDate.day;
                                  final dayData = _monthData[dayNum];
                                  final rating = dayData?.dayType ?? 'empty';
                                  final isSelected = _selectedDay != null &&
                                      _selectedDay!.day == dayNum &&
                                      _selectedDay!.month == dayDate.month &&
                                      _selectedDay!.year == dayDate.year;
                                      
                                  final isToday = dayDate.year == DateTime.now().year &&
                                      dayDate.month == DateTime.now().month &&
                                      dayDate.day == DateTime.now().day;
                                  
                                  // Streak calculations
                                  final col = index % 7;
                                  final connectsLeft = col > 0 && _isProductive(gridDays[index - 1]);
                                  final connectsRight = col < 6 && _isProductive(gridDays[index + 1]);
                                  final isThisProductive = _isProductive(dayDate);
                                  
                                  // Margins for connected shapes
                                  EdgeInsetsGeometry cellMargin;
                                  BorderRadiusGeometry cellBorderRadius;
                                  
                                  if (isThisProductive) {
                                    if (connectsLeft && connectsRight) {
                                      cellMargin = const EdgeInsets.symmetric(vertical: 4);
                                      cellBorderRadius = BorderRadius.zero;
                                    } else if (connectsLeft) {
                                      cellMargin = const EdgeInsets.only(top: 4, bottom: 4, right: 4);
                                      cellBorderRadius = const BorderRadius.only(
                                        topRight: Radius.circular(20),
                                        bottomRight: Radius.circular(20),
                                      );
                                    } else if (connectsRight) {
                                      cellMargin = const EdgeInsets.only(top: 4, bottom: 4, left: 4);
                                      cellBorderRadius = const BorderRadius.only(
                                        topLeft: Radius.circular(20),
                                        bottomLeft: Radius.circular(20),
                                      );
                                    } else {
                                      cellMargin = const EdgeInsets.all(4);
                                      cellBorderRadius = BorderRadius.circular(20);
                                    }
                                  } else {
                                    cellMargin = const EdgeInsets.all(4);
                                    cellBorderRadius = BorderRadius.circular(20);
                                  }
                                  
                                  final cellColor = _getDayColor(rating, isDark);
                                  final textColor = _getDayTextColor(rating, isDark);
                                  
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedDay = dayDate;
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 250),
                                      curve: Curves.easeInOut,
                                      margin: cellMargin,
                                      decoration: BoxDecoration(
                                        color: cellColor == Colors.transparent
                                            ? (isDark ? const Color(0xFF1E1E1E).withOpacity(0.4) : Colors.black.withOpacity(0.02))
                                            : cellColor,
                                        borderRadius: cellBorderRadius,
                                        border: Border.all(
                                          color: isSelected
                                              ? (isDark ? Colors.white : Theme.of(context).primaryColor)
                                              : (isToday
                                                  ? (isDark ? Colors.white30 : Colors.black26)
                                                  : Colors.transparent),
                                          width: isSelected ? 2 : 1,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: (isDark ? Colors.white : Theme.of(context).primaryColor).withOpacity(0.15),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                )
                                              ]
                                            : null,
                                      ),
                                      alignment: Alignment.center,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Text(
                                            "$dayNum",
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: isSelected || isToday ? FontWeight.w900 : FontWeight.bold,
                                              color: textColor,
                                            ),
                                          ),
                                          if (isToday)
                                            Positioned(
                                              bottom: 4,
                                              child: Container(
                                                width: 4,
                                                height: 4,
                                                decoration: BoxDecoration(
                                                  color: textColor.withOpacity(0.7),
                                                  shape: BoxShape.circle,
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
                            
                      const SizedBox(height: 24),
                      
                      // 3. STATS SUMMARY / SEEDER CARD
                      _monthData.isEmpty && !_isLoading
                          ? _buildSeederCard(isDark)
                          : _buildStatsCard(selectedDayData, isDark),
                          
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Visual widget when no records exist
  Widget _buildSeederCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_month_outlined,
            size: 48,
            color: Theme.of(context).primaryColor.withOpacity(0.6),
          ),
          const SizedBox(height: 16),
          Text(
            "No Records for this Month",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "There is no active productivity logs for this month yet. Sync today's activity or seed simulated data to explore the map in action!",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: isDark ? Colors.white.withOpacity(0.58) : Colors.black54,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _syncToday,
                  icon: const Icon(Icons.sync_rounded, size: 16),
                  label: const Text("Sync Today"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    foregroundColor: Theme.of(context).primaryColor,
                    side: BorderSide(color: Theme.of(context).primaryColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _seedSampleData,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                  label: const Text("Seed Demo Map"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Bottom detailed analysis card for selected day
  Widget _buildStatsCard(ProductivityDailyData? dayData, bool isDark) {
    if (dayData == null || dayData.dayType == 'empty') {
      final isTodaySelected = _selectedDay != null &&
          _selectedDay!.day == DateTime.now().day &&
          _selectedDay!.month == DateTime.now().month &&
          _selectedDay!.year == DateTime.now().year;

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.radio_button_unchecked,
              size: 40,
              color: Colors.grey.withOpacity(0.6),
            ),
            const SizedBox(height: 12),
            Text(
              "No Activity Logged",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "This day does not have active snapshots. Real-time scores generate when tasks, habits, or focus time are completed.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isDark ? Colors.white38 : Colors.black54,
              ),
            ),
            if (isTodaySelected) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _syncToday,
                icon: const Icon(Icons.bolt_rounded, size: 16),
                label: const Text("Generate Today's Snapshot"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ]
          ],
        ),
      );
    }

    final scoreColor = _getDayTextColor(dayData.dayType, isDark);
    final bgPastel = _getDayColor(dayData.dayType, isDark);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header of card (Rating Badge)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: bgPastel,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  dayData.dayType.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: scoreColor,
                  ),
                ),
              ),
              if (dayData.streakGroup.isNotEmpty && dayData.streakGroup != '0 days')
                Row(
                  children: [
                    Icon(Icons.local_fire_department_rounded, size: 16, color: Colors.orange.shade700),
                    const SizedBox(width: 4),
                    Text(
                      dayData.streakGroup,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Radial Score & Visual Details Row
          Row(
            children: [
              // Radial Progress indicator
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: CircularProgressIndicator(
                      value: dayData.productivityScore / 100,
                      strokeWidth: 8,
                      backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.03),
                      color: scoreColor,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Text(
                    "${dayData.productivityScore.round()}%",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              
              // Brief Description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Productivity Score",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dayData.productivityScore >= 70
                          ? "Fabulous job! You maintained momentum and kept focus strong."
                          : dayData.productivityScore >= 40
                              ? "Steady pace. A moderate balance of work and habits."
                              : "Rest and recover. Tomorrow is a brand new opportunity to excel.",
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: isDark ? Colors.white.withOpacity(0.58) : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 20),
          
          // Stats Row Grid
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatIndicator(
                icon: Icons.task_alt_rounded,
                label: "Tasks",
                value: "${dayData.tasksCompleted}/${dayData.tasksTotal}",
                color: Colors.blue,
                isDark: isDark,
              ),
              _buildStatIndicator(
                icon: Icons.repeat_rounded,
                label: "Habits",
                value: "${dayData.habitsCompleted}/${dayData.habitsTotal}",
                color: Colors.green,
                isDark: isDark,
              ),
              _buildStatIndicator(
                icon: Icons.timer_rounded,
                label: "Focus",
                value: "${dayData.focusMinutes}m",
                color: Colors.deepOrange,
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatIndicator({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 20,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white.withOpacity(0.8) : Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
      ],
    );
  }
}
