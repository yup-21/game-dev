# 附录 · 第一幕详细剧本与关卡规范：微末斩芒 · 江南药引

> **关联索引**：[企划总库](../README.md) · [主线全景](../03-main-storyline.md) · [人物与女主](../06-characters-and-heroine.md) · [全景人物录](../grand-character-encyclopedia.md) · [序幕详案](act-0-prologue.md)

---

## 一、第一幕核心定位与叙事弧光

本幕承接序幕逃亡之暗淡，将主角正式抛入波澜诡谲的人间江湖，承载五重核心质变：
1. **江湖不再是诗意山水，而是暗流汹涌的修罗场**：表面烟雨如织的江南姑苏，暗地里却在疯狂走私以年轻武者为药引的“血灵芝散”。
2. **主角从独行避祸到并肩立义**：沈长风与顾清霜在市井茶摊初遇，由剑意相试到夜雨剖白，再到联手营救岚尘，建立生死相托的核心团队。
3. **古卷金手指常态化融入玩法**：在面对鬼市诡秘毒功与重甲暗探时，古卷【演武明镜】全面激活，见招拆招的连携系统正式成型。
4. **揭露朝廷与地方勾结的冰山一角**：捣毁地下血炉后缴获大内密封账册，引出大乾皇帝惜命与国师通天血祭的主线大阴谋。

---

## 二、登场人物角色小传与心路

* **沈长风**：身着洗得发白的青灰短褐，怀揣微热兽皮残卷。见识到弱小百姓沦为权贵延寿的药引后，胸中属于侠客的赤子之怒彻底爆发。
* **顾清霜**：沧澜阁嫡传大弟子，奉老阁主之命追查失踪案。外表冷如霜雪，内心背负三十岁早夭死劫，在长风身上看到了不屈的少年意气。
* **岚尘**：烟岚谷青年行者，玩世不恭的外表下藏着师门被毁的切齿之痛。机巧百变，专精暗步与奇门草木。
* **盲骨叟**：天人五衰会外门执事，第一幕关底 Boss。双目皆盲，持白骨药杖，浑身散发甜腻尸香，靠活人血气延寿的典型堕落狂徒。
* **铁鹰**：玄天镇抚司百户，贪得无厌，私下将关押的流民与散修打包卖给鬼市换取黄金与劣质血丹。
* **苏小曼与老药农**：平江茶棚受害祖孙，药王谷的外门采药客，为主角小队提供进入地下鬼市的关键线索。

---

## 三、四大核心场景与关卡机制

1. **场景一：枫桥渡口与平江茶棚（城镇探索与剧情转折）**
   * 青石板长街、临河画舫、飘散着碧螺春茶香的竹棚。暗藏玄天镇抚司爪牙与眼线。
2. **场景二：南岭险径 · 乱石枯林（夜宿剖白与篝火羁绊）**
   * 深山密林中的破败猎人木屋。夜雨连绵，两人烤火长谈，顾清霜首度吐露早夭心事。
3. **场景三：烟岚绝壁 · 迷雾乱石（FREE 连续身法野外战）**
   * 【山岚迷雾】阻碍视野（观势范围 -1）；树桠与悬崖间的高低落差跳跃；联手破解毒箭大阵救下岚尘。
4. **场景四：地下鬼市 · 活人血炉（GRID 15×10 核心大决战）**
   * 干涸古运河改建的地下黑市，深处为青铜蒸汽巨鼎与沸腾血池；【排毒铜阀】机关、击碎三处血锁解救被俘弟子。

---

## 四、第一幕全景剧情分镜与长对白实录

### 第一场：平江茶寮 · 霜剑初遇

