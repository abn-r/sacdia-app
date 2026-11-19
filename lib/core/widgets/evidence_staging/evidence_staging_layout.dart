/// How [EvidenceStagingManager] lays out its files and actions.
enum EvidenceStagingLayout {
  /// The file grid ends with an "Add" tile that opens a source sheet, and the
  /// footer holds a single "Send N files" action.
  addTile,

  /// The previous layout: no add tile, and the footer has "Image" and "PDF"
  /// buttons above the send button. Certifications keep it on purpose.
  classic,
}
