extends RefCounted
## Snapshot-only HUD projection; no BattleModel writes or combat decisions.
## Node handles are owned and created by the scene, allowing incremental
## extraction without changing the tested public control names.
static func render(snapshot: Dictionary, owner_id: int, priority: Variant,
        story_encounter: bool, auto_battle: bool, spatial_mode: String,
        has_free_space: bool, player_decision: bool, ticket: int,
        controls: Dictionary) -> void:
    var status: Label = controls.status
    var mode := "雨夜追兵 · 多人交锋" if story_encounter else "断桥论剑 · HD-2D"
    var active_name := str(priority.name) if priority != null else "等待结算"
    var school_name := str(priority.school_name) if priority != null else ""
    var stance_ready: bool = (priority != null
        and priority.technique_states.has("tf_change_stage")
        and str(priority.technique_states.tf_change_stage.node) == "ready")
    status.text = "第 %d 拍  ·  %s%s" % [
        int(snapshot.get("global_tick", 0)), active_name,
        "  ◈ 变锋待发" if stance_ready else ""]
    var auto: Button = controls.auto
    if auto != null:
        auto.text = "自动战斗 · 开" if auto_battle else "自动战斗 · 关"
    var spatial: Button = controls.spatial
    if spatial != null:
        spatial.text = "无网格 · 自由" if spatial_mode == "FREE" else "网格 · 战棋"
        spatial.disabled = (not has_free_space or auto_battle or not player_decision
            or ticket >= 0 or bool(snapshot.get("animation_pending", false)))
    status.tooltip_text = "%s / %s / %s" % [mode,
        str(snapshot.get("phase", "")), school_name]
    if str(snapshot.get("outcome", "playing")) != "playing":
        status.text += "    ·    战斗结束：" + str(snapshot.get("outcome", ""))
    var roster_labels: Dictionary = controls.roster_labels
    var roster_bars: Dictionary = controls.roster_bars
    for actor in snapshot.get("actors", []):
        var id := int(actor.id)
        if not roster_labels.has(id):
            continue
        var marker := "◆" if id == owner_id else "◇"
        var role := "手动" if str(actor.get("controller", "")) == "PLAYER" else "自动"
        var hp := float(actor.get("hp", 0.0))
        var max_hp := maxf(1.0, float(actor.get("max_hp", 1.0)))
        var qi := float(actor.get("qi", 0.0))
        var gauge := int(actor.get("gauge", 0))
        roster_labels[id].text = "%s %s" % [marker, str(actor.get("name", "江湖客"))]
        roster_labels[id].tooltip_text = "%s  ·  集气 %d\n血 %.0f / %.0f  ·  气 %.1f" % [
            role, gauge, hp, max_hp, qi]
        if roster_bars.has(id):
            var bars: Dictionary = roster_bars[id]
            var hp_bar: ProgressBar = bars.hp
            hp_bar.max_value = max_hp
            hp_bar.value = clampf(hp, 0.0, max_hp)
            hp_bar.tooltip_text = "气血 %.0f / %.0f" % [hp, max_hp]
            var qi_bar: ProgressBar = bars.qi
            var max_qi := maxf(1.0, maxf(qi, float(actor.get("max_qi", 10.0))))
            qi_bar.max_value = max_qi
            qi_bar.value = clampf(qi, 0.0, max_qi)
            qi_bar.tooltip_text = "真气 %.1f / %.1f" % [qi, max_qi]
    var rail: Control = controls.rail
    if rail != null:
        rail.call("set_state", snapshot.get("actors", []), owner_id)
    var in_clash := str(snapshot.get("phase", "")) == "CLASH"
    var commands: VBoxContainer = controls.commands
    var has_commands := commands != null and commands.get_child_count() > 0
    var veil: TextureRect = controls.veil
    if veil != null:
        veil.visible = in_clash or (has_commands and player_decision)
    var scroll: ScrollContainer = controls.scroll
    if scroll != null:
        scroll.visible = has_commands and player_decision
        scroll.offset_top = 78.0 if in_clash else 12.0
    var clash: Label = controls.clash
    if clash != null:
        clash.visible = in_clash
    var phase: Label = controls.phase
    if phase != null:
        phase.text = "◆  交 锋 应 变" if in_clash else (
            "◆  我 方 行 动" if player_decision else "◆  敌 方 行 动")
    if clash != null:
        var clash_data: Dictionary = snapshot.get("clash", {})
        if in_clash:
            clash.text = "响应层 %d / 4    ·    Pass %d / 2\n%s持有响应权；可选择合法应对" % [
                clash_data.get("stack", []).size(),
                int(clash_data.get("consecutive_passes", 0)),
                "我方" if player_decision else "敌方"]
        else:
            clash.text = "走位  /  出招  /  护体  /  连携\n所有指令由原有规则与合法动作校验"
