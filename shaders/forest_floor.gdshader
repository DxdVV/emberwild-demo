shader_type canvas_item;
render_mode unshaded;

uniform sampler2D ground_atlas : source_color, filter_nearest, repeat_disable;
uniform vec2 world_size = vec2(2400.0,1600.0);
uniform float pixel_step = 2.0;
uniform int trail_count = 0;
uniform vec4 trails[32];
uniform float trail_widths[32];
uniform int clearing_count = 0;
uniform vec4 clearings[12];
uniform int surfaces[12];

float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float segment(vec2 p,vec2 a,vec2 b) {
    vec2 v=b-a;
    return length(p-a-v*clamp(dot(p-a,v)/max(dot(v,v),0.001),0.0,1.0));
}
vec3 tile(vec2 p,vec2 cell) {
    vec2 uv=fract(p/128.0);
    vec2 quadrant=mod(floor(p/128.0),2.0);
    uv=mix(uv,1.0-uv,quadrant);
    // The authored quadrant boundary is a few pixels off the exact half.
    // An interior UV region prevents adjacent water/stone rows bleeding in.
    uv=mix(vec2(.02),vec2(.98),uv);
    return texture(ground_atlas,(cell+uv)*.5).rgb;
}
void fragment() {
    vec2 p=floor(UV*world_size/pixel_step)*pixel_step;
    float trail=10000.0;
    for(int i=0;i<trail_count;i++) {
        trail=min(trail,segment(p,trails[i].xy,trails[i].zw)-trail_widths[i]);
    }
    float rough=sin(p.x*.027+p.y*.031)*9.0+sin(p.y*.081)*5.0;
    float blend=clamp((trail+rough)/24.0,0.0,1.0);
    float noise=hash(floor(p/4.0));
    vec3 grass=tile(p,vec2(0,0));
    vec3 dirt=tile(p,vec2(1,0));
    vec3 stone=tile(p,vec2(1,1));
    vec3 color=mix(dirt,grass,step(noise,blend));
    for(int i=0;i<clearing_count;i++) {
        float edge=(length((p-clearings[i].xy)/clearings[i].zw)-1.0)*min(clearings[i].z,clearings[i].w);
        if(edge<24.0) color=mix(surfaces[i]==1 ? stone : dirt,color,step(noise,clamp((edge+rough)/24.0,0.0,1.0)));
    }
    float luma=dot(color,vec3(.299,.587,.114));
    color=mix(vec3(luma),color,.85)*vec3(.84,.88,.81);
    COLOR=vec4(floor(color*31.0+.5)/31.0,1.0);
}
