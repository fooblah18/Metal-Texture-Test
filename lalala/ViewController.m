//
//  ViewController.m
//  lalala
//
//  Created by Michael Ong on 20/09/2015.
//  Copyright © 2015 Michael Ong. All rights reserved.
//

#import "ViewController.h"

#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreGraphics/CoreGraphics.h>

#import <stdlib.h>
#import <stdio.h>

#import "png/png.h"

static const float positions[] =
{
     0.5,  0.5, 0, 1,   1, 1, 1, 1,     1, 0,
    -0.5,  0.5, 0, 1,   1, 1, 1, 1,     0, 0,
    -0.5, -0.5, 0, 1,   1, 1, 1, 1,     0, 1,
    
     0.5,  0.5, 0, 1,   1, 1, 1, 1,     1, 0,
    -0.5, -0.5, 0, 1,   1, 1, 1, 1,     0, 1,
     0.5, -0.5, 0, 1,   1, 1, 1, 1,     1, 1
};

@interface ViewController()
{
    id<MTLDevice>               device;
    id<MTLCommandQueue>         queue;
    
    CAMetalLayer*               layer;
    
    id<MTLBuffer>               buffer_in;
    
    id<MTLLibrary>              library;
    
    id<MTLFunction>             function_vertex;
    id<MTLFunction>             function_fragment;
    
    id<MTLRenderPipelineState>  renderPipelineState;
    
    id<MTLTexture>              resource_texture;
    id<MTLSamplerState>         resource_sampler;
    
    CAMetalLayer*               metalLayer;
}
@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    device      = MTLCreateSystemDefaultDevice();
    queue       = [device newCommandQueue];
    
    layer       = [CAMetalLayer layer];
    
    layer.bounds        = self.view.bounds;
    layer.position      = CGPointMake(self.view.bounds.size.width * 0.5, self.view.bounds.size.height * 0.5);
    
    layer.device        = device;
    layer.pixelFormat   = MTLPixelFormatBGRA8Unorm;
    
    metalLayer  = layer;
    
    [self.view.layer addSublayer: layer];
    
    buffer_in   = [device newBufferWithBytes: &positions
                                      length: sizeof(positions)
                                     options: MTLResourceOptionCPUCacheModeDefault];

    library     = [device newDefaultLibrary];
    
    function_fragment   = [library newFunctionWithName: @"fragment_main"];
    function_vertex     = [library newFunctionWithName: @"vertex_main"  ];
    
    MTLRenderPipelineDescriptor* descriptor     = [MTLRenderPipelineDescriptor new];
    
    descriptor.fragmentFunction                 = function_fragment;
    descriptor.vertexFunction                   = function_vertex;
    
    descriptor.colorAttachments[0].blendingEnabled              = YES;
    descriptor.colorAttachments[0].pixelFormat                  = MTLPixelFormatBGRA8Unorm;
    descriptor.colorAttachments[0].sourceAlphaBlendFactor       = MTLBlendFactorSourceAlpha;
    descriptor.colorAttachments[0].sourceRGBBlendFactor         = MTLBlendFactorSourceAlpha;
    descriptor.colorAttachments[0].destinationAlphaBlendFactor  = MTLBlendFactorOneMinusSourceAlpha;
    descriptor.colorAttachments[0].destinationRGBBlendFactor    = MTLBlendFactorOneMinusSourceAlpha;
    
    MTLVertexDescriptor*        vtxDescriptor   = [MTLVertexDescriptor vertexDescriptor];

    vtxDescriptor.attributes[0].format          = MTLVertexFormatFloat4;
    vtxDescriptor.attributes[0].bufferIndex     = 0;
    vtxDescriptor.attributes[0].offset          = 0;
    
    vtxDescriptor.attributes[1].format          = MTLVertexFormatFloat4;
    vtxDescriptor.attributes[1].bufferIndex     = 0;
    vtxDescriptor.attributes[1].offset          = sizeof(float) * 4;
    
    vtxDescriptor.attributes[2].format          = MTLVertexFormatFloat2;
    vtxDescriptor.attributes[2].bufferIndex     = 0;
    vtxDescriptor.attributes[2].offset          = sizeof(float) * 8;
    
    vtxDescriptor.layouts[0].stride             = sizeof(float) * 10;
    vtxDescriptor.layouts[0].stepFunction       = MTLVertexStepFunctionPerVertex;
    
    descriptor.vertexDescriptor                 = vtxDescriptor;
    
    renderPipelineState = [device newRenderPipelineStateWithDescriptor: descriptor error: nil];
    
    [self loadTexture];
    
    [[CADisplayLink displayLinkWithTarget: self selector: @selector(showStuff)] addToRunLoop: [NSRunLoop mainRunLoop] forMode: NSDefaultRunLoopMode];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [coordinator animateAlongsideTransition :^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context)
     {
         layer.bounds        = CGRectMake(0, 0, size.width, size.height);
         layer.position      = CGPointMake(size.width * 0.5, size.height * 0.5);
         
     } completion  : nil];
}

