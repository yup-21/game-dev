# 附录 · 第一幕详细剧本与关卡规范：微末斩芒 · 江南药引

> **关联索引**：[企划总库](../README.md) · [主线全景](../03-main-storyline.md) · [人物与女主](../06-characters-and-heroine.md) · [序幕详案](act-0-prologue.md)

---

## 一、第一幕核心人物一览

* **沈长风（主角）**：身怀兽皮残卷，初入江湖。青灰短褐、青钢剑，在鬼市中初悟见招拆招之理。
* **顾清霜（女主）**：沧澜阁嫡传大弟子，素白暗竹织锦长袍，腰佩澄霜软剑。追查东南多名年轻武者失踪案，身负早夭诅咒。
* **岚尘（核心同伴）**：烟岚谷青年采药人。机敏洒脱，身手如猿猴，发现鬼市掠夺草药充当药引。
* **盲骨叟（关底 Boss）**：天人五衰会外门执事，假延寿药丹师。双目皆盲，持哭丧白骨药杖，精通【化骨药掌】与【燃髓唤尸】。
* **苏小曼（线索女童）**：采药童女，兄长被掳，作为引出地下鬼市的情感线索。

---

## 二、第一幕四大关卡场景

1. **场景一：烟水渡口 · 晨雾小泊**（安全探索 / 登岸接头，熟悉古卷演武提示）
2. **场景二：平江别院 · 试剑茶寮**（初识顾清霜 / 识破镇抚司暗探强掳童女）
3. **场景三：烟岚古道 · 迷雾乱石**（FREE 连续身法野外战 / 迷雾视野限制 / 联手营救岚尘）
4. **场景四：地下鬼市 · 活人血炉**（GRID 战棋终极大副本 / 地热毒气 / 排毒铜阀 / 斩灭盲骨叟）

---

## 三、完整剧情脚本（Godot 原生 Story 数据规范）

### 第一场：平江茶寮 · 霜剑初逢

```text
[StoryBeat: beat_gusu_arrival]
Caption: "姑苏 · 烟波平江"
Text: "秋水渐平，姑苏城外画舫如织。然而平静水色之下，隐伏着不见天日的暗流。"
Duration: 3.5

[DialogueNode: node_tea_intro]
Speaker: "茶博士"
Text: "客官，您的碧螺春。听您的口音是从江北来的吧？这几天城里查得紧，外乡人可千万别往西市野巷子乱走。"
NextNode: "node_changfeng_inquire"

[DialogueNode: node_changfeng_inquire]
Speaker: "沈长风"
Text: "（放下粗瓷茶碗）小二哥，城里出什么事了？我看沿途官兵比平日多了数倍。"
NextNode: "node_tea_whisper"

[DialogueNode: node_tea_whisper]
Speaker: "茶博士"
Text: "（压低声音，四顾）嘘……听说丢人了！半个月里，十几个身强力壮的武家后生凭空没了踪影。连城西百草堂的大徒弟昨晚去采药，也没能回来……"
NextNode: "node_commotion_start"

[DialogueNode: node_commotion_start]
Speaker: "旁白"
Text: "话音未落，茶棚外突然传来一阵尖锐的哭喊声与铜靴踏地声。"
NextNode: "node_spy_threat"

[DialogueNode: node_spy_threat]
Speaker: "镇抚司暗探甲"
Text: "老东西！私藏禁药还敢抵赖？这小丫头根骨不错，按大乾军律，充入官坊抵罪！带走！"
NextNode: "node_girl_cry"

[DialogueNode: node_girl_cry]
Speaker: "苏小曼"
Text: "爷爷！我不走！爷爷救我……"
NextNode: "choice_tea_intervention"

[DialogueChoice: choice_1_draw_sword]
Text: "【拔剑】光天化日强掳民女，大乾律法难道不管强盗？"
NextNode: "node_changfeng_strike"
Events: [SetFlag: "heroic_reputation" = true]

[DialogueChoice: choice_2_observe_cold]
Text: "【按剑冷观】先看清对方虚实，伺机出手断其后路。"
NextNode: "node_observe_action"
Events: [SetFlag: "tactical_insight" = true]

[DialogueNode: node_changfeng_strike]
Speaker: "沈长风"
Text: "住手！光天化日，朗朗乾坤，披着官皮行强梁之事，也不怕污了祖宗门楣！"
NextNode: "node_frost_appears"

[DialogueNode: node_observe_action]
Speaker: "沈长风"
Text: "（目光如电，指尖搭在剑柄）气机沉实，呼吸急促，不是正规卫所兵，是冲着小姑娘气血去的……"
NextNode: "node_frost_appears"

[DialogueNode: node_frost_appears]
Speaker: "旁白"
Text: "正当暗探狞笑着拔出短刀之际，一道如秋水般的淡青剑芒自临河画舫疾掠而至！"
NextNode: "node_qingshuang_intervene"

[DialogueNode: node_qingshuang_intervene]
Speaker: "顾清霜"
Text: "（剑鞘未出，仅以剑尖带鞘轻点暗探腕骨，暗探惨嚎丢刀）沧澜阁在此，容不得宵小作恶。"
NextNode: "node_changfeng_resonance"

[DialogueNode: node_changfeng_resonance]
Speaker: "旁白"
Text: "【古卷震颤】怀中兽皮残卷忽然微热，沈长风眼前闪过一道灵光，清晰看见那暗探被击飞时露出的下肋破绽。"
NextNode: "node_changfeng_follow_kick"

[DialogueNode: node_changfeng_follow_kick]
Speaker: "沈长风"
Text: "（心念随剑动，一步游身掠至，剑鞘横扫其肋下，三名暗探瞬间溃散倒地）"
NextNode: "node_qingshuang_glance"

[DialogueNode: node_qingshuang_glance]
Speaker: "顾清霜"
Text: "（素白衣袂微敛，清冷眸子打量沈长风）身法沉稳，出招不带官府与宗派匠气。你是何人？"
NextNode: "node_changfeng_reply"

[DialogueNode: node_changfeng_reply]
Speaker: "沈长风"
Text: "江湖散人，沈长风。姑娘那一剑‘惊涛抚浪’精妙至极，多谢解围。"
NextNode: "node_qingshuang_nod"

[DialogueNode: node_qingshuang_nod]
Speaker: "顾清霜"
Text: "沧澜阁，顾清霜。这些人不是寻常恶差，身上带有鬼市血煞气。小丫头，你家大人在哪里？"
NextNode: "node_transition_to_valley"
```

