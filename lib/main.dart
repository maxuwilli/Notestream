import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:notestream_app/models/models.dart';
import 'package:notestream_app/state/note_state.dart';
import 'package:notestream_app/notecard.dart';
import 'package:notestream_app/utilities/note_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'settings_page.dart';
import 'tag_field.dart';
import 'state/theme_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized;
  // await SharedPrefs().init();
  runApp(const MyApp());
}

// Shared preferences for global use.

const String keyThemeColor = "theme_color_hex_string";
const String keyThemeMode = "theme_mode";

// class SharedPrefs {
//   late final SharedPreferences _sharedPrefs;
//   static final SharedPrefs _instance = SharedPrefs._internal();
//   factory SharedPrefs() => _instance;
//   SharedPrefs._internal();

//   init() async {
//     _sharedPrefs = await SharedPreferences.getInstance();
//   }

//   // Get/Set for theme color (hex value)
//   String get themeColorHexString => _sharedPrefs.getString(keyThemeColor) ?? '';

//   set themeColorHexString(String hexString) {
//     _sharedPrefs.setString(keyThemeColor, hexString);
//   }

//   // Get/Set for theme mode (0, 1, 2 == system, light, dark)
//   int get themeMode => _sharedPrefs.getInt(keyThemeMode) ?? 0;

//   set themeMode(int optionValue) {
//     _sharedPrefs.setInt(keyThemeMode, optionValue);
//   }
// }

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<SharedPreferences> initSharedPrefs() async {
    SharedPreferences sharedPrefs = await SharedPreferences.getInstance();
    return sharedPrefs;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
        future: initSharedPrefs(),
        builder:
            (BuildContext context, AsyncSnapshot<SharedPreferences> snapshot) {
          Widget child;
          if (snapshot.hasError) {
            child = const Text('Failed to retrieve settings.');
          } else if (snapshot.hasData) {
            SharedPreferences? sharedPrefsData = snapshot.data;
            if (sharedPrefsData == null) {
              child = const Text('Failed to retrieve settings.');
            } else {
              child = MultiProvider(
                  providers: [
                    ChangeNotifierProvider(create: (context) => NewNoteState()),
                    ChangeNotifierProvider(create: (context) => ThemeState()),
                  ],
                  builder: (context, child) {
                    return Consumer<ThemeState>(
                        builder: (context, themeState, child) {
                      themeState.sharedPreferences = sharedPrefsData;
                      return MaterialApp(
                        title: 'Notestream',
                        theme: themeState.lightTheme,
                        darkTheme: themeState.darkTheme,
                        themeMode: ThemeMode.values[themeState.themeMode],
                        home: const MyHomePage(
                          title: 'Notestream',
                        ),
                      );
                    });
                  });
            }
          } else {
            child = const Column(
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text('Awaiting result...'),
                ),
              ],
            );
          }
          return child;
        });
  }
}

class NoteState extends ChangeNotifier {
  bool initNeeded = true;
  Completer _refreshCompleter = Completer();
  List<Tag> filterTags = []; // Tags used to filter _noteList;
  List<Tag> _allTagsList = []; // All tags in the DB.
  final _nm = NoteManager();
  bool isCreatingNewNote = false;
  bool deletionInProgress = false;
  List<Note?> _noteList = [];
  int noteCount = 0;
  Map<String, Tag> tagNameMap = {};

  Future _initData() async {
    await _nm.loadUserNotes(withSamples: true);
    await refreshNotesAndTags();
    initNeeded = false;
  }

  void startCreatingNote() {
    isCreatingNewNote = true;
    notifyListeners();
  }

  Future finishCreatingNote() async {
    isCreatingNewNote = false;
    await refreshNotesAndTags();
    notifyListeners();
  }

  // Only use this any time the Notes are updates.
  Future refreshNotesAndTags() async {
    _refreshCompleter = Completer();
    await _getAllNotes();
    await _getAllTags();
    await loadTagNames();
    _refreshCompleter.complete();
    // notifyListeners();
  }

  Future _getAllNotes() async {
    // await _nm.loadSamples();
    _noteList = await _nm.getNotesByTags(filterTags);
    // notifyListeners();
  }

  Future _getAllTags() async {
    _allTagsList = await _nm.allTags;
    // notifyListeners();
  }

  /// Retrieves an updated noteList if the result of an operation is true.
  ///
  /// For example, if a note deletion returns true, the noteList is reloaded.
  void reloadAfterNoteDeletion(Future<bool> operationResult) async {
    _refreshCompleter = Completer();
    if (await operationResult) {
      await refreshNotesAndTags();
      notifyListeners();
    } else {
      _refreshCompleter.complete();
    }
  }

  /// Returns a list of all notes, filtered by filterTags.
  ///
  /// Ensures data is initialized before retrieving.
  /// Also ensures only the most recent data is provided.
  Future<List<Note?>> get noteList async {
    if (initNeeded) {
      await _initData();
    }
    // Wait for a possible pending refresh to be completed.
    await _refreshCompleter.future;

    return _noteList;
  }