- (void)showStuff
{
    id<CAMetalDrawable>         drawable    = [layer nextDrawable];
    MTLRenderPassDescriptor*    descriptor  = [MTLRenderPassDescriptor renderPassDescriptor];
    
    descriptor.colorAttachments[0].texture      = drawable.texture;
    descriptor.colorAttachments[0].loadAction   = MTLLoadActionClear;
    descriptor.colorAttachments[0].storeAction  = MTLStoreActionStore;
    descriptor.colorAttachments[0].clearColor   = MTLClearColorMake(0, 0, 0, 1);
    
    id<MTLCommandBuffer>        buffer      = [queue commandBuffer];
    id<MTLRenderCommandEncoder> encoder     = [buffer renderCommandEncoderWithDescriptor: descriptor];
    
    [encoder setRenderPipelineState: renderPipelineState];
    
    [encoder setVertexBuffer: buffer_in offset: 0 atIndex: 0];
    [encoder setFragmentSamplerState: resource_sampler atIndex: 0];
    [encoder setFragmentTexture: resource_texture atIndex: 0];
    
    [encoder drawPrimitives: MTLPrimitiveTypeTriangle vertexStart: 0 vertexCount: 6 instanceCount: 1];
    
    [encoder endEncoding];
    
    [buffer presentDrawable: drawable];
    [buffer commit];
}

-(void)loadTexture
{
    NSString*       texturePath = [[NSBundle mainBundle] pathForResource: @"cow_idle.png" ofType: nil];
    FILE*           file        = fopen([texturePath cStringUsingEncoding: NSUTF8StringEncoding], "rb");
    
    unsigned char   header[8];
    fread(header, 1, 8, file);
    
    if (png_sig_cmp(header, 0, 8))
    {
        NSLog(@"File is not a valid PNG image.");
        
        return;
    }
    
    png_structp     png_ptr     = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
    
    if (png_ptr == NULL)
    {
        NSLog(@"Cannot create PNG read struct.");
        
        return;
    }
    
    png_infop       png_info    = png_create_info_struct(png_ptr);
    
    if (png_info == NULL)
    {
        NSLog(@"Cannot create PNG info struct.");

        png_destroy_read_struct(&png_ptr, NULL, NULL);
        
        return;
    }
    
    png_init_io         (png_ptr, file      );
    png_set_sig_bytes   (png_ptr, 8         );
    
    png_read_info       (png_ptr, png_info  );
    
    unsigned int    tW      = png_get_image_width   (png_ptr, png_info);
    unsigned int    tH      = png_get_image_height  (png_ptr, png_info);
    
    png_bytepp      data    = (png_bytepp) calloc(tH, sizeof(png_bytep));
    
    for (unsigned int i = 0; i < tH; i++)
    {
        data[i] = (png_bytep) malloc(png_get_rowbytes(png_ptr, png_info));
    }
    
    png_read_image          (png_ptr, data);
    png_destroy_read_struct (&png_ptr, &png_info, NULL);
    
    fclose(file);
    
    MTLTextureDescriptor*   texDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatRGBA8Unorm width: tW height: tH mipmapped: NO];
    id<MTLTexture>          texture = [device newTextureWithDescriptor: texDesc];
    
    [texture replaceRegion: MTLRegionMake2D(0, 0, tW, tH)
               mipmapLevel: 0
                     slice: 0
                 withBytes: data
               bytesPerRow: tW * sizeof(png_byte) * 4
             bytesPerImage: 0];
    
    resource_texture                = texture;
    
    MTLSamplerDescriptor* samplerDesc = [MTLSamplerDescriptor new];
    
    samplerDesc.minFilter       = MTLSamplerMinMagFilterNearest;
    samplerDesc.magFilter       = MTLSamplerMinMagFilterNearest;
    
    samplerDesc.tAddressMode    = MTLSamplerAddressModeRepeat;
    samplerDesc.sAddressMode    = MTLSamplerAddressModeRepeat;
    
    resource_sampler                = [device newSamplerStateWithDescriptor: samplerDesc];
    
    for (unsigned int i = 0; i < tH; i++)
    {
        free(data[i]);
    }
    
    free(data);
}

@end
