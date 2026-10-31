extends RefCounted
const UNIT: int = 10000
const Modifiers = preload("res://scripts/stat_modifier_system.gd")
var modifiers = Modifiers.new()

func derive(a: Dictionary) -> Dictionary:
	var ds: int=int(a.get("STR",10))-10
	var da: int=int(a.get("AGI",10))-10
	var dc: int=int(a.get("CON",10))-10
	var dm: int=int(a.get("MND",10))-10
	return {"max_hp":maxi(10,20+dc),"attack":maxi(1,10+ds),"defense":maxi(1,10+dc),
		"break_power":10+floori(0.5*ds+0.25*da),"parry_power":10+floori(0.5*dm+0.25*da),
		"max_qi_u":clampi(6+floori(float(dm)/5),4,10)*UNIT,
		"qi_regen_u_per_100":clampi(30000+300*dm,20000,40000),
		"hp_regen_u_per_100":clampi(2000+200*dc,0,6000),
		"qi_cost_percent":clampi(100-dm,85,110),"charge_speed":clampi(100+2*da,75,130),
		"move_budget":clampi(2+floori(float(maxi(0,da))/12),2,3)}

func configure(actor, overrides: Dictionary = {}, talents: Dictionary = {}) -> void:
    actor.base_attributes = {}
    actor.modifier_sources.clear()
    for key in ["STR","AGI","CON","MND"]:
        actor.base_attributes[key] = clampi(int(overrides.get(key,10)),1,100)
    recalculate(actor)
    actor.hp_u = actor.max_hp_u
    actor.qi_u = 3 * UNIT
    actor.passives = {"insight":clampi(int(talents.get("insight",0)),0,2),
        "conceal":clampi(int(talents.get("conceal",0)),0,2)}

func recalculate(actor) -> void:
    ## Sources are keyed by stable tokens: status:id, equipment:slot, growth:id.
    ## Rebuild from immutable bases to prevent stacking drift or stale debuffs.
    var computed: Dictionary = modifiers.apply(actor.base_attributes,actor.modifier_sources)
    for key in ["STR","AGI","CON","MND"]:
        actor.attributes[key] = clampi(int(computed.get(key,10)),1,100)
    actor.stats = modifiers.apply(derive(actor.attributes),actor.modifier_sources)
    actor.stats.max_hp = clampi(int(actor.stats.max_hp),10,10000)
    actor.stats.attack = maxi(1,int(actor.stats.attack))
    actor.stats.defense = maxi(1,int(actor.stats.defense))
    actor.stats.break_power = maxi(0,int(actor.stats.break_power))
    actor.stats.parry_power = maxi(0,int(actor.stats.parry_power))
    actor.stats.max_qi_u = clampi(int(actor.stats.max_qi_u),UNIT,100*UNIT)
    actor.stats.qi_regen_u_per_100 = maxi(0,int(actor.stats.qi_regen_u_per_100))
    actor.stats.hp_regen_u_per_100 = maxi(0,int(actor.stats.hp_regen_u_per_100))
    actor.stats.qi_cost_percent = clampi(int(actor.stats.qi_cost_percent),0,1000)
    actor.stats.charge_speed = clampi(int(actor.stats.charge_speed),1,1000)
    actor.stats.move_budget = clampi(int(actor.stats.move_budget),0,10)
    actor.max_hp_u = int(actor.stats.max_hp) * UNIT
    actor.max_qi_u = int(actor.stats.max_qi_u)
    # Changing a cap does not grant free health/qi; removal clamps to the cap.
    actor.hp_u = mini(actor.hp_u,actor.max_hp_u)
    actor.qi_u = mini(actor.qi_u,actor.max_qi_u)
