"""Native ComfyUI inputs and transparent candidate output; no nested API queue."""
from __future__ import annotations
import hashlib
import importlib
import json
from pathlib import Path
import re
import shutil
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
import numpy as np
import torch
from PIL import Image
import folder_paths
import nodes
from character_action_paths import ALPHA_MODEL, POSE_MODEL, POSE_DEPS
from character_alpha import process_frame
from comfy_ui_pose_source import prepare_source
from .rig2d import WuxiaRig2DRender

NONE = '(未选择)'
DIRECT_RENDER = '直接生成全部'
PER_FRAME_SEED = '逐帧变化'
PER_ACTION_SEED = '每组固定'
_HASHES = {}


def sha(path):
    p=Path(path); stat=p.stat(); key=(str(p.resolve()),stat.st_size,stat.st_mtime_ns)
    if key not in _HASHES:
        h=hashlib.sha256()
        with p.open('rb') as stream:
            for block in iter(lambda:stream.read(1024*1024),b''):h.update(block)
        _HASHES[key]=h.hexdigest()
    return _HASHES[key]


def data_sha(value):
    return hashlib.sha256(json.dumps(value,sort_keys=True,ensure_ascii=False,separators=(',',':')).encode('utf8')).hexdigest()


def write(path, value):
    p=Path(path);p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n','utf8')


def choices(suffixes):
    root=Path(folder_paths.get_input_directory()); result=[]
    for item in root.rglob('*'):
        relative=item.relative_to(root)
        if relative.parts[0] in ('character_actions','clipspace'):continue
        if item.is_file() and item.suffix.lower() in suffixes:result.append(relative.as_posix())
    return [NONE]+sorted(result)


def resolve_input(value):
    if not value or value==NONE:return None
    path=Path(value)
    if path.is_absolute():
        if not path.exists():raise ValueError('找不到输入文件：'+str(path))
        return path.resolve()
    # Native annotated paths reject traversal and links escaping the input root.
    return Path(folder_paths.get_annotated_filepath(value)).resolve(strict=True)


def sampling_key(prompt, source_key, *, alpha=False, pose=False):
    graph=json.loads(json.dumps(prompt or {})); weights={}
    for spec in graph.values():
        kind=spec.get('class_type'); inputs=spec.get('inputs',{})
        if kind=='WuxiaPoseSource':inputs.pop('execution_mode',None)
        for node_type,field,folder in [('UNETLoader','unet_name','diffusion_models'),('CLIPLoader','clip_name','text_encoders'),
                                      ('VAELoader','vae_name','vae'),('LoraLoaderModelOnly','lora_name','loras')]:
            if kind==node_type and isinstance(inputs.get(field),str):
                p=folder_paths.get_full_path(folder,inputs[field])
                if not p:raise ValueError('模型文件不存在：'+inputs[field])
                weights[folder+'/'+inputs[field]]=sha(p)
    checks = {}
    for enabled, model, field, scripts in (
        (alpha, ALPHA_MODEL, 'alpha_model', ('character_alpha.py',)),
        (pose, POSE_MODEL, 'pose_model', ('pose_following_check.py', 'video_pose_template.py')),
    ):
        if enabled:
            if model is None or not model.is_file():
                raise FileNotFoundError(f'请在 settings.local.json 配置 {field}；找不到模型：{model}')
            checks[str(model)] = sha(model)
            for name in scripts:
                path = ROOT / 'scripts' / name
                checks[str(path)] = sha(path)
    return data_sha({'graph':graph,'weights':weights,'source_key':source_key,'checks':checks,'node_sha256':sha(__file__)}),weights


