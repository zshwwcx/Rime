# GAMES202-高质量实时渲染

## EP2

### Graphics Pipeline 渲染管线

![](../res/GAMES202/Graphics_Pipeline.PNG)


应用程序: 输入顶点和法线数据

顶点处理: 通过MVP和viewport变化，将顶点放置在屏幕空间中

三角形遍历： 将顶点连接成三角形，放置在屏幕空间中

光栅化： 将三角形划分成一个个片元并输出到屏幕空间中

片元处理： 片元着色

帧缓冲区处理： 输出图像

### OpenGL

https://learnopengl-cn.readthedocs.io/zh/latest/ 很有用的OpenGL学习Url

Languages does not matter.

Cross platform.

Alternatives(DirectX, Vulkan, etc.)

![Summary: in each pass](../res/GAMES202/OpenGL_Summary.PNG)

## EP3 Real Time Shadows

### Shadow Mapping

A 2-Pass Algorithm
- The light pass generates the SM
- The camera pass uses the SM(recall last lecture)

A image-space algorithm
- Pro: no knowledge of scene's geometry is required
- Con: causing self occlusion and aliasing issues 


### The math behind shadow mapping

![](../res/GAMES202/Math_in_ShadowMapping.PNG)

### Percentage closer soft shadows(PCSS)

![](../res/GAMES202/PCF.PNG)

![](../res/GAMES202/PCSS.PNG)

![](../res/GAMES202/PCSS_2.PNG)

### Variance Soft Shadow Mapping (VSSM)

Fast blocker search(step 1) and filtering(step 3).

Key Idea:
Quick compute the mean and variance of depths in an area.

Mean(average)
- Hardware MIPMAPing.
- Summed Area Tables(SAT)

Variance
- Var(X) = E(X^2) - E^2(X)

![](../res/GAMES202/VSSM.PNG)

![](../res/GAMES202/VSSM2.PNG)
In this section, t must be larger than mean.(t在均值右边，不等式才有效)

由于降噪技术的成熟，目前PCSS技术在工业界应用实际上是比VSSM要多.(TAA等)

### Summed-Area Table(SAT)

![](../res/GAMES202/SAT.PNG)

### Moment Shadow Mapping


### Distance field

![Distance Functions](../res/GAMES202/SDF.PNG)

Usage:

1. Ray Marching(sphere tracing) to perform ray-SDF intersection.

![Ray marching](../res/GAMES202/RayMarching_SDF.PNG)

SDF适用于运动物体，但是不适用于形变物体。

2. Use SDF to determine the (approx.) percentage of occlusion.

![Soft shadows/SDF](../res/GAMES202/ShadowMapping_SDF.PNG)

Pros:
- Fast*
- High quality

Cons:
- Need precomputation
- Need heavy storage*
- Artifact?

SDF生成的物体表面非常不好贴纹理

## EP5： Real-time Environment Mapping 环境光照

An image representing distant lighting form all directions.

Spherical map vs. Cube map.

Informally named Image-Based Lighting (IBL)

How to use it to shade a point(without shadows)?

General solution - Monte Carlo integration
- Numerical
- Large amount of samples required

Problem - can be slow
- In general, sampling is not preferred in shaders*

![Split Sum](../res/GAMES202/IBL_Shading.PNG)

### Spherical Harmonics

A set of 2D basis functions Bi(w) defined on the sphere.

Analogous to Fourier series in 1D.


3阶SH基本上可以完美表达环境光diffuse效果

SH非常适合来描述低频光照

![](../res/GAMES202/SH_Approx.PNG)

### Precomputed Radiance Transfer(PRT)

Handles shadows and global illumination!

![](../res/GAMES202/PRT.PNG)

![](../res/GAMES202/PRT_diffuse.PNG)

![](../res/GAMES202/PRT_BasisFunc.PNG)

由于V(i)的存在，场景中的物体必须是静态的，才能基于预计算。

由于SH的特殊性质，我们允许光源旋转。任意一个SH的旋转，都可以由同阶的SH线性组合得到。


### SH for glossy transport

## EP: Real-time PBR


### Shading Microfacet Models using Linearly Transformed Cosines(LTC)

### Disney's Principle BRDF

解决微表面模型难以处理的BRDF (多层材质)

![why](../res/GAMES202/Disney_BRDF.PNG)

![](../res/GAMES202/DisneyPBR_Pros_Cons.PNG)

### Non-Photorealistic Rendering(非真实渲染NPR)

== (fast and reliable) stylization 快速且可靠的风格化

#### Outline Rendering 描边

#### Color blocks

#### Strokes Surface Stylezation

![](../res/GAMES202/Tonal_art_maps.PNG)


## EP: Real Time Ray Tracing(RTRT)

实质就是硬件path tracing，RTX的核心在于降噪

![](../res/GAMES202/RayTracing_Denoisy.PNG)

Goals(with 1 SPP)
- Quality(no overblur, no artifacts, keep all details...)

- Speed(<2ms to denoise one frame)

Core: Temporal

Key idea:

Suppose the previous frame is denoised and reuse it.

Use motion vectors to find previous locations

Essentially increased SPP

Temporal info is not always available

Failure case 1: switching scenes

Failure case 2: walking backwards in a hallway
(Screen space issue)

Failure case 3: suddenly appearing backgroud
(disocclusion)


-----------------

