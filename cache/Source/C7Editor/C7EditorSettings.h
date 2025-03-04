#pragma once

#include "CoreMinimal.h"
#include "Engine/DeveloperSettings.h"
#include "Engine/EngineTypes.h"
#include "GameFramework/GameMode.h"
#include "C7EditorSettings.generated.h"

UCLASS(config = Editor, meta = (DisplayName = "C7EditorSettings"), defaultconfig)
class UC7EditorSettings : public UDeveloperSettings
{
	GENERATED_BODY()

public:
	UC7EditorSettings(const FObjectInitializer& Initializer)
		: Super(Initializer)
	{

	}
public:
	UPROPERTY(EditAnywhere, config, Category = Asset, meta = (RelativeToGameContentDir, ToolTip="引擎编辑器启动时就默认加载的目录"))
	TArray<FDirectoryPath> PreScanPaths;


	//美术跑图GameInstance
	UPROPERTY(EditAnywhere, config, Category = LevelPreview, meta = (ToolTip = "美术跑图 GameInstance"))
	FSoftClassPath PreviewGameInstance;
	//美术跑图GameMode
	UPROPERTY(EditAnywhere, config, Category = LevelPreview, meta = (ToolTip = "美术跑图 GameMode"))
	TSubclassOf<AGameMode> PreviewGameMode;
};
