"""Install the canonical custom nodes and editable native ComfyUI workflows."""
from __future__ import annotations
import argparse
import copy
import json
from pathlib import Path
import shutil
import subprocess
import sys
import time
from urllib.request import ProxyHandler, build_opener
import uuid
import webbrowser

sys.path.insert(0,str(Path(__file__).resolve().parent))
from character_action_paths import BUNDLE, DEFAULT_COMFY, MODELS, TEMPLATE_ROOT


def graph_inputs():
    return {'source_mode':'已有骨架','character':['30',0],'video':['31',0],
            'pose_image':['32',0],'source_path':'',
            'action_text':'','height_m':1.8,'width':384,'height':288,'origin_x':171,'origin_y':256,
            'duration_ms':2000,'max_frames':16,'video_start':0.,'video_end':0.,
            'identity_description':'','weapon_description':'','seed':420163,'execution_mode':'样帧检查',
            'seed_mode':'逐帧变化','action_filter':''}


def graphs():
    def node(kind,**inputs):return {'class_type':kind,'inputs':inputs}
    prepare={'1':node('WuxiaPoseSource',**dict(graph_inputs(),execution_mode='整组生成')),
             '2':node('PreviewImage',images=['1',0]),'3':node('PreviewImage',images=['1',1])}
    render={'1':node('WuxiaPoseSource',**graph_inputs()),
            '2':node('UNETLoader',unet_name=MODELS['action'],weight_dtype='default'),
            '3':node('LoraLoaderModelOnly',model=['2',0],lora_name=MODELS['lora'],strength_model=1.0),
            '4':node('CLIPLoader',clip_name=MODELS['clip'],type='flux2',device='default'),
            '5':node('VAELoader',vae_name=MODELS['vae']),
            '6':node('VAEEncode',pixels=['1',0],vae=['5',0]),'7':node('VAEEncode',pixels=['1',1],vae=['5',0]),
            '8':node('CLIPTextEncode',text=['1',2],clip=['4',0]),'9':node('CLIPTextEncode',text='',clip=['4',0]),
            '10':node('ReferenceLatent',conditioning=['8',0],latent=['6',0]),
            '11':node('ReferenceLatent',conditioning=['10',0],latent=['7',0]),
            '12':node('ReferenceLatent',conditioning=['9',0],latent=['6',0]),
            '13':node('ReferenceLatent',conditioning=['12',0],latent=['7',0]),
            '14':node('EmptyFlux2LatentImage',width=['1',4],height=['1',5],batch_size=1),
            '15':node('RandomNoise',noise_seed=['1',6]),'16':node('KSamplerSelect',sampler_name='euler'),
            '17':node('Flux2Scheduler',steps=4,width=['1',4],height=['1',5]),
            '18':node('CFGGuider',model=['3',0],positive=['11',0],negative=['13',0],cfg=1.0),
            '19':node('SamplerCustomAdvanced',noise=['15',0],guider=['18',0],sampler=['16',0],sigmas=['17',0],latent_image=['14',0]),
            '20':node('VAEDecode',samples=['19',0],vae=['5',0]),
            '21':node('WuxiaTransparentFrames',images=['20',0],frame_record=['1',3],plan=['1',7])}
    for graph in (prepare,render):
        graph['30']=node('WuxiaCharacterInput',file='(未选择)')
        graph['31']=node('WuxiaVideoInput',file='(未选择)')
        graph['32']=node('WuxiaPoseImageInput',file='(未选择)')
    return prepare,render


def action_set_graphs(source_path=None):
    prepare,render=copy.deepcopy(graphs())
    source=str(source_path) if source_path is not None else ''
    for graph in (prepare,render):
        graph['1']['inputs'].update(source_mode='已有骨架',source_path=source,max_frames=128)
    calibrate = copy.deepcopy(render)
    render['1']['inputs']['execution_mode'] = '直接生成全部'
    return prepare,render,calibrate


