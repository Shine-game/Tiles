shader_type canvas_item;
render_mode unshaded, blend_mix;
uniform float progress = 0.0;
uniform float elapsed = 0.0;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
void fragment() {
 vec4 art=texture(TEXTURE,UV);
 float cloud=noise(UV*5.0+vec2(elapsed*.17,-elapsed*.11))*.65+noise(UV*13.0+elapsed*.09)*.35;
 float radial=clamp(length(UV-vec2(.5))*1.414,0.0,1.0);
 float field=mix(radial,cloud,.65);
 float reveal=smoothstep(field-.12,field+.12,progress*1.3-.15);
 float glow=(.5+.5*sin(elapsed*8.0+cloud*18.0))*.08*(1.0-progress);
 COLOR=vec4(art.rgb+glow,art.a*reveal);
 if(progress<=0.0)COLOR.a=0.0;
 if(progress>=1.0)COLOR=art;
}