  /// Return a list of all existing tags.
  Future<List<Tag>> get allTagsList async {
    if (initNeeded) {
      _initData();
    }

    // Wait for a possible pending refresh to be completed.
    await _refreshCompleter.future;

    return _allTagsList;
  }

  void reloadAfterNoteUpdate(Future<Note?> note) async {
    _refreshCompleter = Completer();
    if (await note != null) {
      await refreshNotesAndTags();
      notifyListeners();
    } else {
      _refreshCompleter.complete();
    }
  }

  Future validateFilterTag(String name) async {
    if (tagNameMap.keys.contains(name)) {
      filterTags.add(tagNameMap[name]!);
      // await _getAllNotes();
      await refreshNotesAndTags();

      notifyListeners();
    }
  }

  Future removeFilterTag(int index) async {
    filterTags.removeAt(index);
    await _getAllNotes();
    notifyListeners();
  }

  Future loadTagNames() async {
    for (Tag tag in _allTagsList) {
      tagNameMap.putIfAbsent(tag.name, () => tag);
    }
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    required this.title,
  });

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    super.initState();
    // The snippet below is commented out because I added it back when I knew absolutely nothing and now I know that this is only triggered AFTER the frame is rendered which is the opposite of what I think I wanted when I first added this because I'm kinda dumb.

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NewNoteState>(context, listen: false).initData();
    });
  }

  void openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => SettingsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    String notesPath;
    Widget mainPage = LayoutBuilder(builder: (context, constraints) {
      double smallestDimension =
          min(constraints.maxHeight, constraints.maxWidth);
      return Column(
        children: [
          const NewNoteButton(),
          Expanded(
              child: NoteCardList(
            cardWidth: smallestDimension,
          )),
        ],
      );
    });

    return Consumer<NewNoteState>(
      builder: (context, noteState, child) {
        return Scaffold(
          appBar: AppBar(
            title: const TagField(),
            actions: [
              IconButton(
                onPressed: () => openSettings(context),
                icon: const Icon(
                  Icons.settings,
                ),
              ),
              // PopupMenuButton(
              //   // onSelected: (item) => onSelected(context, item),
              //     itemBuilder: (context) => [
              //           const PopupMenuItem(value: 0, child: Text('Settings')),
              //         ])
            ],
          ),
          drawer: Drawer(
            // child: ListView(
            //   children: const [
            //   DrawerHeader(child: Text('Tags')),
            //   ListTile()
            //   ],
            child: ListView.builder(
              itemCount: noteState.allTagsList.length,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const DrawerHeader(
                    margin: EdgeInsets.all(0),
                    child: Text('Tags'),);
                } else {
                  var tagMapEntry = noteState.tagNameMap.entries.elementAt(index - 1);
                  return ListTile(
                    title: Text(tagMapEntry.key),
                    onTap: () {
                      noteState.addFilterTag(tagMapEntry.value);
                      Navigator.pop(context);
                    },
                  );
                }
            })
            ),
          
          body: SafeArea(
            child: noteState.notesPathIsLoaded
                ? mainPage
                : FutureBuilder<String>(
                    future: noteState.getNotesPath(),
                    builder: (context, notesPathSnapshot) {
                      Widget child;
                      if (notesPathSnapshot.hasData) {
                        notesPath = notesPathSnapshot.data!;
                        if (notesPath.isEmpty) {
                          child = const WelcomePage();
                        } else {
                          print('user note path is: $notesPath');
                          child = mainPage;
                        }
                      } else if (notesPathSnapshot.hasError) {
                        child = Column(children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 60,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text('Error: ${notesPathSnapshot.error}'),
                          ),
                        ]);
                      } else {
                        child = const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 60,
                                height: 60,
                                child: CircularProgressIndicator(),
                              ),
                              Padding(
                                padding: EdgeInsets.only(top: 16),
                                child: Text('Getting things ready...'),
                              ),
                            ],
                          ),
                        );
                      }
                      return child;
                    }),
          ),
        );
      },
    );
  }
}

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  Future<String?> _selectDirectory() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      final dir = Directory(selectedDirectory);
      if (await dir.exists()) {
        print('Selected path: $selectedDirectory as the users note folder');
        return selectedDirectory;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NewNoteState>(builder: (context, noteState, child) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Welcome to Notestream',
              ),
              const SizedBox(height: 16),
              const Text(
                'To start using Notestream, first you will need to choose a place to store your notes.\n'
                'You can also choose a folder that already contains some notes in .txt or .md format, and Notestream will import them automatically.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () async {
                  String? notesPath = await _selectDirectory();
                  if (notesPath != null) {
                    await noteState.setNotesPath(notesPath);
                  }
                },
                child: const Text('Select a folder for your notes'),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class NewNoteButton extends StatelessWidget {
  const NewNoteButton({super.key});

  @override
  Widget build(BuildContext context) {
    var noteState = context.watch<NewNoteState>();
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: FilledButton(
          onPressed: () {
            noteState.startNewNote();
          },
          child: const Text("Create new note")),
    );
  }
}
