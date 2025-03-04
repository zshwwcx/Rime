#pragma once

#include "CoreMinimal.h"
#include "C7Define.generated.h"


USTRUCT(BlueprintType)
struct FBitmarkArray
{
	GENERATED_BODY()

public:
	UPROPERTY(BlueprintReadWrite)
	TArray<uint8> BitArray;
};