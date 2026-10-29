extends RefCounted
## Base four attributes -> permanent growth -> reversible states -> derived snapshot.
const UNIT: int=10000
const Pipeline=preload("res://scripts/attribute_modifier_pipeline.gd")

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

func configure(actor,overrides: Dictionary={},talents: Dictionary={}) -> void:
	for key in actor.base_attributes:
		actor.base_attributes[key]=clampi(int(overrides.get(key,10)),1,100)
	actor.attributes=actor.base_attributes.duplicate(true)
	actor.effective_attributes=actor.attributes.duplicate(true)
	actor.stats=derive(actor.attributes)
	actor.base_max_hp_u=int(actor.stats.max_hp)*UNIT
	actor.max_hp_u=actor.base_max_hp_u
	actor.hp_u=actor.max_hp_u
	actor.max_qi_u=int(actor.stats.max_qi_u)
	actor.qi_u=3*UNIT
	actor.passives={"insight":clampi(int(talents.get("insight",0)),0,2),"conceal":clampi(int(talents.get("conceal",0)),0,2)}

func recalculate(actor,states) -> void:
	if states==null:
		actor.effective_attributes=actor.attributes.duplicate(true)
		actor.stats=derive(actor.attributes)
		actor.base_max_hp_u=int(actor.stats.max_hp)*UNIT
		actor.max_hp_u=actor.base_max_hp_u
		actor.max_qi_u=int(actor.stats.max_qi_u)
		actor.hp_u=mini(actor.hp_u,actor.max_hp_u)
		actor.qi_u=mini(actor.qi_u,actor.max_qi_u)
	else:
		Pipeline.new(self).recalculate(actor,states)
