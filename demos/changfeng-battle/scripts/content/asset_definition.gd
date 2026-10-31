@tool
class_name WuxiaAssetDefinition
extends WuxiaContentDefinition
## Imported Godot resources with provenance, dimensions and stable owner binding.
@export_enum("portrait", "pose_sheet", "static_pose", "scene", "vfx", "actor_scene", "audio", "ui_atlas") var asset_kind: String = "portrait"
@export_enum("concept", "preview", "candidate", "runtime", "approved") var status: String = "candidate"
@export var resource: Resource
@export var source: String = ""
@export var rights: String = "owner_review_required"
@export var owner_character_id: String = ""
@export var event_kind: String = ""
@export_range(1, 64, 1) var columns: int = 1
@export_range(1, 64, 1) var rows: int = 1
@export var faces_left: bool = true
@export var foot_anchor: Vector2 = Vector2(0.5, 1.0)

func content_kind() -> String:
    return "asset"

func to_record() -> Dictionary:
    if resource == null or resource.resource_path.is_empty():
        return {}
    return {"schema_version":schema_version,"id":content_id,"kind":asset_kind,
        "path":resource.resource_path,"status":status,
        "source":source,"rights":rights,
        "owner_character_id":owner_character_id,"event_kind":event_kind,
        "columns":columns,"rows":rows,"faces_left":faces_left,
        "foot_anchor":[foot_anchor.x,foot_anchor.y]}
