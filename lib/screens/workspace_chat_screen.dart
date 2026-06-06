import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

// helper models for date grouping
abstract class ChatItem {}

class MessageChatItem extends ChatItem {
  final WorkspaceChatMessage message;
  MessageChatItem(this.message);
}

class DateSeparatorChatItem extends ChatItem {
  final String dateText;
  DateSeparatorChatItem(this.dateText);
}

class UnreadDividerChatItem extends ChatItem {}

class _WorkspaceChatScreenState extends State<WorkspaceChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final WorkspaceChatService _chatService = WorkspaceChatService();

  bool _isSending = false;
  String? _selectedTaskId;
  String? _selectedTaskTitle;

  // UX & Scroll Control State
  final ValueNotifier<bool> _showNewMessagesNotifier = ValueNotifier<bool>(false);
  StreamSubscription? _lastReadSubscription;
  int? _lastMessageCount;

  // Unread divider state (fixed at current session load time)
  Timestamp? _initialLastRead;
  bool _fetchedInitialLastRead = false;

  // Typing state
  Timer? _typingTimer;
  DateTime? _lastTypingSentTime;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onMessageTextChanged);
    _scrollController.addListener(_onScroll);

    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    // Fetch user's initial lastRead timestamp to set the unread marker line
    _lastReadSubscription = FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.workspace.id)
        .collection('chat_last_read')
        .doc(currentUserId)
        .snapshots()
        .listen((doc) {
      if (!_fetchedInitialLastRead) {
        _fetchedInitialLastRead = true;
        if (mounted) {
          setState(() {
            _initialLastRead = doc.exists ? (doc.data()?['lastRead'] as Timestamp?) : null;
          });
        }
      }
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final show = _scrollController.offset > 200.0;
    if (show != _showNewMessagesNotifier.value) {
      _showNewMessagesNotifier.value = show;
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
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

    _handleTypingIndicator();
  }

  void _handleTypingIndicator() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final now = DateTime.now();
    if (_lastTypingSentTime == null || now.difference(_lastTypingSentTime!) > const Duration(milliseconds: 1500)) {
      _lastTypingSentTime = now;
      _chatService.setTypingStatus(widget.workspace.id, currentUserId, true);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      _chatService.setTypingStatus(widget.workspace.id, currentUserId, false);
      _lastTypingSentTime = null;
    });
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

    _typingTimer?.cancel();
    _lastTypingSentTime = null;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null) {
      _chatService.setTypingStatus(widget.workspace.id, currentUserId, false);
    }

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

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final checkDate = DateTime(date.year, date.month, date.day);

    if (checkDate == today) {
      return "Today";
    } else if (checkDate == yesterday) {
      return "Yesterday";
    } else {
      return DateFormat("MMMM d, yyyy").format(date);
    }
  }

  void _showMessageOptions(BuildContext context, WorkspaceChatMessage message) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final isOwn = message.senderId == currentUser.uid;
    final isSystem = message.type == ChatMessageType.system;

    if (isSystem) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              if (!isOwn) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ["👍", "❤️", "😂", "🔥", "👀"].map((emoji) {
                      final hasReacted = message.reactions[emoji]?.contains(currentUser.uid) ?? false;
                      return InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          _chatService.toggleReaction(
                            projectId: widget.workspace.id,
                            messageId: message.messageId,
                            emoji: emoji,
                            userId: currentUser.uid,
                          );
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: hasReacted
                                ? Color(int.parse(widget.workspace.color)).withOpacity(0.15)
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const Divider(),
              ],
              if (isOwn) ...[
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
              ],
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text("Copy Text"),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: message.message));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Copied to clipboard")),
                  );
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

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 200),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.9 + (0.1 * value),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
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
      ),
    );
  }

  Widget _buildReactionChips(WorkspaceChatMessage message, Color primaryColor) {
    if (message.reactions.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: message.reactions.entries.map((entry) {
        final emoji = entry.key;
        final userIds = entry.value;
        final hasReacted = userIds.contains(currentUserId);

        return TweenAnimationBuilder<double>(
          key: ValueKey("${emoji}_${userIds.length}"),
          tween: Tween<double>(begin: 0.8, end: 1.0),
          duration: const Duration(milliseconds: 150),
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: child,
            );
          },
          child: GestureDetector(
            onTap: () => _chatService.toggleReaction(
              projectId: widget.workspace.id,
              messageId: message.messageId,
              emoji: emoji,
              userId: currentUserId,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: hasReacted
                    ? primaryColor.withOpacity(isDark ? 0.25 : 0.12)
                    : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
                border: Border.all(
                  color: hasReacted ? primaryColor : (isDark ? Colors.white10 : Colors.grey.shade200),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 4),
                  Text(
                    "${userIds.length}",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: hasReacted
                          ? (isDark ? Colors.white : primaryColor)
                          : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDateSeparator(String dateText) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: isDark ? Colors.white12 : Colors.grey.shade300, thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              dateText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(child: Divider(color: isDark ? Colors.white12 : Colors.grey.shade300, thickness: 1)),
        ],
      ),
    );
  }

  Widget _buildUnreadDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Colors.redAccent, thickness: 1.5)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                border: Border.all(color: Colors.redAccent, width: 1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                "New Messages",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                ),
              ),
            ),
          ),
          const Expanded(child: Divider(color: Colors.redAccent, thickness: 1.5)),
        ],
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
                if (message.reactions.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _buildReactionChips(message, primaryColor),
                ],
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
                      color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade100,
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
                    child: GestureDetector(
                      onLongPress: () => _showMessageOptions(context, message),
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
                          if (message.reactions.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            _buildReactionChips(message, primaryColor),
                          ],
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
          child: Stack(
            children: [
              StreamBuilder<List<WorkspaceChatMessage>>(
                stream: _chatService.getMessages(widget.workspace.id),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          "Error loading messages: ${snapshot.error}",
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(color: projectColor),
                    );
                  }

                  final messages = snapshot.data ?? [];

                  // Auto-scroll logic inside builder
                  if (_lastMessageCount != null && messages.length > _lastMessageCount!) {
                    if (_scrollController.hasClients && _scrollController.offset < 200.0) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _scrollToBottom();
                      });
                    }
                  }
                  _lastMessageCount = messages.length;

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

                  // Chronological grouping
                  final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
                  final chronologicalMessages = messages.reversed.toList();
                  final List<ChatItem> chatItems = [];
                  DateTime? lastDate;

                  for (int i = 0; i < chronologicalMessages.length; i++) {
                    final msg = chronologicalMessages[i];
                    final msgDate = msg.createdAt.toDate();

                    // 1. Date Separator
                    if (lastDate == null || !_isSameDay(lastDate, msgDate)) {
                      chatItems.add(DateSeparatorChatItem(_formatDateHeader(msgDate)));
                      lastDate = msgDate;
                    }

                    // 2. Unread Divider
                    if (_initialLastRead != null &&
                        msg.senderId != currentUserId &&
                        msg.type != ChatMessageType.system &&
                        msg.createdAt.compareTo(_initialLastRead!) > 0) {
                      if (!chatItems.any((item) => item is UnreadDividerChatItem)) {
                        chatItems.add(UnreadDividerChatItem());
                      }
                    }

                    chatItems.add(MessageChatItem(msg));
                  }

                  final reversedItems = chatItems.reversed.toList();

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    reverse: true,
                    itemCount: reversedItems.length,
                    itemBuilder: (context, index) {
                      final item = reversedItems[index];
                      if (item is MessageChatItem) {
                        return FadeInSlideWidget(
                          key: ValueKey(item.message.messageId),
                          child: _buildMessageItem(item.message, projectColor),
                        );
                      } else if (item is DateSeparatorChatItem) {
                        return _buildDateSeparator(item.dateText);
                      } else if (item is UnreadDividerChatItem) {
                        return _buildUnreadDivider();
                      }
                      return const SizedBox.shrink();
                    },
                  );
                },
              ),
              ValueListenableBuilder<bool>(
                valueListenable: _showNewMessagesNotifier,
                builder: (context, show, child) {
                  if (!show) return const SizedBox.shrink();
                  return Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: FloatingActionButton.extended(
                        onPressed: _scrollToBottom,
                        label: const Text("New Messages"),
                        icon: const Icon(Icons.arrow_downward),
                        backgroundColor: projectColor,
                        foregroundColor: Colors.white,
                        elevation: 4,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // Typing Indicator Row
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _chatService.getTypingUsersStream(widget.workspace.id),
          builder: (context, snapshot) {
            final typingUsers = snapshot.data ?? [];
            if (typingUsers.isEmpty) return const SizedBox.shrink();

            String text = "";
            if (typingUsers.length == 1) {
              text = "${typingUsers[0]['userName']} is typing ";
            } else {
              text = "${typingUsers[0]['userName']} and ${typingUsers.length - 1} other${typingUsers.length - 1 > 1 ? 's' : ''} typing ";
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const BouncingDotsIndicator(),
                ],
              ),
            );
          },
        ),

        // Bottom: Message Composer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
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
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _showNewMessagesNotifier.dispose();
    _lastReadSubscription?.cancel();
    _typingTimer?.cancel();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null) {
      _chatService.setTypingStatus(widget.workspace.id, currentUserId, false);
    }
    super.dispose();
  }
}

// Micro-animations: Fade in and slide up message items
class FadeInSlideWidget extends StatefulWidget {
  final Widget child;
  const FadeInSlideWidget({super.key, required this.child});

  @override
  State<FadeInSlideWidget> createState() => _FadeInSlideWidgetState();
}

class _FadeInSlideWidgetState extends State<FadeInSlideWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacityAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: widget.child,
      ),
    );
  }
}

// Micro-animations: Bouncing typing dots
class BouncingDotsIndicator extends StatefulWidget {
  const BouncingDotsIndicator({super.key});

  @override
  State<BouncingDotsIndicator> createState() => _BouncingDotsIndicatorState();
}

class _BouncingDotsIndicatorState extends State<BouncingDotsIndicator> with TickerProviderStateMixin {
  late final AnimationController _controller;
  final List<Animation<double>> _animations = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    for (int i = 0; i < 3; i++) {
      final start = i * 0.2;
      final end = start + 0.6;
      _animations.add(
        Tween<double>(begin: 0.0, end: -6.0).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Interval(start, end, curve: Curves.easeInOut),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _animations[index].value),
              child: child,
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: isDark ? Colors.white54 : Colors.black45,
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }
}
