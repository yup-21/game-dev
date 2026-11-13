"""Install the editable and API versions of the rig project workflow."""
import json
import shutil


WORKFLOW_NAME = "08_生成2D骨骼工程"
NODE_KIND = "WuxiaRig2DProject"


def install_rig_project_workflow(destination, user):
    inputs = {
        "parts_path": "",
        "motion_path": "",
        "character_id": "",
        "display_name": "",
        "action_filter": "",
    }
    api = {"1": {"class_type": NODE_KIND, "inputs": inputs}}
    ui = {
        "id": "b0240477-9f2a-4f4f-a97b-178c0a1d03e4", "revision": 0,
        "last_node_id": 2, "last_link_id": 0, "links": [], "groups": [], "config": {},
        "nodes": [
            {"id": 1, "type": NODE_KIND, "title": "生成 2D 骨骼工程，预览目标关节",
             "pos": [0, 0], "size": [660, 550], "flags": {}, "order": 0, "mode": 0,
             "inputs": [], "outputs": [{"name": "project_path", "type": "STRING", "links": []}],
             "properties": {"Node name for S&R": NODE_KIND}, "widgets_values": list(inputs.values())},
            {"id": 2, "type": "Note", "title": "输入和输出", "pos": [700, 0], "size": [470, 280],
             "flags": {}, "order": 1, "mode": 0, "inputs": [], "outputs": [], "properties": {},
             "widgets_values": [
                 "填写本地已审核的 parts.json、motion.json、角色标识和显示名。\n"
                 "action_filter 留空使用全部动作，填 walk 或 walk,run 选择动作。\n"
                 "排队后预览目标关节。工程和报告保存在 ComfyUI 输出目录的 WuxiaRig2DProject 下。\n"
                 "在 06_2D骨骼渲染 填写本批 project.json 的路径，即可渲染角色动作。"]},
        ],
        "extra": {"ds": {"scale": 0.8, "offset": [50, 50]}}, "version": 0.4,
    }
    for suffix, graph in ((".api.json", api), (".json", ui)):
        path = destination / (WORKFLOW_NAME + suffix)
        path.write_text(json.dumps(graph, ensure_ascii=False, indent=2) + "\n", "utf8")
    shutil.copy2(destination / (WORKFLOW_NAME + ".json"), user / (WORKFLOW_NAME + ".json"))
