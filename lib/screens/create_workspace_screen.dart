import 'package:flutter/material.dart';
import '../services/workspace_service.dart';

class CreateWorkspaceScreen extends StatefulWidget {
  const CreateWorkspaceScreen({super.key});

  @override
  State<CreateWorkspaceScreen> createState() => _CreateWorkspaceScreenState();
}

class _CreateWorkspaceScreenState extends State<CreateWorkspaceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  
  final WorkspaceService _workspaceService = WorkspaceService();
  bool _isLoading = false;

  int _selectedColorIndex = 0;
  final List<Color> _colors = [
    const Color(0xFF0D47A1), // Blue
    const Color(0xFF6A1B9A), // Purple
    const Color(0xFF00695C), // Teal
    const Color(0xFFEF6C00), // Orange
    const Color(0xFFD84315), // Deep Orange
    const Color(0xFF37474F), // Blue Grey
  ];

  int _selectedIconIndex = 0;
  final List<IconData> _icons = [
    Icons.code,
    Icons.rocket_launch,
    Icons.business_center,
    Icons.devices,
    Icons.pie_chart,
    Icons.science,
  ];

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final colorHex = "0x${_colors[_selectedColorIndex].value.toRadixString(16)}";
    final iconCode = _icons[_selectedIconIndex].codePoint;

    final id = await _workspaceService.createWorkspace(
      name: _nameController.text.trim(),
      description: _descController.text.trim(),
      color: colorHex,
      icon: iconCode,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (id != null) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create workspace')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        title: Text(
          "New Workspace",
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Let's build something great",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Create a dedicated workspace for your team, project, or startup.",
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey.shade400 : Colors.grey,
                ),
              ),
              const SizedBox(height: 32),
              
              Text(
                "Workspace Name",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: "e.g., Tasker AI App",
                  hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _colors[_selectedColorIndex], width: 2),
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E1E24) : Colors.grey.shade50,
                ),
                validator: (val) => val == null || val.isEmpty ? "Name is required" : null,
              ),
              const SizedBox(height: 24),
              
              Text(
                "Description",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descController,
                maxLines: 3,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: "What is this project about?",
                  hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _colors[_selectedColorIndex], width: 2),
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E1E24) : Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 32),

              Text(
                "Theme Color",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _colors.length,
                  itemBuilder: (context, index) {
                    final color = _colors[index];
                    final isSelected = index == _selectedColorIndex;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColorIndex = index),
                      child: Container(
                        width: 50,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected ? Border.all(color: isDark ? Colors.white : Colors.black, width: 3) : null,
                        ),
                        child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),

              Text(
                "Workspace Icon",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _icons.length,
                  itemBuilder: (context, index) {
                    final icon = _icons[index];
                    final isSelected = index == _selectedIconIndex;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedIconIndex = index),
                      child: Container(
                        width: 60,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _colors[_selectedColorIndex].withOpacity(isDark ? 0.2 : 0.1)
                              : (isDark ? const Color(0xFF1E1E24) : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(color: _colors[_selectedColorIndex], width: 2)
                              : Border.all(color: isDark ? Colors.transparent : Colors.grey.shade200, width: 2),
                        ),
                        child: Icon(
                          icon,
                          color: isSelected
                              ? _colors[_selectedColorIndex]
                              : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 48),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _create,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _colors[_selectedColorIndex],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Create Workspace", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
