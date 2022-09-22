# Python

## 装饰器

最近想提高一下代码质量，发现高阶python编程的第一个建议就是善用装饰器，所以就过来研究一下装饰器相关的东西了。之前也看过很多遍，但总是看完就会，就觉得很好用，到用的时候又总是容易忘，然后又懒得去查，然后就懒得再用了。

这次长记性了，把一些常用的和不常用的装饰器用法都记录下来，下次使用的时候直接查一下markdown日志，也强迫自己多用，这样才能慢慢提高代码质量。

### 装饰器的理解

装饰器wrapper本质是重写func，返回一个包含原函数func功能的新的函数对象，但函数的名称、参数什么的都不会发生变化。对装饰器的理解能够加深python一切皆对象的理念。

```python
def deco():
    pass
@deco
def func():
   pass
```

等价于:

```python
def func():
    pass

def deco():
    pass

func = deco(func)
```

在给func套上装饰器@deco之后，原先的func就消失了，func被deco(func)取代。如果希望保留原先func这样一个对象的话，有一种方式，在装饰器返回的对象中添加一个成员函数，用来存储你想要保存的原函数func对象:

```python
def deco(func):
    def inner():
        pass
    inner._f = func
    return inner

@deco
def func():
    pass
```

### 常用装饰器

最普通的装饰器，看代码就行

```python
def wrapper(func):
    def inner():
        print "before inner func()."
        func()
        print "after inner func()."
    inner._f = func # 将func函数保存在wrapper内，保证需要的时候，可以通过func._f()来调用
    return inner


@wrapper
def foo():
    print "hello world."
```

### 上下文装饰器(contextlib decorator)

```python
#todo: 这个看过，也理解了一些内容，但是实际上一次都没用过。等真正遇到使用场景再来填这个坑吧
```

## 魔术方法(magic methods)

## 一些奇怪的小技巧

### 字符串反向处理

将字符串a进行反转

```python
a = '!dlrow olleH'

b = a[::-1]
# result:  b = 'Hello world!'#
```

### 智能开箱

一种比较酷的解压缩列表的方法

```python3(python2不支持这种方式)
a, *b, c = [1,2,3,4,5]

a = 1
b = [2, 3, 4]
c = 5
```

### 各种推导式

#### 列表推导式

使用[]生成list

```fake_code
variable = [out_exp_res for out_exp in input_list if out_exp == 2]
```

例子:

```python
list1 = [i for i in range(30) if i % 3 == 1]


def double(i):
    return 2 * i
list2 = [double(i) for i in range(20) if i % 3 == 0]
```

#### 字典推导

```python
d = {x: x % 2 == 0 for x in range(1, 11) }
```

## subprocess-子进程管理

### run()

### Popen()

今天在处理messiah-feature-hub的时候遇到一个问题，在程序自更新阶段出现软件卡死/在重新启动新进程失败的情况。代码断在了subprocess的Popen调用阶段。

## metaclass-元类

__metaclass__ = xxx

作用：在创建类的过程中实现一些自定义的操作(保证类对象是一个Singleton单例，用来给创建的类对象、函数方法包装装饰器等等),先讲讲class是啥，是一个对象，怎么创建的，由type创建的，type是一个class，metaclass是跟type类似的，创建一个类的类，metaclass一般会直接继承自type,或者重写__init__()和__call__(),__new__()，来实现创建类的方法。（改写__init__还是改写__new__取决于具体需求，如果需要在class对象创建的时候进行处理，则改写__new__，如果在对象属性初始化的时候处理，则改写__init__即可）

metaclass本身来说并不复杂，复杂的是用metaclass来做的一些事情：利用metaclass来做类对象的内部审查，操纵继承或者修改类似于__dict__的变量之类的操作.

其本身本质非常简单:

1. 拦截一个类对象的创建
2. 修改类对象
3. 返回一个修改之后的类对象

```python
from functools import wraps

def hook_convert_to_expr(func):
    @wraps(func)
    def _wrapper(self, *args, **kwargs):
        r = func(self, *args, **kwargs)
        if r.__class__.__name__ == 'EAGetValue':
            from custom.pub.game_trigger.GameTrigger import GameTriggerArgFactory
            sub_type_cls = GameTriggerArgFactory.sub_arg_parser[self.arg_type]
            for key in dir(sub_type_cls):
                if getattr(sub_type_cls, key, None) == self.sub_type:
                    r.val_desc = key
                    break
        return r
    return _wrapper

class upmetaclass(type):
    def __new__(cls, name, bases, attrs):
        if 'convert_to_expr' in attrs:
            attrs['convert_to_expr'] = hook_convert_to_expr(attrs['convert_to_expr'])
        return super(upmetaclass, cls).__new__(cls, name, bases, attrs)
```

## magic methods-魔法方法

### __getattribute__

## Collections - 容器类

### Counter()- Dict子类，用于计数

```python
from collections import Counter
temp_dict = {1:3, 5:4, 2:2}
ct = Counter(temp_dict)
print ct.most_common
print [lambda num: num,_ in ct.most_common()]
```

## Lambda表达式

Lambda表达式实际上就是一个匿名函数，它的主要作用就是优化代码结构，让代码看起来更加整洁，

```python
lambda x: x+10
```

等价于

```python
def anonymous_func(x):
    return x+10
```

==========================================================================================================

