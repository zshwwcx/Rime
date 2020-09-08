# -*- coding:utf-8 -*-


def deco(func):
    def inner():
        print "before inner func()."
        func()
        print "after inner func()."

    inner._f = func
    return inner


@deco
def foo():
    print "hello world."

def test():
    print "hello world"
    return A()


class A():
    def __init__(self):
        pass

    def close(self):
        print "A.close"


if __name__ == '__main__':
    # foo()
    # foo._f()
    # a = 'Hello world!'
    # b = a[::-1]
    # print b
    from contextlib import closing
    with closing(test()) as f:
        print "end like."
