/// A kind of app `moarch init` can start from: which checklist options are
/// ticked to begin with, and which of those cannot be unticked.
///
/// A preset only fills in the checklists, so a project is never "a fintech
/// project" afterwards: nothing records the preset, and every later command
/// detects the options from disk as usual.
class InitPreset {
  /// Creates a preset.
  const InitPreset({
    required this.slug,
    required this.name,
    required this.description,
    required this.selected,
    this.required = const <String>{},
  });

  /// What `--preset` takes.
  final String slug;

  /// What the "Project type" question shows.
  final String name;

  /// One line under [name], saying what the preset is for.
  final String description;

  /// The checklist labels ticked when the checklists open.
  final Set<String> selected;

  /// The labels that stay ticked: the options this kind of app cannot do
  /// without. Each is also in [selected].
  final Set<String> required;
}