```text
[StoryBeat: beat_gusu_arrival]
Caption: "姑苏 · 烟波平江"
Text: "秋水渐平，姑苏城外画舫如织。然而平静水色之下，隐伏着不见天日的暗流。"
Duration: 3.5

[DialogueNode: node_tea_intro]
Speaker: "茶博士"
Text: "（端着一壶滚烫的碧螺春，眼珠子机灵地在长风手腕的粗麻布上打转，压低嗓门）客官，您这一身青灰短褐，料子是江北粗棉，可手腕上缠的却是行家才用的倒马扣。小老儿在这平江渡口看了四十年水，听小老儿一句劝——城里这半月不太平，水下的漩涡比水面上的浪头大得多。"
NextNode: "node_changfeng_inquire"

[DialogueNode: node_changfeng_inquire]
Speaker: "沈长风"
Text: "（用粗瓷碗盖轻轻拨开浮沫，神色平静）小二哥，茶很香。不过我一路走来，连江边晒网的老渔翁都被官兵盘查了三次，这大乾的法度，什么时候管起江里的泥鳅来了？"
NextNode: "node_tea_whisper"

[DialogueNode: node_tea_whisper]
Speaker: "茶博士"
Text: "（苦笑擦拭桌面，四顾耳语）泥鳅官府不管，官府要的是‘活龙’！十几个身强力壮的武家后生，青壮猎户，一夜之间连人带被褥没了踪影。连城西百草堂那位刚修出内劲的大师兄，前儿夜里去西山采药，到天明只在草窠子里留下一只带血的布鞋……衙门不管，反倒把报官的苦主全抓进了‘安康坊’，谁敢多嘴，立刻扣上通匪的帽子！"
NextNode: "node_commotion_start"

[DialogueNode: node_commotion_start]
Speaker: "旁白"
Text: "街巷尽头突然传来一阵尖锐的哭喊声与重靴踏地声。三名腰悬黑铁锁链、佩短刃的差役踢翻了隔壁竹摊，拖着一名扎羊角辫的七岁女童！"
NextNode: "node_spy_threat"

[DialogueNode: node_spy_threat]
Speaker: "镇抚司暗探甲"
Text: "（铁靴踏在老药农胸口）老骨头！私藏西山紫灵芝还敢抵赖？这小丫头气血充盈得很，按大乾军律充入安康坊抵罪！带走！"
NextNode: "node_girl_cry"

[DialogueNode: node_girl_cry]
Speaker: "苏小曼"
Text: "爷爷！放开我！爷爷救我……我不去安康坊！"
NextNode: "choice_tea_intervention"

[DialogueChoice: choice_1_draw_sword]
Text: "【拔剑怒喝】光天化日强掳弱小，大乾律法难道不管强盗？"
NextNode: "node_changfeng_strike"
Events: [SetFlag: "heroic_reputation" = true]

[DialogueChoice: choice_2_observe_cold]
Text: "【按剑冷观】指尖按在剑鞘机簧，暗查三人真气破绽。"
NextNode: "node_observe_action"
Events: [SetFlag: "tactical_insight" = true]

[DialogueNode: node_changfeng_strike]
Speaker: "沈长风"
Text: "住手！光天化日，朗朗乾坤，披着官皮行强梁之事，也不怕污了祖宗门楣！"
NextNode: "node_frost_appears"

[DialogueNode: node_observe_action]
Speaker: "沈长风"
Text: "（目光如寒星）下盘轻浮，太阳穴发青，呼吸带甜腻药臭……他们不是普通捕快，是吸过人血邪药的走狗！"
NextNode: "node_frost_appears"

[DialogueNode: node_frost_appears]
Speaker: "旁白"
Text: "暗探狞笑拔刀之际，一道如秋水般的淡青剑芒自临河画舫疾掠而至！剑鞘未出，轻点暗探腕骨，暗探惨嚎丢刀！"
NextNode: "node_qingshuang_intervene"

[DialogueNode: node_qingshuang_intervene]
Speaker: "顾清霜"
Text: "（一袭素白暗竹织锦长袍，立于画舫船头，神情清冷如初雪）沧澜阁在此，容不得宵小作恶。"
NextNode: "node_changfeng_resonance"

[DialogueNode: node_changfeng_resonance]
Speaker: "旁白"
Text: "【古卷震颤】怀中兽皮残卷泛起微热，沈长风眼前闪过金色轨迹，一眼看穿暗探倒退时的下肋死穴！"
NextNode: "node_changfeng_follow_kick"

[DialogueNode: node_changfeng_follow_kick]
Speaker: "沈长风"
Text: "（心念随剑动，一步游身掠至，剑鞘横扫其肋下，三名暗探如断线风筝倒飞而出）"
NextNode: "node_qingshuang_glance"

[DialogueNode: node_qingshuang_glance]
Speaker: "顾清霜"
Text: "（素袖微敛，清冷眸子打量沈长风）出剑不带官气，身法纯正沉稳。你是何人？"
NextNode: "node_changfeng_reply"

[DialogueNode: node_changfeng_reply]
Speaker: "沈长风"
Text: "江湖散人，沈长风。姑娘那一式‘惊涛抚浪’化劲至深，多谢出手解围。"
NextNode: "node_qingshuang_nod"

[DialogueNode: node_qingshuang_nod]
Speaker: "顾清霜"
Text: "沧澜阁，顾清霜。这些人身上带有鬼市血煞气，城中失踪的年轻武者，怕是凶多吉少。小丫头，你兄长在何处？"
NextNode: "node_girl_tell_truth"

[DialogueNode: node_girl_tell_truth]
Speaker: "苏小曼"
Text: "（抽泣擦泪）大哥哥，仙子姐姐！我师兄为了护送解毒草药，被黑衣人追杀进了南岭烟岚谷……求求你们救救师兄！"
NextNode: ""
```

