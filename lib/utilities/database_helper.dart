import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:notestream_app/models/models.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static const noteTable = 'Notes';
  static const tagTable = 'Tags';
  static const noteTagTable = 'NoteTags';
  static const _databaseName = 'notes.db';
  static const _databaseVersion = 1;

  static Database? _database;

  // Singleton
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  /// Get access to the database.
  ///
  /// Returns the database, initializing it first if it doesn't exist yet.
  Future<Database> get database async {
    return _database ??= await _initDatabase();
  }

  Future<Database> _initDatabase() async {
    String path = p.join(await getDatabasesPath(), _databaseName);

    developer.log('initializing app database at path: $path');

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $noteTable(
        id INTEGER PRIMARY KEY,
        filename TEXT NOT NULL UNIQUE,
        createdAt TEXT,
        modifiedAt TEXT,
        size INTEGER,
        location TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE $tagTable(
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE $noteTagTable(
        noteId INTEGER,
        tagId INTEGER,
        PRIMARY KEY (noteId, tagId),
        FOREIGN KEY (noteId) REFERENCES Note(id),
        FOREIGN KEY (tagId) REFERENCES Tag(id)
      )
    ''');
  }

  //--------- Helper methods ---------

  /// Insert a new Note in the db based on a given file.
  Future<Note?> insertNote(File file, String content) async {
    final Database db = await database;
    final DateFormat formatter = DateFormat('yyyy-MM-dd | HH:mm:ss');
    List<String?> tagList = tagParser(content);
    String lastModified = formatter.format(await file.lastModified());
    String createdAt = formatter.format(file.statSync().changed);

    // Prepare a new note with details from the file.
    Note newNote = Note(
      id: null,
      filename: p.basename(file.path),
      createdAt: createdAt,
      modifiedAt: lastModified,
      size: await file.length(),
      location: file.path,
      tags: tagList,
    );

    // Insert the new note into the db.
    int noteId = await db.insert(
      noteTable,
      newNote.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Update the tag relationships.
    if (tagList.isNotEmpty) {
      for (String? tagName in tagList) {
        int tagId = await getTagId(tagName!);

        // If the tag isn't in the db, insert it.
        if (tagId < 0) {
          tagId = await insertTag(Tag(name: tagName));
        }

        // Insert the junction (NoteTag relationship) into the db.
        if (tagId > 0) {
          insertJunction(NoteTag(noteId: noteId, tagId: tagId));
        }
      }
    }

    // Retrieve the updated note directly from the db.
    Note? insertedNote = await getNoteById(noteId);

    // Return null if something went wrong
    if (insertedNote == null) {
      return null;
    }
    return insertedNote;
  }

  /// Update an existing note and return the updated note object.
  Future<Note?> updateNote(Note note, String content, File file) async {
    final Database db = await database;
    final DateFormat formatter = DateFormat('yyyy-MM-dd | HH:mm:ss');
    List<String?> tagList = tagParser(content);
    int newSize = await file.length();
    String newModifiedAt = formatter.format(await file.lastModified());

    // Update the note row in the db.
    db.rawUpdate('UPDATE $noteTable SET size = ?, modifiedAt = ? WHERE id = ?',
        [newSize, newModifiedAt, note.id]);

    // Update the tag relationships.
    if (tagList.isNotEmpty) {
      for (String? tagName in tagList) {
        int tagId = await getTagId(tagName!);

        // If the tag isn't in the db, insert it.
        if (tagId < 0) {
          tagId = await insertTag(Tag(name: tagName));
        }

        // Insert the junction (NoteTag relationship) into the db.
        if (tagId > 0) {
          insertJunction(NoteTag(noteId: note.id!, tagId: tagId));
        }
      }
    }

    // Retrieve the updated note directly from the db.
    Note? insertedNote = await getNoteById(note.id!);

    // Return null if something went wrong
    if (insertedNote == null) {
      return null;
    }
    return insertedNote;
  }

  Future<bool> deleteNote(Note note) async {
    final Database db = await database;
    int noteId = note.id!;
    int noteDeleteResult =
        await db.rawDelete('DELETE FROM $noteTable WHERE id = ?', [noteId]);

    return (noteDeleteResult > 0);
  }

  /// Inserts a tag into the db.
  ///
  /// Returns tag id if successful, or -1 if unsuccessful.
  Future<int> insertTag(Tag tag) async {
    // returns the id assigned by SQLite
    final Database db = await database;

    try {
      return await db.insert(
        tagTable,
        tag.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      developer.log('DbException: $e');
      return -1;
    }
  }

  /// Inserts a junction (NoteTag relationship) into the db.
  Future<int?> insertJunction(NoteTag noteTag) async {
    final Database db = await database;

    try {
      return await db.insert(
        noteTagTable,
        noteTag.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      developer.log('DbException: $e');
      return null;
    }
  }

  /// Return list of all notes in the db.
  Future<List<Note>> notes() async {
    final db = await database;

    // query the table for all the notes
    final List<Map<String, Object?>> noteMaps =
        await db.query(noteTable, orderBy: 'modifiedAt DESC');

    // convert the maps into Note instances
    final List<Note> noteObjects = [];
    for (Map<String, Object?> map in noteMaps) {
      noteObjects.add(Note.fromMap(map));
    }

    return noteObjects;
  }

  Future<List<Tag>> tags() async {
    final db = await database;
    List<Map<String, Object?>> results = await db.query(tagTable);

    // convert the list of maps to a list of Tags
    final List<Tag> tagList = [];
    for (Map<String, Object?> map in results) {
      tagList.add(Tag.fromMap(map));
    }
    return tagList;
  }

  /// Returns true if note exists in the db.
  Future<bool> noteExists(int noteId) async {
    final Database db = await database;
    var queryResult =
        await db.rawQuery('SELECT * FROM $noteTable WHERE id="$noteId"');
    return queryResult.isNotEmpty;
  }

  /// Returns tag id if the tagName exists in the db, -1 if it does not exist.
  Future<int> getTagId(String tagName) async {
    final Database db = await database;
    var queryResult =
        await db.rawQuery('SELECT * FROM $tagTable WHERE name="$tagName"');
    if (queryResult.isNotEmpty) {
      return Tag.fromMap(queryResult[0]).id!;
    }
    return -1;
  }

  /// Return all Notes that contain a Tag from the given list of Tags.
  Future<List<Note>> getNotesWithTags(List<Tag> tags) async {
    developer.log('retrieving notes using taglist... ');
    if (tags.isEmpty) {
      developer.log('no tags provided; retrieving all notes');
      return notes();
    }
    final Database db = await database;
    List<int> tagIdList = [];
    List<Note> noteList = [];
    for (Tag t in tags) {
      if (t.id != null) {
        tagIdList.add(t.id!);
      }
    }
    final placeHolderList = List.filled(tagIdList.length, '?').join(', ');
    var result = await db.rawQuery(
      '''
      SELECT DISTINCT n.* 
      FROM $noteTable n
      JOIN $noteTagTable nt ON n.id = nt.noteId
      JOIN $tagTable t ON t.id = nt.tagId 
      WHERE t.id IN ($placeHolderList)
      ORDER BY n.modifiedAt DESC
      ''',
      tagIdList,
    );

    developer.log('retrieved ${result.length} notes');

    for (Map<String, Object?> map in result) {
      noteList.add(Note.fromMap(map));
    }

    return noteList;
  }

  /// Returns true if noteTag junction row exists.
  Future<bool> junctionExists(int noteId, int tagId) async {
    final Database db = await database;
    var queryResult = await db.rawQuery(
        'SELECT * FROM $noteTagTable WHERE noteId="$noteId" AND tagId="$tagId"');
    return queryResult.isNotEmpty;
  }

  /// Finds a note using its id.
  Future<Note?> getNoteById(int noteId) async {
    final db = await database;
    final queryResult = await db.query(
      noteTable,
      where: 'id = ?',
      whereArgs: [noteId],
    );

    if (queryResult.isEmpty) {
      return null;
    }

    final note = Note.fromMap(queryResult[0]);

    return note;
  }

  /// Find a note with a given filename.
  ///
  /// Returns note id if note exists in db, or null if not.
  Future<int?> getNoteIdByFilename(String filename) async {
    final db = await database;
    final queryResult = await db
        .rawQuery('SELECT * FROM $noteTable WHERE filename = ?', [filename]);

    if (queryResult.isEmpty) {
      return null;
    }
    return Note.fromMap(queryResult[0]).id;
  }

  Future<Note?> getNoteByPath(String path) async {
    final db = await database;
    final queryResult = await db
        .rawQuery('SELECT * FROM $noteTable WHERE location = ?', [path]);

    if (queryResult.isNotEmpty) {
      return Note.fromMap(queryResult[0]);
    }

    return null;
  }

  /// Finds all the tags in a text and returns them in a list.
  List<String?> tagParser(String content) {
    final tagRegex = RegExp(r'#([a-zA-Z0-9_-]+)');
    final matches = tagRegex.allMatches(content);
    final tags = matches
        .map((match) => match.group(0)!.replaceAll(RegExp(r'#'), ''))
        .toList();
    // developer.log('found tags in note: $tags');
    return tags;
  }
}
