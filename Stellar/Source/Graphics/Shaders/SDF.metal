//
//  SDF.metal
//  Stellar
//
//  Created by Gellert Li on 2/17/21.
//  Copyright © 2021 Gellert. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct Sphere {
    float3 center;
    float radius;
    Sphere(float3 c, float r) {
      center = c;
      radius = r;
    }
};

struct Ray {
    float3 origin;
    float3 direction;
    Ray(float3 o, float3 d) {
        origin = o;
        direction = d;
    }
};

float distanceToSphere(Ray r, Sphere s) {
    return length(r.origin - s.center) - s.radius;
}

kernel void compute(texture2d<float, access::write> output [[texture(0)]],
                    constant float &time [[buffer(0)]],
                    uint2 gid [[thread_position_in_grid]]) {
  int width = output.get_width();
  int height = output.get_height();
  float2 uv = float2(gid) / float2(width, height);
  uv = uv * 2.0 - 1.0;
  float3 color = float3(0.0);
  
  // raymarching
  
  output.write(float4(color, 1.0), gid);
}
