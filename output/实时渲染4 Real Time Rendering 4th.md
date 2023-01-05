# 实时渲染4 Real Time Rendering 4th

## Chapter 1. Introduction

## Chapter2. 图形学渲染管线

### Architecture 架构

实时渲染管线可以粗略分为四个阶段： 应用阶段(application), 几何处理(geometry processing)，光栅化(rasterization)， 像素处理(pixel processing)

![](../res/Graphics/RenderPipeLine.PNG)

### 应用阶段

应用阶段执行在CPU上，开发者在这个阶段拥有完全控制权。

部分应用阶段的工作可以由GPU来执行，使用一个称为compute shader的独立模式。此模式将 GPU 视为高度并行的通用处理器，忽略其专门用于渲染图形的特殊功能。

应用阶段通常会进行碰撞检测的运算，同时也会接收来自其他源的输入：比如键盘、鼠标、头戴设备等。基于这些输入，不同种类的操作将被执行。加速算法(比如特定的遮挡剔除)也会在这个阶段执行。

### 几何阶段

![](../res/Graphics/Geometry_Stage.PNG)

几何阶段的操作在GPU上进行，包含了逐三角形和逐顶点操作。 几何阶段通常会被分为顶点着色，投影，裁剪以及屏幕映射几个子阶段。

#### 顶点着色(Vertex Shading)

计算顶点坐标，输出顶点数据。 (MVP变换)

Optional Vertex Processing

1. tessellation.
2. geometry shader.
3. stream output.

Clipping

ScreenMapping

#### 光栅化(Rasterization)

1. triangle setup
2. triangle traversal

### 像素处理(Pixel Processing)

#### Pixel Shading

#### Merging

## Chapter3. 图形处理单元

### The Vertex Shader

VS在渲染管线中，是处理三角形mesh的第一个阶段。

### The Tessellation Stage

细分阶段允许我们渲染曲面，细分阶段是一个可选阶段。

曲面细分分为三个元素： hull shader, tessellator, domain shader。

![](../res/Graphics/Tessellation_Stage.PNG)

### The Geometry Shader

### The Pixel Shader

