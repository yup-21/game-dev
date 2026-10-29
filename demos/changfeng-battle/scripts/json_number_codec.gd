extends RefCounted
## Godot JSON parsing yields float for all numeric tokens. Recreate safe integer values.
static func normalize(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary={}
		for key in value: result[key]=normalize(value[key])
		return result
	if value is Array:
		var result: Array=[]
		for child in value: result.append(normalize(child))
		return result
	if value is float and is_finite(value) and absf(value)<9000000000000000.0 and floor(value)==value:
		return int(value)
	return value
