shader_type canvas_item;

void fragment() {
    vec2 distance_from_center = UV - vec2(0.5);
    if (dot(distance_from_center, distance_from_center) > 0.210) {
        discard;
    }
    COLOR = texture(TEXTURE, UV);
}
