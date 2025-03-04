#include "NPCGeneratorEdMode.h"
#include "C7Editor/C7Editor.h"
#include "Toolkits/ToolkitManager.h"
#include "ScopedTransaction.h"
#include "NPCGeneratorEdModeToolkit.h"
#include "EngineUtils.h"
#include "Engine/Selection.h"


class NPCGeneratorEditorCommands : public TCommands<NPCGeneratorEditorCommands>
{
public:
	NPCGeneratorEditorCommands() : TCommands <NPCGeneratorEditorCommands>
		(
			"C7Editor",	
			FText::FromString(TEXT("C7 Editor")),
			NAME_None,	
			FAppStyle::GetAppStyleSetName()
		)
	{
	}

#define LOCTEXT_NAMESPACE ""
	virtual void RegisterCommands() override
	{
		//UI_COMMAND(DeleteNPC, "Delete NPC", "Delete The Currently Selected NPC.", EUserInterfaceActionType::Button, FInputGesture(EKeys::Delete));
	}
#undef LOCTEXT_NAMESPACE

public:
	TSharedPtr<FUICommandInfo> DeleteNPC;
};

IMPLEMENT_HIT_PROXY(HNPCGeneratorPointProxy, HHitProxy);

const FEditorModeID FNPCGeneratorEdMode::EM_NPCGenerator(TEXT("EM_NPCGenerator"));

FNPCGeneratorEdMode::FNPCGeneratorEdMode()
{
	NPCGeneratorEditorCommands::Register();
	NPCGeneratorEdModeActions = MakeShareable(new FUICommandList);
}

FNPCGeneratorEdMode::~FNPCGeneratorEdMode()
{
	NPCGeneratorEditorCommands::Unregister();
}

void FNPCGeneratorEdMode::MapCommands()
{
	const auto& Commands = NPCGeneratorEditorCommands::Get();

	NPCGeneratorEdModeActions->MapAction(
		Commands.DeleteNPC,
		FExecuteAction::CreateSP(this, &FNPCGeneratorEdMode::RemoveNPC),
		FCanExecuteAction::CreateSP(this, &FNPCGeneratorEdMode::CanRemoveNPC));
}

void FNPCGeneratorEdMode::Enter()
{
	FEdMode::Enter();
	
	if (!Toolkit.IsValid())
	{
		Toolkit = MakeShareable(new FNPCGeneratorEdModeToolkit);
		Toolkit->Init(Owner->GetToolkitHost());
	}

	MapCommands();
}

void FNPCGeneratorEdMode::Exit()
{
	FToolkitManager::Get().CloseToolkit(Toolkit.ToSharedRef());
	Toolkit.Reset();
	
	FEdMode::Exit();
}


void FNPCGeneratorEdMode::Render(const FSceneView* View, FViewport* Viewport, FPrimitiveDrawInterface* PDI)
{
	FEdMode::Render(View, Viewport, PDI);
}


bool FNPCGeneratorEdMode::HandleClick(FEditorViewportClient* InViewportClient, HHitProxy *HitProxy, const FViewportClick &Click)
{
	bool IsHandled = false;
	return IsHandled;
}

bool FNPCGeneratorEdMode::InputDelta(FEditorViewportClient* InViewportClient, FViewport* InViewport, FVector& InDrag, FRotator& InRot, FVector& InScale)
{
	if (InViewportClient->GetCurrentWidgetAxis() == EAxisList::None)
	{
		return false;
	}
	
	return false;
}

bool FNPCGeneratorEdMode::InputKey(FEditorViewportClient* ViewportClient, FViewport* Viewport, FKey Key, EInputEvent Event)
{
	bool IsHandled = false;

	if (!IsHandled && Event == IE_Pressed)
	{
		IsHandled = NPCGeneratorEdModeActions->ProcessCommandBindings(Key, FSlateApplication::Get().GetModifierKeys(), false);
	}


return IsHandled;
}

bool FNPCGeneratorEdMode::ShowModeWidgets() const
{
	return true;
}

bool FNPCGeneratorEdMode::ShouldDrawWidget() const
{
	return true;
}

bool FNPCGeneratorEdMode::UsesTransformWidget() const
{
	return true;
}

FVector FNPCGeneratorEdMode::GetWidgetLocation() const
{
	return FEdMode::GetWidgetLocation();
}

// ALTBase* GetSelectedNPCActor()
// {
// 	TArray<UObject*> SelectedObjects;
// 	GEditor->GetSelectedActors()->GetSelectedObjects(SelectedObjects);
// 	if (SelectedObjects.Num() == 1)
// 	{
// 		return Cast<ALTBase>(SelectedObjects[0]);
// 	}
// 	return nullptr;
// }

void FNPCGeneratorEdMode::AddNPC()
{
	UWorld* World = GWorld;
	FEditorViewportClient* Client = (FEditorViewportClient*)GEditor->GetActiveViewport()->GetClient();
	if (World && Client)
	{ 
		FVector EndLocation = Client->GetViewLocation() + Client->GetViewRotation().Vector() * 10000.f;
		FHitResult Hit;
		FCollisionQueryParams CollisionParams;
		const bool bHit = World->LineTraceSingleByChannel(Hit,
			Client->GetViewLocation(),
			EndLocation,
			ECC_WorldStatic,
			CollisionParams);
		FRotator Rotation = FRotator::ZeroRotator;
		FActorSpawnParameters Params;
		Params.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;
		Params.bAllowDuringConstructionScript = true;
		Params.ObjectFlags |= (RF_TextExportTransient | RF_NonPIEDuplicateTransient);
		// comment by shijingzhe: delete deprecated ALTBase
		// UClass* BlueprintVar = StaticLoadClass(ALTBase::StaticClass(), nullptr, *TemplatePath);
// 		if (BlueprintVar)
// 		{
// #if WITH_EDITOR
// 			Params.bTemporaryEditorActor = true;
// #endif
			// ALTBase* NewActor = Cast<ALTBase>(World->SpawnActor(BlueprintVar, &Hit.Location, &Rotation, Params));
		// }
	}
}

bool FNPCGeneratorEdMode::CanAddNPC() const
{
	return true;
}

void FNPCGeneratorEdMode::RemoveNPC()
{
	if (HasValidSelection())
	{
		// GWorld->DestroyActor(GetSelectedNPCActor());
	}
}

bool FNPCGeneratorEdMode::CanRemoveNPC() const
{
	return HasValidSelection();
}

bool FNPCGeneratorEdMode::HasValidSelection() const
{
	// return GetSelectedNPCActor() != nullptr;
	return false;
}

void FNPCGeneratorEdMode::SetNPCTemplate(FString Path)
{
	TemplatePath = Path;
}