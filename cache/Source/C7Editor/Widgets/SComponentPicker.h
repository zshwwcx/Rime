//// Copyright 2021 T, Inc. All Rights Reserved.
//#pragma once
//
//#include "CoreMinimal.h"
//#include "Widgets/DeclarativeSyntaxSupport.h"
//#include "Widgets/SCompoundWidget.h"
//
//class PROJECTCEDITOR_API SComponentPicker : public SCompoundWidget
//{
//public:
//	DECLARE_DELEGATE_OneParam(FComponentPickDelegate, const UActorComponent* /*SelectedComponent*/);
//	DECLARE_DELEGATE_RetVal_OneParam(bool, FComponentFilterDelegate, const UActorComponent* /*Component*/);
//
//	SLATE_BEGIN_ARGS(SComponentPicker)
//		: _HostActorClass(nullptr), _HostActor(nullptr), _CurrentComponent(nullptr)
//	{}
//		SLATE_ATTRIBUTE(TSubclassOf<AActor>, HostActorClass)
//		SLATE_ATTRIBUTE(AActor*, HostActor)
//		SLATE_ATTRIBUTE(UActorComponent*, CurrentComponent)
//		SLATE_EVENT(FComponentPickDelegate, OnSelectedComponent)
//		SLATE_EVENT(FComponentFilterDelegate, OnFilterComponent)
//	SLATE_END_ARGS()
//
//	void Construct(const FArguments& InArgs);
//
//	TSharedRef<SWidget> OnGetMenuContent();
//
//	/**获取当前选中的函数名*/
//	FText GetCurrentComponentText() const;
//
//	void PickComponent(UActorComponent* SelectedComponent);
//
//	void ResetComponent();
//
//private:
//	FString GetComponentDisplayString(UActorComponent* InComponent) const;
//
//private:
//	/**类型*/
//	TAttribute<TSubclassOf<class AActor>> HostActorClass;
//
//	TAttribute<AActor*> HostActor;
//
//	/**选中的组件*/
//	TAttribute<UActorComponent*> CurrentComponent;
//
//	/**回调*/
//	FComponentPickDelegate SelectedFunctionDelegate;
//	FComponentFilterDelegate ComponentFilterDelegate;
//};
//
