import 'dart:io';
import 'package:intl/intl.dart';
import 'package:notestream_app/models/models.dart';
import 'package:notestream_app/utilities/database_helper.dart';
import 'package:notestream_app/utilities/file_service.dart';

class NoteManager {
  /// Load sample notes into the DB.
  Future loadSamples() async {
    final FileService fs = FileService();
    scanForNotes(fs.samplePath);
  }

  /// Scan the directory at a given path and add found notes to db.
  ///
  /// Creates or updates Note references for any files it finds that end in .md or .txt.
  /// Files with existing Note entries in the db will only have the references updated if size or modifiedAt do not match.
  /// Returns the number of notes found or updated, or -1 if the scan failed.
  Future<int> scanForNotes(String path) async {
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
          db.updateNote(
            note,
            await getNoteContent(note),
            f,
          );
        }
      } else {
        // Insert new note into the db.
        db.insertNote(
          f,
          await getNoteContent(note),
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

  /// Save the note as a file, then stores a reference to it in the db.
  Future<Note?> saveNewNote(String content) async {
    final DatabaseHelper db = DatabaseHelper.instance;
    final FileService fs = FileService();
    int dupCount = 0;

    // String in format 'yyyy-MM-dd-hhmmss'
    String dateTimeString =
        "${DateTime.now().year.toString().padLeft(4, '0')}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}_${DateTime.now().hour.toString().padLeft(2, '0')}${DateTime.now().minute.toString().padLeft(2, '0')}${DateTime.now().second.toString().padLeft(2, '0')}";

    // Filename is the current date.
    // String dateString =
    //     "${DateTime.now().year.toString().padLeft(4, '0')}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}";

    String filename = dateTimeString;

    // Append a copy count number if the filename is already in use.
    while (await fs.fileExists('${fs.samplePath}$filename.md')) {
      dupCount++;
      filename = '$dateTimeString ($dupCount)';
    }

    // Write the content to a new file.
    File newFile = await fs.writeFile('$filename.md', content);

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

    File file = await fs.writeFile(
      note.filename,
      content,
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
  Future<String> getNoteContent(Note? note) async {
    final FileService fs = FileService();
    if (note == null) {
      return "Error: Note does not exist";
    }
    final path = note.location;
    try {
      return await fs.readFile(path);
    } catch (e) {
      print(path);
      return "Error: Failed to retrieve note contents";
    }
  }

  /// Create an empty note file with corresponding database entry.
}
