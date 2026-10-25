shader_type canvas_item;
uniform sampler2D scene_image : hint_screen_texture, repeat_disable, filter_linear;
void fragment() {
 vec3 scene=texture(scene_image,SCREEN_UV).rgb;
 float luminance=dot(scene,vec3(0.2126,0.7152,0.0722));
 float signal=clamp(pow(max(luminance,0.0),0.46)*1.55,0.0,1.0);
 float vignette=1.0-smoothstep(0.28,0.78,length(UV-vec2(0.5)))*0.25;
 float scan=1.0-0.018*step(0.5,fract(FRAGCOORD.y*0.5));
 vec3 phosphor=vec3(0.52,0.91,0.77)*signal*vignette*scan;
 COLOR=vec4(mix(phosphor,scene,0.12),1.0);
}
