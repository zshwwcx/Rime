#include "MapShoot.h"
#include "MapShotDebugDrawComponent.h"

AMapShoot::AMapShoot(const FObjectInitializer& ObjectInitializer)
{
#if WITH_EDITOR
	DebugDrawComponent = CreateDefaultSubobject<UMapShotDebugDrawComponent>("DebugDrawComponent");
	DebugDrawComponent->SetupAttachment(GetRootComponent());
#endif
}

#if WITH_EDITOR
#include "MapCustomPanel.h"
void AMapShoot::OnOpenSelectionPanel()
{
	SMapCustomPanel::OpenDialog(this);
}
# endif