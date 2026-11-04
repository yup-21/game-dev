extends "res://scripts/pingjiang_scroll_qa.gd"
## PJ-01 isolated playtest. Neighbouring areas are explicitly marked QA
## connector maps; the actual PJ-02 and wilderness assets remain independent.

func _additional_regions() -> Dictionary:
    return {
        "pingjiang_south_gate_qa": {
            "title": "PJ-01 · 平江瓮城正南门",
            "map": "res://data/maps/pingjiang_south_gate_qa.tres",
            "art": "res://data/native/scene_art/pingjiang_south_gate_qa.tres",
            "size": Vector2(1600, 2000), "start": "from_south"},
        "pingjiang_crossroads_connector_qa": {
            "title": "PJ-02 北端连接占位 · 仅QA",
            "map": "res://data/maps/pingjiang_crossroads_connector_qa.tres",
            "art": "res://data/native/scene_art/pingjiang_connector_qa.tres",
            "size": Vector2(1600, 1000), "start": "from_south"},
        "pingjiang_wild_road_connector_qa": {
            "title": "城外官道南端连接占位 · 仅QA",
            "map": "res://data/maps/pingjiang_wild_road_connector_qa.tres",
            "art": "res://data/native/scene_art/pingjiang_connector_qa.tres",
            "size": Vector2(1600, 1000), "start": "from_north"}
    }