---

### 第二场：烟岚古道 · 奇门解围

```text
[StoryBeat: beat_valley_entrance]
Caption: "南岭 · 烟岚迷径"
Text: "林深雾重，草木含毒。前方刀剑撞击之声不绝于耳。"
Duration: 3.0

[DialogueNode: node_lancheng_dodge]
Speaker: "岚尘"
Text: "（嘴里叼着草茎，一边身法如猿猴般在树桠间跳跃，一边叫嚷）我说几位大哥，不就是摘了你们两株杂草吗？至于追我三个山头吗？"
NextNode: "node_hunter_shout"

[DialogueNode: node_hunter_shout]
Speaker: "鬼市猎手首领"
Text: "小子找死！那不是草，是老祖要的血灵药引！留下你的狗头充当药肥！放穿云箭！"
NextNode: "node_ambush_danger"

[DialogueChoice: choice_rescue_1_shield]
Text: "【配合清霜】以剑气挑起枯木作盾，助清霜施展化劲掌法。"
NextNode: "node_combo_shield"
Events: [SetFlag: "synergy_point" = 1]

[DialogueChoice: choice_rescue_2_flank]
Text: "【独自突袭】身法全开，直插敌方弩手后排死角。"
NextNode: "node_flank_attack"
Events: [SetFlag: "solo_flank" = true]

[DialogueNode: node_combo_shield]
Speaker: "沈长风"
Text: "清霜，借力！"
NextNode: "node_combo_frost_action"

[DialogueNode: node_combo_frost_action]
Speaker: "顾清霜"
Text: "（足尖点在长风剑脊之上，凌空跃起，素袖翻飞如浪潮）沧澜诀 · 逆水还潮！"
NextNode: "node_arrows_deflected"

[DialogueNode: node_arrows_deflected]
Speaker: "旁白"
Text: "毒箭尽数被回潮掌风卷入气旋反掷而出，猎手惨叫倒地。岚尘趁机轻灵飘落两人身侧。"
NextNode: "node_lancheng_thanks"

[DialogueNode: node_lancheng_thanks]
Speaker: "岚尘"
Text: "呼……好险好险！在下烟岚谷岚尘，多谢二位侠士拔刀相助！这位仙子姐姐这一掌，简直神乎其技！"
NextNode: "node_lancheng_reveal"

[DialogueNode: node_lancheng_reveal]
Speaker: "岚尘"
Text: "（收起嬉笑，神情严肃）城西地下鬼市，有个叫‘盲骨叟’的疯魔老怪。他们用活人年轻武者的精血，灌溉上古邪种‘血灵芝’，号称炼制长生不老仙丹，实际上服下之人全成了噬肉怪物！今晚子时，就是血丹出炉祭祀！"
NextNode: "node_changfeng_resolve"

[DialogueNode: node_changfeng_resolve]
Speaker: "沈长风"
Text: "（按紧佩剑）活人炼药……灭绝人道。今晚，平了这处鬼市！"
NextNode: "encounter_trigger_forest"
```

