extends RefCounted
const UNIT: int = 10000
var id: int
var team_id: int = 0
var controller: String = "AI"
var name: String
var cell: Vector2i
var base_attributes: Dictionary = {"STR":10,"AGI":10,"CON":10,"MND":10}
var attributes: Dictionary = {"STR":10,"AGI":10,"CON":10,"MND":10}
var effective_attributes: Dictionary = {"STR":10,"AGI":10,"CON":10,"MND":10}
var equipment_modifiers: Array=[]
var progression: Dictionary = {}
var martial_progress: Dictionary = {}
var stats: Dictionary = {}
var passives: Dictionary = {"insight":0,"conceal":0}
var school_id: String = "tingfeng"
var school_name: String = "听风五式"
var hand_generation: int = 0
var hp_u: int = 200000
var base_max_hp_u: int = 200000 # Innate/persistent attribute-derived ceiling, untouched by status effects.
var max_hp_u: int = 200000 # Effective ceiling after buffs/debuffs; legacy max_hp reads this.
var qi_u: int = 30000
var max_qi_u: int = 60000
var shield_u: int = 0
var shield_expiry: int = -1
var gauge: int = 10000
var regen_qi_remainder: int = 0
var regen_hp_remainder: int = 0
var turns_started: int = 0
var normal_moves_used: int = 0
var basic_attack_used: bool = false
var basic_guard_used: bool = false
var pitch_used: bool = false
var hand: Array = []
var draw_pile: Array = []
var discard_pile: Array = []
var resolving: Array = []
var exile_pile: Array = []
var statuses: Dictionary = {}
var equipped_passives: Array = []
var learned_combos: Array = []
var attack_history: Array = []
var combo_used: Array = []
var card_uses: Dictionary = {}
var technique_states: Dictionary = {}
var hp: float:
	get: return float(hp_u)/UNIT
var base_max_hp: float:
	get: return float(base_max_hp_u)/UNIT
var max_hp: float:
	get: return float(max_hp_u)/UNIT
var qi: float:
	get: return float(qi_u)/UNIT
var max_qi: float:
	get: return float(max_qi_u)/UNIT
var shield: float:
	get: return float(shield_u)/UNIT

func _init(actor_id: int = 0, actor_name: String = "", start_cell: Vector2i = Vector2i.ZERO) -> void:
	id=actor_id
	name=actor_name
	cell=start_cell

func public_data(_include_hand: bool = false) -> Dictionary:
	return {"id":id,"name":name,"team_id":team_id,"controller":controller,"cell":cell,"hp":hp,"max_hp":max_hp,"base_max_hp":base_max_hp,"qi":qi,"max_qi":max_qi,
		"school_id":school_id,"school_name":school_name,
		"shield":shield,"gauge":gauge,"charge_speed":stats.get("charge_speed",100),
		"attributes":effective_attributes.duplicate(true),"base_attributes":base_attributes.duplicate(true),"growth_attributes":attributes.duplicate(true),"statuses":statuses.duplicate(true),
		"turns_started":turns_started,"normal_moves_used":normal_moves_used,"move_budget":stats.get("move_budget",2),
		"basic_attack_used":basic_attack_used,"basic_guard_used":basic_guard_used,"pitch_used":pitch_used,
		"hand_count":hand.size(),"draw_count":draw_pile.size(),"discard_count":discard_pile.size(),"resolving_count":resolving.size(),"exile_count":exile_pile.size()}
