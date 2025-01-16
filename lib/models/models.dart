class Note {
  // Notes in the db are only a reference to the file and its tags.
  // To get the actual note content,
  //  open and parse the file @ location.
  int? id; // primary key
  String filename;
  String? createdAt;
  String? modifiedAt;
  int? size; // in bytes
  String location;
  List<String?>? tags;

  Note({
    required this.id,
    required this.filename,
    required this.createdAt,
    required this.modifiedAt,
    required this.size,
    required this.location,
    required this.tags,
  });

  // Tags and content aren't included here because they aren't added to the db table
  //  this is because they have their own table in the db
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'filename': filename,
      'createdAt': createdAt,
      'modifiedAt': modifiedAt,
      'size': size,
      'location': location,
    };
  }

  factory Note.fromMap(Map<String, Object?> map) {
    return Note(
      id: map['id'] as int,
      filename: map['filename'] as String,
      createdAt: map['createdAt'] as String?,
      modifiedAt: map['modifiedAt'] as String?,
      size: map['size'] as int?,
      location: map['location'] as String,
      tags: map['tags'] as List<String?>?,
    );
  }

  @override
  String toString() {
    return '''
      id = $id\n
      filename = $filename\n
      createdAt = $createdAt\n
      modifiedAt = $modifiedAt\n
      size = $size\n
      location = $location\n
      tags = $tags\n
      ''';
  }
}

class Tag {
  // Since the main purpose of the db is to track the relationships between notes and tags,
  //  tags are also modeled, and the relationship is modeled with the NoteTag junction table.
  final int? id;
  final String name; // primary key

  const Tag({
    this.id,
    required this.name,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  factory Tag.fromMap(Map<String, Object?> map) {
    return Tag(
      id: map['id'] as int,
      name: map['name'] as String,
    );
  }
}

class NoteTag {
  final int noteId;
  final int tagId;

  const NoteTag({
    required this.noteId,
    required this.tagId,
  });

  Map<String, Object?> toMap() {
    return {
      'noteId': noteId,
      'tagId': tagId,
    };
  }
}