OUTPUTS={'WuxiaPoseSource':['IMAGE','IMAGE','STRING','STRING','INT','INT','INT','WUXIA_PLAN'],
         'WuxiaCharacterInput':['STRING'],'WuxiaVideoInput':['STRING'],'WuxiaPoseImageInput':['STRING'],
         'WuxiaTransparentFrames':['STRING'],'PreviewImage':[],'UNETLoader':['MODEL'],'LoraLoaderModelOnly':['MODEL'],
         'CLIPLoader':['CLIP'],'VAELoader':['VAE'],'VAEEncode':['LATENT'],'CLIPTextEncode':['CONDITIONING'],
         'ReferenceLatent':['CONDITIONING'],'EmptyFlux2LatentImage':['LATENT'],'RandomNoise':['NOISE'],
         'KSamplerSelect':['SAMPLER'],'Flux2Scheduler':['SIGMAS'],'CFGGuider':['GUIDER'],
         'SamplerCustomAdvanced':['LATENT','LATENT'],'VAEDecode':['IMAGE']}
WIDGETS={'WuxiaPoseSource':[k for k in graph_inputs() if k not in ('character','video','pose_image')],
         'WuxiaCharacterInput':['file'],'WuxiaVideoInput':['file'],'WuxiaPoseImageInput':['file'],'UNETLoader':['unet_name','weight_dtype'],
         'LoraLoaderModelOnly':['lora_name','strength_model'],'CLIPLoader':['clip_name','type','device'],
         'VAELoader':['vae_name'],'CLIPTextEncode':['text'],'EmptyFlux2LatentImage':['width','height','batch_size'],
         'RandomNoise':['noise_seed'],'KSamplerSelect':['sampler_name'],'Flux2Scheduler':['steps','width','height'],'CFGGuider':['cfg']}
DEFAULTS={'width':384,'height':288,'noise_seed':420163,'text':''}
TITLES={'1':'① 选择来源、上传原画、设置尺寸与身高','2':'视频路线：Klein4B蒸馏版','3':'姿态LoRA：默认1','4':'文字编码器',
        '5':'VAE','6':'骨架编码（图1）','7':'固定原画编码（图2）','8':'逐帧局部提示词','9':'负向条件（CFG1时不参与）',
        '10':'骨架参考','11':'加入固定原画','12':'负向骨架','13':'负向原画','14':'原生输出尺寸',
        '15':'逐帧种子','16':'Euler','17':'采样步数：默认4','18':'CFG：默认1','19':'② 逐帧生成','20':'解码原始帧','21':'③ 去背景、检查、保存透明候选'}


