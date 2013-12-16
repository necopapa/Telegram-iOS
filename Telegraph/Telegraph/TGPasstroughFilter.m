#if TG_USE_CUSTOM_CAMERA

#import "TGPasstroughFilter.h"

static NSString *TGTiltShiftFilter_VertexShader = SHADER_STRING
(
attribute vec4 position;
attribute vec4 inputTextureCoordinate;
 
uniform float imageWidthFactor;
uniform float imageHeightFactor;

varying highp vec2 textureCoordinate;
 
void main()
{
 	gl_Position = position;
 	textureCoordinate = inputTextureCoordinate.xy;
}
);

static NSString *TGTiltShiftFilter_FragmentShader = SHADER_STRING
(
uniform sampler2D inputImageTexture;

varying highp vec2 textureCoordinate;

void main()
{
    highp vec4 YCbCr = texture2D(inputImageTexture, textureCoordinate);

    gl_FragColor = vec4((YCbCr * yuv2rgb).xyz, 1.0);
    
    /*gl_FragColor = vec4(
        YCbCr.x + 1.59602734375 * YCbCr.z - 0.87078515625,
        YCbCr.x - 0.39176171875 * YCbCr.y - 0.81296875 * YCbCr.z + 0.52959375,
        YCbCr.x + 2.017234375 * YCbCr.y - 1.081390625,
        1.0
    );*/
}
);

@interface TGPasstroughFilter ()
{
}

@end

@implementation TGPasstroughFilter

- (id)init
{
    if (!(self = [super initWithVertexShaderFromString:TGTiltShiftFilter_VertexShader fragmentShaderFromString:TGTiltShiftFilter_FragmentShader]))
    {
		return nil;
    }
    
    return self;
}

@end

#endif
