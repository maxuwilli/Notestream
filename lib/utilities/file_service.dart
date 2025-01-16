import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:notestream_app/models/models.dart';
import 'package:intl/intl.dart';


/// Handles read and write operations for files on the target device.
class FileService {
  String samplePath = '/Users/maxu/Dev/Flutter/NoteStream/notestream_app/lib/samples/';

  /// Gets the application directory across different platforms.
  Future<Directory> get _localDirectory async {
    
    final directory = await getApplicationDocumentsDirectory();
    // const dirString = '/Users/maxu/Dev/Flutter/SingleNote-app/singlenote_app/lib/sample_notes/';
    return directory;
  }

  /// Scan the directory at the given path and return a list of .md and .txt files.
  Future<List<File>?> scanDirectory(String path) async {
    final dir = Directory(path);
    List<File> foundFiles = [];
    
    try {
      final dirList = dir.list();
      await for (FileSystemEntity f in dirList) {
        if (f is File) {
          String ext = p.extension(f.path).toLowerCase();

          if (ext == '.md' || ext == '.txt') {
            File found = f;
            foundFiles.add(found);
          }
        }
      }
    } catch(e) {
      print(e);
      return null;
    }

    return foundFiles;
  }

  Future<bool> deleteFile(Note note) async {
    final directory = Directory(note.location);
    final path = directory.path;
    final file = File(path);
    
    try {
      await file.delete();
      return true;
    } catch(e) {
      print(e);
      return false;
    }
  }

  /// Writes content to a filename, returns the file reference.
  Future<File> writeFile(String filename, String content) async {
    // final directory = _localDirectory;
    final directory = Directory(samplePath);
    final path = directory.path;
    final file = File('$path/$filename');
    await file.writeAsString(content);
    print("FS.writeFile: file saved as $file");
    // return openNote(file);
    return file;
  }

  /// Checks whether a file exists at path.
  Future<bool> fileExists(String path) {
    final possibleFile = File(path);
    return possibleFile.exists();
  }


  /// Creates an instance of a Note using an existing .txt or .md file.
  /// 
  /// This is the only method in FileService that is allowed to create or handle Note objects.
  Future<Note?> openFileAsNote(File file) async {
    final String fileExtension = p.extension(file.path).toLowerCase();
    final DateFormat formatter = DateFormat('dd-MM-yyyy | HH:mm:ss');

    if (fileExtension == '.md' || fileExtension == '.txt') {
      String content = await file.readAsString();
      Note note = Note(
        id: null,
        filename: p.basename(file.path),
        createdAt: formatter.format(DateTime.now()),
        modifiedAt: formatter.format(await file.lastModified()),
        size: await file.length(),
        location: file.path,
        tags: tagParser(content),
      );
      return note;
    } else {
      return null;
    }
  }

  /// Reads a file at path.
  Future<String> readFile(String path) async {
    if (await fileExists(path)) {
      var file = File(path);
      return await file.readAsString();
    }
    return "Error: File could not be found.";
  }

  /// Finds all the tags in a text and returns them in a list.
  List<String?> tagParser(String content) {
    final tagRegex = RegExp(r'#([a-zA-Z0-9_-]+)');
    final matches = tagRegex.allMatches(content);
    final tags = matches.map((match) => match.group(0)).toList();
    return tags;
  }
}
