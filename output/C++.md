# C++

重新刷一遍《C++ Prime Plus》

## constexpr

C++11的改善——常量表达式，允许程序利用编译时的计算能力。

常量表达式主要是允许一些计算发生在编译时，即发生在代码编译而不是运行的时候。这是很大的优化：假如有些事情可以在编译时做，它将只做一次，而不是每次程序运行时。需要计算一个编译时已知的常量，比如特定值的sine或cosin？确实你亦可以使用库函数sin或cos，但那样你必须花费运行时的开销。使用constexpr，你可以创建一个编译时的函数，它将为你计算出你需要的数值。用户的电脑将不需要做这些工作。

### constexpr函数的限制

1.函数中只能有一个return语句

2.只能调用其他constexpr函数

3.只能使用全局constrexpr变量

[注] 递归并不受限制，但只允许一个返回语句。(三元运算符)

```c++
//计算n的阶乘
constexpr int factorial (int n)
{
    return n > 0 ? n * factorial( n - 1 ) : 1;
}
```

## 基础数据类型

### 占用空间大小

16bit 编译器：
char == 1 Byte;
short int == 2 Byte;
int == 2 Byte;
unsigned int == 2 Byte;
long == 4 Byte;
unsigned long == 4 Byte;
long long == 8 Byte;
float == 4 Byte;
double == 8 Byte.

32bit 编译器：
char == 1 Byte;
short int == 2 Byte;
int == 4 Byte;
unsigned int == 4 Byte;
long == 4 Byte;
unsigned long == 4 Byte;
long long == 8 Byte;
float == 4 Byte;
double == 8 Byte.

64bit 编译器：
char == 1 Byte;
short int == 2 Byte;
int == 4 Byte;
unsigned int == 4 Byte;
long == 4 Byte;
unsigned long == 4 Byte;
long long == 8 Byte;
float == 4 Byte;
double == 8 Byte.

指针变量所占字节
指针变量所占字节数是根据编译器的寻址空间决定宽度的：

16 bit编译器寻址空间为16 bit，所以指针变量宽度为2 Byte;
32 bit编译器寻址空间为32 bit，所以指针变量宽度为4 Byte;
64 bit编译器寻址空间为64 bit，所以指针变量宽度为8 Byte.
以上32bit & 64bit编译器均是在vs2017上测试所得

虚函数虚表占用4个字节, 空类只占1个字节。

## 内存管理

### 内存区域

内核空间、栈区、堆区、全局变量区、代码区、保留区

堆: new 分配空间, delete 释放空间

栈: {}内定义的变量，出了括号自动清理

全局变量区: .ddta非0值和.bss未初始化会存放在全局变量的两个地方

代码区： .text函数代码

保留区: 0地址开始的c库

![C++内存区域](res/C++/Memory_arch.PNG)

## 智能指针

### unique_ptr

### shared_ptr, weak_ptr


## 数组

存储多个同类型值的数据格式，数组的通用格式:

```c++
typeName arrayName [arraySize]
-- arraySize必须是整型常数(如8，10)或者const值，也可以是常量表达式(8 * sizeof(int)),其所有的值在编译的时候都是已知的。
```

### 数组的初始化

只有在定义数组的时候才能使用数组初始化，此后就不能再使用了，也不能将一个数组赋值给另一个数组。只能使用下标分别给数组元素进行赋值。

```cpp
int card[4] = {3, 6, 8, 10};

int hand[4];

这两种方式都是ok的。

hand[4] = {5,6,7,8};  //错误！
hand = cards;         //错误!
```

初始化数组的时候，可以提供少于数组元素数目的值，这样编译器会自动把其他的元素设置为0.

如果初始化数组的时候方括号内([])为空，C++编译器将计算元素的个数。

```c++
short things[] = {1, 2, 3, 4}; 
```

[c++11]
列表初始化新增了一些功能

1.初始化数组的时候，可以省略等号(=):

```c++
double earnings[4] {1.2e4, 1/6e4, 1.1e4, 1.7e4};    //ok with c++11
```

2.可以不再大括号内包含任何东西，这将把所有元素都设置为0：

```c++
unsigned int counts[10] = {};
float balances[100] {};
```

3.列表初始化不允许缩窄转换

## 类大小的计算 -- sizeof

### 总结

1.空类的大小为1个字节

2.一个类中，虚函数本身、成员函数(包括静态和非静态)和静态数据成员都不占用类对象的存储空间。

3，对于包含虚函数的类，不管有多少个虚函数，只有一个虚指针,vptr的大小。

4.普通竭诚，派生类继承了所有基类的函数与成员，要按照字节对齐来计算大小。

5.虚函数继承，不管是单继承还是多继承，都是继承了基类的vptr。(32位系统4字节，64位系统8字节)

6.虚继承，继承基类的vptr。

## const关键字

## 类和结构的区别

c++中类和结构只有一个区别:

**类的成员默认是private,结构的成员是public**

## inline

在c/c++中，为了解决一些频繁调用的小函数大量消耗栈空间的问题，特别的引入了inline修饰符，表示为内联函数。

在系统下，栈空间是有限的，加入频繁大量的使用就会造成因栈空间不足而导致程序出错的问题。

inline以代码膨胀(复制)为代价，省去了函数调用的开销，从而提高了函数的执行效率。

[注]下列情况不宜使用inline:
1.函数体内的代码比较长，使用内联将导致内存消耗比较搞高。

2.如果函数体内出现循环，那么执行函数体内代码的时间要比函数调用的开销要大。

