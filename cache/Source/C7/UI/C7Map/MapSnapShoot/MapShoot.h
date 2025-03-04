#pragma once

#include "Camera/CameraActor.h"
#include "MapShoot.generated.h"

class UMapShotDebugDrawComponent;

UCLASS()
class C7_API AMapShoot : public ACameraActor
{
	GENERATED_BODY()
public:
	AMapShoot(const FObjectInitializer& ObjectInitializer);

#if WITH_EDITOR
	UFUNCTION(CallInEditor, Category = "Shoot", meta = (DisplayName = "Custom Panel"))
	void OnOpenSelectionPanel();
#endif
	virtual bool IsEditorOnly() const { return true; }//�������õģ����ܱ����л�

#if WITH_EDITORONLY_DATA
	UPROPERTY()
	UMapShotDebugDrawComponent* DebugDrawComponent;
#endif
};