def pilot_ids(frames):
    groups={}
    for frame in frames:groups.setdefault(frame.get('action_id') or '_single',[]).append(frame)
    if len(groups)>1:
        return [fid for group in groups.values() for fid in pilot_ids(group)]
    if len(frames)==1:return [frames[0]['id']]
    first=frames[0].get('planned_points')
    if first:
        def distance(frame):
            p=frame.get('planned_points') or {}
            return sum(sum((p[k][i]-first[k][i])**2 for i in (0,1)) for k in first if k in p)
        other=max(frames[1:],key=distance)
    else:other=frames[len(frames)//2]
    return [frames[0]['id'],other['id']]


def frame_output_path(record):
    """Keep action groups separate without trusting imported path components."""
    action=record.get('action_id')
    if action is not None and (not isinstance(action,str) or not re.fullmatch(r'[A-Za-z][A-Za-z0-9_-]{0,63}',action)):
        raise ValueError('动作名称必须是安全的字母、数字或下划线标识。')
    index=record.get('action_frame_index')
    if action and index is not None:
        if type(index) is not int or not 0<=index<4096:raise ValueError('组内帧号不合法。')
        return Path(action)/f'frame_{index:04d}.png'
    fid=record['id']
    if not isinstance(fid,str) or not re.fullmatch(r'[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}',fid):raise ValueError('帧名称不合法。')
    return (Path(action) if action else Path())/(fid+'.png')


def verify_pilot(path, plan, recipe, frames=None):
    if not path.is_file():raise ValueError('请先选择“样帧检查”并运行；通过后才能整组生成。')
    report=json.loads(path.read_text('utf8'))
    payload={k:v for k,v in report.items() if k!='evidence_sha256'}
    if report.get('evidence_sha256')!=data_sha(payload):raise ValueError('样帧检查记录已变化，请重新生成样帧。')
    if report.get('source_key')!=plan['source_key'] or report.get('sampling_key')!=recipe:
        raise ValueError('输入或采样参数已变化，请重新运行样帧检查。')
    if report.get('frame_ids')!=pilot_ids(plan['frames'] if frames is None else frames) or not report.get('passed'):
        raise ValueError('样帧尚未通过姿态与透明检查；请查看本批报告，不继续扩展整组。')
    for file,digest in report['files'].items():
        if not Path(file).is_file() or sha(file)!=digest:raise ValueError('样帧文件已变化，请重新运行样帧检查。')
    return report


class WuxiaCharacterInput:
    @classmethod
    def INPUT_TYPES(cls):return {'required':{'file':(choices({'.png','.jpg','.jpeg','.webp'}),{'image_upload':True})}}
    RETURN_TYPES=('STRING',)
    RETURN_NAMES=('原画文件',)
    FUNCTION='select'
    CATEGORY='武侠角色动作/上传'
    def select(self,file):return (file,)


class WuxiaVideoInput(WuxiaCharacterInput):
    @classmethod
    def INPUT_TYPES(cls):return {'required':{'file':(choices({'.mp4','.webm','.mov','.mkv','.avi','.gif'}),{'video_upload':True})}}
    RETURN_NAMES=('视频文件',)


class WuxiaPoseImageInput(WuxiaCharacterInput):
    @classmethod
    def INPUT_TYPES(cls):return {'required':{'file':(choices({'.png','.jpg','.webp','.gif'}),{'image_upload':True})}}
    RETURN_NAMES=('骨架文件',)


class WuxiaPoseSource:
    @classmethod
    def INPUT_TYPES(cls):
        images=choices({'.png','.jpg','.jpeg','.webp','.gif'})
        videos=choices({'.mp4','.webm','.mov','.mkv','.gif','.avi'})
        return {'required':{
            'source_mode':(['已有骨架','视频提取','文字规划'],),
            'character':('STRING',{'forceInput':True}),
            'video':('STRING',{'forceInput':True}),
            'pose_image':('STRING',{'forceInput':True}),
            'source_path':('STRING',{'default':'','tooltip':'骨架目录、motion.json、AI分镜JSON或GIF的本地路径；为空则使用上传文件。'}),
            'action_text':('STRING',{'default':'','multiline':True}),
            'height_m':('FLOAT',{'default':1.8,'min':1.0,'max':2.2,'step':0.01}),
            'width':('INT',{'default':384,'min':64,'max':2048,'step':16}),
            'height':('INT',{'default':288,'min':64,'max':2048,'step':16}),
            'origin_x':('INT',{'default':171,'min':0,'max':2047}),
            'origin_y':('INT',{'default':256,'min':0,'max':2047}),
            'duration_ms':('INT',{'default':2000,'min':100,'max':30000}),
            'max_frames':('INT',{'default':16,'min':1,'max':128,'tooltip':'文字规划/视频提取的帧数上限；已有骨架按清单完整导入，最多256帧。'}),
            'video_start':('FLOAT',{'default':0.0,'min':0.0,'max':3600.0,'step':0.01}),
            'video_end':('FLOAT',{'default':0.0,'min':0.0,'max':3600.0,'step':0.01}),
            'identity_description':('STRING',{'default':'','multiline':True}),
            'weapon_description':('STRING',{'default':'','multiline':True}),
            'seed':('INT',{'default':420163,'min':0,'max':0xffffffffffffffff,'control_after_generate':False}),
            'execution_mode':(['样帧检查','整组生成',DIRECT_RENDER],),
        },'optional':{
            'seed_mode': ([PER_FRAME_SEED, PER_ACTION_SEED], {
                'tooltip': '每组固定：同一动作复用初始噪声。逐帧变化：用基础种子加帧序号。'
            }),
            'action_filter': ('STRING', {'default': '', 'tooltip': '只处理指定动作，例如 walk 或 attack_thrust；留空处理全部。'}),
        },'hidden':{'prompt':'PROMPT'}}
    RETURN_TYPES=('IMAGE','IMAGE','STRING','STRING','INT','INT','INT','WUXIA_PLAN')
    RETURN_NAMES=('骨架序列','固定原画参考','逐帧提示词','逐帧记录','宽','高','逐帧种子','本批计划')
    OUTPUT_IS_LIST=(True,False,True,True,False,False,True,False)
    FUNCTION='prepare'
    CATEGORY='武侠角色动作/输入'
    @classmethod
    def IS_CHANGED(cls,**kwargs):return float('nan')

    def prepare(self,source_mode,character,video,pose_image,source_path,action_text,height_m,width,height,origin_x,origin_y,
                duration_ms,max_frames,video_start,video_end,identity_description,weapon_description,seed,execution_mode,prompt=None,
                seed_mode=PER_FRAME_SEED,action_filter=''):
        character_path=resolve_input(character)
        if character_path is None:raise ValueError('请上传角色原画。')
        mode={'已有骨架':'pose','视频提取':'video','文字规划':'text'}[source_mode]
        source=resolve_input(source_path) if source_path.strip() else None
        nodes.before_node_execution()
        plan=prepare_source(mode=mode,character_path=character_path,action_text=action_text,
                            video_path=source or resolve_input(video) if mode=='video' else None,
                            pose_path=(source or resolve_input(pose_image)) if mode=='pose' else source if mode=='text' else None,
                            height_m=height_m,width=width,height=height,origin=(origin_x,origin_y),duration_ms=duration_ms,
                            max_frames=max_frames,video_start=video_start,video_end=video_end,
                            identity_description=identity_description,weapon_description=weapon_description)
        plan=json.loads(json.dumps(plan))
        action_filter = action_filter.strip()
        scoped_frames = plan['frames']
        if action_filter:
            scoped_frames = [frame for frame in scoped_frames if frame.get('action_id') == action_filter]
            if not scoped_frames:
                available = sorted({frame['action_id'] for frame in plan['frames'] if frame.get('action_id')})
                raise ValueError(f'找不到动作 {action_filter}。可选：{", ".join(available) or "本输入没有动作分组，请留空"}')
        graph_classes = {v.get('class_type') for v in (prompt or {}).values()}
        alpha = 'WuxiaTransparentFrames' in graph_classes
        pose = alpha and execution_mode != DIRECT_RENDER and any(f.get('planned_points') for f in scoped_frames)
        key,weights=sampling_key(prompt,plan['source_key'],alpha=alpha,pose=pose)
        plan.update(sampling_key=key,sampling_weights=weights,execution_mode=execution_mode,seed_mode=seed_mode,
                    action_filter=action_filter)
        has_sampler=any(v.get('class_type')=='SamplerCustomAdvanced' for v in (prompt or {}).values())
        if execution_mode=='整组生成' and has_sampler:
            verify_pilot(Path(plan['root'])/'ui-pilots'/key/'report.json',plan,key,scoped_frames)
        selected=pilot_ids(scoped_frames) if execution_mode=='样帧检查' else [f['id'] for f in scoped_frames]
        plan['selected_frame_ids']=selected
        frames_by_id = {frame['id']: frame for frame in scoped_frames}
        frames = [frames_by_id[frame_id] for frame_id in selected]
        def tensor(path):
            with Image.open(path) as image:return torch.from_numpy(np.asarray(image.convert('RGB'),dtype=np.float32).copy()/255.0)[None,]
        poses=[tensor(f['pose']) for f in frames]
        prompts=[f['prompt'] for f in frames]
        indices = {}
        action_starts = {}
        for i, frame in enumerate(plan['frames']):
            action_start = action_starts.setdefault(frame.get('action_id'), i)
            indices[frame['id']] = action_start if seed_mode == PER_ACTION_SEED else i
        noise_seeds = [(seed + indices[frame['id']]) % (2**64) for frame in frames]
        metadata = [json.dumps(dict(frame, noise_seed=noise_seed), ensure_ascii=False)
                    for frame, noise_seed in zip(frames, noise_seeds)]
        assert poses and len(poses)==len(metadata)==len(prompts)
        return poses,tensor(plan['reference']),prompts,metadata,width,height,noise_seeds,plan


class WuxiaTransparentFrames:
    @classmethod
    def INPUT_TYPES(cls):
        return {'required':{'images':('IMAGE',),'frame_record':('STRING',),'plan':('WUXIA_PLAN',)},
                'hidden':{'prompt':'PROMPT','extra_pnginfo':'EXTRA_PNGINFO'}}
    RETURN_TYPES=('STRING',)
    RETURN_NAMES=('报告',)
    INPUT_IS_LIST=True
    OUTPUT_NODE=True
    FUNCTION='save'
    CATEGORY='武侠角色动作/输出'

    def save(self,images,frame_record,plan,prompt=None,extra_pnginfo=None):
        if len(plan)!=1 or len(images)!=len(frame_record):raise ValueError('本批计划与帧序列数量不一致。')
        plan=plan[0];actual_prompt=(prompt or [{}])[0]
        direct = plan['execution_mode'] == DIRECT_RENDER
        from comfy_ui_pose_source import _cached
        frozen=_cached(Path(plan['root']),plan['source_key'])
        if frozen['frames']!=plan['frames'] or frozen['reference']!=plan['reference']:raise ValueError('准备后的骨架或固定参考发生变化。')
        records=[json.loads(v) for v in frame_record]
        pose_check = not direct and any(r.get('planned_points') for r in records)
        key,weights=sampling_key(actual_prompt,plan['source_key'],alpha=True,pose=pose_check)
        if key!=plan['sampling_key'] or weights!=plan['sampling_weights']:raise ValueError('采样配方在执行期间发生变化。')
        if [r['id'] for r in records]!=plan['selected_frame_ids']:raise ValueError('动作帧顺序或数量不一致。')
        if len({frame_output_path(r) for r in records})!=len(records):raise ValueError('组内输出帧号重复。')
        run_id=time.strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8]
        root=Path(plan['root'])/'ui-runs'/run_id
        root.mkdir(parents=True,exist_ok=False)
        preview_root=Path(folder_paths.get_output_directory())/'WuxiaCharacterActions'/plan['source_key'][:16]/run_id
        preview_root.mkdir(parents=True,exist_ok=False)
        write(root/'actual-prompt.json',actual_prompt)
        session=None;pose=None
        if pose_check:
            if POSE_DEPS is not None:
                sys.path.insert(0,str(POSE_DEPS))
            pose=importlib.import_module('video_pose_template')
            pose.np=importlib.import_module('numpy');pose.cv2=importlib.import_module('cv2')
            ort=importlib.import_module('onnxruntime');options=ort.SessionOptions()
            options.intra_op_num_threads=2;options.inter_op_num_threads=1
            session=ort.InferenceSession(str(POSE_MODEL),sess_options=options,providers=['CPUExecutionProvider'])
        from pose_following_check import compare_landmarks
        results=[];previews=[];files={}
        for image,record in zip(images,records):
            nodes.before_node_execution()
            if image.shape[0]!=1 or list(image.shape[1:3])!=[plan['height'],plan['width']]:raise ValueError('输出不是本批原生画布，禁止自动缩放。')
            relative=frame_output_path(record)
            raw=root/'frames_raw'/relative;raw.parent.mkdir(parents=True,exist_ok=True)
            rgb=Image.fromarray(np.clip(image[0].detach().cpu().numpy()*255.0,0,255).astype(np.uint8),'RGB')
            rgb.save(raw)
            item={'frame_id':record['id'],'action_id':record.get('action_id'),'action_frame_index':record.get('action_frame_index'),
                  'source_frame_id':record.get('source_frame_id'),'duration_ms':record.get('duration_ms'),
                  'noise_seed':record.get('noise_seed'),
                  'raw':str(raw),'raw_sha256':sha(raw),'alpha_ok':False,
                  'pose_status':'skipped' if direct else 'insufficient_plan_coordinates'}
            files[str(raw)]=sha(raw);files[record['pose']]=sha(record['pose'])
            if session is not None and record.get('planned_points'):
                points,bbox,method=pose.infer(session,pose.np.asarray(rgb),None)
                diagnostic=compare_landmarks(record['planned_points'],points,round(plan['height_m']*100))
                item.update(pose_status=diagnostic['status'],pose_diagnostic=diagnostic)
            target=root/'transparent_frames'/relative
            preview_source = None
            try:
                alpha=process_frame(raw,target,ALPHA_MODEL,POSE_DEPS,keep_margin_failure=True) if direct else process_frame(raw,target,ALPHA_MODEL,POSE_DEPS)
                item.update(alpha_ok=alpha['ok'],alpha_report=alpha['report_path'],transparent=str(target))
                files[str(target)]=sha(target)
                preview_source = target
            except Exception as exc:item['alpha_error']=str(exc)
            if direct:
                preview_source = preview_source or raw
                category = 'transparent' if item['alpha_ok'] else 'alpha_margin_failed' if 'transparent' in item else 'raw_fallback'
                preview = preview_root / category / relative
            else:
                preview = preview_root / relative
            if preview_source is not None:
                preview.parent.mkdir(parents=True,exist_ok=True)
                shutil.copy2(preview_source,preview)
                previews.append({'filename':preview.name,'subfolder':preview.parent.relative_to(folder_paths.get_output_directory()).as_posix(),'type':'output'})
            results.append(item)
        passed=all(r['alpha_ok'] and r['pose_status']=='no_large_deviation_detected' for r in results)
        _cached(Path(plan['root']),plan['source_key'])
        if sampling_key(actual_prompt,plan['source_key'],alpha=True,pose=pose_check)[0]!=key:
            raise ValueError('模型或检查配方在输出期间发生变化。')
        report={'schema_version':1,'source_key':plan['source_key'],'sampling_key':key,'frame_ids':plan['selected_frame_ids'],
                'passed':passed,'execution_mode':plan['execution_mode'],'seed_mode':plan.get('seed_mode',PER_FRAME_SEED),
                'action_filter':plan.get('action_filter',''),
                'status':'candidate','visual_acceptance':False,
                'post_generation_resized':False,'frames':results,'files':files,'run_dir':str(root),
                'limits':'身份/武器/真实承重/人体高度/连续性/Godot仍未验收；黑底骨架PNG缺少坐标时仅作试样。'}
        if direct:
            report['counts'] = {'generated':len(results), 'transparent':sum('transparent' in r for r in results),
                                'alpha_passed':sum(r['alpha_ok'] for r in results)}
            report['limits'] = '直接生成候选。姿态检查在独立校准工作流执行。'
        report['evidence_sha256']=data_sha(report)
        write(root/'report.json',report);write(preview_root/'report.json',report)
        if plan['execution_mode']=='样帧检查':write(Path(plan['root'])/'ui-pilots'/key/'report.json',report)
        text=('样帧/姿态与Alpha检查通过，仍为待视觉复核候选。' if passed else '已保存候选试样，姿态或Alpha检查未通过；请查看报告。')+'\n'+str(root/'report.json')
        if direct:
            counts = report['counts']
            text = (f"已生成 {counts['generated']} 帧。透明候选 {counts['transparent']} 帧，"
                    f"其中 {counts['alpha_passed']} 帧通过 Alpha 检查。\n{root / 'report.json'}")
        return {'ui':{'images':previews,'text':[text]},'result':(text,)}


NODE_CLASS_MAPPINGS={'WuxiaPoseSource':WuxiaPoseSource,'WuxiaTransparentFrames':WuxiaTransparentFrames,
                     'WuxiaRig2DRender':WuxiaRig2DRender,
                     'WuxiaCharacterInput':WuxiaCharacterInput,'WuxiaVideoInput':WuxiaVideoInput,'WuxiaPoseImageInput':WuxiaPoseImageInput}
NODE_DISPLAY_NAME_MAPPINGS={'WuxiaPoseSource':'角色动作：文字／视频／骨架输入','WuxiaTransparentFrames':'角色动作：透明帧与检查报告',
                            'WuxiaRig2DRender':'角色动作：2D 骨骼渲染',
                            'WuxiaCharacterInput':'上传角色原画','WuxiaVideoInput':'上传模板视频','WuxiaPoseImageInput':'上传骨架PNG'}
