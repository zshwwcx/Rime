#include "Opt/OptCmdMgr.h"



UE_DISABLE_OPTIMIZATION

#if UE_BUILD_SHIPPING
	#define ASAN_TEST 0
#else
	#define ASAN_TEST 1
#endif

// 只打开windows平台
#if PLATFORM_WINDOWS
#else
	#undef ASAN_TEST
	#define ASAN_TEST 0
#endif

#if ASAN_TEST

#include <vector>

namespace asan_test
{
	// https://learn.microsoft.com/en-us/cpp/sanitizers/asan?view=msvc-170#error-types
	static void Test1()
	{
		int X[100] = {};
		volatile int I = 100;
		X[I] = 5; // Boom!
		UE_LOG(LogTemp, Warning, TEXT("ASan Test. Test1 222"));

		volatile int* array = new int[10];
		int v = array[31];
		UE_LOG(LogTemp, Warning, TEXT("ASan Test. Test1-1"));

		volatile int* foo = new int;
		*foo = 3;
		delete foo;
		*foo = 4;
		UE_LOG(LogTemp, Warning, TEXT("ASan Test. Test1-2"));

		int k = 0x7fffffff;
		k += 1;

		UE_LOG(LogTemp, Warning, TEXT("ASan Test. Test1-3"));

		int* foo2 = (int*)malloc(sizeof(int));
		*foo2 = 3;
		free(foo2);
		*foo2 = 4;
		UE_LOG(LogTemp, Warning, TEXT("ASan Test. Test1-4"));
	}

	static void Test2()
	{
		void* Ptr = malloc(4);
		free(Ptr);
		free(Ptr); // Boom!
		UE_LOG(LogTemp, Warning, TEXT("ASan Test. Test2"));
	}

	static void Test3()
	{
		char Buffer[10] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9};
		int Size = 10;
		char* Local = (char*)malloc(Size);
		for (auto ii = 0; ii <= Size; ii++) // bad loop exit test 
		{
			Local[ii] = ~Buffer[ii]; // Two memory safety errors 
		}
		UE_LOG(LogTemp, Warning, TEXT("ASan Test. Test3"));
	}

	static void Test4()
	{
		// 无效
		delete (new int[10]);
	}

	namespace asan_test5
	{
		double GValue[5];

		static int Test5()
		{
			int RC = (int)GValue[5]; // Boom!
			return RC;
		}
	}

	static char Test6()
	{
		char* Ptr = (char*)malloc(10 * sizeof(char));
		free(Ptr);

		// ...

		UE_LOG(LogTemp, Warning, TEXT("ASan Test. Test6"));
		return Ptr[5]; // Boom!
	}

	static int Test7()
	{
		int ExternalAlign = 5;
		void* Ptr = _aligned_malloc(8, ExternalAlign); // Boom!
		return (Ptr == nullptr && errno == EINVAL) ? 0 : -1;
	}

	static void Test8()
	{
		// 检查不出来
		char Buf[] = "hello";
		memcpy(Buf, Buf + 1, 5); // BOOM!
	}

	namespace asan_test9
	{
		struct T
		{
			T() : V(100)
			{
			}

			std::vector<int> V;
		};

		struct Base
		{
		};

		struct Derived : public Base
		{
			T Vt;
		};

		static void Test9()
		{
			Base* Ptr = new Derived;

			delete Ptr; // Boom! 
		}
	}

	static void Test10()
	{
		int Subscript = -1;
		char Buf[42];
		Buf[Subscript] = 42; // Boom!
	}

	namespace asan_test11
	{
		// 检查不出来
		volatile char* X = nullptr;

		void foo()
		{
			char StackBuffer[42];
			X = &StackBuffer[13];
		}

		static void Test11()
		{
			foo();
			*X = 42; // Boom!
		}
	}

	namespace asan_test12
	{
		int* Gp;
		bool B = true;

		int Test12()
		{
			if (B)
			{
				int x[5];
				Gp = x + 1;
			}
			return *Gp; // Boom!
		}
	}

	void Test13()
	{
		char Buf[] = "hello\0XXX";
		strncat(Buf, Buf + 1, 3); // BOOM
		return;
	}

	void Test14()
	{
		int X = 1000;
		int Y = 1000;

		char* Buffer = (char*)malloc(X * Y * X * Y); //Boom!

		memcpy(Buffer, Buffer + 8, 8);
	}

	namespace asan_test15
	{
		void Foo(int Index, int Len)
		{
			volatile char* Str = (volatile char*)malloc(Len);

			//    reinterpret_cast<long>(str) & 31L;

			Str[Index] = '1'; // Boom !
		}

		static void Test15()
		{
			Foo(33, 10);
		}
	}
	static void Test16()
	{
		int* foo = new int;
		*foo = 3;
		delete foo;
		*foo = 4; // Boom!
	}
	static void Test17()
	{
		int k = 0x7fffffff;
		k += 1;
	}
}

