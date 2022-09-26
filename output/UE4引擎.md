# UE4引擎

## UE Plugin

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

