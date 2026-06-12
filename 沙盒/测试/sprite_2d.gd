extends Sprite2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
gdscript
shader_type canvas_item;
uniform sampler2D mask_texture;
void fragment() {
    vec4 mask_color = texture(mask_texture, UV);
    COLOR = texture(TEXTURE, UV);
    COLOR.a = mask_color.r;
}