---

### 第三场：地下鬼市 · 血炉破妄

```text
[StoryBeat: beat_ghost_market]
Caption: "子时 · 地下血窟"
Text: "幽暗火光摇曳，铜鼎内沸水翻滚。人间炼狱，莫过于此。"
Duration: 3.5

[DialogueNode: node_furnace_view]
Speaker: "岚尘"
Text: "（贴着石柱潜行）看，那三十多个铁笼里锁的，全是这一个月来失踪的各派弟子与散修！"
NextNode: "node_boss_monologue"

[DialogueNode: node_boss_monologue]
Speaker: "盲骨叟"
Text: "（拄着白骨药杖，贪婪吸吮着热气，枯哑大笑）好！好药力！纯阳纯阴的血脉交融，再加上国师赐下的‘仙界死煞引’……老夫这具残躯，终于能再延寿三十载了！"
NextNode: "node_changfeng_burst_in"

[DialogueNode: node_changfeng_burst_in]
Speaker: "沈长风"
Text: "（长剑出鞘，剑芒贯穿幽暗大殿，轰然斩碎悬吊血锁）凭这些无辜性命为你这苟延残喘的恶鬼续命？你配吗！"
NextNode: "node_boss_rage"

[DialogueNode: node_boss_rage]
Speaker: "盲骨叟"
Text: "黄口小儿！懂什么长生之苦？天下老祖都要死，唯有老夫能活！杀了他们，抽干精血丢入鼎中！"
NextNode: "node_scroll_awakening"

[DialogueNode: node_scroll_awakening]
Speaker: "旁白"
Text: "盲骨叟周身血煞翻腾，杖法无漏，常规剑招难以击穿其邪罡护罩。沈长风胸口古卷剧烈共鸣，【演武明镜】彻底显化！"
NextNode: "node_insight_flash"

[DialogueNode: node_insight_flash]
Speaker: "沈长风"
Text: "（心眼洞照，在盲骨叟铜铃摇晃的瞬间，看到了他膻中穴气脉逆流的死穴）清霜，截他左路！岚尘，断其排烟铜管！"
NextNode: "node_trio_action"

[DialogueNode: node_trio_action]
Speaker: "顾清霜 & 岚尘"
Text: "好！/ 瞧我的！"
NextNode: "node_boss_defeat"

[DialogueNode: node_boss_defeat]
Speaker: "旁白"
Text: "长风施展推演出的破穴绝招【折柳·无痕】，剑芒精准洞穿骨杖核心，盲骨叟狂嚎吐血，轰然跌落熄灭的铜炉之中！"
NextNode: "node_aftermath_dawn"
```

---

### 第四场：尾声 · 逆仙盟约

```text
[StoryBeat: beat_act1_dawn]
Caption: "拂晓 · 破晓清霜"
Text: "地下血窟被彻底焚毁，朝阳自水面升起，洒在少年游侠带伤的脸庞。"
Duration: 3.5

[DialogueNode: node_ledger_discovery]
Speaker: "岚尘"
Text: "（翻看着从盲骨叟密室搜出的血字账册，脸色大变）长风，清霜，事情比我们想的可怖百倍……这些血丹，根本不是盲骨叟一个人的主意，绝大部分成品，全部贴着皇室封条，直运大乾神都——通天观！"
NextNode: "node_qingshuang_heaviness"

[DialogueNode: node_qingshuang_heaviness]
Speaker: "顾清霜"
Text: "国师陈玄道……朝廷以天下苍生为药引，只为给垂死的暴君续命。难怪沧澜阁多次上书皆石沉大海。"
NextNode: "node_changfeng_look_ahead"

[DialogueNode: node_changfeng_look_ahead]
Speaker: "沈长风"
Text: "师父的武馆，也是被他们这群求长生的恶鬼焚毁的。神都这一趟，哪怕九死一生，我也去定了。"
NextNode: "node_trio_vow"

[DialogueNode: node_trio_vow]
Speaker: "顾清霜"
Text: "（素手轻按长风手背，目光温柔而坚定）你不是一人。沧澜之剑，与你同行。"
NextNode: "node_lancheng_join"

[DialogueNode: node_lancheng_join]
Speaker: "岚尘"
Text: "算我一个！神都路远，没我这个识药认路的名捕，你们指不定在荒山里迷路呢！"
NextNode: "node_act1_complete"

[DialogueNode: node_act1_complete]
Speaker: "旁白"
Text: "晨风吹拂，青衫猎猎。微末草莽初试锋芒，三道身影并肩策马，踏上直面神都天倾的漫漫长路！"
NextNode: ""
```

