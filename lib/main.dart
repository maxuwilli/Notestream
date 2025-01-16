import 'package:flutter/material.dart';
import 'package:notestream_app/models/models.dart';
import 'package:notestream_app/utilities/note_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_quill/flutter_quill.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    var theme = ThemeData(
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Colors.red,
        ),
        brightness: Brightness.light,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromARGB(255, 118, 193, 124)));
    return ChangeNotifierProvider(
      create: (context) => NoteState(),
      child: MaterialApp(
        title: 'Notestream',
        theme: theme,
        darkTheme: ThemeData(
          brightness: Brightness.dark,
        ),
        themeMode: ThemeMode.light,
        home: const MyHomePage(
          title: 'Notestream',
        ),
      ),
    );
  }
}

class NoteState extends ChangeNotifier {
  final _nm = NoteManager();
  bool isCreatingNewNote = false;
  bool deletionInProgress = false;
  List<Note> _noteList = [];

  void startCreatingNote() {
    isCreatingNewNote = true;
    notifyListeners();
  }

  void finishCreatingNote() {
    isCreatingNewNote = false;
    _getAllNotes();
    notifyListeners();
  }

  void _getAllNotes() async {
    await _nm.loadSamples();
    _noteList = await _nm.allNotes;
    notifyListeners();
  }

  /// Retrieves an updated noteList if the result of an operation is true.
  ///
  /// For example, if a note deletion returns true, the noteList is reloaded.
  void reloadAfterNoteDeletion(Future<bool> operationResult) async {
    if (await operationResult) {
      _getAllNotes();
      notifyListeners();
    }
  }

  List<Note> get noteList {
    if (_noteList.isEmpty) {
      _getAllNotes();
    }
    return _noteList;
  }

  void reloadAfterNoteUpdate(Future<Note?> note) async {
    deletionInProgress = true;
    if (await note != null) {
      _getAllNotes();
      deletionInProgress = false;
      notifyListeners();
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
    // widget.storage.loadSampleNotes().then((value) {
    //   setState(() {
    //     _noteList = value;
    //   });
    // });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NoteState>(context, listen: false)._getAllNotes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NoteState>(
      builder: (context, noteState, child) {
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                const NewNoteButton(),
                NoteCardChain(noteList: noteState.noteList),
              ],
            ),
          ),
        );
      },
    );
  }
}

class TagBar extends StatefulWidget {
  const TagBar({super.key});

  @override
  State<TagBar> createState() => _TagBarState();
}

class _TagBarState extends State<TagBar> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class TagButton extends StatefulWidget {
  const TagButton({
    super.key,
    required this.tag,
  });

  final Tag tag;

  @override
  State<TagButton> createState() => _TagButtonState();
}

class _TagButtonState extends State<TagButton> {
  bool isEngaged = false;

  void toggle() {
    isEngaged = !isEngaged;
  }

  @override
  Widget build(BuildContext context) {
    return isEngaged
        ? FilledButton.tonalIcon(
            onPressed: () {},
            label: Text(widget.tag.name),
            icon: const Icon(Icons.tag),
          )
        : ElevatedButton.icon(
            onPressed: () {},
            label: Text(widget.tag.name),
            icon: const Icon(Icons.tag),
          );
  }
}

class NewNoteButton extends StatelessWidget {
  const NewNoteButton({super.key});

  @override
  Widget build(BuildContext context) {
    var noteState = context.watch<NoteState>();
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ElevatedButton(
          onPressed: () {
            noteState.startCreatingNote();
          },
          child: const Text("Create new note")),
    );
  }
}

class NoteCardChain extends StatelessWidget {
  const NoteCardChain({
    super.key,
    required this.noteList,
  });

  final List<Note> noteList;

  @override
  Widget build(BuildContext context) {
    // var noteState = context.watch<NoteState>();
    // var notes = noteState.noteList;
    return Expanded(
      child: ListView(
        children: [
          const NewBlankNote(),
          for (Note note in noteList)
            FractionallySizedBox(
              widthFactor: 0.9,
              child: Align(
                // widthFactor: 0.5,
                alignment: Alignment.topLeft,
                child: NoteCard(
                  note: note,
                ),
              ),
            )
        ],
      ),
    );
  }
}

class NewBlankNote extends StatelessWidget {
  const NewBlankNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NoteState>(
      builder: (context, noteState, child) {
        return noteState.isCreatingNewNote
            ? const FractionallySizedBox(
                widthFactor: 0.9,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: NoteCard(note: null),
                ),
              )
            : const SizedBox.shrink();
      },
    );
  }
}

/// Parent widget for individual Note content.
///
/// If instantiated with a null Note, creates a 'Blank card'.
/// A blank card can edited and saved as a new note, or be discarded.
class NoteCard extends StatefulWidget {
  const NoteCard({
    super.key,
    required this.note,
  });
  final Note? note;

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
  late bool isBlankNote;
  final nm = NoteManager();
  Future<String> get noteContent async {
    return await nm.getNoteContent(widget.note);
  }

