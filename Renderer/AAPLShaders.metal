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
    float4 color;
    vector_uint2 viewportSize;
};

vertex RasterizerData
vertexShader(uint vertexID [[vertex_id]],
             constant AAPLVertex *vertices [[buffer(AAPLVertexInputIndexVertices)]],
             constant vector_uint2 *viewportSizePointer [[buffer(AAPLVertexInputIndexViewportSize)]])
{
    RasterizerData out;

    out.position = float4(vertices[vertexID].position.xy, 0, 1);
    out.color = vertices[vertexID].color;
    out.viewportSize = *viewportSizePointer;

    return out;
}


float smoothedge(float v) {
    return smoothstep(0.0, 0.01, v);
//    return smoothstep(0.0, 1.0 / u_resolution.x, v);
}


// based on capsule from https://thebookofshaders.com/edit.php?log=160414041142
// p: point being processed
// a: base point of the capsule
// b: end point of the capsule
// r: radius of capsule. draw a line for r=0
float2 line(float2 p, float2 a, float2 b, float thickness) {
    float2 pa = p - a;    // a -> p vector
    float2 ba = b - a;    // a -> b vector
    
    // h is the length of pa on ba
    float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
    
    // returning the length of the point's distance to the h point (sth like vertical distance to the line?)
    float on_the_line = smoothedge(length( pa - ba*h ) - thickness);
    float distance_from_start = h;
    return float2(on_the_line, distance_from_start);
}

float3 colored_line(float2 p, float2 a, float2 b, float thickness, int offset, int blocks, float time) {
    float m = blocks;
    
    float2 l = line(p, a, b, thickness);
    float hue = fract(l.y / m + (offset-1)/m - fract(time/2.));
    float3 hsb = float3(hue, 1., 1.);
    hsb.z = smoothstep(0.2, 0.8, (hsb.x * 2));

    float3 color = (1.-l.x) * hsb2rgb(hsb);
    return color;
}



fragment float4 fragmentShader(RasterizerData in [[stage_in]],
                               constant vector_float2 *points [[buffer(AAPLFragmentInputIndexPoints)]],
                               constant int *n_points [[buffer(AAPLFragmentInputIndexNPoints)]],
                               constant float *_scale[[buffer(AAPLFragmentInputIndexScale)]],
                               constant float *_time[[buffer(AAPLFragmentInputIndexTime)]])
{
    float2 uv = (in.position.xy / float2(in.viewportSize.xy) * 2.0 - 1.0) * float2(1, -1);

    float time = *_time;
    float scale = *_scale;

    uv *= scale;
    
    if (false) {
        // this code block is adding RGB colors at the overlapping ends of the lines, making them visible as big dots.
        // it is kept is as reference only. Following code block is handling it by taking max on HSB colors
        
        float3 color = float3(0);
        for (int i=0; i<*n_points-1; i++) {
            color += colored_line(uv, points[i], points[i+1], 0.08, i, *n_points, time);
        }
        return float4(color, 1.0);
    }

    float3 hsb = float3(0);
    for (int i=0; i<*n_points-1; i++) {
        float3 rgb = colored_line(uv, points[i], points[i+1], 0.08, i, *n_points, time);
        hsb = max(hsb, rgb2hsb(rgb));   // if there is an overlap, high HSB color overrides
    }
    return float4(hsb2rgb(hsb), 1.0);
}


