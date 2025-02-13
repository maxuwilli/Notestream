import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:notestream_app/models/models.dart';
import 'package:notestream_app/note_state.dart';
import 'package:notestream_app/notecard.dart';
import 'package:notestream_app/utilities/note_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:material_tag_editor/tag_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:field_suggestion/field_suggestion.dart';
import 'settings_page.dart';
import 'tag_field.dart';

void main() async {
  // WidgetsFlutterBinding.ensureInitialized;
  // await SharedPrefs().init();
  runApp(const MyApp());
}

// Shared preferences for global use.

const String keyThemeColor = "theme_color";
var themeColor = const Color.fromARGB(255, 243, 208, 33);
var themeColorString = themeColor.value;

class SharedPrefs {
  late final SharedPreferences _sharedPrefs;
  static final SharedPrefs _instance = SharedPrefs._internal();
  factory SharedPrefs() => _instance;
  SharedPrefs._internal();

  init() async {
    _sharedPrefs = await SharedPreferences.getInstance();
    if (themeColor == '') {}
  }

  String get themeColor => _sharedPrefs.getString(keyThemeColor) ?? '';

  set themeColor(String value) {
    _sharedPrefs.setString(keyThemeColor, value);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    var lightTheme = ThemeData(
      scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Consolas',
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Colors.red,
        ),
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 202, 161, 15),
          // brightness: Brightness.dark,
        ));
    var darkTheme = ThemeData(
      // scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Consolas',
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Colors.red,
        ),
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 202, 161, 15),
          brightness: Brightness.dark,
        ));
    return ChangeNotifierProvider(
        create: (context) => NewNoteState(),
        builder: (context, child) {
          return MaterialApp(
            title: 'Notestream',
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: ThemeMode.system,
            home: const MyHomePage(
              title: 'Notestream',
            ),
          );
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
  List<Note> _noteList = [];
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
  Future<List<Note>> get noteList async {
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
      MaterialPageRoute(builder: (context) => const SettingsPage()),
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
          // CustomTagField(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                const Expanded(child: TagField()),
                IconButton(
                  onPressed: () => openSettings(context),
                  icon: const Icon(Icons.settings),
                )
              ],
            ),
          ),
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
          // appBar: AppBar(
          //   actions: [
          //     PopupMenuButton(
          //       onSelected: (item) => onSelected(context, item),
          //         itemBuilder: (context) => [
          //               const PopupMenuItem(value: 0, child: Text('Settings')),
          //             ])
          //   ],
          // ),
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

// class CustomTagField extends StatefulWidget {
//   const CustomTagField({super.key});

//   // final List<String> initTagValues;

//   @override
//   State<CustomTagField> createState() => _CustomTagFieldState();
// }

// class _CustomTagFieldState extends State<CustomTagField> {
//   String hintText = 'Filter using tags...';

//   void changeHintText(String text) {
//     setState(() {
//       hintText = text;
//     });
//   }

//   @override
//   void initState() {
//     // values = widget.initTagValues;
//     super.initState();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Consumer<NewNoteState>(builder: (context, noteState, child) {
//       // List<Tag> allTags = noteState.allTagsList;
//       List<Tag> filterTags = noteState.filterTagsList;
//       return Padding(
//         padding: const EdgeInsets.all(8.0),
//         child: TagEditor(
//           length: filterTags.length,
//           delimiters: const [',', ' '],
//           hasAddButton: true,
//           inputDecoration: InputDecoration(
//             border: const OutlineInputBorder(),
//             hintText: hintText,
//           ),
//           onTagChanged: (newValue) {
//             // setState(() {
//             noteState.validateFilterTag(newValue);
//             // });
//           },
//           tagBuilder: (context, index) => Padding(
//             padding: const EdgeInsets.all(2.0),
//             child: Chip(
//               label: Text('#${filterTags[index].name}'),
//               deleteIcon: const Icon(Icons.remove),
//               deleteIconColor: Colors.red,
//               onDeleted: () => {noteState.removeFilterTag(index)},
//             ),
//           ),
//         ),
//       );
//     });
//   }
// }

// class TagBar extends StatefulWidget {
//   const TagBar({super.key});

//   @override
//   State<TagBar> createState() => _TagBarState();
// }

// class _TagBarState extends State<TagBar> {
//   @override
//   Widget build(BuildContext context) {
//     return const Placeholder();
//   }
// }

// class TagButton extends StatefulWidget {
//   const TagButton({
//     super.key,
//     required this.tag,
//   });

//   final Tag tag;

//   @override
//   State<TagButton> createState() => _TagButtonState();
// }

// class _TagButtonState extends State<TagButton> {
//   bool isEngaged = false;

