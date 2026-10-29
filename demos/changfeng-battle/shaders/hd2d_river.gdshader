shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// Stylized river surface. Geometry stays visual-only; gameplay terrain remains
// the authoritative 15x10 BattleModel grid.
uniform vec4 deep_color : source_color = vec4(0.07, 0.26, 0.30, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.19, 0.48, 0.48, 1.0);
uniform vec4 foam_color : source_color = vec4(0.67, 0.83, 0.75, 1.0);
uniform float flow_speed : hint_range(0.0, 4.0) = 0.65;
uniform float ripple_scale : hint_range(0.1, 10.0) = 2.7;
uniform float ripple_strength : hint_range(0.0, 0.2) = 0.055;

void vertex() {
    float wave = sin(VERTEX.z * ripple_scale + TIME * flow_speed * 3.0)
        + sin(VERTEX.x * 3.2 - VERTEX.z * 1.8 + TIME * flow_speed * 2.2);
    VERTEX.y += wave * ripple_strength;
}

void fragment() {
    float streak = sin((UV.y * 23.0 + UV.x * 4.0 - TIME * flow_speed) * 6.283185);
    float ripples = sin(UV.y * 67.0 - TIME * flow_speed * 2.4)
        * sin(UV.x * 13.0 + UV.y * 29.0);
    float blend = clamp(0.45 + streak * 0.17 + ripples * 0.12, 0.0, 1.0);
    ALBEDO = mix(deep_color.rgb, shallow_color.rgb, blend);
    float foam = smoothstep(0.89, 0.985, streak * 0.5 + 0.5);
    EMISSION = foam_color.rgb * foam * 0.19;
    ROUGHNESS = 0.19;
    METALLIC = 0.08;
}
