class_name UiText
extends RefCounted

## Translated text for code that has no node to call `tr()` on: the static text modules
## (LocalServerText). Keys live in data/i18n/strings.csv; Spanish is the default locale.
## Ref: RFC-045b.

static func t(key: StringName) -> String:
	return TranslationServer.translate(key)
