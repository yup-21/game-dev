extends RefCounted
## Definition registry: authoring metadata and links, never combat-side effects.
## Does not require a definition to be present in an initial deck.
var error: String = ""

func register(store: Dictionary, definition: Dictionary) -> bool:
	if str(definition.get("id", "")).is_empty() or store.has(str(definition.id)):
		error="Duplicate/empty card definition id"
		return false
	if not valid_relations(definition):
		error="Invalid card relations: " + str(definition.id)
		return false
	if definition.get("lifecycle", "normal") not in ["normal", "exile_on_finish"]:
		error="Invalid card lifecycle: " + str(definition.id)
		return false
	var retention = definition.get("retain_own_actions", 0)
	if not (retention is int or retention is float) or not is_finite(float(retention)) or retention < 0 or retention > 20 or (retention is float and retention != floor(retention)):
		error="Invalid retention: "+str(definition.id)
		return false
	store[str(definition.id)] = definition.duplicate(true)
	return true

func valid_relations(definition: Dictionary) -> bool:
	var relation = definition.get("relations", {})
	if not relation is Dictionary: return false
	for key in relation:
		if key not in ["parent", "children", "related"]: return false
	if relation.has("parent") and (not relation.parent is String or relation.parent == definition.id): return false
	for key in ["children", "related"]:
		var entries = relation.get(key, [])
		if not entries is Array: return false
		var seen: Dictionary = {}
		for id in entries:
			if not id is String or id.is_empty() or id == definition.id or seen.has(id): return false
			seen[id] = true
	return true

func verify(store: Dictionary) -> bool:
	for definition in store.values():
		var relation: Dictionary = definition.get("relations", {})
		var references: Array = relation.get("children", []).duplicate()
		references.append_array(relation.get("related", []))
		if relation.has("parent") and not str(relation.parent).is_empty(): references.append(relation.parent)
		for id in references:
			if not store.has(id):
				error="Unknown related card: "+str(definition.id)+" -> "+str(id)
				return false
		for usage in definition.get("usages", []):
			if not verify_effects(usage.get("effects", []), store, str(definition.id)): return false
	return true

func verify_effects(effects: Array, store: Dictionary, owner: String) -> bool:
	for effect in effects:
		if not effect is Dictionary: return false
		if str(effect.get("type", "")) == "grant_card" and not store.has(str(effect.get("card_id", ""))):
			error="Unknown grant_card target: "+owner+" -> "+str(effect.get("card_id",""))
			return false
		for key in ["effects", "on_success", "on_contested", "on_failure", "on_hit"]:
			if effect.has(key) and not verify_effects(effect[key], store, owner): return false
	return true

func related(store: Dictionary, id: String, kind: String) -> Array:
	if not store.has(id) or kind not in ["children", "related"]: return []
	return store[id].get("relations", {}).get(kind, []).duplicate()
