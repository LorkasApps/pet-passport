/// Role discriminator for `contacts.role`. Drift stores the enum index,
/// so appending new roles at the end is safe; reordering breaks stored
/// rows.
enum ContactRole { sitter, trainer, groomer, other }
