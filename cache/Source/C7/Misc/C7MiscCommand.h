//Add By Masou 2023.11.23 MiscCommand
#pragma once

#include "CoreMinimal.h"
#include "Commandlets/Commandlet.h"
#include "C7MiscCommand.generated.h"

DECLARE_LOG_CATEGORY_EXTERN(LogC7MiscCommandlet, Log, All);

enum EPakFileCheck
{
	MAP = 1,
	PLAYER = 2,
	OTHER = 4
};

#if WITH_EDITOR
/*==== GuidTextureScan ====*/
struct FSubmitGuidGroup
{
	FGuid Guid;
	FString Texture2DPath;
};
/*==== GuidTextureScan ====*/
#endif

UCLASS()
class C7_API UC7MiscCommandlet : public UCommandlet
{
	GENERATED_BODY()
public:
	UC7MiscCommandlet();
	virtual int32 Main(const FString& InCommandline) override;

#if WITH_EDITOR
	int32 PakFileCheck(uint32 Token);
	int32 GuidTextureScan(const FString Branch);
#endif

protected:

	bool HasSwitch(const FString& InSwitch) const;
	bool HasParam(const FString& InParamName) const;
	FString GetParamAsString(const FString& InParamName, const FString& InDefaultValue = TEXT("")) const;
	int32 GetParamAsInt(const FString& InParamName, int32 InDefaultValue = 0) const;
	int32 RunCommandlet();
#if WITH_EDITOR
	/*==== GuidTextureScan ====*/
	bool SubmitGuidGroupTask(int32 GroupId, TArray<FSubmitGuidGroup> SubmitList, int32 StartIdIndex, FString ProjectName, FString BranchName);
	/*==== GuidTextureScan ====*/
#endif

	TArray<FString> Tokens;
	TArray<FString> Switches;
	TMap<FString, FString> Params;
};