---

### 第二场：南岭破庙 · 夜雨心灯（长剧本感情升华）

```text
[StoryBeat: beat_night_confession]
Caption: "南岭夜雨 · 枯木寒火"
Text: "追查途中夜雨骤降，两人借宿于山道一处荒废的猎户木屋。窗外雷声隆隆，炉火噼啪作响。"
Duration: 3.5

[DialogueNode: node_fire_silence]
Speaker: "旁白"
Text: "顾清霜坐在破旧竹椅上，双手抱着膝盖，目光凝视着跃动的火焰。橘红色的火光映照着她眉宇间那点清冷的朱砂冰痣，却掩不住眼底深处如冰海般的疲惫。"
NextNode: "node_changfeng_give_coat"

[DialogueNode: node_changfeng_give_coat]
Speaker: "沈长风"
Text: "（将用树枝架着烤干的蓑衣轻轻递过去）山里夜寒湿重，把衣服披上吧。你方才施展化劲时，指尖隐隐泛着青紫寒气……你体内有暗伤？"
NextNode: "node_qingshuang_hesitate"

[DialogueNode: node_qingshuang_hesitate]
Speaker: "顾清霜"
Text: "（接过蓑衣，手指触及长风温热的掌心，微微颤动了一下，低声轻语）沈长风，你见过一个人……在最明媚的春天，无病无痛，就这么当着你的面，化作一地冰屑散去的样子吗？"
NextNode: "node_changfeng_listen"

[DialogueNode: node_changfeng_listen]
Speaker: "沈长风"
Text: "（坐在火堆另一侧，添了一根枯柴）我没见过。但我见过我师父……那夜青州大火，老头子一人挡在武馆门前，胸口插了五根透骨箭，浑身烧焦，手里的铁剑却依然平举着。他回过头冲我吼：‘滚！活下去！学武不是给权贵当奴才，是让你站着做人！’"
NextNode: "node_qingshuang_reveal_curse"

[DialogueNode: node_qingshuang_reveal_curse]
Speaker: "顾清霜"
Text: "（眼眶泛起微红，声音清冷中带着一丝颤音）我娘三十岁死在我面前。这世上所有人都求长生，各大门派的名宿为了多活一年，背地里做的脏事罄竹难书。可他们不知道……被天道诅咒的人，连活到三十岁都是奢望。若是活下去需要去喝那些被拐少年的精血……沈长风，如果有一天我也变成了那样的恶鬼，你拔剑杀我，千万不要手软。"
NextNode: "node_changfeng_vow_fire"

[DialogueNode: node_changfeng_vow_fire]
Speaker: "沈长风"
Text: "（放下茶碗，将青钢剑平平横在两人之间的泥地上，字字千钧）\n若天地不公，那是天地的错，不是你的罪。\n长风手中这把剑，只斩喝血的妖仙，绝不向同伴挥刃。\n你的命，我们一起向天讨回来。"
NextNode: "node_qingshuang_melt"

[DialogueNode: node_qingshuang_melt]
Speaker: "顾清霜"
Text: "（怔怔看着长风坚毅的面庞，唇角泛起一抹雪融春水般的微暖笑意）笨蛋游侠……向天讨命，哪有那么容易。不过……若有你这把剑在身边，这条路，倒也不算太冷。"
NextNode: ""
```

