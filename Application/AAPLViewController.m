/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Implementation of our cross-platform view controller
*/

#import "AAPLViewController.h"
#import "AAPLRenderer.h"

@implementation AAPLViewController
{
    MTKView *_view;

    AAPLRenderer *_renderer;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self setupMetalView];
}

- (void)setupMetalView
{
    // adding another view to center on the ViewController's main view
    
    MTKView *v = [MTKView new];
    [self.view addSubview:v];
    
    v.translatesAutoresizingMaskIntoConstraints = NO;
    [v.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor].active = YES;
    [v.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor].active = YES;
    [v.widthAnchor constraintEqualToAnchor:self.view.widthAnchor multiplier:0.6].active = YES;
    [v.heightAnchor constraintEqualToAnchor:v.widthAnchor multiplier:1].active = YES;

    _view = v;
    
    
    // Initialization code from Apple's sample
    _view.device = MTLCreateSystemDefaultDevice();
    NSAssert(_view.device, @"Metal is not supported on this device");
    
    _renderer = [[AAPLRenderer alloc] initWithMetalKitView:_view];
    NSAssert(_renderer, @"Renderer failed initialization");

    // Initialize our renderer with the view size
    [_renderer mtkView:_view drawableSizeWillChange:_view.drawableSize];

    _view.delegate = _renderer;
}

@end
