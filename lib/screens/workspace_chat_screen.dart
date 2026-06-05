import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/workspace_model.dart';
import '../models/workspace_chat_message.dart';
import '../services/workspace_chat_service.dart';
import '../widgets/task_picker_sheet.dart';
import 'task_details_screen.dart';

class WorkspaceChatScreen extends StatefulWidget {
  final Workspace workspace;

  const WorkspaceChatScreen({super.key, required this.workspace});

  @override
  State<WorkspaceChatScreen> createState() => _WorkspaceChatScreenState();
}

class _WorkspaceChatScreenState extends State<WorkspaceChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final WorkspaceChatService _chatService = WorkspaceChatService();
  bool _isSending = false;
  String? _selectedTaskId;
  String? _selectedTaskTitle;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onMessageTextChanged);
  }

  void _onMessageTextChanged() {
    if (_selectedTaskTitle != null) {
      if (!_messageController.text.contains('@$_selectedTaskTitle')) {
        setState(() {
          _selectedTaskId = null;
          _selectedTaskTitle = null;
        });
      }
    }
    
    final text = _messageController.text;
    if (text.endsWith('@')) {
      _showTaskPicker();
    }
  }

  void _showTaskPicker() async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TaskPickerSheet(projectId: widget.workspace.id),
    );

    if (result != null && result['id'] != null && result['title'] != null) {
      final taskId = result['id']!;
      final taskTitle = result['title']!;

      setState(() {
        _selectedTaskId = taskId;
        _selectedTaskTitle = taskTitle;
      });

      final text = _messageController.text;
      if (text.endsWith('@')) {
        final newText = text.substring(0, text.length - 1) + '@$taskTitle ';
        _messageController.text = newText;
        _messageController.selection = TextSelection.fromPosition(
          TextPosition(offset: newText.length),
        );
      } else {
        final newText = text + (text.isEmpty || text.endsWith(' ') ? '' : ' ') + '@$taskTitle ';
        _messageController.text = newText;
        _messageController.selection = TextSelection.fromPosition(
          TextPosition(offset: newText.length),
        );
      }
    }
  }

  void _handleSend() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final taskId = _selectedTaskId;
    final taskTitle = _selectedTaskTitle;

    setState(() {
      _isSending = true;
    });

    _messageController.clear();

    try {
      if (taskId != null && taskTitle != null && text.contains('@$taskTitle')) {
        final mentionToken = '@$taskTitle';
        final cleanedMessage = text.replaceFirst(mentionToken, '').trim();

        await _chatService.sendTaskMention(
          projectId: widget.workspace.id,
          taskId: taskId,
          taskTitle: taskTitle,
          customMessage: cleanedMessage,
        );
      } else {
        await _chatService.sendMessage(
          projectId: widget.workspace.id,
          message: text,
        );
      }
      setState(() {
        _selectedTaskId = null;
        _selectedTaskTitle = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to send: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  String _formatTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    return DateFormat.jm().format(date); // e.g. "5:30 PM"
  }

  void _showMessageOptions(BuildContext context, WorkspaceChatMessage message) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final isOwn = message.senderId == currentUser.uid;
    final isSystem = message.type == ChatMessageType.system;

    if (!isOwn || isSystem) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E24) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text("Edit Message"),
                onTap: () {
                  Navigator.pop(context);
                  _showEditDialog(context, message);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text("Delete Message", style: TextStyle(color: Colors.redAccent)),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await _chatService.deleteMessage(
                      projectId: widget.workspace.id,
                      messageId: message.messageId,
                    );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString())),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showEditDialog(BuildContext context, WorkspaceChatMessage message) {
    final controller = TextEditingController(text: message.message);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Message"),
          content: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.sentences,
            maxLines: null,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final newText = controller.text.trim();
                if (newText.isEmpty) return;
                Navigator.pop(context);
                try {
                  await _chatService.editMessage(
                    projectId: widget.workspace.id,
                    messageId: message.messageId,
                    newText: newText,
                  );
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                }
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  void _onTaskMentionTap(String taskId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.workspace.id)
          .collection('tasks')
          .doc(taskId)
          .get();

      if (!doc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Task unavailable")),
          );
        }
        return;
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TaskDetailsScreen(
              taskId: taskId,
              currentUserId: currentUserId,
              projectId: widget.workspace.id,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Task unavailable")),
        );
      }
    }
  }

  Widget _buildTaskMentionChip(WorkspaceChatMessage message, Color primaryColor) {
    if (message.taskId == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onTaskMentionTap(message.taskId!),
          borderRadius: BorderRadius.circular(8),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: primaryColor.withOpacity(0.35),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "📌",
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    message.taskTitle ?? 'Task',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.open_in_new,
                  size: 11,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageItem(WorkspaceChatMessage message, Color primaryColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = FirebaseAuth.instance.currentUser;
    final isMe = message.senderId == (currentUser?.uid ?? '');

    if (message.type == ChatMessageType.system) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message.message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    if (isMe) {
      return Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          onLongPress: () => _showMessageOptions(context, message),
          child: Container(
            margin: const EdgeInsets.only(left: 64, right: 16, top: 4, bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(isDark ? 0.2 : 0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(2),
              ),
              border: Border.all(
                color: primaryColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.type == ChatMessageType.task_mention)
                  _buildTaskMentionChip(message, primaryColor),
                if (message.message.isNotEmpty)
                  Text(
                    message.message,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.isEdited) ...[
                      Text(
                        "edited • ",
                        style: TextStyle(
                          color: isDark ? Colors.white30 : Colors.black38,
                          fontSize: 9,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    Text(
                      _formatTime(message.createdAt),
                      style: TextStyle(
                        color: isDark ? Colors.white30 : Colors.black45,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Team Messages
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 16, right: 64, top: 6, bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
              backgroundImage: message.senderPhoto != null && message.senderPhoto!.isNotEmpty
                  ? NetworkImage(message.senderPhoto!)
                  : null,
              child: message.senderPhoto == null || message.senderPhoto!.isEmpty
                  ? Text(
                      message.senderName.isNotEmpty ? message.senderName[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.senderName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF24242B) : Colors.grey.shade100,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(2),
                        topRight: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.grey.shade200,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (message.type == ChatMessageType.task_mention)
                          _buildTaskMentionChip(message, primaryColor),
                        if (message.message.isNotEmpty)
                          Text(
                            message.message,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 14,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (message.isEdited) ...[
                              Text(
                                "edited • ",
                                style: TextStyle(
                                  color: isDark ? Colors.white30 : Colors.black38,
                                  fontSize: 9,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                            Text(
                              _formatTime(message.createdAt),
                              style: TextStyle(
                                color: isDark ? Colors.white30 : Colors.black45,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final projectColor = Color(int.parse(widget.workspace.color));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Header
        Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Workspace Chat",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                "Team communication",
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        const Divider(),

        // Middle: Message Feed
        Expanded(
          child: StreamBuilder<List<WorkspaceChatMessage>>(
            stream: _chatService.getMessages(widget.workspace.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(color: projectColor),
                );
              }

              final messages = snapshot.data ?? [];

              if (messages.isEmpty) {
                return Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.forum_outlined,
                            size: 64,
                            color: projectColor.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Start the conversation",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Discuss tasks, sprint progress, and project updates with your team.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                reverse: true,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  return _buildMessageItem(messages[index], projectColor);
                },
              );
            },
          ),
        ),

        // Bottom: Message Composer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E24) : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.alternate_email, color: isDark ? Colors.white54 : Colors.grey.shade600),
                  onPressed: _showTaskPicker,
                  tooltip: "Mention Task",
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: "Message workspace...",
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                    ),
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send, color: projectColor),
                  onPressed: _isSending ? null : _handleSend,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _messageController.removeListener(_onMessageTextChanged);
    _messageController.dispose();
    super.dispose();
  }
}
