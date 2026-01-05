# UE4引擎

## UE Plugin

## Shader系统

## 骨骼动画

BoneSpace, 当前骨骼相对于父骨骼坐标空间的Transform信息。

ComponentSpace, 当前骨骼相对于Root骨骼坐标空间的Transform信息。

WorldSpace，真正的世界空间，以坐标原点坐标空间，在动画中一般用不着，程序侧使用。

骨骼蒙皮，骨骼动画影响顶点位置，顶点位置映射到SkinInfo的mesh位置。

#### FK前向动力学

由根骨骼发起，并依次由父骨骼驱动子骨骼运动

#### IK逆向动力学

由子骨骼确定位置，反向计算父骨骼的位置。

IKBone: End bone的骨骼名字

##### TwoBoneIK

几何解析算法，只适用于2根骨骼的IK算法，效果好切快，但是适用范围很窄

##### CCD IK

它的处理方式主要是通过对当前关节的旋转使得末端节点在此旋转角度下最靠近目标点。（全称：cyclic coordinatedecent，中文意思是循环坐标下降）具体实现的方法如下：
1,从骨骼链上最深的子骨节开始进行处理，将这段骨节相对于原点进行旋转从而使它指向效应点。

2,将这个骨节的父节点针对于原点进行旋转，以使得此父骨节的原点到新旋转的子骨节端点的连线指向效应点即可。

3,对每个骨节进行1~2步骤的处理。

4,上述步骤进行多次循环从而得到更加稳定的值。适合任意长IK。

##### FABRIK

前向后向沿伸（全称：fowarward and backward reaching，中文意思是前向和后向到达）适合任意长IK。它和CCD不一样的地方是，它不是通过旋转关节来使末端逼近目标的，而是通过关节的位移调整就可以达到逐步逼近目的，不存在CCD算法中可能遇到的断点或者突变情况。

##### JACOBIAN（雅克比矩阵，UE不支持）

它是通过骨骼链各关节的旋转角度向量与终端骨骼位置向量之间的矩阵变换关系来反向求出骨骼链各关节对应需要的旋转角度，这个矩阵我们称之为雅克比矩阵。
克比矩阵很可能是奇异的或者甚至是非方阵（都无法求逆），一般需要通过广义逆的方式来求解，但是实际应用中会直接使用雅克比矩阵的转置作为逆的求解来简化计算过程。

#### Layered Blend Per Bone 动画骨骼分层

节点从骨架上的特定骨骼进行动画混合,原理是选择一根骨骼进行切分，分别使用不用的动画.比如下半身走路，上半身拿着枪瞄准，上下分别用不同动画的数据分离混合。bone depth用于设置骨骼被动画影响的程度，不受影响的bonedepth设为-1、实际blend影响值为:1.f/BlendDepth,也就是1最大，越往上blend越少。

#### ApplyAdditive 动画叠加

普通blend会减弱失真，additive会加强效果。可以实现上半身动画+下半身动画混合成为全身动画，效果更好的上下半身分离，不会导致质心偏移。一般用在2段不同动画控制了不同的骨骼 然后想合并表现，比如眨眼动画和张嘴动画的叠加混合。需要将动画资源的AdditiveSetting设置正确。

#### RootMotion

物理胶囊体和动画一起运动，为了响应实际碰撞，而不是传统的动画在动，胶囊体原地不动。实现原理也是移动组件每帧更新动画组件的矩阵，去重写位置。



### Shader变体



## 智能指针
```refrence
https://docs.unrealengine.com/5.0/zh-CN/smart-pointers-in-unreal-engine/
https://zhuanlan.zhihu.com/p/94198883
```
智能指针的主要类型分为：TSharedPtr, TSharedRef, TWeakPtr, TUniquePtr。

先声明一个测试类
```c++
class TestA
{
public:
	int32 a;
	float b;
};
```
### TSharedPtr（共享指针）用法
```c++
void TestSharedPtr()
{
    //声明
    TSharedPtr<TestA>MyTestA;
    //分配内存
    MyTestA = MakeShareable(new TestA());
    //先判读智能指针是否有效
    if (MyTestA.IsValid()||MyTestA.Get())
    {
        //访问
        int32 a = MyTestA->a;
        //复制指针
        TSharedPtr<TestA>MyTesta = MyTestA;
        //获取共享指针引用计数
        int32 Count = MyTestA.GetSharedReferenceCount();
        //销毁对象
        MyTesta.Reset();
    }
    //MyTestA.IsValid()中"."是访问共享指针的成员，而MyTestA->a中"->"是访问这个指针指向的对象中的成员。
};
```
1.共享指针可以置为空“Null”。

2.在访问共享指针时，要先判读这个共享指针是否有效，如果这个指针无效，将会导致奔溃。

3.MyTestA.IsValid()中"."是访问共享指针的成员，而MyTestA->a中"->"是访问这个指针指向的对象中的成员。

### TSharedRef（共享引用）的用法
```c++
void TestSharedRef()
{
    //声明：
    TSharedRef<TestA>MyTestB(new TestA());
    //访问：
    int32 a = MyTestB->a;//方法一
    int32 b = (*MyTestB).a;//方法二
    //销毁对象
    MyTestB.Reset();
};
```
与共享指针类似，共享引用固定引用非空对象

### TSharedPtr 和 TSharedRef之间的相互转换
```c++
void ATestSharedRefAndPtr()
{
    //创建普通指针
    TestA* MyTestC = new TestA();
    //创建共享指针
    TSharedPtr<TestA>MyTestA;
    //创建共享引用
    TSharedRef<TestA>MyTestB(new TestA());

    //共享引用转换为共享指针，支持隐式转换
    MyTestA = MyTestB;
    //普通的指针转换为共享指针
    MyTestA = MakeShareable(MyTestC);
    //共享指针转换为共享引用，共享指针不能为空
    MyTestB = MyTestA.ToSharedRef();
};
```

### 使用TWeakPtr（弱指针）用法
```c++
void TestTWeakPtr()
{
    //创建共享指针
    TSharedPtr<TestA> _TestA_ptr = MakeShareable(new TestA());
    //创建共享引用
    TSharedRef<TestA> _TestA_ref(new TestA);
    //声明弱指针
    TWeakPtr<TestA>Test_e;

    //共享指针转换为弱指针
    TWeakPtr<TestA>Test_B(_TestA_ptr);
    //共享引用转换为弱指针
    TWeakPtr<TestA>Test_C(_TestA_ref);

    Test_e = Test_B;
    Test_e = Test_C;

    //使用完弱指针可以重置为nullptr
    Test_e = nullptr;

    //弱指针转换为共享指针
    TSharedPtr<TestA> NewTest(Test_e.Pin());
    if (NewTest.IsValid()||NewTest.Get())
    {
        //访问指针成员
        NewTest->a;
    }
};
```

## APL/UPL