def ui_graph(graph,prepare=False):
    nodes=[];links=[]
    positions={'1':[0,0],'30':[-520,0],'31':[-520,280],'32':[-520,560],
               '2':[530,0],'3':[530,200],'4':[530,430],'5':[530,650],
               '6':[1040,0],'7':[1040,200],'8':[1040,410],'9':[1040,690],
               '10':[1550,0],'11':[1550,200],'12':[1550,420],'13':[1550,620],
               '14':[2060,0],'15':[2060,230],'16':[2060,430],'17':[2060,620],'18':[2060,860],
               '19':[2570,0],'20':[2570,360],'21':[3080,0]}
    for key,spec in graph.items():
        kind=spec['class_type'];inputs=[];values=[]
        for name in WIDGETS.get(kind,[]):
            value=spec['inputs'][name]
            values.append(DEFAULTS.get(name,0) if isinstance(value,list) else value)
        for name,value in spec['inputs'].items():
            if not isinstance(value,list):continue
            source,slot=value;kind_out=OUTPUTS[graph[source]['class_type']][slot];lid=len(links)+1
            links.append([lid,int(source),slot,int(key),len(inputs),kind_out])
            field={'name':name,'type':kind_out,'link':lid}
            if name in WIDGETS.get(kind,[]):field['widget']={'name':name}
            inputs.append(field)
        title={'30':'上传角色原画','31':'上传模板视频（MP4等）','32':'上传骨架PNG'}.get(key,TITLES.get(key,kind))
        pos=positions[key]
        if prepare and key in ('2','3'):
            pos=[600 if key=='2' else 1200,0];title='骨架预览' if key=='2' else '固定原画参考预览'
        size=[470,1040] if key=='1' else [470,430] if kind in ('WuxiaTransparentFrames','PreviewImage') else [460,220]
        nodes.append({'id':int(key),'type':kind,'title':title,'pos':pos,'size':size,'flags':{},'order':int(key)-1,'mode':0,
                      'inputs':inputs,'outputs':[{'name':t,'type':t,'links':[]} for t in OUTPUTS[kind]],
                      'properties':{'Node name for S&R':kind},'widgets_values':values,
                      'widgets_values_named':dict(zip(WIDGETS.get(kind,[]),values))})
    by_id={n['id']:n for n in nodes}
    for link in links:by_id[link[1]]['outputs'][link[2]]['links'].append(link[0])
    note=max(by_id)+1
    mode = graph['1']['inputs']['execution_mode']
    instructions = (
        '准备图预览全部骨架。' if prepare else
        '直接生成全部骨架对应的角色帧。样帧校准在独立的05工作流执行。画廊展示每帧，去背景失败时展示原始图。' if mode == '直接生成全部' else
        '样帧检查从每组抽取代表帧，生成后进行姿态与Alpha检查并保存报告。'
    )
    nodes.append({'id':note,'type':'Note','title':'使用顺序','pos':[0,1100],'size':[480,240],'flags':{},'order':note,'mode':0,
                  'inputs':[],'outputs':[],'properties':{},'widgets_values':[
                      '先在本图选择文字／视频／已有骨架并上传角色原画。已有骨架可上传单PNG，或在source_path填motion.json/骨架目录。GIF可填本地路径。文字规划使用现有Codex登录。\n'
                      + instructions + '\n'
                      'action_filter留空处理全部；填walk、attack_thrust等只处理这一组。\n'
                      '模型默认蒸馏4B、4步、CFG1、LoRA1；输出原生384×288，不事后缩放。角色身高须按实际设定填写。\n'
                      '全部结果保持候选，原图不当首帧，不用前帧作身份参考。']})
    return {'id':str(uuid.uuid4()),'revision':0,'last_node_id':note,'last_link_id':len(links),'nodes':nodes,'links':links,
            'groups':[],'config':{},'extra':{'ds':{'scale':0.35 if prepare else 0.23,'offset':[600,40]}},'version':0.4}


def install(comfy_root, templates_root=None, *, replace_loader=False, user_directory=None):
    portable=Path(comfy_root).resolve();core=portable/'ComfyUI' if (portable/'ComfyUI/main.py').is_file() else portable
    if not (core/'main.py').is_file():raise ValueError('ComfyUI main.py not found')
    motion = None
    if templates_root is not None:
        motion = Path(templates_root).resolve() / 'comfyui' / '12-actions' / 'motion.json'
        if not motion.is_file():
            raise FileNotFoundError(f'找不到模板清单：{motion}')
    target=core/'custom_nodes/wuxia_character_actions';target.mkdir(parents=True,exist_ok=True)
    source=BUNDLE/'integrations/comfyui_wuxia/__init__.py'
    text=('import importlib.util\nimport sys\nfrom pathlib import Path\n'
          f'SOURCE = Path({str(source)!r})\n'
          'spec=importlib.util.spec_from_file_location("wuxia_character_actions_canonical", SOURCE, submodule_search_locations=[str(SOURCE.parent)])\n'
          'module=importlib.util.module_from_spec(spec)\nsys.modules[spec.name]=module\nspec.loader.exec_module(module)\n'
          'NODE_CLASS_MAPPINGS=module.NODE_CLASS_MAPPINGS\nNODE_DISPLAY_NAME_MAPPINGS=module.NODE_DISPLAY_NAME_MAPPINGS\n')
    loader = target/'__init__.py'
    if loader.is_file() and loader.read_text('utf8') != text and not replace_loader:
        raise ValueError(f'已有其他来源的加载器：{loader}。确认迁移时请显式使用 --replace-loader。')
    loader.write_text(text,'utf8')
    destination=BUNDLE/'workflows/ComfyUI统一入口';destination.mkdir(parents=True,exist_ok=True)
    user_root = Path(user_directory).resolve() if user_directory else core/'user'
    user=user_root/'default/workflows/角色动作工作流';user.mkdir(parents=True,exist_ok=True)
    variants=[*zip(('01_准备与预览骨架','02_骨架原画生成透明动作帧'),graphs()),
              *zip(('03_12组骨架一次性预览','04_12组动作批量生成','05_12组动作样帧校准'),action_set_graphs(motion))]
    for name,g in variants:
        api=destination/(name+'.api.json');ui=destination/(name+'.json')
        api.write_text(json.dumps(g,ensure_ascii=False,indent=2)+'\n','utf8')
        ui.write_text(json.dumps(ui_graph(g,name.startswith(('01','03'))),ensure_ascii=False,indent=2)+'\n','utf8')
        shutil.copy2(ui,user/ui.name)
    print('UI_WORKFLOWS='+str(destination),flush=True)
    return core


