import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:notestream_app/state/note_state.dart';
import 'package:notestream_app/widgets/notecard.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'widgets/settings_page.dart';
import 'widgets/tag_field.dart';
import 'state/theme_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized;
  runApp(const MyApp());
}

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
                    ChangeNotifierProvider(create: (context) => NoteState()),
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
              ],
            );
          }
          return child;
        });
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
      Provider.of<NoteState>(context, listen: false).initData();
    });
  }

  void openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    String notesPath;
    Widget mainPage = Center(
      child: LayoutBuilder(builder: (context, constraints) {
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
      }),
    );

    return Consumer<NoteState>(
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
            ],
          ),
          drawer: Drawer(
              child: ListView.builder(
                  itemCount: noteState.allTagsList.length,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return const DrawerHeader(
                        margin: EdgeInsets.all(0),
                        child: Text('Tags'),
                      );
                    } else {
                      var tagMapEntry =
                          noteState.tagNameMap.entries.elementAt(index - 1);
                      return ListTile(
                        title: Text(tagMapEntry.key),
                        onTap: () {
                          noteState.addFilterTag(tagMapEntry.value);
                          Navigator.pop(context);
                        },
                      );
                    }
                  })),
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
                          developer.log('user note path is: $notesPath');
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
        developer.log('user selected the following note path: $selectedDirectory');
        return selectedDirectory;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NoteState>(builder: (context, noteState, child) {
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
    var noteState = context.watch<NoteState>();
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
