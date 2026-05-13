import 'package:cloud_firestore/cloud_firestore.dart';

class Workspace {
  final String id;
  final String name;
  final String description;
  final String ownerId;
  final String ownerName;
  final List<String> members;
  final Timestamp createdAt;
  final String color; // hex string
  final int icon; // code point
  final String type;

  Workspace({
    required this.id,
    required this.name,
    required this.description,
    required this.ownerId,
    required this.ownerName,
    required this.members,
    required this.createdAt,
    required this.color,
    required this.icon,
    this.type = 'developer',
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'members': members,
      'createdAt': createdAt,
      'color': color,
      'icon': icon,
      'type': type,
    };
  }

  factory Workspace.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Workspace(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      ownerId: data['ownerId'] ?? '',
      ownerName: data['ownerName'] ?? '',
      members: List<String>.from(data['members'] ?? []),
      createdAt: data['createdAt'] ?? Timestamp.now(),
      color: data['color'] ?? '0xFF0D47A1',
      icon: data['icon'] ?? 0xe14d, // Icons.code.codePoint
      type: data['type'] ?? 'developer',
    );
  }
}
