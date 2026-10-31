extends SceneTree
## R18: author a character, buff and item with .tres only; exercise old runtime.
const NativeContent = preload("res://scripts/content/content_registry.gd")
const ContentManifest = preload("res://scripts/content/content_manifest.gd")
const CharacterDefinition = preload("res://scripts/content/character_definition.gd")
const CharacterRegistry = preload("res://scripts/character_registry.gd")
const StatusCatalog = preload("res://scripts/status_catalog.gd")
const ItemCatalog = preload("res://scripts/item_catalog.gd")
const CharacterRuntime = preload("res://scripts/character_runtime.gd")

const FIXTURE = "res://data/native_examples.tres"
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        printerr("R18 NATIVE FAIL: " + label)

func _run() -> void:
    var native = NativeContent.new(FIXTURE)
    check(native.load_error.is_empty(), "load .tres manifest: " + native.load_error)
    var character: Dictionary = native.entries("character").get("r18_guest_swordsman", {})
    check(character.get("name") == "试剑游侠", "typed character card converts to read-only record")
    check(str(character.get("art", {}).get("portrait", "")).begins_with("res://assets/"),
        "native texture reference is bound")
    var buffs: Dictionary = native.entries("buff")
    check(buffs.has("r18_steady_breath"), "typed buff registered")
    var items: Dictionary = native.entries("item")
    check(items.has("r18_field_medicine"), "typed consumable registered")

    # Test native additions with the actual catalogs; legacy definitions remain intact.
    var characters = CharacterRegistry.new("res://data/characters/index.json",
        "res://data/characters/", FIXTURE)
    check(characters.load_error.is_empty(), "character schema and school references pass")
    check(characters.get_profile("shen_changfeng").get("id") == "shen_changfeng",
        "existing character stays available")
    var battle_options: Dictionary = characters.battle_options([], {81: "r18_guest_swordsman"})
    check(battle_options.get("character_ids", {}).get(81, "") == "r18_guest_swordsman",
        "native character enters existing battle options without core edits")

    var statuses = StatusCatalog.new(StatusCatalog.DEFAULT_INDEX, FIXTURE)
    check(statuses.load_error.is_empty() and statuses.get_buff("r18_steady_breath").get("stack_limit") == 2,
        "native buff passes existing status validation")
    var catalog = ItemCatalog.new(ItemCatalog.DEFAULT_INDEX, null, FIXTURE)
    check(catalog.load_error.is_empty() and catalog.get_item("r18_field_medicine").get("kind") == "consumable",
        "native item passes existing item validation")
    # The default production manifest is empty while the old dataset migrates.
    check(ItemCatalog.new().definitions.size() == 4, "legacy default catalog count preserved")

    var malformed = ContentManifest.new()
    var incomplete = CharacterDefinition.new()
    incomplete.content_id = "R18_BAD_ID"
    malformed.characters.append(incomplete)
    check(not native.import_manifest(malformed), "invalid ID is rejected")
    check(native.entries("character").is_empty() and not native.load_error.is_empty(),
        "failed import never leaves partial definitions")
    # Reimport proves an invalid attempt has not mutated the .tres source file.
    check(NativeContent.new(FIXTURE).entries("character").has("r18_guest_swordsman"),
        "native resources stay immutable after validation")

    print("R18_NATIVE_CONTENT_PASS failures=", failures)
    quit(0 if failures == 0 else 1)
