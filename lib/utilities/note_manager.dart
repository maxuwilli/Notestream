import 'dart:io';
import 'dart:developer' as developer;
import 'package:intl/intl.dart';
import 'package:notestream_app/models/models.dart';
import 'package:notestream_app/utilities/database_helper.dart';
import 'package:notestream_app/utilities/file_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NoteManager {
  Future<String?> get userNotePath async {
    final prefs = await SharedPreferences.getInstance();
    String? userNotesPath = prefs.getString('notes_path');
    return userNotesPath;
  }

  /// Scan designated note path for notes and load into db.
  ///
  /// Scans the note path provided by the user ( path stored in SharedPreferences).
  /// Optionally, copy app's sample notes into note path and db.
  Future loadUserNotes({bool withSamples = false}) async {
    final FileService fs = FileService();
    final notePath = await userNotePath;
    if (notePath != null) {
      if (withSamples) await fs.writeSampleFiles();
      (notePath);
      int count = await _scanForNotes(notePath);
      developer.log('$count notes found');
    }
  }

  /// Scan the directory at a given path and add found notes to db.
  ///
  /// Creates or updates Note references for any files it finds that end in .md or .txt.
  /// Files with existing Note entries in the db will only have the references updated if size or modifiedAt do not match.
  /// Returns the number of notes found or updated, or -1 if the scan failed.
  Future<int> _scanForNotes(String path) async {
    final db = DatabaseHelper.instance;
    final fs = FileService();
    final DateFormat formatter = DateFormat('dd-MM-yyyy | HH:mm:ss');
    int count = 0;
    List<File>? noteFiles = await fs.scanDirectory(path);

    // Operation failed if scanDirectory failed to return a list.
    if (noteFiles == null) {
      return -1;
    }

    for (File f in noteFiles) {
      int fileSize = await f.length();
      String fileModifiedAt = formatter.format(await f.lastModified());
      Note? note = await db.getNoteByPath(f.path);

      // Case if note is already in the db.
      if (note != null) {
        // Update the note if needed.
        if (note.size != fileSize || note.modifiedAt != fileModifiedAt) {
          String content = await getNoteContent(note.location);
          await db.updateNote(
            note,
            content,
            f,
          );
        }
      } else {
        // Insert new note into the db.
        String content = await getNoteContent(f.path);
        await db.insertNote(
          f,
          content,
        );
      }
      count++;
    }
    return count;
  }

  /// Retrieve all known notes as a list of Note objects.
  Future<List<Note>> get allNotes async {
    // retrieve a list of note paths from the db
    final db = DatabaseHelper.instance;
    List<Note> noteList = await db.notes();

    // retrieve note contents from the files, convert maps to Note, and add contents to entities
    return noteList;
  }

  Future<List<Tag>> get allTags async {
    final db = DatabaseHelper.instance;
    List<Tag> tagList = await db.tags();
    return tagList;
  }

  /// Retreive all notes that are tagged with at least one of the given tags.
  ///
  /// The tag filtering is OR, not AND.
  Future<List<Note?>> getNotesByTags(List<Tag> tags) {
    final db = DatabaseHelper.instance;
    return db.getNotesWithTags(tags);
  }

  /// Save the note as a file, then stores a reference to it in the db.
  Future<Note?> saveNewNote(String content, {String? filename}) async {
    final DatabaseHelper db = DatabaseHelper.instance;
    final FileService fs = FileService();
    final notePath = await userNotePath;
    if (notePath == null) return null;

    int dupCount = 0;

    if (filename == null) {
      // String in format 'yyyy-MM-dd-hhmmss'
      String dateTimeString =
          "${DateTime.now().year.toString().padLeft(4, '0')}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}_${DateTime.now().hour.toString().padLeft(2, '0')}${DateTime.now().minute.toString().padLeft(2, '0')}${DateTime.now().second.toString().padLeft(2, '0')}";
      filename = dateTimeString;
    }

    String filenameStatic = filename;

    // Append a copy count number if the filename is already in use.
    while (await fs.fileExists('$notePath$filename.md')) {
      dupCount++;
      filename = '$filenameStatic ($dupCount)';
    }

    // Write the content to a new file.
    File newFile = await fs.writeFile('$filename.md', content, notePath);

    // Insert a new Note into the db based on the file.
    Note? newNote = await db.insertNote(newFile, content);

    // Return null if insert failed.
    if (newNote == null) {
      return null;
    }

    return newNote;
  }

  /// Save changes to an existing note.
  Future<Note?> updateExistingNote(String content, Note note) async {
    final DatabaseHelper db = DatabaseHelper.instance;
    final FileService fs = FileService();
    final notePath = await userNotePath;
    if (notePath == null) return null;

    File file = await fs.writeFile(
      note.filename,
      content,
      notePath,
    );

    Note? updated = await db.updateNote(
      note,
      content,
      file,
    );

    return updated;
  }

  Future<bool> deleteNote(Note note) async {
    final DatabaseHelper db = DatabaseHelper.instance;
    final FileService fs = FileService();
    if (await fs.deleteFile(note)) {
      if (await db.deleteNote(note)) {
        return true;
      }
    }
    return false;
  }

  /// Get the note content as a string.
  Future<String> getNoteContent(String path) async {
    final FileService fs = FileService();

    try {
      return await fs.readFile(path);
    } catch (e) {
      developer.log('error while retrieving note contents at path $path: $e');
      return 'Oops: something went wrong while retrieving this note';
    }
  }
}