//   void toggle() {
//     isEngaged = !isEngaged;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return isEngaged
//         ? FilledButton.tonalIcon(
//             onPressed: () {},
//             label: Text(widget.tag.name),
//             icon: const Icon(Icons.tag),
//           )
//         : ElevatedButton.icon(
//             onPressed: () {},
//             label: Text(widget.tag.name),
//             icon: const Icon(Icons.tag),
//           );
//   }
// }

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

// class NoteCardChain extends StatelessWidget {
//   const NoteCardChain({
//     super.key,
//     required this.noteList,
//   });

//   final List<Note> noteList;

//   @override
//   Widget build(BuildContext context) {
//     // var noteState = context.watch<NoteState>();
//     // var notes = noteState.noteList;
//     return Expanded(
//       child: ListView(
//         addAutomaticKeepAlives: true,
//         children: [
//           const NewBlankNote(),
//           for (Note note in noteList)
//             FractionallySizedBox(
//               widthFactor: 0.9,
//               child: Align(
//                 // widthFactor: 0.5,
//                 alignment: Alignment.topLeft,
//                 child: NoteCard(
//                   note: note,
//                 ),
//               ),
//             )
//         ],
//       ),
//     );
//   }
// }

// class NewBlankNote extends StatelessWidget {
//   const NewBlankNote({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Consumer<NoteState>(
//       builder: (context, noteState, child) {
//         return noteState.isCreatingNewNote
//             ? const FractionallySizedBox(
//                 widthFactor: 0.9,
//                 child: Align(
//                   alignment: Alignment.topLeft,
//                   child: NoteCard(note: null),
//                 ),
//               )
//             : const SizedBox.shrink();
//       },
//     );
//   }
// }

/// Parent widget for individual Note content.
///
/// If instantiated with a null Note, creates a 'Blank card'.
/// A blank card can edited and saved as a new note, or be discarded.
// class NoteCard extends StatefulWidget {
//   const NoteCard({
//     super.key,
//     required this.note,
//   });
//   final Note? note;

//   @override
//   State<NoteCard> createState() => _NoteCardState();
// }

// class _NoteCardState extends State<NoteCard>
//     with AutomaticKeepAliveClientMixin {
//   late bool isBlankNote;
//   final nm = NoteManager();

//   Future<String> get noteContent async {
//     if (widget.note != null) {
//       return await nm.getNoteContent(widget.note!.location);
//     } else {
//       return '';
//     }
//   }

//   @override
//   void initState() {
//     if (widget.note == null) {
//       isBlankNote = true;
//     } else {
//       isBlankNote = false;
//     }
//     super.initState();
//   }

//   @override
//   Widget build(BuildContext context) {
//     super.build(context);
//     print(widget.note.toString());
//     // var noteState = context.watch<NoteState>();
//     return isBlankNote
//         ? const InnerNoteCard(
//             isBlankCard: true,
//             note: null,
//           )
//         : FutureBuilder(
//             future: noteContent,
//             builder: (BuildContext context,
//                 AsyncSnapshot<String> noteContentSnapshot) {
//               Widget loadWidget;
//               if (noteContentSnapshot.hasData) {
//                 String content = '';
//                 if (noteContentSnapshot.data != null) {
//                   content = noteContentSnapshot.data!;
//                 }
//                 loadWidget = InnerNoteCard(
//                   content: content,
//                   note: widget.note,
//                 );
//                 // loadWidget = Text("Wazzap");
//               } else if (noteContentSnapshot.hasError) {
//                 loadWidget =
//                     loadWidget = const Text("Failed to load note content.");
//               } else {
//                 loadWidget = Container(
//                   color: Colors.white,
//                   child: const Center(
//                     child: CircularProgressIndicator(),
//                   ),
//                 );
//               }
//               return loadWidget;
//             });
//   }

//   @override
//   bool get wantKeepAlive => true;
// }

// class InnerNoteCard extends StatefulWidget {
//   const InnerNoteCard({
//     super.key,
//     required this.note,
//     this.content = '',
//     this.isBlankCard = false,
//   });

//   final Note? note;
//   final bool isBlankCard;
//   final String content;

//   @override
//   State<InnerNoteCard> createState() => _InnerNoteCardState();
// }

// class _InnerNoteCardState extends State<InnerNoteCard> {
//   late bool _isEditing;
//   late String leadingHeader;

//   @override
//   void initState() {
//     _isEditing = widget.isBlankCard;
//     if (widget.note == null) {
//       leadingHeader = "What's on your mind?";
//     } else {
//       leadingHeader = widget.note!.modifiedAt!;
//     }
//     super.initState();
//   }

