shader_type canvas_item;


uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;


uniform vec4 sea_light : source_color = vec4(0.05, 0.60, 0.85, 1.0);
uniform vec4 sea_dark : source_color = vec4(0.00, 0.08, 0.25, 1.0);
uniform vec4 ray_color : source_color = vec4(0.85, 0.95, 1.0, 1.0);
uniform float aspect_ratio = 1.777;


uniform float ray_intensity : hint_range(0.0, 2.0) = 0.8; 



uniform float ray_length : hint_range(0.1, 5.0) = 2.0; 

uniform float ray_focus : hint_range(1.0, 10.0) = 3.0; 

uniform float ray_cone_width : hint_range(0.01, 1.0) = 0.4; 


uniform float ambient_tint_strength : hint_range(0.0, 1.0) = 0.25;


uniform float z_distance : hint_range(0.0, 1.0) = 0.0; 
uniform float vignette_strength : hint_range(0.0, 2.0) = 0.8; 



float rayStrength(vec2 ray_source, vec2 ray_ref_dir, vec2 uv, float seedA, float seedB, float speed, float time, float length_mult) {
    vec2 source_to_uv = uv - ray_source;
    

    float cos_angle = dot(normalize(source_to_uv), ray_ref_dir);
    

    float ray = clamp(
        (0.45 + 0.15 * sin(cos_angle * seedA + time * speed)) +
        (0.3 + 0.2 * cos(-cos_angle * seedB + time * speed)),
        0.0, 1.0);
        

    ray = pow(ray, ray_focus);
        

    float dist_fade = smoothstep(ray_length * length_mult, 0.0, length(source_to_uv));
    

    float cone_fade = smoothstep(1.0 - ray_cone_width, 1.0, cos_angle);
    
    return ray * dist_fade * cone_fade;
}

void fragment() {



    vec4 screen_color = texture(screen_texture, SCREEN_UV);

    vec2 aspect_uv = UV;
    aspect_uv.x *= aspect_ratio;




    vec2 ray_pos1 = vec2(0.5, -0.4); 
    vec2 ray_dir1 = normalize(vec2(0.0, 1.0)); 

    float r1 = rayStrength(ray_pos1, ray_dir1, UV, 35.0, 22.0, 1.1, TIME, 1.0);

    vec2 ray_pos2 = vec2(0.3, -0.2); 
    vec2 ray_dir2 = normalize(vec2(0.2, 1.0)); 

    float r2 = rayStrength(ray_pos2, ray_dir2, UV, 25.0, 18.0, 0.9, TIME, 0.8);

    float total_rays = (r1 * 0.6 + r2 * 0.4);


    float light_absorption = smoothstep(ray_length, 0.1, UV.y); 
    
    vec3 god_rays_layer = ray_color.rgb * total_rays * light_absorption * ray_intensity;




    float depth_grad = smoothstep(0.0, 0.25, UV.y) * 0.2 + smoothstep(0.25, 1.0, UV.y) * 0.8;
    vec3 ambient_gradient = mix(sea_light.rgb, sea_dark.rgb, depth_grad);
    
    vec3 tinted_scene = mix(screen_color.rgb, screen_color.rgb * ambient_gradient, ambient_tint_strength);




    float dist_from_center = distance(UV, vec2(0.5, 0.5));
    float vignette = smoothstep(0.2, 1.0, dist_from_center) * vignette_strength;
    
    float total_darkness = clamp(z_distance + vignette, 0.0, 1.0);
    
    vec3 deep_void_color = sea_dark.rgb * 0.15; 
    tinted_scene = mix(tinted_scene, deep_void_color, total_darkness);
    
    god_rays_layer *= (1.0 - (total_darkness * 0.7));




    COLOR = vec4(tinted_scene + god_rays_layer, screen_color.a);
}
