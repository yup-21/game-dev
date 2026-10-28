extends RefCounted
## Storage only: emitting a display event never calls rules or hooks.
var state
func _init(s) -> void:
	state=s

func emit(kind: String, data: Dictionary = {}) -> Dictionary:
	var event: Dictionary=data.duplicate(true)
	event["type"]=kind
	event["seq"]=state.event_seq
	event["event_id"]="%s:event:%d" % [state.battle_id,state.event_seq]
	event["root_action_id"]=state.root_action_id
	event["tick"]=state.global_tick
	state.event_seq+=1
	state.events.append(event)
	state.pending_events.append(event)
	var text: String=str(event.get("text",""))
	state.logs.append({"text":text,"type":kind,"tick":state.global_tick,"seq":event.seq})
	if state.logs.size()>80: state.logs.pop_front()
	return event