FAutoConsoleCommand OptC7ASanTest1(TEXT("c7.asan.test"), TEXT("c7.asan.test"),
       FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
       {
			typedef void (*FUNC)();
	        TArray<FUNC> Callback;
	        Callback.Push(asan_test::Test1);
	        Callback.Push(asan_test::Test2);
	        Callback.Push(asan_test::Test3);
	        Callback.Push(asan_test::Test4);
	        Callback.Push([]()
	        {
	            asan_test::asan_test5::Test5();
	        });
	        Callback.Push([]()
	        {
	            asan_test::Test6();
	        });
	        Callback.Push([]()
			   {
				   asan_test::Test7();
			   });
	        Callback.Push(asan_test::Test8);
	        Callback.Push(asan_test::asan_test9::Test9);
	        Callback.Push(asan_test::Test10);
	        Callback.Push(asan_test::asan_test11::Test11);
	        Callback.Push([]()
			   {
				   asan_test::asan_test12::Test12();
			   });
	        Callback.Push(asan_test::Test13);
	        Callback.Push(asan_test::Test14);
	        Callback.Push(asan_test::asan_test15::Test15);
	        Callback.Push(asan_test::Test16);
	        Callback.Push(asan_test::Test17);

       		int Idx = -1;
       		if(Args.Num() > 0)
       		{
       			Idx = FCString::Atoi(*Args[0]);
       		}
       		if(Idx == 1000)
       		{
				for(int i=0; i<Callback.Num(); i++)
				{
					auto Func = Callback[i];
					UE_LOG(LogTemp, Warning, TEXT("ASan Test. Idx=%d"), i);
					(*Func)();
					UE_LOG(LogTemp, Warning, TEXT("ASan Test. Idx=%d done..."), i);
				}
       		}
       		else if(Callback.IsValidIndex(Idx))
       		{
		        UE_LOG(LogTemp, Warning, TEXT("ASan Test. Idx=%d"), Idx);
       			(*Callback[Idx])();
		        UE_LOG(LogTemp, Warning, TEXT("ASan Test. Idx=%d done..."), Idx);
       		}
	        else
	        {
		        UE_LOG(LogTemp, Warning, TEXT("ASan Test. Invalid Idx=%d. Len=%d"), Idx, Callback.Num());
	        }
       }));


FAutoConsoleCommand OptC7ASanTestMacro(TEXT("c7.asan.test.macro"), TEXT("c7.asan.test.macro"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
		{
#if ENABLE_NAN_DIAGNOSTIC
			UE_LOG(LogTemp, Warning, TEXT("ASan TestMacro ENABLE_NAN_DIAGNOSTIC=1"));
#else
			UE_LOG(LogTemp, Warning, TEXT("ASan TestMacro ENABLE_NAN_DIAGNOSTIC=0"));
#endif

		}));
	

#endif

UE_ENABLE_OPTIMIZATION