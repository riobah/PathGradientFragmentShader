/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Metal shaders used for this sample
*/

#include <metal_stdlib>

using namespace metal;

// Include header shared between this Metal shader code and C code executing Metal API commands.
#include "AAPLShaderTypes.h"


// HSB -> RGB and RGB -> HSB methods from https://thebookofshaders.com/edit.php#06/hsb.frag
float3 rgb2hsb( float3 c ) {
    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = mix(float4(c.bg, K.wz),
                 float4(c.gb, K.xy),
                 step(c.b, c.g));
    float4 q = mix(float4(p.xyw, c.r),
                 float4(c.r, p.yzx),
                 step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)),
                d / (q.x + e),
                q.x);
}

float3 hsb2rgb( float3 c ) {
    float3 rgb = clamp(abs(fmod(c.x * 6.0 + float3(0.0,4.0,2.0), 6.0) - 3.0) - 1.0,
                     0.0,
                     1.0 );
    rgb = rgb*rgb*(3.0-2.0*rgb);
    return c.z * mix(float3(1.0), rgb, c.y);
}




// Vertex shader outputs and fragment shader inputs
struct RasterizerData
{
    // The [[position]] attribute of this member indicates that this value
    // is the clip space position of the vertex when this structure is
    // returned from the vertex function.
    float4 position [[position]];

    // Since this member does not have a special attribute, the rasterizer
    // interpolates its value with the values of the other triangle vertices
    // and then passes the interpolated value to the fragment shader for each
    // fragment in the triangle.
    float4 color;
    
    float time;
};

vertex RasterizerData
vertexShader(uint vertexID [[vertex_id]],
             constant AAPLVertex *vertices [[buffer(AAPLVertexInputIndexVertices)]],
             constant vector_uint2 *viewportSizePointer [[buffer(AAPLVertexInputIndexViewportSize)]],
             constant float *time [[buffer(AAPLVertexInputIndexTime)]])
{
    RasterizerData out;

    out.position = float4(vertices[vertexID].position.xy, 0, 1);
    out.color = vertices[vertexID].color;
    out.time = *time;

    return out;
}

typedef enum {
    BONAnimationTypeContinuous,
    BONAnimationTypeDecreasingBrightness,
    BONAnimationTypeDecreasingDiscreteBrightness,
} BONAnimationType;

fragment float4 fragmentShader(RasterizerData in [[stage_in]],
                               float2 uv[[point_coord]])
{
    const BONAnimationType animation = BONAnimationTypeDecreasingBrightness;
    
    float3 hsb = rgb2hsb(in.color.rgb);
    float pct = fract(1 - in.time / 4.0);
    hsb.x = fmod(hsb.x + pct, 1.0);
    
    switch(animation) {
        case BONAnimationTypeContinuous:
            break;
        case BONAnimationTypeDecreasingBrightness:
            hsb.z = hsb.x * 2.0f;
            break;
        case BONAnimationTypeDecreasingDiscreteBrightness:
            hsb.z = step(0.2f, hsb.x) * 4.0f;
            break;
        default:
            break;
    }

    return float4(hsb2rgb(hsb), 1.0f);
}

