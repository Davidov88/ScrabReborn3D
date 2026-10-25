shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 base_color : source_color = vec4(0.35,0.39,0.4,1.0);
uniform float metalness = 0.18;
uniform float damage : hint_range(0.0,1.0) = 0.0;
uniform sampler2D surface_color : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D surface_normal : hint_normal, filter_linear_mipmap, repeat_enable;
varying vec3 local_pos;
float hash3(vec3 p) {return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
void vertex(){local_pos=VERTEX;}
void fragment(){
 float coarse=hash3(floor(local_pos*32.0));
 float grain=hash3(floor(local_pos*680.0));
 float grime=smoothstep(0.48,0.95,coarse);
 float scratch=step(0.993,fract(local_pos.y*270.0+hash3(floor(local_pos*vec3(22.0,2.0,22.0)))));
 vec3 texture_color=texture(surface_color,UV*2.0).rgb;
 ALBEDO=base_color.rgb*(0.94+grain*0.025-grime*0.08)*mix(vec3(1.0),texture_color,0.10)+vec3(scratch*0.025);
 ALBEDO*=mix(1.0,0.28,damage*smoothstep(0.1,0.8,coarse));
 NORMAL_MAP=texture(surface_normal,UV*2.0).rgb;
 NORMAL_MAP_DEPTH=0.08;
 METALLIC=metalness;
 ROUGHNESS=clamp(0.42+grime*0.27+grain*0.08,0.0,1.0);
}
