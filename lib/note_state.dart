import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:notestream_app/models/models.dart';
import 'package:notestream_app/utilities/note_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NewNoteState extends ChangeNotifier {
  String? _userNotesPath;
  final NoteManager _nm = NoteManager();
  bool isCreatingNewNote = false;
  final Map<int, String> _noteContents = {};
  List<Note?> noteList = [];
  List<Tag> allTagsList = [];
  List<Tag> filterTagsList = [];
  Map<String, Tag> tagNameMap = {};
  bool userNotesLoaded = false;

  bool booted = false;

  /// Passively check for a notes path.
  bool get notesPathIsLoaded {
    if (_userNotesPath == null) {
      return false;
    }
    return true;
  }

  /// Async check shared preferences for presences of notes path.
  Future<bool> notesPathExists() async {
    String notesPath = await getNotesPath();
    if (notesPath.isEmpty) {
      return false;
    } else {
      return true;
    }
  }

  /// Returns the notes path if it exists.
  ///
  /// Returns an empty string if not set.
  /// A nullable output here creates difficulty when used with a future builder.
  Future<String> getNotesPath() async {
    final prefs = await SharedPreferences.getInstance();

    // TODO: use if statement below to always clear preferences on startup for testing purposes.
    // if (!booted) {
    //   await prefs.clear();
    //   booted = true;
    // }

    _userNotesPath ??= prefs.getString('notes_path');

    if (_userNotesPath != null) {
      return _userNotesPath!;
    }

    // Case if running on iOS.
    // Default to appDocDir because anything else requires ample shenaniganery.
    if (Platform.isIOS) {
      final dir = await getApplicationDocumentsDirectory();
      await setNotesPath(dir.path);
      _userNotesPath = prefs.getString('notes_path');
      initData();
      if (_userNotesPath != null) return _userNotesPath!;
    }
    return '';
  }

  Future setNotesPath(String userNotesPath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notes_path', userNotesPath);
    _userNotesPath = userNotesPath;
    notifyListeners();
  }

  Future initData() async {
    // TODO: use if statement below to always clear preferences on startup for testing purposes.
    // if (!booted) {
    //   final prefs = await SharedPreferences.getInstance();
    //   await prefs.clear();
    //   booted = true;
    // }

    if (!userNotesLoaded) {
      userNotesLoaded = true;
      await _nm.loadUserNotes(withSamples: true);
    }
    List<Tag> allTags = await _nm.allTags;
    List<Note> notes = await _nm.getNotesByTags([]);
    for (Note note in notes) {
      await _retrieveNoteContent(note);
      noteList.add(note);
      notifyListeners();
    }
    allTagsList = allTags;
    loadTagNames();
    notifyListeners();
  }

  Future reloadTags() async {
    List<Tag> allTags = await _nm.allTags;
    allTagsList = allTags;
    loadTagNames();
  }

  Future reloadNotesAndTags() async {
    List<Tag> allTags = await _nm.allTags;
    List<Note> notes = await _nm.getNotesByTags(filterTagsList);
    for (Note note in notes) {
      if (!_noteContents.containsKey(note.id)) {
        _retrieveNoteContent(note);
      }
    }
    noteList = notes;
    allTagsList = allTags;
    loadTagNames();
  }

  /// Retrieve individual note's content from backend and caches in _noteContents.
  Future _retrieveNoteContent(Note note) async {
    if (note.id != null) {
      String content = await _nm.getNoteContent(note.location);
      _noteContents.addAll({note.id!: content});
    }
  }

  /// Gets note content from app's note cache.
  String? getNoteContent(Note? note) {
    if (note == null) {
      return '';
    }
    return _noteContents[note.id];
  }

  void startNewNote() {
    if (!isCreatingNewNote) {
      isCreatingNewNote = true;
      Note? nullNote;
      noteList.insert(0, nullNote);
      notifyListeners();
    }
  }

  void finishNewNote() {
    isCreatingNewNote = false;
  }

  /// Saves a new note to db and filesystem and updates app's note cache.
  void saveNewNote(String content) async {
    if (content.isNotEmpty) {
      Note? note = await _nm.saveNewNote(content);
      if (note != null) {
        await _retrieveNoteContent(note);
        noteList.remove(null);
        noteList.insert(0, note);
        await reloadTags();
        notifyListeners();
      }
    } else {
      cancelNewNote();
    }
  }

  Future cancelNewNote() async {
    noteList.remove(null);
    notifyListeners();
  }

  Future saveNoteChanges(Note note, String newContent) async {
    Note? updatedNote = await _nm.updateExistingNote(newContent, note);
    if (updatedNote != null) {
      await _retrieveNoteContent(updatedNote);
      noteList.remove(note);
      noteList.insert(0, updatedNote);
      notifyListeners();
    }
  }

  Future deleteNote(Note note) async {
    if (await _nm.deleteNote(note)) {
      noteList.remove(note);
      notifyListeners();
    }
  }

  Future validateFilterTag(String name) async {
    if (tagNameMap.keys.contains(name)) {
      filterTagsList.add(tagNameMap[name]!);
      // await _getAllNotes();
      await reloadNotesAndTags();
      notifyListeners();
    }
  }

  Future removeFilterTag(int index) async {
    filterTagsList.removeAt(index);
    noteList = await _nm.getNotesByTags(filterTagsList);
    notifyListeners();
  }

  Future removeFilterTagByName(String tagName) async {
    print('removing ${tagNameMap[tagName]}');
    filterTagsList.removeWhere((tag) => tag.name == tagName);
    noteList = await _nm.getNotesByTags(filterTagsList);

    notifyListeners();
  }

  Future loadTagNames() async {
    for (Tag tag in allTagsList) {
      tagNameMap.putIfAbsent(tag.name, () => tag);
    }
  }
}
