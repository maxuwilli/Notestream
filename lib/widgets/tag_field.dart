import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:textfield_tags/textfield_tags.dart';
import 'package:notestream_app/state/note_state.dart';
import '../models/models.dart';

class TagField extends StatefulWidget {
  const TagField({super.key});

  @override
  State<TagField> createState() => _TagFieldState();
}

class _TagFieldState extends State<TagField> {
  late double _distanceToField;
  late StringTagController _stringTagController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _distanceToField = MediaQuery.of(context).size.width;
  }

  @override
  void initState() {
    super.initState();
    _stringTagController = StringTagController();
  }

  @override
  void dispose() {
    super.dispose();
    _stringTagController.dispose();
  }

   static const List<String> _initialTags = [];

  @override
  Widget build(BuildContext context) {
    return Consumer<NoteState>(builder: (context, noteState, child) {
      Map<String, Tag> tagNameMap = noteState.tagNameMap;
      List<Tag> filterTagsList = noteState.filterTagsMap.values.toList();

      // Add currently active filter tags; necessary due to tags enabled via the tag drawer in the appBar.
      List<String>? currentTags = _stringTagController.getTags;
      currentTags ??= [];
      for (Tag tag in filterTagsList) {
        if (!currentTags.contains(tag.name)) {
        _stringTagController.onTagSubmitted(tag.name);
        }
      }


      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          children: [
            Autocomplete<String>(
              optionsViewBuilder: (context, onSelected, options) {
                return Container(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 10.0, vertical: 4.0),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Material(
                      elevation: 4.0,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (BuildContext context, int index) {
                            final String option = options.elementAt(index);
                            return TextButton(
                              onPressed: () {
                                onSelected(option);
                              },
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '#$option',
                                  textAlign: TextAlign.left,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text == '') {
                  return const Iterable<String>.empty();
                }
                return tagNameMap.keys.where((String option) {
                  return option.contains(textEditingValue.text.toLowerCase());
                });
              },
              onSelected: (String selectedTag) {
                _stringTagController.onTagSubmitted(selectedTag);
                noteState.validateFilterTag(selectedTag);
              },
              fieldViewBuilder: (context, textEditingController, focusNode,
                  onFieldSubmitted) {
                return TextFieldTags<String>(
                  textEditingController: textEditingController,
                  focusNode: focusNode,
                  textfieldTagsController: _stringTagController,
                  initialTags: _initialTags,
                  textSeparators: const [' ', ','],
                  letterCase: LetterCase.normal,
                  validator: (String tag) {
                    noteState.validateFilterTag(tag);
                    return null;
                  },
                  inputFieldBuilder: (context, inputFieldValues) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      child: TextField(
                        controller: inputFieldValues.textEditingController,
                        focusNode: inputFieldValues.focusNode,
                        decoration: InputDecoration(
                          // contentPadding: const EdgeInsets.all(16.0),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 3.0,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 3.0,
                            ),
                          ),
                          // helperText: 'Filter by tags...',
                          helperStyle: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          hintText: inputFieldValues.tags.isNotEmpty
                              ? ''
                              : "Enter tag...",
                          errorText: inputFieldValues.error,
                          prefixIconConstraints:
                              BoxConstraints(maxWidth: _distanceToField * 0.74),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: inputFieldValues.tags.isNotEmpty
                                ? SingleChildScrollView(
                                    controller:
                                        inputFieldValues.tagScrollController,
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                        children: inputFieldValues.tags
                                            .map((String tag) {
                                      return Container(
                                        decoration: BoxDecoration(
                                          borderRadius: const BorderRadius.all(
                                            Radius.circular(20.0),
                                          ),
                                          color:
                                              Theme.of(context).colorScheme.primary,
                                        ),
                                        margin:
                                            const EdgeInsets.only(right: 10.0),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10.0, vertical: 4.0),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            InkWell(
                                              child: Text(
                                                '#$tag',
                                                style: const TextStyle(
                                                    color: Colors.white),
                                              ),
                                              onTap: () {
                                              },
                                            ),
                                            const SizedBox(width: 4.0),
                                            InkWell(
                                              child: const Icon(
                                                Icons.cancel,
                                                size: 14.0,
                                                color: Color.fromARGB(
                                                    255, 233, 233, 233),
                                              ),
                                              onTap: () {
                                                inputFieldValues
                                                    .onTagRemoved(tag);
                                                noteState.removeFilterTagByName(tag);
                                              },
                                            )
                                          ],
                                        ),
                                      );
                                    }).toList()),
                                  )
                                : null,
                          ),
                        ),
                        onChanged: inputFieldValues.onTagChanged,
                        onSubmitted: inputFieldValues.onTagSubmitted,
                      ),
                    );
                  },
                );
              },
            ),
            // ElevatedButton(
            //   style: ButtonStyle(
            //     backgroundColor: WidgetStateProperty.all<Color>(
            //       Theme.of(context).colorScheme.primary,
            //     ),
            //   ),
            //   onPressed: () {
            //     _stringTagController.clearTags();
            //   },
            //   child: const Text(
            //     'Clear tags',
            //     style: TextStyle(color: Colors.white),
            //   ),
            // ),
          ],
        ),
      );
    });
  }
}