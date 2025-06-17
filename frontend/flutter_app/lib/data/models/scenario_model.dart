import 'dart:convert';

class ScenarioModel {
  final String id;
  final String name;
  final String description;
  final String type;
  final String? difficulty;
  final String language;
  final List<String>? tags;
  final String? previewImage;

  ScenarioModel({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.difficulty,
    required this.language,
    this.tags,
    this.previewImage,
  });

  factory ScenarioModel.fromJson(Map<String, dynamic> json) {
    return ScenarioModel(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      type: json['type'],
      difficulty: json['difficulty'],
      language: json['language'] ?? 'fr',
      tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
      previewImage: json['preview_image'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type,
      'difficulty': difficulty,
      'language': language,
      'tags': tags,
      'preview_image': previewImage,
    };
  }
}

// La classe SessionModel a été déplacée vers session_model.dart