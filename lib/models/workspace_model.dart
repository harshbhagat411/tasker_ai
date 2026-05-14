import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Workspace {
  final String id;
  final String name;
  final String description;
  final String ownerId;
  final String ownerName;
  final List<String> members;
  final Map<String, String> memberRoles;
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
    required this.memberRoles,
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
      'memberRoles': memberRoles,
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
      memberRoles: Map<String, String>.from(data['memberRoles'] ?? { (data['ownerId'] ?? ''): 'owner' }),
      createdAt: data['createdAt'] ?? Timestamp.now(),
      color: data['color'] ?? '0xFF0D47A1',
      icon: data['icon'] ?? 0xe14d, // Icons.code.codePoint
      type: data['type'] ?? 'developer',
    );
  }

  IconData get iconData {
    if (icon == Icons.rocket_launch.codePoint) return Icons.rocket_launch;
    if (icon == Icons.business_center.codePoint) return Icons.business_center;
    if (icon == Icons.devices.codePoint) return Icons.devices;
    if (icon == Icons.pie_chart.codePoint) return Icons.pie_chart;
    if (icon == Icons.science.codePoint) return Icons.science;
    return Icons.code;
  }
}
