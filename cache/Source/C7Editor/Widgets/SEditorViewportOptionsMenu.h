// Copyright 2021 T, Inc. All Rights Reserved.

#include "EditorViewportOptionsContext.h"
#include "EditorViewportCommands.h"
#include "SEditorViewportViewMenu.h"
#include "ToolMenus.h"
#include "EngineUtils.h"
#include "LevelViewportActions.h"

#define LOCTEXT_NAMESPACE "SEditorViewportOptionsMenu"

class SEditorViewportOptionsMenu : public SEditorViewportToolbarMenu
{
public:
	DECLARE_DELEGATE_RetVal(float, FOnGetFOVValueHandler);
	DECLARE_DELEGATE_OneParam(FOnFOVValueChangedHandler, float);

	SLATE_BEGIN_ARGS(SEditorViewportOptionsMenu)
	{}
		SLATE_ARGUMENT( TSharedPtr<class FExtender>, MenuExtenders )
		SLATE_EVENT( FOnGetFOVValueHandler, OnGetFOVValueHandler)
		SLATE_EVENT( FOnFOVValueChangedHandler, OnFOVValueChangedHandler)
	SLATE_END_ARGS()

	void Construct(const FArguments& InArgs, TSharedRef<SEditorViewport> InViewport, TSharedRef<class SViewportToolBar> InParentToolBar)
	{
		Viewport = InViewport;
		MenuExtender = InArgs._MenuExtenders;
		OnGetFOVValueHandler = InArgs._OnGetFOVValueHandler;
		OnFOVValueChangedHandler = InArgs._OnFOVValueChangedHandler;

		SEditorViewportToolbarMenu::Construct
		(
			SEditorViewportToolbarMenu::FArguments()
				.ParentToolBar( InParentToolBar)
				.Cursor( EMouseCursor::Default )
				.Image( "EditorViewportToolBar.MenuDropdown" )
				.AddMetaData<FTagMetaData>(FTagMetaData(TEXT("EditorViewportToolBar.MenuDropdown")))
				.OnGetMenuContent( this, &SEditorViewportOptionsMenu::GenerateOptionsMenu )
		);
	}

private:
	TSharedRef<SWidget> GenerateOptionsMenu() const
	{
		static const FName OptionsMenuName("Editor.EditorViewportToolBar.Options");
		if (!UToolMenus::Get()->IsMenuRegistered(OptionsMenuName))
		{
			UToolMenu* Menu = UToolMenus::Get()->RegisterMenu(OptionsMenuName);
			Menu->AddDynamicSection("DynamicSection", FNewToolMenuDelegate::CreateLambda([](UToolMenu* InMenu)
			{
				if (UEditorViewportOptionsMenuContext* Context = InMenu->FindContext<UEditorViewportOptionsMenuContext>())
				{
					Context->EditorViewportOptionsMenu.Pin()->FillOptionsMenu(InMenu);
				}
			}));
		}

		UEditorViewportOptionsMenuContext* ContextObject = NewObject<UEditorViewportOptionsMenuContext>();
		ContextObject->EditorViewportOptionsMenu = SharedThis(this);

		FToolMenuContext MenuContext(Viewport.Pin()->GetCommandList(), MenuExtender, ContextObject);
		return UToolMenus::Get()->GenerateWidget(OptionsMenuName, MenuContext);
	}

	void FillOptionsMenu(UToolMenu* Menu) const
	{
		const FLevelViewportCommands& LevelViewportActions = FLevelViewportCommands::Get();
		FToolMenuSection& Section = Menu->AddSection("EditorViewportOptions", LOCTEXT("OptionsMenuHeader", "Viewport Options"));
		Section.AddMenuEntry(FEditorViewportCommands::Get().ToggleRealTime);
		Section.AddEntry(FToolMenuEntry::InitWidget("FOVAngle", GenerateFOVMenu(), LOCTEXT("FOVAngle", "Field of View (H)")));
		Section.AddMenuEntry( LevelViewportActions.ToggleGameView );
	}

private:
	TSharedRef<SWidget> GenerateFOVMenu() const
	{
		const float FOVMin = 5.f;
		const float FOVMax = 170.f;

		return
			SNew( SBox )
			.HAlign( HAlign_Right )
			[
				SNew( SBox )
				.Padding( FMargin(4.0f, 0.0f, 0.0f, 0.0f) )
				.WidthOverride( 100.0f )
				[
					SNew(SSpinBox<float>)
					.Font( FAppStyle::GetFontStyle( TEXT( "MenuItem.Font" ) ) )
					.MinValue(FOVMin)
					.MaxValue(FOVMax)
					.Value( this, &SEditorViewportOptionsMenu::GetFOVValue )
					.OnValueChanged( const_cast<SEditorViewportOptionsMenu*>(this), &SEditorViewportOptionsMenu::OnFOVValueChanged )
				]
			];
	}

	float GetFOVValue() const
	{
		if (OnGetFOVValueHandler.IsBound())
		{
			return OnGetFOVValueHandler.Execute();
		}
		return 0.f;
	}

	void OnFOVValueChanged(float NewFOV)
	{
		OnFOVValueChangedHandler.ExecuteIfBound(NewFOV);
	}

private:
	TWeakPtr<SEditorViewport> Viewport;
	TSharedPtr<class FExtender> MenuExtender;

	// Delegates
	FOnGetFOVValueHandler OnGetFOVValueHandler;
	FOnFOVValueChangedHandler OnFOVValueChangedHandler;
};

#undef LOCTEXT_NAMESPACE