---

### 第三场：烟岚绝壁 · 奇门解围

```text
[StoryBeat: beat_valley_combat]
Caption: "南岭绝壁 · 雾瘴弥漫"
Text: "黎明时分，烟岚迷谷边缘刀剑撞击之声不绝于耳。一名头戴破斗笠的年轻身影在古树间飞跃腾挪。"
Duration: 3.0

[DialogueNode: node_lancheng_banter]
Speaker: "岚尘"
Text: "（嘴里叼着草茎，一边在树桠间如猿猴般飞荡，一边大呼小叫）几位大哥，不就是摘了你们两株杂草吗？追了我三个山头，你们镇抚司的军饷是按步数领的啊？！"
NextNode: "node_hunter_volley"

[DialogueNode: node_hunter_volley]
Speaker: "鬼市黑衣统领"
Text: "放穿云破气弩！把这兔崽子射成筛子！老祖说了，烟岚谷的药苗一株也不能留！"
NextNode: "node_changfeng_combo_rescue"

[DialogueNode: node_changfeng_combo_rescue]
Speaker: "沈长风"
Text: "清霜，借力！"
NextNode: "node_qingshuang_tide_deflect"

[DialogueNode: node_qingshuang_tide_deflect]
Speaker: "顾清霜"
Text: "（足尖点在长风剑脊之上，凌空跃起，素袖翻飞如浪潮）沧澜诀 · 逆水还潮！"
NextNode: "node_lancheng_land"

[DialogueNode: node_lancheng_land]
Speaker: "岚尘"
Text: "（轻灵飘落在两人身侧，擦拭冷汗，两眼放光）哇！好俊的身法！仙子姐姐，你刚才那一掌简直是神仙下凡啊！在下烟岚谷岚尘，多谢二位拔刀相助！"
NextNode: "node_lancheng_expose_truth"

[DialogueNode: node_lancheng_expose_truth]
Speaker: "岚尘"
Text: "（收起嬉笑，神情严肃）你们是为城中失踪案来的吧？城西地下鬼市，天人五衰会的‘盲骨叟’建了一座活人血炉，用数十名纯阳武者的精血，培育上古邪种‘血灵芝’，今晚子时就要开炉献祭！"
NextNode: "node_trio_march"

[DialogueNode: node_trio_march]
Speaker: "沈长风"
Text: "（按紧佩剑）子时开炉……事不宜迟，立刻杀入鬼市！"
NextNode: ""
```

---

### 第四场：地下鬼市 · 血炉破妄（大决战实录）

