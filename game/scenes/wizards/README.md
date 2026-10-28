# wizards

The wizards: `wizard_body.tscn` (the body the player or the AI drives), `WizardSpawner` and `WizardType`
(`data/catalog/wizards/<name>.tres`).
- `Drive` (`WizardDrive`) is the only writer of the wizard's movement each tick. The kit's `MpActor` predicts it for the
  owner and draws it buffered on other peers; an AI seat does not predict.
- Replicated properties are listed in `MpActor` › `sync_extra`; save the scene after changing it.
- `GhostForm` handles death and return to the altar; `DeathLook` lays the body down as a ragdoll.
- The book is the god's, unless `WizardBody.book` is set (local only, never sent over the network).
