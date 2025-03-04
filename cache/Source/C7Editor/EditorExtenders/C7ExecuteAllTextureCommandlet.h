#pragma once

#include "CoreMinimal.h"
#include "Commandlets/Commandlet.h"
#include "Commandlets/ResavePackagesCommandlet.h"
#include "C7ExecuteAllTextureCommandlet.generated.h"

DECLARE_LOG_CATEGORY_EXTERN(LogC7ExecuteAllTextureCommandlet, All, All);

UCLASS()
class UC7ExecuteAllTextureCommandlet : public UResavePackagesCommandlet
{
	GENERATED_BODY()

public:
	UC7ExecuteAllTextureCommandlet();

	virtual int32 Main(const FString& InCommandline) override;
};
