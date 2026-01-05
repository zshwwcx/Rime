# UE5

## Slate

### Slate主流程

![Slate主流程](./res/UE5/Slate/slate_main_flow.png)

Slate主流程分为两个阶段: 1.Prepass ,  2.DrawWindows
DrawPrepass()是一个自底而上的过程，深度遍历子节点，从最下面的叶子节点开始，调用SWidget->Prepass_Internal()，计算并更新每个SWidget的DesiredSize并Cache住。
DrawWindow()则是一个自顶而下的过程，从根节点开始，依次调用DrawWindowAndChildren(), SWidget->Paint()，再到SWidget->OnPaint()。 对于PanelWidget,会额外再OnPaint中触发ArrangedLayeredChildren()，对子节点递归调用Paint()，子节点会在Paint()中调用自身的OnPaint()。


#### DrawPrepass()
DrawPrepass的核心逻辑在PrepassWindowAndChildren()，代码如下:
```
static void PrepassWindowAndChildren(TSharedRef<SWindow> WindowToPrepass, const TSharedPtr<SWindow>& DebuggingWindow, TWeakPtr<SWidget>& CurrentContext)
{
	// Skip Prepass if we are debugging that window or if we are on the server.
	if (IsRunningDedicatedServer() || WindowToPrepass == DebuggingWindow)
	{
		return;
	}

	const bool bIsWindowVisible = WindowToPrepass->IsVisible() && !WindowToPrepass->IsWindowMinimized();

	if (bIsWindowVisible || DoAnyWindowDescendantsNeedPrepass(WindowToPrepass))
	{
		TGuardValue TmpContext(CurrentContext, TWeakPtr<SWidget>(WindowToPrepass));
		FScopedSwitchWorldHack SwitchWorld(WindowToPrepass);
		
		{
		    // 这里会先对当前的SWindow执行一轮Invalidate(但是得开启GlobalInvalidation才会生效)
			WindowToPrepass->ProcessWindowInvalidation();
			// 真正的SlatePrepass，里面是一轮递归，对每个子节点都会执行SlatePrepass
			WindowToPrepass->SlatePrepass(FSlateApplication::Get().GetApplicationScale() * WindowToPrepass->GetNativeWindow()->GetDPIScaleFactor());
		}

		if ( bIsWindowVisible && WindowToPrepass->IsAutosized() )
		{
			WindowToPrepass->Resize(WindowToPrepass->GetDesiredSizeDesktopPixels());
		}

		// Note: Iterate over copy since num children can change during resize above.
		TArray<TSharedRef<SWindow>, FConcurrentLinearArrayAllocator> ChildWindows(WindowToPrepass->GetChildWindows());
		for (const TSharedRef<SWindow>& ChildWindow : ChildWindows)
		{
			PrepassWindowAndChildren(ChildWindow, DebuggingWindow, CurrentContext);
		}
	}
}
```
#### SWidget::SlatePrepass()
SlatePrepass()的核心逻辑在Prepass_Internal()，本质也是对所有Children执行一轮prepass，基于children的prepass结果，得出自己的DesiredSize，随后再往上传递。
```
void SWidget::Prepass_Internal(float InLayoutScaleMultiplier)
{
	PrepassLayoutScaleMultiplierValue = InLayoutScaleMultiplier;
	bPrepassLayoutScaleMultiplierSet = true;

	bool bShouldPrepassChildren = true;
	if (bHasCustomPrepass)
	{
		bShouldPrepassChildren = CustomPrepass(InLayoutScaleMultiplier);
	}

	if (bCanHaveChildren && bShouldPrepassChildren)
	{
		// Cache child desired sizes first. This widget's desired size is
		// a function of its children's sizes.
		FChildren* MyChildren = this->GetChildren();
		const int32 NumChildren = MyChildren->Num();
		// 递归子节点，执行Prepass_ChildLoop
		Prepass_ChildLoop(InLayoutScaleMultiplier, MyChildren);
		ensure(NumChildren == MyChildren->Num());
	}

	{
		// Cache this widget's desired size.
		CacheDesiredSize(GetPrepassLayoutScaleMultiplier());
		bNeedsPrepass = false;

		//BEGIN ADD BY limunan@kuaishou.com : add delegate for prepass done
		FVector2f Size = DesiredSize;
		OnPostPrepass.Broadcast(Size); 
		//END ADD BY limunan@kuaishou.com : add delegate for prepass done
	}
}
```

#### SWindow::DrawWindowAndChildren()
Prepass结束，就开始DrawWindow()了， SWindow本身也是FSlateInvalidationRoot，所以在DrawWindow()里面的核心逻辑就是SWindow::PaintInvalidationRoot(),随后会调用到SWindow::PaintSlowPath(),再到Paint()->OnPaint()，OnPaint()内部是一个深度递归，对每个子节点执行OnPaint()，并获取MaxLayerId进行return。

```c++
int32 SWindow::PaintSlowPath(const FSlateInvalidationContext& Context)
{
	HittestGrid->Clear();

	const FSlateRect WindowCullingBounds = GetClippingRectangleInWindow();
	const int32 LayerId = 0;
	const FGeometry WindowGeometry = GetWindowGeometryInWindow();

	int32 MaxLayerId = 0;

	//OutDrawElements.PushBatchPriortyGroup(*this);
	{
		
		MaxLayerId = Paint(*Context.PaintArgs, WindowGeometry, WindowCullingBounds, *Context.WindowElementList, LayerId, Context.WidgetStyle, Context.bParentEnabled);
	}

	//OutDrawElements.PopBatchPriortyGroup();



	return MaxLayerId;
}
```

Paint()里面先做自身的渲染数据计算，把相关数据存入到OutDrawElements中后，执行OnPaint()，OnPaint()内部会对子节点依次执行Paint()逻辑。
简单总结，Paint()算位置、大小，并更新OutDrawElementsList，OnPaint()执行子节点的Paint(),并依据子节点的Paint()结果，更新LayerId并返回。

### Slate基础 [https://zhuanlan.zhihu.com/p/692551733]
Slate最简单的节点是SWidget，所有的Slate Widget都会继承自SWidget这个基类。
从SWidget又会派生出三种不同的中继类: 
1. SCompoundWidget 只能有一个child widget的SWidget， SComponentWidget只有一个child slot，但是这个child slot可以填充SPanel，继而实现拥有多个child->childSlot的功能。SComponentWidget本身只能有一个子节点，但是子节点如果是SPanel，那么可以继续衍生更多的子节点。
2. SLeafWidget 叶子节点，不能有任何的child.
3. SPanel 容器节点，可以有任意多个子节点



# UE5

## UE5内存分配器