  @override
  void initState() {
    if (widget.note == null) {
      isBlankNote = true;
    } else {
      isBlankNote = false;
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var noteState = context.watch<NoteState>();
    return isBlankNote
        ? const InnerNoteCard(
            isBlankCard: true,
            note: null,
          )
        : FutureBuilder(
            future: noteContent,
            builder: (BuildContext context,
                AsyncSnapshot<String> noteContentSnapshot) {
              Widget loadWidget;
              if (noteContentSnapshot.hasData) {
                String content = '';
                if (noteContentSnapshot.data != null) {
                  if (noteState.deletionInProgress) {
                    content = 'Deletion in progress...';
                  }
                  content = noteContentSnapshot.data!;
                }
                loadWidget = InnerNoteCard(
                  content: content,
                  note: widget.note,
                );
                // loadWidget = Text("Wazzap");
              } else if (noteContentSnapshot.hasError) {
                loadWidget =
                    loadWidget = const Text("Failed to load note content.");
              } else {
                loadWidget = Container(
                  color: Colors.white,
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              return loadWidget;
            });
  }
}

class InnerNoteCard extends StatefulWidget {
  const InnerNoteCard({
    super.key,
    required this.note,
    this.content = '',
    this.isBlankCard = false,
  });

  final Note? note;
  final bool isBlankCard;
  final String content;

  @override
  State<InnerNoteCard> createState() => _InnerNoteCardState();
}

class _InnerNoteCardState extends State<InnerNoteCard> {
  late bool _isEditing;
  late String leadingHeader;

  @override
  void initState() {
    _isEditing = widget.isBlankCard;
    if (widget.note == null) {
      leadingHeader = "What's on your mind?";
    } else {
      leadingHeader = widget.note!.modifiedAt!;
    }
    super.initState();
  }

  void toggleEditor() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget cardInner;
    if (!_isEditing) {
      cardInner = Card(
        shadowColor: Theme.of(context).colorScheme.primary,
        color: Theme.of(context).colorScheme.inversePrimary,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.min,
                // crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    leadingHeader,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  // Text(
                  //   leadingHeader,
                  //   style: Theme.of(context).textTheme.bodySmall,
                  // ),
                ],
              ),
              MarkdownBody(
                selectable: true,
                data: widget.content,
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
              ),
            ],
          ),
        ),
      );
    } else {
      cardInner = Card(
        shadowColor: Theme.of(context).colorScheme.primary,
        color: Theme.of(context).colorScheme.inversePrimary,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    leadingHeader,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              EditingNoteCardInner(
                isNew: widget.isBlankCard,
                onEditorClose: toggleEditor,
                widget: widget,
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        GestureDetector(
            onLongPress: () {
              toggleEditor();
            },
            child: cardInner),
      ],
    );
  }
}

class EditingNoteCardInner extends StatefulWidget {
  const EditingNoteCardInner({
    super.key,
    required this.widget,
    required this.onEditorClose,
    required this.isNew,
    // required this.noteContent,
  });

  final InnerNoteCard widget;
  final Function() onEditorClose;
  final bool isNew;
  // final String noteContent;

  @override
  State<EditingNoteCardInner> createState() => _EditingNoteCardInnerState();
}

class _EditingNoteCardInnerState extends State<EditingNoteCardInner> {
  // late TextEditingController _textEditingController;
  late QuillController _quillController;

  @override
  void initState() {
    super.initState();
    // _textEditingController = TextEditingController();
    _quillController = QuillController.basic();
  }

  @override
  void dispose() {
    // _textEditingController.dispose();
    _quillController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var noteState = context.watch<NoteState>();
    NoteManager nm = NoteManager();
    var textTheme = const TextSelectionThemeData(
      cursorColor: Colors.black,
      selectionColor: Colors.black,
    );
    var quillEditorConfigs = const QuillEditorConfigurations(
      showCursor: true,
      // textSelectionThemeData: textTheme,
    );
    if (!widget.isNew) {
      var document = Document()..insert(0, widget.widget.content);
      _quillController.document = document;
    }
    return Card(
      shadowColor: Theme.of(context).colorScheme.shadow,
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          spacing: 24.0,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.max,
          children: [
            QuillEditor.basic(
              controller: _quillController,
              configurations: quillEditorConfigs,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    String editedContent =
                        _quillController.document.toPlainText().trim();
                    widget.isNew
                        ? noteState.reloadAfterNoteUpdate(
                            nm.saveNewNote(editedContent))
                        : noteState.reloadAfterNoteUpdate(nm.updateExistingNote(
                            editedContent, widget.widget.note!));

                    // This triggers state in the parent and updates the view to close the editor.
                    widget.onEditorClose();
                    if (widget.isNew) noteState.finishCreatingNote();
                  },
                  label: const Icon(
                    Icons.done,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    // This triggers state in the parent and updates the view to close the editor.
                    widget.onEditorClose();

                    // Disable the blank note card.
                    if (widget.isNew) noteState.finishCreatingNote();
                  },
                  label: const Icon(
                    Icons.cancel,
                  ),
                ),
                if (!widget.isNew)
                  ElevatedButton.icon(
                    onPressed: () {
                      // Triggers a deletion and then sends the result of the operation to noteState.
                      noteState.reloadAfterNoteDeletion(
                          nm.deleteNote(widget.widget.note!));
                      // This triggers state in the parent and updates the view to close the editor.
                      widget.onEditorClose();
                    },
                    label: const Icon(
                      Icons.delete,
                    ),
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
