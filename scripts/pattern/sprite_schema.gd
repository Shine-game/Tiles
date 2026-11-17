class_name PatternSpriteSchema
extends RefCounted

# The JSON Schema vocabulary used by the bundled, versioned sprite schema.
# This is intentionally not a general implementation of every Draft 2020-12 keyword.
static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _equal(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b) and not (_number(a) and _number(b)): return false
	return a == b

static func _type(value: Variant, type: String) -> bool:
	match type:
		"object": return value is Dictionary
		"array": return value is Array
		"string": return value is String
		"boolean": return value is bool
		"number": return _number(value)
		"integer": return _number(value) and float(value) == floorf(float(value))
	return false

static func validate(value: Variant, schema: Variant, path: String = "$") -> Array:
	if schema is bool: return [] if schema else [path + ": value is not permitted"]
	var errors: Array = []
	if schema.has("type") and not _type(value, schema.type): return [path + ": expected " + str(schema.type)]
	if schema.has("const") and not _equal(value, schema.const): errors.append(path + ": unexpected constant")
	if schema.has("enum") and not schema.enum.any(func(item): return _equal(value, item)): errors.append(path + ": unsupported value")
	if value is Dictionary:
		var properties: Dictionary = schema.get("properties", {})
		for key: String in schema.get("required", []):
			if not value.has(key): errors.append(path + "." + key + ": required")
		if value.size() < int(schema.get("minProperties", 0)): errors.append(path + ": too few properties")
		for key: Variant in value:
			if not key is String:
				errors.append(path + ": keys must be strings")
			elif properties.has(key): errors.append_array(validate(value[key], properties[key], path + "." + key))
			elif schema.has("additionalProperties"): errors.append_array(validate(value[key], schema.additionalProperties, path + "." + key))
	if value is Array:
		if value.size() < int(schema.get("minItems", 0)) or value.size() > int(schema.get("maxItems", 2147483647)): errors.append(path + ": invalid array length")
		var prefix: Array = schema.get("prefixItems", [])
		for i in range(value.size()):
			if i < prefix.size(): errors.append_array(validate(value[i], prefix[i], path + "[%d]" % i))
			elif schema.has("items"): errors.append_array(validate(value[i], schema.items, path + "[%d]" % i))
			if schema.get("uniqueItems", false):
				for j in range(i):
					if _equal(value[i], value[j]): errors.append(path + "[%d]: duplicate value" % i)
	if _number(value):
		if schema.has("minimum") and value < schema.minimum: errors.append(path + ": below minimum")
		if schema.has("maximum") and value > schema.maximum: errors.append(path + ": above maximum")
		if schema.has("exclusiveMinimum") and value <= schema.exclusiveMinimum: errors.append(path + ": must exceed minimum")
	if value is String:
		if value.length() < int(schema.get("minLength", 0)): errors.append(path + ": string is too short")
		if schema.has("pattern"):
			var pattern := RegEx.new()
			if pattern.compile(schema.pattern) != OK or pattern.search(value) == null: errors.append(path + ": invalid string format")
	for rule: Dictionary in schema.get("allOf", []): errors.append_array(validate(value, rule, path))
	if schema.has("if") and validate(value, schema["if"], path).is_empty() and schema.has("then"): errors.append_array(validate(value, schema.then, path))
	return errors
