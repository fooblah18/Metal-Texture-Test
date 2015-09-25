//
//  shaders.metal
//  lalala
//
//  Created by Michael Ong on 20/09/2015.
//  Copyright © 2015 Michael Ong. All rights reserved.
//

#include <metal_stdlib>

using namespace metal;

struct Input
{
    float4  position    [[attribute(0)]];
    float4  color       [[attribute(1)]];
    
    float2  texCoord    [[attribute(2)]];
};

struct ColoredVertex
{
    float4 position [[position]];
    float4 color;
    float2 texCoord;
};

vertex ColoredVertex    vertex_main     (Input          input   [[stage_in]])
{
    ColoredVertex   vert;
    
    vert.position   = input.position;
    vert.color      = input.color;
    vert.texCoord   = input.texCoord;
    
    return vert;
}

fragment float4         fragment_main   (ColoredVertex      vert    [[stage_in]]    ,
                                         sampler            s       [[sampler(0)]]  ,
                                         texture2d<float>   t       [[texture(0)]]  )
{
    return t.sample(s, vert.texCoord);
}