def launch(core,port=8189,open_browser=True, *, python=None, user_directory=None):
    url=f'http://127.0.0.1:{port}'
    process=None
    opener = build_opener(ProxyHandler({}))
    try:
        with opener.open(url+'/object_info/WuxiaPoseSource',timeout=3) as response:info=json.load(response)
        if 'WuxiaPoseSource' not in info:raise ValueError(f'端口{port}已有其他ComfyUI实例，请换端口或重启该实例以加载节点。')
    except OSError:
        embedded=core.parent/'python_embeded/python.exe'
        python=Path(python).resolve(strict=True) if python else embedded if embedded.is_file() else Path(sys.executable)
        portable = python == embedded
        logs=BUNDLE/'logs';logs.mkdir(exist_ok=True)
        command=[str(python),'-s',str(core/'main.py'),'--disable-auto-launch','--listen','127.0.0.1',
                 '--port',str(port),'--lowvram','--cpu-vae','--preview-method','none','--user-directory',
                 str(Path(user_directory).resolve() if user_directory else core/'user'),
                 '--output-directory',str(BUNDLE/'outputs/comfyui-gallery')]
        if portable:
            command.append('--windows-standalone-build')
        with (logs/f'comfy-ui-{port}.log').open('a',encoding='utf8') as stream:
            process=subprocess.Popen(command,cwd=core.parent,stdout=stream,stderr=subprocess.STDOUT,
                                     creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
        (logs/f'comfy-ui-{port}.json').write_text(json.dumps({'pid':process.pid,'command':command},ensure_ascii=False,indent=2),'utf8')
        for _ in range(180):
            if process.poll() is not None:raise RuntimeError('ComfyUI启动失败，请查看logs/comfy-ui日志。')
            try:
                with opener.open(url+'/object_info/WuxiaPoseSource',timeout=2) as response:info=json.load(response)
                if 'WuxiaPoseSource' not in info:raise ValueError('自定义节点未加载，请检查日志。')
                break
            except OSError:time.sleep(1)
        else:raise TimeoutError('ComfyUI启动超时；进程保留，查看日志。')
    if open_browser:webbrowser.open(url)
    print('COMFY_UI_URL='+url,flush=True)
    return process


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--comfy-root',type=Path,default=DEFAULT_COMFY)
    parser.add_argument('--templates-root',type=Path,default=TEMPLATE_ROOT)
    parser.add_argument('--user-directory',type=Path)
    parser.add_argument('--python',type=Path,help='Python used to launch a non-portable ComfyUI')
    parser.add_argument('--replace-loader',action='store_true')
    parser.add_argument('--launch',action='store_true');parser.add_argument('--no-browser',action='store_true')
    parser.add_argument('--keep-alive',action='store_true',help='Keep the launcher alive while its owned ComfyUI process runs')
    parser.add_argument('--port',type=int,default=8189)
    args=parser.parse_args()
    if args.comfy_root is None:
        parser.error('设置 settings.local.json 中的 comfy_root 或传入 --comfy-root。')
    core=install(args.comfy_root,args.templates_root,replace_loader=args.replace_loader,user_directory=args.user_directory)
    if args.launch:
        process=launch(core,args.port,not args.no_browser,python=args.python,user_directory=args.user_directory)
        if args.keep_alive and process is not None:
            try:process.wait()
            finally:
                if process.poll() is None:process.terminate()
