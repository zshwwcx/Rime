// Fill out your copyright notice in the Description page of Project Settings.


#include "SceneActor/C7SceneBaseActor.h"
#include "Components/LocalLightComponent.h"
#include "Engine/Light.h"
#include "Components/SpotLightComponent.h"
#include "Engine/SpotLight.h"
#include "Engine/StaticMeshActor.h"
#include "Engine/PointLight.h"
#include "Components/BoxComponent.h"
#include "ContentStreaming.h"
#if WITH_EDITOR
#include "EditorActorFolders.h"
#include "ActorGroupingUtils.h"
#endif


// Sets default values
AC7SceneBaseActor::AC7SceneBaseActor()
{
 	// Set this actor to call Tick() every frame.  You can turn this off to improve performance if you don't need it.
	PrimaryActorTick.bCanEverTick = true;
	bIsEditorOnlyActor = false;

#if WITH_EDITORONLY_DATA
	bToggleBPSplit = false;
#endif
	BoxComponent = CreateDefaultSubobject<UBoxComponent>(TEXT("RootBound"));
	BoxComponent->SetBoxExtent(FVector(100.f, 100.f, 100.f));
	RootComponent = BoxComponent;
	BoxComponent->SetMobility(EComponentMobility::Static);
}

// Called when the game starts or when spawned
void AC7SceneBaseActor::BeginPlay()
{
	Super::BeginPlay();
	
}

// Called every frame
void AC7SceneBaseActor::Tick(float DeltaTime)
{
	Super::Tick(DeltaTime);

}

