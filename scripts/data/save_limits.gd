class_name SaveLimits extends RefCounted

const MAX_BYTES := 8*1024*1024
const MAX_VALUES := 100000
const MAX_DEPTH := 32
const MAX_COLLECTION := 10000
const MAX_STRING := 4096

static func valid(data) -> bool:
	return visit(data,0,[MAX_VALUES,MAX_BYTES])

static func visit(value, depth: int, remaining: Array) -> bool:
	remaining[0] -= 1
	remaining[1] -= 16
	if remaining[0]<0 or remaining[1]<0 or depth>MAX_DEPTH: return false
	if value is String or value is StringName:
		if str(value).length()>MAX_STRING: return false
		remaining[1] -= str(value).to_utf8_buffer().size()
		return remaining[1]>=0
	if value is float: return is_finite(value)
	if value==null or value is bool or value is int: return true
	if value is Array:
		if value.size()>MAX_COLLECTION: return false
		for entry in value:
			if not visit(entry,depth+1,remaining): return false
		return true
	if value is Dictionary:
		if value.size()>MAX_COLLECTION: return false
		for key in value:
			if not (key is String or key is StringName) or not visit(key,depth+1,remaining) or not visit(value[key],depth+1,remaining): return false
		return true
	return false
