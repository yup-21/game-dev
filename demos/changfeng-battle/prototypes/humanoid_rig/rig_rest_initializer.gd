@tool
extends Skeleton2D
## Initialize each Bone2D's rest pose from the authored scene transform.
## The same script works for a universal body or an independent accessory rig.

func _ready() -> void:
    _init_bones(self)


func _init_bones(node: Node) -> void:
    for child in node.get_children():
        if child is Bone2D:
            child.rest = child.transform
            _init_bones(child)