//   void toggleEditor() {
//     setState(() {
//       _isEditing = !_isEditing;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     Widget cardInner;
//     if (!_isEditing) {
//       cardInner = Card(
//         shadowColor: Theme.of(context).colorScheme.primary,
//         color: Theme.of(context).colorScheme.inversePrimary,
//         child: Padding(
//           padding: const EdgeInsets.all(8.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Row(
//                 // mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 mainAxisSize: MainAxisSize.min,
//                 // crossAxisAlignment: CrossAxisAlignment.end,
//                 children: [
//                   Text(
//                     leadingHeader,
//                     style: Theme.of(context).textTheme.bodySmall,
//                   ),
//                   // Text(
//                   //   leadingHeader,
//                   //   style: Theme.of(context).textTheme.bodySmall,
//                   // ),
//                 ],
//               ),
//               MarkdownBody(
//                 selectable: true,
//                 data: widget.content,
//                 styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
//               ),
//             ],
//           ),
//         ),
//       );
//     } else {
//       cardInner = Card(
//         shadowColor: Theme.of(context).colorScheme.primary,
//         color: Theme.of(context).colorScheme.inversePrimary,
//         child: Padding(
//           padding: const EdgeInsets.all(8.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Text(
//                     leadingHeader,
//                     style: Theme.of(context).textTheme.bodySmall,
//                   ),
//                 ],
//               ),
//               EditingNoteCardInner(
//                 isNew: widget.isBlankCard,
//                 onEditorClose: toggleEditor,
//                 widget: widget,
//               ),
//             ],
//           ),
//         ),
//       );
//     }
//     return Column(
//       children: [
//         GestureDetector(
//             onLongPress: () {
//               toggleEditor();
//             },
//             child: cardInner),
//       ],
//     );
//   }
// }

// class EditingNoteCardInner extends StatefulWidget {
//   const EditingNoteCardInner({
//     super.key,
//     required this.widget,
//     required this.onEditorClose,
//     required this.isNew,
//     // required this.noteContent,
//   });

//   final InnerNoteCard widget;
//   final Function() onEditorClose;
//   final bool isNew;
//   // final String noteContent;

//   @override
//   State<EditingNoteCardInner> createState() => _EditingNoteCardInnerState();
// }

// class _EditingNoteCardInnerState extends State<EditingNoteCardInner> {
//   // late TextEditingController _textEditingController;
//   late QuillController _quillController;

//   @override
//   void initState() {
//     super.initState();
//     // _textEditingController = TextEditingController();
//     _quillController = QuillController.basic();
//   }

//   @override
//   void dispose() {
//     // _textEditingController.dispose();
//     _quillController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     var noteState = context.watch<NoteState>();
//     NoteManager nm = NoteManager();
//     var textTheme = const TextSelectionThemeData(
//       cursorColor: Colors.black,
//       selectionColor: Colors.black,
//     );
//     var quillEditorConfigs = const QuillEditorConfigurations(
//       showCursor: true,
//       // textSelectionThemeData: textTheme,
//     );
//     if (!widget.isNew) {
//       var document = Document()..insert(0, widget.widget.content);
//       _quillController.document = document;
//     }
//     return Card(
//       shadowColor: Theme.of(context).colorScheme.shadow,
//       color: Theme.of(context).colorScheme.primaryContainer,
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           spacing: 24.0,
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           mainAxisSize: MainAxisSize.max,
//           children: [
//             QuillEditor.basic(
//               controller: _quillController,
//               configurations: quillEditorConfigs,
//             ),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               crossAxisAlignment: CrossAxisAlignment.center,
//               children: [
//                 ElevatedButton.icon(
//                   onPressed: () {
//                     String editedContent =
//                         _quillController.document.toPlainText().trim();
//                     widget.isNew
//                         ? noteState.reloadAfterNoteUpdate(
//                             nm.saveNewNote(editedContent))
//                         : noteState.reloadAfterNoteUpdate(nm.updateExistingNote(
//                             editedContent, widget.widget.note!));

//                     // This triggers state in the parent and updates the view to close the editor.
//                     widget.onEditorClose();
//                     if (widget.isNew) noteState.finishCreatingNote();
//                   },
//                   label: const Icon(
//                     Icons.done,
//                   ),
//                 ),
//                 ElevatedButton.icon(
//                   onPressed: () {
//                     // This triggers state in the parent and updates the view to close the editor.
//                     widget.onEditorClose();

//                     // Disable the blank note card.
//                     if (widget.isNew) noteState.finishCreatingNote();
//                   },
//                   label: const Icon(
//                     Icons.cancel,
//                   ),
//                 ),
//                 if (!widget.isNew)
//                   ElevatedButton.icon(
//                     onPressed: () {
//                       // Triggers a deletion and then sends the result of the operation to noteState.
//                       noteState.reloadAfterNoteDeletion(
//                           nm.deleteNote(widget.widget.note!));
//                       // This triggers state in the parent and updates the view to close the editor.
//                       widget.onEditorClose();
//                     },
//                     label: const Icon(
//                       Icons.delete,
//                     ),
//                   ),
//               ],
//             )
//           ],
//         ),
//       ),
//     );
//   }
// }
