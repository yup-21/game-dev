"""Build the editable 07 workflow from the existing FLUX.2 model graph."""
import copy
import json
from pathlib import Path
import shutil


def parts_atlas_template(templates_root):
    if templates_root is None:
        return None
    path = Path(templates_root).resolve() / 'rig2d' / 'parts-template' / 'parts.template.json'
    if not path.is_file():
        raise FileNotFoundError(f'找不到部件布局模板：{path}')
    return path


def parts_atlas_graph(render_graph, parts_template):
    def node(kind, **inputs):
        return {'class_type': kind, 'inputs': inputs}

    graph = copy.deepcopy(render_graph)
    for unused in ('3', '12', '13', '31', '32'):
        del graph[unused]
    graph.update({
        '1': node('WuxiaPartsAtlasGuide', character=['30', 0],
                  parts_template=str(parts_template) if parts_template else '', identity_notes=''),
        '22': node('ImageScaleToTotalPixels', image=['1', 2], upscale_method='lanczos',
                   megapixels=0.5, resolution_steps=16),
        '21': node('WuxiaPartsAtlasOutput', images=['20', 0]),
        '23': node('PreviewImage', images=['1', 0]),
    })
    graph['7']['inputs']['pixels'] = ['22', 0]
    graph['8']['inputs']['text'] = ['1', 1]
    graph['15']['inputs']['noise_seed'] = 420163
    for key in ('14', '17'):
        graph[key]['inputs'].update(width=1536, height=1024)
    graph['18']['inputs'].update(model=['2', 0], negative=['9', 0])
    return graph


def install_parts_atlas_workflow(destination, user, render_graph, templates_root, ui_graph):
    name = '07_原画生成2D拆件候选'
    graph = parts_atlas_graph(render_graph, parts_atlas_template(templates_root))
    for suffix, spec in (('.api.json', graph), ('.json', ui_graph(graph, parts_atlas=True))):
        (destination / (name + suffix)).write_text(json.dumps(spec, ensure_ascii=False, indent=2) + '\n', 'utf-8')
    shutil.copy2(destination / (name + '.json'), user / (name + '.json'))
