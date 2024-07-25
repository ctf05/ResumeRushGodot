extends Node

class_name HitboxGenerator

static func generate_hitbox_from_png(texture: Texture2D) -> CollisionPolygon2D:
	var bitmap = BitMap.new()
	bitmap.create_from_image_alpha(texture.get_image())
	
	var polygons = bitmap.opaque_to_polygons(Rect2(Vector2.ZERO, texture.get_size()))
	
	if polygons.size() > 0:
		var collision_polygon = CollisionPolygon2D.new()
		collision_polygon.polygon = polygons[0]  # Use the first (and usually only) polygon
		return collision_polygon
	else:
		push_error("No opaque pixels found in the image")
		return null

static func create_texture_button_with_hitbox(texture_path: String) -> TextureButton:
	var texture = load(texture_path)
	if not texture:
		push_error("Failed to load texture: " + texture_path)
		return null
	
	var button = TextureButton.new()
	button.texture_normal = texture
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_COVERED
	button.size = texture.get_size()
	
	var hitbox = generate_hitbox_from_png(texture)
	if hitbox:
		button.add_child(hitbox)
	
	return button
