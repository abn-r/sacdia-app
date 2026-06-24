bool hasHealthSelectionPendingChanges({
  required bool noneExplicit,
  required bool hasNewSelections,
  required bool hasModifiedRegistered,
}) {
  return noneExplicit || hasNewSelections || hasModifiedRegistered;
}