```text
[StoryBeat: beat_furnace_battle]
Caption: "子夜 · 地下血窟"
Text: "巨大的青铜药鼎悬挂在沸腾血池上，数十个铁笼锁链撞击，空气中弥漫着令人作呕的甜腻药气。"
Duration: 3.5

[DialogueNode: node_boss_arrogant]
Speaker: "盲骨叟"
Text: "（拄着白骨骷髅药杖，吸吮着蒸汽枯哑狂笑）好！吸足了纯阳武者的骨血，再配上国师赐下的‘仙界死煞引’……老夫这具残躯，终于能再活三十年了！哈哈哈！"
NextNode: "node_changfeng_break_in"

[DialogueNode: node_changfeng_break_in]
Speaker: "沈长风"
Text: "（长剑破空，剑芒斩碎吊挂铁锁，救下整排牢笼）老恶鬼！拿年轻人的性命为你苟延残喘？今日便是你的死期！"
NextNode: "node_boss_frenzy"

[DialogueNode: node_boss_frenzy]
Speaker: "盲骨叟"
Text: "不知死活的后生！铜铃响，化骨掌！给老夫吸干他们！"
NextNode: "node_scroll_deduce_moment"

[DialogueNode: node_scroll_deduce_moment]
Speaker: "旁白"
Text: "盲骨叟周身血雾翻腾，白骨杖舞得密不透风，寻常招式难以近身。沈长风胸口古卷爆发出刺目青芒，【演武明镜】彻底洞彻其气机运转！"
NextNode: "node_insight_command"

[DialogueNode: node_insight_command]
Speaker: "沈长风"
Text: "清霜，截他左路膻中！岚尘，斩断他后背的供血铜管！"
NextNode: "node_trio_strike"

[DialogueNode: node_trio_strike]
Speaker: "旁白"
Text: "清霜一式化劲封住骨杖锋芒，岚尘飞刀斩断输气铜管！\n沈长风施展推演出的破穴绝技【折柳·无痕】，青钢剑如惊鸿贯日，精准点破盲骨叟膻中死穴！\n盲骨叟骨杖爆碎，凄厉尖叫着跌落熄灭的铜炉血池！"
NextNode: "node_dawn_break"
```

---

### 第五场：枫桥破晓 · 逆仙誓盟

```text
[StoryBeat: beat_maple_dawn]
Caption: "拂晓 · 枫桥古渡"
Text: "地下血窟被尽数捣毁，黎明朝阳洒在少年游侠带伤的脸庞。江风微凉，吹散了漫天血腥。"
Duration: 3.5

[DialogueNode: node_ledger_shock]
Speaker: "岚尘"
Text: "（翻看着从暗格搜出的血字账册，面色凝重如铁）长风，清霜，你们看这账册底款……大批血丹的收货人，全盖着‘内廷司礼监’与‘无极通天观’的紫金玉印！整座神都……全是这个吃人血阵的源头！"
NextNode: "node_qingshuang_resolve"

[DialogueNode: node_qingshuang_resolve]
Speaker: "顾清霜"
Text: "天下苍生皆为鼎炉，高高在上的仙人与天子，竟视人间如牧场。长风，这一趟神都，我们非去不可。"
NextNode: "node_changfeng_gaze"

[DialogueNode: node_changfeng_gaze]
Speaker: "沈长风"
Text: "师门的大仇在神都，天下的公道也在神都。神都纵是龙潭虎穴，我沈长风凭手中三尺剑，也誓要踏平它！"
NextNode: "node_trio_mount"

[DialogueNode: node_trio_mount]
Speaker: "岚尘"
Text: "（将斗笠往头上一扣，拍拍背上的药囊，爽朗大笑）算我一个！神都水深，没我这个天下第一向导带路，你们可别迷路了！"
NextNode: "node_act1_end"

[DialogueNode: node_act1_end]
Speaker: "旁白"
Text: "晨风拂动青衫，朝阳初染霜剑。三道年轻的身影跃上骏马，马蹄踏碎晨露，向着帝国中枢的巍峨神都，并肩策马而去！"
NextNode: ""
```
