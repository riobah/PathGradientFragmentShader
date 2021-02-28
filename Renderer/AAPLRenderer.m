/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Implementation of a platform independent renderer class, which performs Metal setup and per frame rendering
*/

@import simd;
@import MetalKit;

#import "AAPLRenderer.h"

// Header shared between C code here, which executes Metal API commands, and .metal files, which
// uses these types as inputs to the shaders.
#import "AAPLShaderTypes.h"


#if defined(TARGET_IOS) || defined(TARGET_TVOS)
#define PlatformColor UIColor
vector_float4 components(UIColor *color) {
    CGFloat r, g, b, a;
    [color getRed:&r green:&g blue:&b alpha:&a];
    return (vector_float4){r, g, b, a};
}
#else
#define PlatformColor NSColor
vector_float4 components(NSColor *color) {
    float r = color.redComponent;
    float g = color.greenComponent;
    float b = color.blueComponent;
    float a = color.alphaComponent;
    return (vector_float4){r, g, b, a};
}
#endif


// Main class performing the rendering
@implementation AAPLRenderer
{
    id<MTLDevice> _device;

    // The render pipeline generated from the vertex and fragment shaders in the .metal shader file.
    id<MTLRenderPipelineState> _pipelineState;

    // The command queue used to pass commands to the device.
    id<MTLCommandQueue> _commandQueue;

    // The current size of the view, used as an input to the vertex shader.
    vector_uint2 _viewportSize;

    float _time;
}

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)mtkView
{
    self = [super init];
    if(self)
    {
        NSError *error;

        _device = mtkView.device;

        // Load all the shader files with a .metal file extension in the project.
        id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];

        id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];
        id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"fragmentShader"];

        // Configure a pipeline descriptor that is used to create a pipeline state.
        MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineStateDescriptor.label = @"Simple Pipeline";
        pipelineStateDescriptor.vertexFunction = vertexFunction;
        pipelineStateDescriptor.fragmentFunction = fragmentFunction;
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;

        _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor
                                                                 error:&error];
                
        // Pipeline State creation could fail if the pipeline descriptor isn't set up properly.
        //  If the Metal API validation is enabled, you can find out more information about what
        //  went wrong.  (Metal API validation is enabled by default when a debug build is run
        //  from Xcode.)
        NSAssert(_pipelineState, @"Failed to create pipeline state: %@", error);

        // Create the command queue
        _commandQueue = [_device newCommandQueue];
    }

    return self;
}

/// Called whenever view changes orientation or is resized
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
    // Save the size of the drawable to pass to the vertex shader.
    _viewportSize.x = size.width;
    _viewportSize.y = size.height;
}

/// Called whenever the view needs to render a frame.
- (void)drawInMTKView:(nonnull MTKView *)view
{
    static const AAPLVertex triangleVertices[] =
    {
        // 2D positions,    RGBA colors
        { { -1,  -1 }, { 1, 1, 1, 1 } },
        { { -1,   1 }, { 1, 1, 1, 1 } },
        { {  1,   1 }, { 1, 1, 1, 1 } },
        { {  1,   1 }, { 1, 1, 1, 1 } },
        { {  1,  -1 }, { 1, 1, 1, 1 } },
        { { -1,  -1 }, { 1, 1, 1, 1 } },
    };
    
    static const float scaleFactor = 3.0;
    static BONVertex pathVertices[] = {
        {-3,  0},
        {-1,  0},
        { 0,  0.5},
        { 1,  0},
        { 0, -0.5},
        {-1,  0},
        {-1, -1},
        { 0, -1.5},
        { 1, -1},
        { 1,  0},
        { 3,  0},
    };


    
    // time is 32 bits float. Metal does not support 64 bit double (NSTimeInterval)
    // this is passed to be used as input for animations
    _time = NSProcessInfo.processInfo.systemUptime;
    
    // Create a new command buffer for each render pass to the current drawable.
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"MyCommand";

    // Obtain a renderPassDescriptor generated from the view's drawable textures.
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;

    if(renderPassDescriptor != nil)
    {
        // Create a render command encoder.
        id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderEncoder.label = @"MyRenderEncoder";

        // Set the region of the drawable to draw into.
        [renderEncoder setViewport:(MTLViewport){0.0, 0.0, _viewportSize.x, _viewportSize.y, 0.0, 1.0 }];
        
        [renderEncoder setRenderPipelineState:_pipelineState];

        // Pass in the parameter data.
        [renderEncoder setVertexBytes:triangleVertices
                               length:sizeof(triangleVertices)
                              atIndex:AAPLVertexInputIndexVertices];

        [renderEncoder setVertexBytes:&_viewportSize
                               length:sizeof(_viewportSize)
                              atIndex:AAPLVertexInputIndexViewportSize];
        
        [renderEncoder setFragmentBytes:&_time
                                 length:sizeof(_time)
                                atIndex:AAPLFragmentInputIndexTime];
        
        [renderEncoder setFragmentBytes:&scaleFactor
                                 length:sizeof(scaleFactor)
                                atIndex:AAPLFragmentInputIndexScale];
        
        int nPoints = sizeof(pathVertices) / sizeof(pathVertices[0]);
        [renderEncoder setFragmentBytes:&nPoints
                                 length:sizeof(nPoints)
                                atIndex:AAPLFragmentInputIndexNPoints];
        
        [renderEncoder setFragmentBytes:pathVertices
                                 length:sizeof(pathVertices)
                                atIndex:AAPLFragmentInputIndexPoints];


        // Draw the triangle.
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                          vertexStart:0
                          vertexCount:sizeof(triangleVertices)/sizeof(triangleVertices[0])];

        [renderEncoder endEncoding];

        // Schedule a present once the framebuffer is complete using the current drawable.
        [commandBuffer presentDrawable:view.currentDrawable];
    }

    // Finalize rendering here & push the command buffer to the GPU.
    [commandBuffer commit];
}

@end
