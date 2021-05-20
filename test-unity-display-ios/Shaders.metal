//
//  Shaders.metal
//  test-unity-plugin-display-ios
//
//  Created by Yuchen on 2021/3/19.
//

#include <metal_stdlib>
using namespace metal;
struct AppData
{
    float4 in_pos [[attribute(0)]];
};
struct VProgOutput
{
    float4 out_pos [[position]];
    float2 texcoord;
};
struct FShaderOutput
{
    half4 frag_data [[color(0)]];
};
vertex VProgOutput vprog(AppData input [[stage_in]])
{
    VProgOutput out = { float4(input.in_pos.xy, 0, 1), input.in_pos.zw };
    return out;
}
constexpr sampler blit_tex_sampler(address::clamp_to_edge, filter::linear);
fragment FShaderOutput fshader_tex(VProgOutput input [[stage_in]], texture2d<half> tex [[texture(0)]], texture2d<half> tex2 [[texture(1)]])
{
    // merge two textures into one for ATW
    FShaderOutput out;
    if(input.out_pos.x < tex.get_width() / 2) {
        input.texcoord.x *= 2;
        out = { tex.sample(blit_tex_sampler, input.texcoord) };
    } else {
        input.texcoord.x = (input.texcoord.x - tex.get_width() / 2) * 2;
        out = { tex2.sample(blit_tex_sampler, input.texcoord) };
    }
    return out;
}
fragment FShaderOutput fshader_color(VProgOutput input [[stage_in]])
{
    FShaderOutput out = { half4(1,0,0,1) };
    return out;
}
