#pragma once

#include "CoreMinimal.h"
#include "Commandlets/Commandlet.h"
#include "Commandlets/ResavePackagesCommandlet.h"
#include "C7NavmeshAndVoxBuildCommandlet.generated.h"

#define MAP_NAME TEXT("MapName")

DECLARE_LOG_CATEGORY_EXTERN(LogC7NavmeshAndVoxBuildCommandlet, All, All);

UCLASS()
class UC7NavmeshAndVoxBuildCommandlet : public UResavePackagesCommandlet
{
	GENERATED_BODY()

public:
	UC7NavmeshAndVoxBuildCommandlet();

	virtual int32 Main(const FString& InCommandline) override;

	bool ValidParams(const TArray<FString>& InParamArray, FString& ErrorMessage);

	bool HasParam(const FString& InParamName) const;

	FString GetParamAsString(const FString& InParamName, const FString& InDefaultValue = TEXT("")) const;

	TArray<FString> Tokens;
	TArray<FString> Switches;
	TMap<FString, FString> Params;
};