void AC7SceneBaseActor::SplitActorPOIToStaticMesh()
{
#if WITH_EDITOR
	UWorld* World = nullptr;
	TArray<AActor*> GeneratedActors;

	//UClass* ParentClass = GetClass()->GetSuperClass();
	if (GetClass() == AC7SceneBaseActor::StaticClass())
	{
		return;
	}

	AActor* Actor = this;
	World = Actor->GetWorld();

	if (!World)
	{
		UE_LOG(LogTemp, Fatal, TEXT("Can't get world ptr!"));

		return;
	}

	FString POIName = Actor->GetClass()->GetFName().ToString();

	if (POIName.Right(2) == TEXT("_C"))
	{
		POIName = POIName.Left(POIName.Len() - 2);
	}

	int32 MaxIndex = 0;
	FActorFolders::Get().ForEachFolder(*World, [this, &World, &MaxIndex, &POIName](const FFolder& Folder)
	{
		FString Str = Folder.GetPath().ToString();
		if (Str.Contains(POIName))
		{
			Str = Str.Right(Str.Len() - POIName.Len() - 1);
			MaxIndex = FMath::Max(FCString::Atoi(*Str), MaxIndex);
		}
		return true;
	});

	MaxIndex += 1;

	POIName = POIName + TEXT("_") + FString::FormatAsNumber(MaxIndex);

	FolderName = POIName;

	TMap<USceneComponent*, AActor*> ActorMapping;

	// Handle mesh component
	TInlineComponentArray<UMeshComponent*> ActorComponents(Actor);
	for (UMeshComponent* ActorComponent : ActorComponents)
	{
		if (!ActorComponent->IsA(UStaticMeshComponent::StaticClass()))
			continue;

		AStaticMeshActor* NewActor = Actor->GetWorld()->SpawnActor<AStaticMeshActor>(ActorComponent->GetComponentLocation(), ActorComponent->GetComponentRotation());
		UStaticMeshComponent* TargetStaticMeshComponent = NewActor->GetStaticMeshComponent();
		UStaticMeshComponent* SourceStaticMeshComponent = Cast<UStaticMeshComponent>(ActorComponent);

		AActor* SourceActor = Actor;
		AActor* TargetActor = NewActor;

		UActorComponent* SourceComponent = SourceStaticMeshComponent;
		UActorComponent* TargetComponent = TargetStaticMeshComponent;

		CopyComponentProperty(SourceComponent, TargetComponent, SourceActor);

		TargetStaticMeshComponent->MarkRenderStateDirty();
		TargetStaticMeshComponent->RecreatePhysicsState();
		TargetStaticMeshComponent->bNavigationRelevant = TargetStaticMeshComponent->IsNavigationRelevant();
		IStreamingManager::Get().NotifyPrimitiveUpdated(TargetStaticMeshComponent);

		TargetStaticMeshComponent->UpdateBounds();

		NewActor->SetActorTransform(ActorComponent->GetComponentTransform());
		FName MeshName = SourceStaticMeshComponent->GetStaticMesh()->GetFName();
		NewActor->SetActorLabel(MeshName.ToString());

		GeneratedActors.Add(NewActor);
		ActorMapping.FindOrAdd(SourceStaticMeshComponent, NewActor);
	}

	// Handle local light component
	TInlineComponentArray<ULocalLightComponent*> LocalLightComponents(Actor);

	for (ULocalLightComponent* LocalLightComponent : LocalLightComponents)
	{
		ALight* NewActor = nullptr;
		if (LocalLightComponent->IsA(USpotLightComponent::StaticClass()))
		{
			NewActor = Actor->GetWorld()->SpawnActor<ASpotLight>(LocalLightComponent->GetComponentLocation(), LocalLightComponent->GetComponentRotation());
		}
		else if (LocalLightComponent->IsA(UPointLightComponent::StaticClass()))
		{
			NewActor = Actor->GetWorld()->SpawnActor<APointLight>(LocalLightComponent->GetComponentLocation(), LocalLightComponent->GetComponentRotation());
		}

		if (NewActor)
		{
			ULocalLightComponent* TargetLocalLightComponent = Cast<ULocalLightComponent>(NewActor->GetLightComponent());
			ULocalLightComponent* SourceLocalLightComponent = LocalLightComponent;

			AActor* SourceActor = Actor;
			AActor* TargetActor = NewActor;

			CopyComponentProperty(SourceLocalLightComponent, TargetLocalLightComponent, SourceActor);
			SourceLocalLightComponent->MarkRenderStateDirty();

			NewActor->SetActorTransform(LocalLightComponent->GetComponentTransform());

			GeneratedActors.Add(NewActor);
			ActorMapping.FindOrAdd(LocalLightComponent, NewActor);
		}
	}

	// Handle child actor component
	TArray<AActor*> AttachedActors;
	Actor->GetAttachedActors(AttachedActors);

	for (auto InsideActor : AttachedActors)
	{
		FActorSpawnParameters SpawnParameters;
		//SpawnParameters.Template = InsideActor;
		FTransform ActorTransform = InsideActor->GetTransform();
		AActor* NewActor = InsideActor->GetWorld()->SpawnActor(InsideActor->GetClass(), &ActorTransform, SpawnParameters);

		using ECopyOption = EditorUtilities::ECopyOptions::Type;

		EditorUtilities::CopyActorProperties(InsideActor, NewActor, EditorUtilities::FCopyOptions((ECopyOption)(ECopyOption::CallPostEditMove | ECopyOption::OnlyCopyEditOrInterpProperties | ECopyOption::CallPostEditChangeProperty)));

		TInlineComponentArray<UMeshComponent*> MeshComponents(NewActor);

		for (auto& Iter : MeshComponents)
		{
			Iter->MarkRenderStateDirty();
			Iter->RecreatePhysicsState();
			Iter->bNavigationRelevant = Iter->IsNavigationRelevant();
			IStreamingManager::Get().NotifyPrimitiveUpdated(Iter);
			Iter->UpdateBounds();
		}

		NewActor->SetActorTransform(ActorTransform);
		if (AStaticMeshActor* StaticMesh = Cast<AStaticMeshActor>(NewActor))
		{
			const FName MeshName = StaticMesh->GetStaticMeshComponent()->GetStaticMesh()->GetFName();
			StaticMesh->SetActorLabel(MeshName.ToString());
		}

		GeneratedActors.Add(NewActor);
		//ActorMapping.FindOrAdd(LocalLightComponent, NewActor);
	}

	for (auto& Iter : ActorMapping)
	{
		USceneComponent* ParentSceneComponent = Iter.Key->GetAttachParent();
		if (ParentSceneComponent && ActorMapping.Find(ParentSceneComponent))
		{
			AActor* ParentActor = *ActorMapping.Find(ParentSceneComponent);
			Iter.Value->AttachToActor(ParentActor, FAttachmentTransformRules::KeepWorldTransform);

			Iter.Key->UnregisterComponent();
		}
			
		CachedComponentInfo.FindOrAdd(Iter.Key->GetFName(), FComponentInfo(Iter.Key->GetRelativeTransform(), true));
	}

	ClassType = GetClass();
	AC7SceneBaseActor* ProxyActor = GetWorld()->SpawnActor<AC7SceneBaseActor>(GetActorLocation(), GetActorRotation());
	ProxyActor->ReferenceActors = GeneratedActors;
	ProxyActor->ClassType = ClassType;
	ProxyActor->bToggleBPSplit = true;
	ProxyActor->CachedComponentInfo = CachedComponentInfo;
	ProxyActor->FolderName = FolderName;

	if (World)
	{
		UActorGroupingUtils::Get()->GroupActors(GeneratedActors);

		GeneratedActors.Add(ProxyActor);
		FName NewFolderName(*POIName);
		const FFolder NewFolder = FFolder(FFolder::GetWorldRootFolder(GetWorld()).GetRootObject(), *POIName);
		FActorFolders::Get().CreateFolder(*World, NewFolder);

		for (auto& Iter : GeneratedActors)
		{
			Iter->SetFolderPath_Recursively(NewFolderName);
		}
	}
	
	GeneratedActors.Reset();

	// Destroy current actor
	Destroy();
#endif
}