## lambda表达式

```refrence
https://docs.microsoft.com/zh-cn/cpp/cpp/lambda-expressions-in-cpp?view=msvc-160
```

C++11以及更高的版本中，lambda表达式是一种定义匿名函数对象的简便方法，在调用的位置或作为参数传递给函数的位置。Lambda通常用于封装传递给算法或异步方法的少量代码行。

```cpp  --在sort中使用lambda表达式定义cmp函数--
auto cmp = [](string left, string right) -> bool {
    return left + right > right + left;
};

sort(str.begin(), str.end(), cmp);

```
### 基础
Lambda 表达式的基本语法如下：

```c++
[捕获列表](参数列表) mutable(可选) 异常属性 -> 返回类型 {
// 函数体
}
```

上面的语法规则除了 [捕获列表] 内的东西外，其他部分都很好理解，只是一般函数的函数名被略去， 返回值使用了一个 -> 的形式进行（我们在上一节前面的尾返回类型已经提到过这种写法了）。

所谓捕获列表，其实可以理解为参数的一种类型，Lambda 表达式内部函数体在默认情况下是不能够使用函数体外部的变量的， 这时候捕获列表可以起到传递外部数据的作用。根据传递的行为，捕获列表也分为以下几种：

1. 值捕获
与参数传值类似，值捕获的前提是变量可以拷贝，不同之处则在于，被捕获的变量在 Lambda 表达式被创建时拷贝， 而非调用时才拷贝：

```cpp
void lambda_value_capture() {
    int value = 1;
    auto copy_value = [value] {
        return value;
    };
    value = 100;
    auto stored_value = copy_value();
    std::cout << "stored_value = " << stored_value << std::endl;
    // 这时, stored_value == 1, 而 value == 100.
    // 因为 copy_value 在创建时就保存了一份 value 的拷贝
}
```

2. 引用捕获

与引用传参类似，引用捕获保存的是引用，值会发生变化。

```cpp
void lambda_reference_capture() {
    int value = 1;
    auto copy_value = [&value] {
        return value;
    };
    value = 100;
    auto stored_value = copy_value();
    std::cout << "stored_value = " << stored_value << std::endl;
    // 这时, stored_value == 100, value == 100.
    // 因为 copy_value 保存的是引用
}
```

3. 隐式捕获

手动书写捕获列表有时候是非常复杂的，这种机械性的工作可以交给编译器来处理，这时候可以在捕获列表中写一个 & 或 = 向编译器声明采用引用捕获或者值捕获.

总结一下，捕获提供了 Lambda 表达式对外部值进行使用的功能，捕获列表的最常用的四种形式可以是：
[] 空捕获列表
[name1, name2, ...] 捕获一系列变量
[&] 引用捕获, 让编译器自行推导引用列表
[=] 值捕获, 让编译器自行推导值捕获列表

4. 表达式捕获

上面提到的值捕获、引用捕获都是已经在外层作用域声明的变量，因此这些捕获方式捕获的均为左值，而不能捕获右值。

C++14 给与了我们方便，允许捕获的成员用任意的表达式进行初始化，这就允许了右值的捕获， 被声明的捕获变量类型会根据表达式进行判断，判断方式与使用 auto 本质上是相同的：

```cpp
#include <iostream>
#include <memory>  // std::make_unique
#include <utility> // std::move

void lambda_expression_capture() {
    auto important = std::make_unique<int>(1);
    auto add = [v1 = 1, v2 = std::move(important)](int x, int y) -> int {
        return x+y+v1+(*v2);
    };
    std::cout << add(3,4) << std::endl;
}
```

在上面的代码中，important 是一个独占指针，是不能够被 "=" 值捕获到，这时候我们可以将其转移为右值，在表达式中初始化。

### 泛型Lambda

上一节中我们提到了 auto 关键字不能够用在参数表里，这是因为这样的写法会与模板的功能产生冲突。 但是 Lambda 表达式并不是普通函数，所以 Lambda 表达式并不能够模板化。 这就为我们造成了一定程度上的麻烦：参数表不能够泛化，必须明确参数表类型。

幸运的是，这种麻烦只存在于 C++11 中，从 C++14 开始， Lambda 函数的形式参数可以使用 auto 关键字来产生意义上的泛型：

```cpp
auto add = [](auto x, auto y) {
    return x+y;
};

add(1, 2);
add(1.1, 2.2);
```

## new和malloc的区别

1.new和delete是操作符，可以重载，只能在C++中使用

malloc、free是函数，可以覆盖，C、C++中都可以使用

2.new可以调用对象的构造函数，对应的delete调用相应的析构函数

malloc仅仅分配内存，free仅仅回收内存，并不执行构造和析构函数

3.new、delete返回的是某种数据类型的指针

malloc、free返回的是void指针，需要强制类型转换后使用。

## ++i和i++

++i先自增1， 再返回

i++先返回i，再自增1

## C++程序编译的内存分配

C，C++程序编译时内存分为5大存储区：堆、栈、全局静态区、文字常量区、程序代码区

1.静态存储区分配
内存在程序编译的时候就已经分配好了，这块内存在程序的整个运行期间都存在。速度快、不容易出错，因为有系统会善后。例如全局变量,static变量，常量字符串等

2.

## Stack Overflow Special(编译器分支预测)- 为什么有序的c++/java array执行要比无序的快得多

<https://stackoverflow.com/questions/11227809/why-is-processing-a-sorted-array-faster-than-processing-an-unsorted-array>

==========================================================================================================

