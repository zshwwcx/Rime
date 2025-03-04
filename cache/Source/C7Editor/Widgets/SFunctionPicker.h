// Copyright 2020 T, Inc. All Rights Reserved.
#pragma once

#include "CoreMinimal.h"
#include "Widgets/DeclarativeSyntaxSupport.h"
#include "Widgets/SCompoundWidget.h"

class SFunctionPicker : public SCompoundWidget
{
public:
	DECLARE_DELEGATE_OneParam(FFunctionDelegate, const FName& /*SelectedFunctionName*/);
	DECLARE_DELEGATE_RetVal_OneParam(bool, FFunctionFilterDelegate, const UFunction* /*Function*/);

	SLATE_BEGIN_ARGS(SFunctionPicker)
	{}
		SLATE_ATTRIBUTE(TOptional<FName>, CurrentFunction)
		SLATE_EVENT(FFunctionDelegate, OnSelectedFunction)
		SLATE_EVENT(FFunctionFilterDelegate, OnFilterFunction)
	SLATE_END_ARGS()

	void Construct(const FArguments& InArgs, UClass* InFromClass, UFunction* InAllowedSignature);

	TSharedRef<SWidget> OnGenerateDelegateMenu();

	/**获取当前选中的函数名*/
	FText GetCurrentFunctionText() const;

	/**查看方法内容*/
	FReply HandleGotoFunctionClicked();

	/**打开蓝图或者源码*/
	void GotoFunction(class UEdGraph* FunctionGraph);

	/**是否显示查看方法内容的按钮*/
	EVisibility GetGotoFunctionVisibility() const;

	/**是否已选中绑定方法*/
	bool HasFunctionBinding() const;

	void ResetFunctionBinding();

	void PickFunction(UFunction* SelectedFunction);

private:
	/**类型*/
	TObjectPtr<UClass> FromClass;

	/**函数签名*/
	TObjectPtr<UFunction> FuncSignature;

	/**选中的函数名*/
	TAttribute<TOptional<FName>> CurrentFunction;

	/**回调*/
	FFunctionDelegate SelectedFunctionDelegate;
	FFunctionFilterDelegate FunctionFilterDelegate;
};