void AC7SceneBaseActor::CopyComponentProperty(class UActorComponent* SourceComponent, class UActorComponent* TargetComponent, class AActor* SourceActor)
{
#if WITH_EDITOR
	if (SourceComponent->CreationMethod == EComponentCreationMethod::UserConstructionScript)
	{
		return;
	}

	if (TargetComponent != nullptr)
	{
		UClass* ComponentClass = SourceComponent->GetClass();
		check(ComponentClass == TargetComponent->GetClass());

		TSet<const FProperty*> SourceUCSModifiedProperties;
		SourceComponent->GetUCSModifiedProperties(SourceUCSModifiedProperties);

		EditorUtilities::FCopyOptions Options(EditorUtilities::ECopyOptions::Default);

		// Copy component properties
		for (FProperty* Property = ComponentClass->PropertyLink; Property != nullptr; Property = Property->PropertyLinkNext)
		{
			const bool bIsTransient = !!(Property->PropertyFlags & CPF_Transient);
			const bool bIsIdentical = Property->Identical_InContainer(SourceComponent, TargetComponent);
			const bool bIsComponent = !!(Property->PropertyFlags & (CPF_InstancedReference | CPF_ContainsInstancedReference));
			const bool bIsTransform =
				Property->GetFName() == USceneComponent::GetRelativeScale3DPropertyName() ||
				Property->GetFName() == USceneComponent::GetRelativeLocationPropertyName() ||
				Property->GetFName() == USceneComponent::GetRelativeRotationPropertyName();

			if (!bIsTransient && !bIsIdentical && !bIsComponent && !SourceUCSModifiedProperties.Contains(Property)
				&& (!bIsTransform/* || (!SourceActor->HasAnyFlags(RF_ClassDefaultObject | RF_ArchetypeObject) && !TargetActor->HasAnyFlags(RF_ClassDefaultObject | RF_ArchetypeObject))*/))
			{
				const bool bIsSafeToCopy = Property->HasAnyPropertyFlags(CPF_Edit);
				if (bIsSafeToCopy)
				{
					if (!Options.CanCopyProperty(*Property, *SourceActor))
					{
						continue;
					}
					EditorUtilities::CopySingleProperty(SourceComponent, TargetComponent, Property);
				}
			}
		}
	}
#endif
}

void AC7SceneBaseActor::RestoreComponents()
{
#if WITH_EDITOR
	if (ClassType && GetClass() == AC7SceneBaseActor::StaticClass())
	{
		AC7SceneBaseActor* OriginActor = GetWorld()->SpawnActor<AC7SceneBaseActor>(ClassType, GetActorLocation(), GetActorRotation());
		
		TArray<UActorComponent*> AllComponents;
		OriginActor->GetComponents<UActorComponent>(AllComponents);
		for (int32 i = 0; i < AllComponents.Num(); ++i)
		{
			FName CompName = AllComponents[i]->GetFName();
			if (auto Info = CachedComponentInfo.Find(CompName))
			{
				Cast<USceneComponent>(AllComponents[i])->SetRelativeTransform(Info->Transform);
			}
		}

		UActorGroupingUtils::Get()->UngroupActors(ReferenceActors);

		for(auto Iter : ReferenceActors)
			Iter->Destroy();

		Destroy();
	}
	
	const FFolder NewFolder = FFolder(FFolder::GetWorldRootFolder(GetWorld()).GetRootObject(), *FolderName);
	FActorFolders::Get().DeleteFolder(*GetWorld(), NewFolder);
#endif
}

#if WITH_EDITOR
void AC7SceneBaseActor::PostEditChangeChainProperty(FPropertyChangedChainEvent& PropertyChangedEvent)
{
	Super::PostEditChangeChainProperty(PropertyChangedEvent);

	/*if (PropertyChangedEvent.Property->GetFName() == GET_MEMBER_NAME_STRING_CHECKED(AC7SceneBaseActor, bToggleBPSplit))
	{
		if(bToggleBPSplit)
			SplitActorPOIToStaticMesh();
		else
			RestoreComponents();
	}*/
}
#endif
