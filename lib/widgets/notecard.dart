import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:notestream_app/models/models.dart';
import 'package:notestream_app/state/note_state.dart';
import 'package:notestream_app/utilities/note_manager.dart';
import 'package:provider/provider.dart';

// TODO: NoteCardList is a replacement for NoteCardChain
class NoteCardList extends StatelessWidget {
  const NoteCardList({
    super.key,
    required this.cardWidth,
  });

  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    // TODO: NewNoteState is a replacement for NoteState, so refactor accordingly.
    return Consumer<NoteState>(builder: (context, noteState, child) {
      // bool isCreatingNewNote = noteState.isCreatingNewNote;
      // int newNote = isCreatingNewNote ? 1 : 0;
      return SizedBox(
        width: cardWidth,
        child: ListView.builder(
          itemCount: noteState.noteList.length,
          itemBuilder: (context, index) {
            Note? note = noteState.noteList[index];
            return FractionallySizedBox(
              widthFactor: 0.9,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: NoteCard(key: ObjectKey(note), note: note),
              ),
            );
          },
        ),
      );
    });
  }
}

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
  final NoteManager nm = NoteManager();
  late NoteState nState;
  late bool isEditing;
  late bool isNewNote;
  late Note? note;
  late String content;
  late String leadingHeader;

  @override
  void initState() {
    note = widget.note;
    if (widget.note == null) {
      isNewNote = true;
      isEditing = true;
      leadingHeader = "What's on your mind?";
    } else {
      isNewNote = false;
      isEditing = false;
      leadingHeader = widget.note!.modifiedAt!;
    }
    nState = context.read<NoteState>();
    content = nState.getNoteContent(note) ?? '';
    super.initState();
  }

  /// Sends the new content to the NoteState for updating.
  ///
  /// No need to change the widget state, as the change provider will notify the parent to rebuild this widget with updated content.
  void finishEditing(bool canceled, String newContent) async {
    if (!canceled) {
      if (newContent.isNotEmpty) {
        if (isNewNote) {
          nState.saveNewNote(newContent);
        } else {
          note = await nState.saveNoteChanges(widget.note!, newContent);
        }
      }
    } else {
      if (isNewNote) {
        await nState.cancelNewNote();
      }
      setState(() {
        isEditing = false;
      });
    }
    if (isNewNote) {
      nState.finishNewNote();
    }
  }

  void toggleEditor() {
    if (isEditing == false) {
      setState(() {
        isEditing = true;
      });
    }
  }

  // Future<String> retrieveNoteContent() async {
  //   if (widget.note != null) {
  //     return await nm.getNoteContent(widget.note!.location);
  //   } else {
  //     return '';
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Consumer<NoteState>(builder: (context, noteState, child) {
      Widget innerCard = isEditing
          ? EditingNoteCardInner(
              widget: widget,
              onEditingFinish: finishEditing,
              isNewNote: isNewNote,
              content: content,
            )
          : StaticNoteCardInner(
              content: content,
            );

      Widget outerCard = Card(
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
              innerCard,
            ],
          ),
        ),
      );

      return GestureDetector(
        onLongPress: () {
          toggleEditor();
        },
        child: outerCard,
      );
    });
  }
}

// ----

class EditingNoteCardInner extends StatefulWidget {
  const EditingNoteCardInner({
    super.key,
    required this.widget,
    required this.onEditingFinish,
    required this.isNewNote,
    required this.content,
  });

  final Function onEditingFinish;
  final bool isNewNote;
  final String content;
  final NoteCard widget;

  @override
  State<EditingNoteCardInner> createState() => _EditingNoteCardInnerState();
}

class _EditingNoteCardInnerState extends State<EditingNoteCardInner> {
  late QuillController _quillController;

  @override
  void initState() {
    _quillController = QuillController.basic();
    super.initState();
  }

  @override
  void dispose() {
    _quillController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NoteState>(builder: (context, noteState, child) {
      var quillEditorConfigs = const QuillEditorConfigurations(
        showCursor: true,
        // textSelectionThemeData: textTheme,
      );
      if (!widget.isNewNote) {
        var document = Document()..insert(0, widget.content);
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
                  // Save changes or new note.
                  ElevatedButton.icon(
                    onPressed: () {
                      String editedContent =
                          _quillController.document.toPlainText().trim();
                      widget.onEditingFinish(false, editedContent);
                    },
                    label: const Icon(
                      Icons.done,
                    ),
                  ),
                  // Cancel changes.
                  ElevatedButton.icon(
                    onPressed: () {
                      // This triggers state in the parent and updates the view to close the editor.
                      widget.onEditingFinish(true, '');
                    },
                    label: const Icon(
                      Icons.cancel,
                    ),
                  ),
                  if (!widget.isNewNote)
                    ElevatedButton.icon(
                      onPressed: () {
                        // Triggers a deletion.
                        noteState.deleteNote(widget.widget.note!);
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
    });
  }
}

// ----

class StaticNoteCardInner extends StatelessWidget {
  const StaticNoteCardInner({
    super.key,
    required this.content,
  });

  final String content;

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      selectable: true,
      data: content,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
    );
  }
}
