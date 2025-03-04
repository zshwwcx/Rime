
#include "AssetToolsModule.h"
#include "ContentBrowserModule.h"
#include "ConvexDecompTool.h"
#include "IContentBrowserSingleton.h"
#include "ILandscapeEdToolsModule.h"
#include "IMeshMergeUtilities.h"
#include "LandscapeComponent.h"
#include "MeshDescription.h"
#include "MeshMergeModule.h"
#include "ObjectTools.h"
#include "Selection.h"
#include "StaticMeshAttributes.h"
#include "Algo/ForEach.h"
#include "AssetRegistry/AssetRegistryModule.h"

#include "Opt/OptCmdMgr.h"

#include "Blueprint/WidgetTree.h"
#include "Components/CanvasPanel.h"
#include "Materials/MaterialInstance.h"
#include "Components/ShapeComponent.h"
#include "Components/StaticMeshComponent.h"
#include "PhysicsEngine/BodySetup.h"
#include "MaterialDomain.h"
#include "Components/HierarchicalInstancedStaticMeshComponent.h"
#include "Components/InstancedStaticMeshComponent.h"
#include "WorldPartition/WorldPartitionRuntimeHash.h"
#include "WorldPartition/WorldPartitionRuntimeLevelStreamingCell.h"
#include "WorldPartition/WorldPartitionRuntimeSpatialHash.h"
#include "NaniteSceneProxy.h"
#include "WorldPartition/HLOD/HLODActor.h"
#include "Landscape.h"


namespace c7opt
{
	class FRegexHelper
	{
	public:
		bool IsMatch(const FString& Path) const
		{
			if(RegexPatterns.Num() == 0)
			{
				return true;
			}
			
			for(auto It : RegexPatterns)
			{
				FRegexMatcher Matcher(It, Path);
				while (Matcher.FindNext())
				{
					return true;
				}			
			}			
			return false;			
		}
		bool IsMatch(UPackage* Pkg) const
		{
			if(!Pkg)
			{
				return false;
			}
			return IsMatch(Pkg->GetPathName());
		}
		void AddStr(const FString& Str)
		{
			auto Trimed = Str.TrimStart().TrimEnd();
			if(Trimed.Len() == 0)
			{
				return;
			}
			RegexPatterns.Add(FRegexPattern(Trimed));
		}
		void AddArray(const TArray<FString>& Arr)
		{
			for(auto It : Arr)
			{
				AddStr(It);
			}
		}
		void AddStrArray(const FString& CmdArg, const FString& Delim)
		{
			TArray<FString> MeshPath;
			CmdArg.ParseIntoArray(MeshPath, *Delim);
			AddArray(MeshPath);
		}
		void AddFromCommandLine(const FString& CmdArg)
		{
			TArray<FString> MeshPath;
			CmdArg.ParseIntoArray(MeshPath, TEXT(";"));
			AddArray(MeshPath);
		}
		void AddDefault(const FString& RegStr)
		{
			if(RegexPatterns.Num() == 0)
			{
				RegexPatterns.Add(FRegexPattern(RegStr));
			}			
		}
		bool HasData() const
		{
			return RegexPatterns.Num() > 0;
		}
	private:
		TArray<FRegexPattern> RegexPatterns;
	};	
}

/// 根据mat，过滤actor
FAutoConsoleCommand OptFilterActorUseMesh(TEXT("opt.FilterActorUseMesh"), TEXT("opt.FilterActorUseMesh"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
#if WITH_EDITOR
		
		if(Args.Num() == 0)
		{
			UE_LOG(LogTemp, Warning, TEXT("opt FilterActorUseMesh Invalid Args!!!"));
			return;
		}
		
		UE_LOG(LogTemp, Log, TEXT("opt FilterActorUseMesh"));
			
		auto World = GEditor->GetEditorWorldContext().World();
		FString MatKeyworld = Args[0];

		TArray<AActor*> PendingActors;
		for(FActorIterator It(World); It; ++It)
		{
			bool bFind = false;
			It->ForEachComponent<UStaticMeshComponent>(false, [&bFind, MatKeyworld](UStaticMeshComponent* Comp)
			{
				int N = Comp->GetNumMaterials();
				for(int i=0; i<N ;i++)
				{
					UMaterialInterface* Mat = Comp->GetMaterial(i);
					if(FOptHelper::MaybeIsMat(Mat, MatKeyworld))
					{
						bFind = true;
					}
				}
			});
			
			if(bFind)
			{
				PendingActors.Add(*It);
				UE_LOG(LogTemp, Log, TEXT("Filter ActorLabel:%s"), *It->GetActorLabel());				
			}
		}

		if(PendingActors.Num() > 0)
		{
			GEditor->SelectNone(true, true);
			for(auto Actor : PendingActors)
			{
				GEditor->SelectActor(Actor, true, true);				
			}
			
		}	
		
#endif
	}));


/// 根据模型，过滤actor
FAutoConsoleCommand OptFilterActorUseMat(TEXT("opt.FilterActorUseMat"), TEXT("opt.FilterActorUseMat"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
#if WITH_EDITOR
		
		if(Args.Num() == 0)
		{
			UE_LOG(LogTemp, Warning, TEXT("opt FilterActorUseMat Invalid Args!!!"));
			return;
		}
		
		UE_LOG(LogTemp, Log, TEXT("opt FilterActorUseMat"));
			
		auto World = GEditor->GetEditorWorldContext().World();
		FString MatKeyworld = Args[0];

		TArray<AActor*> PendingActors;
		for(FActorIterator It(World); It; ++It)
		{
			bool bFind = false;
			It->ForEachComponent<UStaticMeshComponent>(false, [&bFind, MatKeyworld](UStaticMeshComponent* Comp)
			{
				if(Comp->GetStaticMesh() && Comp->GetStaticMesh()->GetName().Contains(MatKeyworld))
				{
					bFind = true;
				}
			});
			
			if(bFind)
			{
				PendingActors.Add(*It);
				UE_LOG(LogTemp, Log, TEXT("Filter ActorLabel:%s"), *It->GetActorLabel());				
			}
		}

		if(PendingActors.Num() > 0)
		{
			GEditor->SelectNone(true, true);
			for(auto Actor : PendingActors)
			{
				GEditor->SelectActor(Actor, true, true);				
			}
			
		}	
		
#endif
	}));


/// 根据模型，过滤actor
FAutoConsoleCommand OptFilterActor(TEXT("opt.FilterActor"), TEXT("opt.FilterActor"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
#if WITH_EDITOR
		
		if(Args.Num() != 2)
		{
			UE_LOG(LogTemp, Warning, TEXT("opt FilterActor Invalid Args!!!"));
			return;
		}
		
		UE_LOG(LogTemp, Log, TEXT("opt FilterActor"));
			
		auto World = GEditor->GetEditorWorldContext().World();
		FString MatKeyworld = Args[0];
		FString MeshKeyworld = Args[1];

		TArray<AActor*> PendingActors;
		for(FActorIterator It(World); It; ++It)
		{
			bool bFind = false;
			It->ForEachComponent<UStaticMeshComponent>(false, [&bFind, MatKeyworld, MeshKeyworld](UStaticMeshComponent* Comp)
			{
				if(Comp->GetStaticMesh() && Comp->GetStaticMesh()->GetName().Contains(*MeshKeyworld))
				{
					int N = Comp->GetNumMaterials();
					for(int i=0; i<N ;i++)
					{
						UMaterialInterface* Mat = Comp->GetMaterial(i);
						if(FOptHelper::MaybeIsMat(Mat, MatKeyworld))
						{
							bFind = true;
						}
					}
				}
			});
			
			if(bFind)
			{
				PendingActors.Add(*It);
				UE_LOG(LogTemp, Log, TEXT("Filter ActorLabel:%s"), *It->GetActorLabel());				
			}
		}

		if(PendingActors.Num() > 0)
		{
			GEditor->SelectNone(true, true);
			for(auto Actor : PendingActors)
			{
				GEditor->SelectActor(Actor, true, true);				
			}
			
		}	
		
#endif
	}));

/// dump潜在的合并批次的数目
FAutoConsoleCommand OptDumpBatch(TEXT("opt.dumpBatch"), TEXT("opt.dumpBatch"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
#if WITH_EDITOR				
		UE_LOG(LogTemp, Log, TEXT("opt FilterActor"));
			
		auto World = GEditor->GetEditorWorldContext().World();
		
		TMap<FString, int> Dict;
		int TotalBatch = 0;
		int SectionCount = 0;

		TArray<AActor*> PendingActors;
		for(FActorIterator It(World); It; ++It)
		{
			bool bFind = false;
			It->ForEachComponent<UStaticMeshComponent>(false, [&bFind, &Dict, &TotalBatch, &SectionCount](UStaticMeshComponent* Comp)
			{
				if(Comp->GetStaticMesh())
				{
					// 暂不区分ISM和HISM					
					FString Key = FOptHelper::MakeMeshKey(Comp);
					int N = Comp->GetNumMaterials();
					int* V = Dict.Find(Key);
					if(V == nullptr)
					{
						Dict.Add(Key, N);
						SectionCount += N;
					}
					TotalBatch += N;
				}
			});
		}

		UE_LOG(LogTemp, Log, TEXT("SceneBatchCount=%d, Can Reduced To=%d, MeshCount=%d"), TotalBatch, SectionCount, Dict.Num());
		
#endif
	}));

/// dump actor
FAutoConsoleCommand OptDumpActor(TEXT("opt.editor.dumpactor"), TEXT("opt.editor.dumpactor"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
#if WITH_EDITOR				
		UE_LOG(LogTemp, Log, TEXT("opt dump actor"));
			
		auto World = GEditor->GetEditorWorldContext().World();
		
		TArray<AActor*> PendingActors;
		for(FActorIterator It(World); It; ++It)
		{
			UE_LOG(LogTemp, Log, TEXT("Actor=%s/%s, %s"), *It->GetFolderPath().ToString(), *It->GetActorLabel(), *It->GetFullName());
		}		
#endif
	}));

/// dump actor
FAutoConsoleCommand OptDumpISMCustomData(TEXT("opt.editor.dump.ism.customdata"), TEXT("opt.editor.dump.ism.customdata"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
#if WITH_EDITOR				
		UE_LOG(LogTemp, Log, TEXT("opt dump actor"));
			
		auto World = GEditor->GetEditorWorldContext().World();
		
		TArray<AActor*> PendingActors;
		for(FActorIterator It(World); It; ++It)
		{
			// UE_LOG(LogTemp, Log, TEXT("Actor=%s/%s, %s"), *It->GetFolderPath().ToString(), *It->GetActorLabel(), *It->GetFullName());
			bool bDump = false;
			It->ForEachComponent<UInstancedStaticMeshComponent>(false, [&bDump](UInstancedStaticMeshComponent* Comp)
			{
				if(Comp)
				{
					bDump = (Comp->PerInstanceSMCustomData.Num() > 0);
				}
			});
			
			if(bDump)
			{
				UE_LOG(LogTemp, Log, TEXT("Actor=%s/%s, %s"), *It->GetFolderPath().ToString(), *It->GetActorLabel(), *It->GetFullName());
			}
		}		
#endif
	}));


/// 移除场景中的editoronly对象
FAutoConsoleCommand OptDeleteEditorObj(TEXT("opt.editor.deleditor"), TEXT("opt.editor.deleditor"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
#if WITH_EDITOR				
		UE_LOG(LogTemp, Log, TEXT("opt dump actor"));
			
		auto World = GEditor->GetEditorWorldContext().World();
		
		TArray<AActor*> PendingActors;
		for(FActorIterator It(World); It; ++It)
		{
			if (!It->GetRootComponent())
			{
				continue;
			}

			if (It->GetRootComponent()->Mobility != EComponentMobility::Static)
			{
				continue;
			}			
			
			FString ActorName = It->GetActorLabel();
			if (ActorName.Contains("landscape"))
			{
				continue;
			}

			// 跳过HLODActor
			if (It->IsA<AWorldPartitionHLOD>())
			{
				continue;
			}

			// 如果comp全是editoronly，那么actor也得标记成editoronly
			bool bAllEditorOnly = true;
			It->ForEachComponent<USceneComponent>(false, [&bAllEditorOnly](USceneComponent* Comp)
			{
				if(Comp && !Comp->IsEditorOnly())
				{
					bAllEditorOnly = false;
				}
			});
			if(bAllEditorOnly && !It->IsEditorOnly())
			{
				It->bIsEditorOnlyActor = true;
				It->MarkPackageDirty();
			}
			
			if(It->IsEditorOnly())
			{
				PendingActors.Add(*It);
			}
		}
		for(auto It : PendingActors)
		{
			UE_LOG(LogTemp, Log, TEXT("Delete Actor=%s/%s, %s"), *It->GetFolderPath().ToString(), *It->GetActorLabel(), *It->GetFullName());
			It->Destroy();
		}
#endif
	}));

class FOptCmdMgrFoliageHelper
{
public:
	static bool IsFoliage(const UStaticMeshComponent* Comp)
	{
		// SM的路径是：/Game/Arts/Environment/Mesh/Flora/SM_Wutong001/SM_Wutong003
		// MI的路径是：/Script/Engine.MaterialInstanceConstant'/Game/Arts/Environment/Mesh/Flora/SM_Wutong001/MI_Wutong001_A.MI_Wutong001_A'
		if(!Comp || !Comp->GetStaticMesh())
		{
			return false;
		}
			
		auto MeshPath = Comp->GetStaticMesh()->GetPathName();
		if(MeshPath.Contains("/Mesh/Flora/"))
		{
			return true;
		}		
		if(MeshPath.Contains("/Foliage/"))
		{
			return true;
		}
			
		return false;		
	}
	static bool IsProps(const UStaticMeshComponent* Comp)
	{
		// SM的路径是：/Game/Arts/Environment/Mesh/Flora/SM_Wutong001/SM_Wutong003
		// MI的路径是：/Script/Engine.MaterialInstanceConstant'/Game/Arts/Environment/Mesh/Flora/SM_Wutong001/MI_Wutong001_A.MI_Wutong001_A'
		if(!Comp || !Comp->GetStaticMesh())
		{
			return false;
		}
			
		auto MeshPath = Comp->GetStaticMesh()->GetPathName();
		if(MeshPath.Contains("/Environment/Mesh/Props"))
		{
			return true;
		}
			
		return false;		
	}

	// 收集植被	
	static void CollectFoliageInfo(const TArray<AActor*>& ActorsInCell, TArray<UStaticMeshComponent*>& OutPendingFoliages)
	{
		for(auto Actor : ActorsInCell)
		{
			if(Actor->IsEditorOnly())
			{
				continue;
			}
			Actor->ForEachComponent<UStaticMeshComponent>(false, [&OutPendingFoliages](UStaticMeshComponent* Comp)
			{
				if(!Comp || Comp->IsEditorOnly())
				{
					return;
				}
					
				if(Comp->Mobility != EComponentMobility::Static)
				{
					return;
				}

				if(FOptCmdMgrFoliageHelper::IsFoliage(Comp))
				{
					OutPendingFoliages.Add(Comp);
				}
			});
		}
	};

	// 合成FoliageActor
	static TMap<UStaticMesh*, TArray<UStaticMeshComponent*>> CombineFoliage(const TArray<UStaticMeshComponent*>& PendingFoliages)
	{
		TMap<UStaticMesh*, TSet<UStaticMeshComponent*>> MeshMap;
		for(auto It : PendingFoliages)
		{
			if(!It->GetStaticMesh())
			{
				continue;
			}
			
			if(!MeshMap.Contains(It->GetStaticMesh()))
			{
				MeshMap.Add(It->GetStaticMesh(), TSet<UStaticMeshComponent*>());
			}
			MeshMap[It->GetStaticMesh()].Add(It);
		}
		
		// 输出结果
		TMap<UStaticMesh*, TArray<UStaticMeshComponent*>> Ret;
		for(auto It : MeshMap)
		{
			Ret.Add(It.Key, It.Value.Array());
		}
		return Ret;
	}

	static FName NAME_SPECIAL_FOLIAGE()
	{
		return FName("liubo_foliage");
	}
	static FName NAME_SPECIAL_FOLIAGE_DEL()
	{
		return FName("liubo_foliage_del");
	}
	
	static TArray<AActor*> MakeFoliageActor(UWorld* World, const TMap<UStaticMesh*, TArray<UStaticMeshComponent*>>& PendingFoliages)
	{
		TArray<AActor*> Ret;
		if(!World)
		{
			return Ret;
		}
		if(PendingFoliages.Num() == 0)
		{
			return Ret;
		}

		TSet<AActor*> DirtyActorSet;
		
		// 按Level拆分
		TArray<TArray<UStaticMeshComponent*>> PendingGroups;
		for(auto Kt : PendingFoliages)
		{
			TMap<ULevel*, TArray<UStaticMeshComponent*>> LevelFoliages;
			for(auto Jt : Kt.Value)
			{
				auto Level = Jt->GetOwner()->GetLevel();
				if(!LevelFoliages.Contains(Level))
				{
					LevelFoliages.Add(Level, TArray<UStaticMeshComponent*>());
				}
				LevelFoliages[Level].AddUnique(Jt);
			}
			for(auto It : LevelFoliages)
			{
				PendingGroups.Add(It.Value);
			}
		}

		// 一个group，一个actor！！
		for(auto OneGroup : PendingGroups)
		{
			auto Sm = OneGroup[0]->GetStaticMesh();
			auto Level = OneGroup[0]->GetOwner()->GetLevel();
			
			// 输出结果
			FActorSpawnParameters SpawnParameters;
			SpawnParameters.OverrideLevel = Level;
			auto Actor = World->SpawnActor<AActor>(SpawnParameters);
			
			Actor->EditorTags.AddUnique(NAME_SPECIAL_FOLIAGE());
			{
				USceneComponent* Comp = NewObject<USceneComponent>(Actor,
											USceneComponent::StaticClass(), 
											*FString::Printf(TEXT("Root")));
				Actor->AddInstanceComponent(Comp);
				Comp->RegisterComponent();
				Comp->Mobility = EComponentMobility::Static;
				Actor->SetRootComponent(Comp);
				
				Comp->ComponentEditorTags.AddUnique(NAME_SPECIAL_FOLIAGE());
			}

			bool bInited = false;

			int CompCount = 0;
			for(auto It : PendingFoliages)
			{
				if(!bInited)
				{
					bInited = true;				
					Actor->SetActorLabel(FString::Printf(TEXT("FoliageHISM-%s"), *Sm->GetName()));
					FTransform ActorTransform(It.Value[0]->GetComponentLocation());
					Actor->SetActorTransform(ActorTransform);
				}
				
				CompCount++;
				if(It.Value.Num() >= 1)
				{
					UHierarchicalInstancedStaticMeshComponent* Comp = NewObject<UHierarchicalInstancedStaticMeshComponent>(Actor,
												UHierarchicalInstancedStaticMeshComponent::StaticClass(), 
												*FString::Printf(TEXT("HISMComp-%d"), CompCount));
					Actor->AddInstanceComponent(Comp);
					Comp->RegisterComponent();
					Comp->Mobility = EComponentMobility::Static;
				
					Comp->SetStaticMesh(Sm);
					Comp->SetMobility(EComponentMobility::Static);
					Comp->AttachToComponent(Actor->GetRootComponent(), FAttachmentTransformRules::KeepRelativeTransform);
					Comp->SetWorldTransform(It.Value[0]->GetComponentTransform());

					Comp->SetVisibleFlag(true);
					Comp->SetCollisionProfileName("BlockAll");
				
					int Cnt = Comp->GetNumMaterials();
					for(int i=0; i<Cnt; i++)
					{
						Comp->SetMaterial(i, It.Value[0]->GetMaterial(i));				
					}
				
					for(auto V : It.Value)
					{
						Comp->AddInstance(V->GetComponentTransform(), true);
					}

					// 默认可见范围是：todo. config
					const float Radius = It.Key->GetBounds().SphereRadius;
					if(Radius < 200)
					{
						Comp->InstanceEndCullDistance = 6400;
					}
					else if(Radius < 500)
					{
						Comp->InstanceEndCullDistance = 12800;
					}
					else
					{
						Comp->InstanceEndCullDistance = 25600;
					}				
					Comp->WorldPositionOffsetDisableDistance = 6400;

					Comp->ComponentEditorTags.AddUnique(NAME_SPECIAL_FOLIAGE());				
					for(auto V : It.Value)
					{
						V->ComponentEditorTags.AddUnique(NAME_SPECIAL_FOLIAGE_DEL());
						V->bIsEditorOnly = true;
						DirtyActorSet.Add(V->GetOwner());
					}
				}			
			}
		}

		// 标脏
		// 如果Actor都是EditorOnly，
		for(auto V : DirtyActorSet)
		{
			bool bAllEditorOnly = true;
			V->ForEachComponent<USceneComponent>(false, [&bAllEditorOnly](USceneComponent* Comp)
			{
				if(Comp && !Comp->bIsEditorOnly)
				{
					bAllEditorOnly = false;
				}
			});
			
			if(bAllEditorOnly)
			{
				V->bIsEditorOnlyActor = true;
			}
			
			V->MarkPackageDirty();
		}

		return Ret;
	}
};

/// 把植被从hlod中移除
FAutoConsoleCommand OptHlodStripFoliage(TEXT("opt.hlod.foliage"), TEXT("opt.hlod.foliage"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
#if WITH_EDITOR				
			
		auto World = GEditor->GetEditorWorldContext().World();
		
		TArray<AActor*> PendingActors;
		for(FActorIterator It(World); It; ++It)
		{
			if(It->IsEditorOnly())
			{
				PendingActors.Add(*It);
			}
			bool bDirty = false;
			
			if(It->IsEditorOnly())
			{
				if(It->bEnableAutoLODGeneration != false)
				{
					It->bEnableAutoLODGeneration = false;
					bDirty = true;
				}				
			}
			It->ForEachComponent<UStaticMeshComponent>(false, [&bDirty](UStaticMeshComponent* SmComp)
			{
				if(SmComp->bIsEditorOnly
					|| FOptCmdMgrFoliageHelper::IsFoliage(SmComp)
					|| FOptCmdMgrFoliageHelper::IsProps(SmComp))
				{
					if(SmComp->bEnableAutoLODGeneration != false)
					{
						SmComp->bEnableAutoLODGeneration = false;
						bDirty = true;						
					}
				}

				// 如果是阴影体
				if(SmComp->GetName().Contains("ShadowProxy"))
				{
					if(SmComp->bEnableAutoLODGeneration != false)
					{
						SmComp->bEnableAutoLODGeneration = false;
						bDirty = true;						
					}					
				}
			});

			// 如果comp的nothlod都是true，那么把actor也设置成这样！
			bool bAllNotHLod = true;
			It->ForEachComponent<UPrimitiveComponent>(false, [&bAllNotHLod](UPrimitiveComponent* SmComp)
				{
					if (SmComp->bEnableAutoLODGeneration != false)
					{
						bAllNotHLod = false;
					}
				});
			
			if (bAllNotHLod)
			{
				if (It->bEnableAutoLODGeneration != false)
				{
					It->bEnableAutoLODGeneration = false;
					bDirty = true;
				}
			}

			if(bDirty)
			{
				UE_LOG(LogTemp, Log, TEXT("Modify Actor=%s/%s, %s"), *It->GetFolderPath().ToString(), *It->GetActorLabel(), *It->GetFullName());
				It->MarkPackageDirty();
			}
		}
#endif
	}));

/// 把植被从hlod中移除
FAutoConsoleCommand OptHlodStripHuge(TEXT("opt.hlod.huge"), TEXT("opt.hlod.huge"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
#if WITH_EDITOR			
		auto World = GEditor->GetEditorWorldContext().World();
		float MinSize = 12800;
		if(Args.Num() > 0)
		{
			MinSize = FCString::Atoi(*Args[0]);
		}
		
		
		for(FActorIterator It(World); It; ++It)
		{
			bool bDirty = false;
			

			// 跳过地形
			FString ActorName = It->GetActorLabel();
			if(ActorName.Contains("landscape"))
			{
				continue;
			}

			// 跳过HLODActor
			if(It->IsA<AWorldPartitionHLOD>())
			{
				continue;
			}
			
			
			if(It->IsEditorOnly())
			{
				if(It->bEnableAutoLODGeneration != false)
				{
					It->bEnableAutoLODGeneration = false;
					bDirty = true;
				}				
			}
			bool bHasMesh = false;
			It->ForEachComponent<UStaticMeshComponent>(false, [&bDirty, &bHasMesh](UStaticMeshComponent* SmComp)
			{
				if(SmComp->bIsEditorOnly)
				{
					if(SmComp->bEnableAutoLODGeneration != false)
					{
						SmComp->bEnableAutoLODGeneration = false;
						bDirty = true;						
					}
				}
				bHasMesh = true;
			});
			if(bHasMesh)
			{
				if(!It->IsEditorOnly())
				{
					auto ActorBounds = It->GetComponentsBoundingBox(true);
					auto ActorSize = ActorBounds.GetSize();
					const float MaxV = FMath::Max<float>(ActorSize.X, ActorSize.Y);
					if(MaxV > MinSize)
					{
						if (It->bEnableAutoLODGeneration != false)
						{
							It->bEnableAutoLODGeneration = false;
							bDirty = true;
						}
					}
				}
			}

			// 如果comp的nothlod都是true，那么把actor也设置成这样！
			bool bAllNotHLod = true;
			It->ForEachComponent<UPrimitiveComponent>(false, [&bAllNotHLod](UPrimitiveComponent* SmComp)
				{
					if (SmComp->bEnableAutoLODGeneration != false)
					{
						bAllNotHLod = false;
					}
				});
			
			if (bAllNotHLod)
			{
				if (It->bEnableAutoLODGeneration != false)
				{
					It->bEnableAutoLODGeneration = false;
					bDirty = true;
				}
			}

			if(bDirty)
			{
				UE_LOG(LogTemp, Log, TEXT("Modify Actor=%s/%s, %s"), *It->GetFolderPath().ToString(), *It->GetActorLabel(), *It->GetFullName());
				It->MarkPackageDirty();
			}
		}
#endif
	}));

// 植被合并成FoliageActor
FAutoConsoleCommand OptHlodFoliageHism(TEXT("opt.foliage.hism"), TEXT("opt.foliage.hism"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
#if WITH_EDITOR	
		auto World = GEditor->GetEditorWorldContext().World();
		
		// 如果是大世界，那么按Cell合并
		// 如果是普通的，那么按地图合并
		TArray<TArray<UStaticMeshComponent*>> PendingList;
		if(World->IsPartitionedWorld())
		{			
			UWorldPartition* WorldPartition = World->GetWorldPartition();			
			UWorldPartitionRuntimeHash* RuntimeHash = WorldPartition->RuntimeHash;
			UWorldPartitionRuntimeSpatialHash* RuntimeSpatialHash = Cast<UWorldPartitionRuntimeSpatialHash>(RuntimeHash);
			const TArray<FSpatialHashRuntimeGrid>& SpatialGrids = RuntimeSpatialHash->GetGrids();
			int32 SpatialGridCellSize = (int)(SpatialGrids[0].CellSize);
			TArray<const UWorldPartitionRuntimeCell*> PendingCells;
			
			RuntimeSpatialHash->ForEachStreamingCells([SpatialGridCellSize, &PendingCells](const UWorldPartitionRuntimeCell* RuntimeCell)
			{
				// 只找第一级Cell的
				if(RuntimeCell->GetCellBounds().GetSize().X > SpatialGridCellSize)
				{
					return true;
				}
				PendingCells.Add(RuntimeCell);
				return true;
			});
			UE_LOG(LogTemp, Log, TEXT("liubo, PendingCell.Num=%d"), PendingCells.Num());

			for(auto RuntimeCell : PendingCells)
			{
				auto StreamingCell = Cast<UWorldPartitionRuntimeLevelStreamingCell>(RuntimeCell);
				
				// 收集有效的Actor
				TArray<FGuid> ActorInCellGuids;
				ActorInCellGuids.Reserve(StreamingCell->GetPackages().Num());
				for (const auto& ActorPackage : StreamingCell->GetPackages())
				{
					ActorInCellGuids.Add(ActorPackage.ActorInstanceGuid);
				}
				
				TArray<AActor*> ActorsInCell;
				ActorsInCell.Reserve(ActorInCellGuids.Num());
				for (const auto& ActorInCellGuid : ActorInCellGuids)
				{
					FWorldPartitionReference ActorRef(WorldPartition, ActorInCellGuid);
					FWorldPartitionActorDescInstance* ActorDesc = ActorRef.GetInstance();
					if (ActorDesc)
					{
						ActorsInCell.Add(ActorDesc->GetActor());
					}
				}

				TArray<UStaticMeshComponent*> PendingFoliages;
				FOptCmdMgrFoliageHelper::CollectFoliageInfo(ActorsInCell, PendingFoliages);
				PendingList.Add(PendingFoliages);				
			}			
		}
		else
		{
			TArray<AActor*> ActorsInCell;
			for(FActorIterator It(World); It; ++It)
			{
				ActorsInCell.Add(*It);
			}
			TArray<UStaticMeshComponent*> PendingFoliages;
			FOptCmdMgrFoliageHelper::CollectFoliageInfo(ActorsInCell, PendingFoliages);
			PendingList.Add(PendingFoliages);
		}

		// 生成
		for(auto It : PendingList)
		{
			auto KvMap = FOptCmdMgrFoliageHelper::CombineFoliage(It);
			auto Actor = FOptCmdMgrFoliageHelper::MakeFoliageActor(World, KvMap);
		}


		
#endif
	}));

/// 根据模型，过滤actor
FAutoConsoleCommand OptMeshNanite(TEXT("opt.meshnanite"), TEXT("opt.meshnanite"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		auto World = GEditor->GetEditorWorldContext().World();

		UMaterialInstance* DefaultMat = Cast<UMaterialInstance>(StaticLoadObject(
			UMaterialInstance::StaticClass(), nullptr,
			TEXT(
				"/Game/Arts/MaterialLibraryNew/MI_Dirt_Building_liubo.MI_Dirt_Building_liubo"),
			nullptr, LOAD_None, nullptr));
		if(!DefaultMat)
		{
			return;
		}
		
		TArray<AActor*> PendingActors;
		TSet<UStaticMesh*> Meshes;
		for(FActorIterator It(World); It; ++It)
		{
			bool bFind = false;
			It->ForEachComponent<UStaticMeshComponent>(false, [&bFind, &Meshes](UStaticMeshComponent* Comp)
			{
				if(Comp->GetStaticMesh() && !Comp->GetStaticMesh()->NaniteSettings.bEnabled)
				{
					if(!Comp->GetStaticMesh()->GetPathName().Contains("/Engine/"))
					{
						Meshes.Add(Comp->GetStaticMesh());						
					}
				}
			});
		}

		for(auto StaticMesh : Meshes)
		{
			// 检查是否有半透
			bool bHasUnsupportedBlendMode = false;
			bool bHasUnsupportedShadingModel = false;
			bool bHasSupport = false;
			bool bHasUnSupport = false;
			for(const auto& StaticMat : StaticMesh->GetStaticMaterials())
			{
				auto MatInterface = StaticMat.MaterialInterface.Get();
				if(!MatInterface)
				{
					continue;
				}
				bool bSupportBlendMode = Nanite::IsSupportedBlendMode(MatInterface->GetBlendMode());
				bool bSupportShadingModel = Nanite::IsSupportedShadingModel(MatInterface->GetShadingModels());
				bHasUnsupportedBlendMode |= !bSupportBlendMode;
				bHasUnsupportedShadingModel |= !bSupportShadingModel;
				bHasSupport |= ( bSupportBlendMode && bSupportShadingModel );
				bHasUnSupport |= ( !bSupportBlendMode || !bSupportShadingModel );
			}

			// 剔除掉不支持的
			if(bHasSupport && bHasUnSupport)
			{
				// 修改Material
				auto Old = StaticMesh->GetStaticMaterials();
				bool bDirty = false;
				for(int i=0; i<Old.Num(); i++)
				{
					auto MatInterface = Old[i].MaterialInterface.Get();
					if(MatInterface == nullptr)
					{
						continue;
					}
					bool bSupportBlendMode = Nanite::IsSupportedBlendMode(MatInterface->GetBlendMode());
					bool bSupportShadingModel = Nanite::IsSupportedShadingModel(MatInterface->GetShadingModels());
					if(!bSupportBlendMode || !bSupportShadingModel)
					{
						// 修改
						Old[i].MaterialInterface = DefaultMat;
						bDirty = true;						
					}
				}
				if(bDirty)
				{
					StaticMesh->SetStaticMaterials(Old);
					StaticMesh->MarkPackageDirty();					
				}
			}
			else if(!bHasSupport)
			{
				// 没有支持的nanite的mesh section，直接返回了				
				if(bHasUnsupportedBlendMode || bHasUnsupportedShadingModel)
				{
					// 不支持的，应该关掉nanite
	#if false				
					StaticMesh->Modify();
					StaticMesh->NaniteSettings.bEnabled = false;

					FProperty* ChangedProperty = FindFProperty<FProperty>(UStaticMesh::StaticClass(), GET_MEMBER_NAME_CHECKED(UStaticMesh, NaniteSettings));
					FPropertyChangedEvent Event(ChangedProperty);
					StaticMesh->PostEditChangeProperty(Event);
	#endif				
				}
				
				continue;
			}
			
			StaticMesh->Modify();
			StaticMesh->NaniteSettings.bEnabled = true;
			StaticMesh->NaniteSettings.FallbackTarget = ENaniteFallbackTarget::PercentTriangles;
			StaticMesh->NaniteSettings.FallbackPercentTriangles = 1.f;
				
			FProperty* ChangedProperty = FindFProperty<FProperty>(UStaticMesh::StaticClass(), GET_MEMBER_NAME_CHECKED(UStaticMesh, NaniteSettings));
			FPropertyChangedEvent Event(ChangedProperty);
			StaticMesh->PostEditChangeProperty(Event);
			StaticMesh->MarkPackageDirty();
			UE_LOG(LogTemp, Log, TEXT("liubo, static mesh:%s"), *StaticMesh->GetPathName());
		}
		
	}));


/// 删掉场景中的植被、小物件
FAutoConsoleCommand OptDeleteFoliageAndProps(TEXT("opt.editor.del.foliagepros"), TEXT("opt.editor.del.foliagepros"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
#if WITH_EDITOR				
		UE_LOG(LogTemp, Log, TEXT("opt del.foliagepros"));
			
		auto World = GEditor->GetEditorWorldContext().World();

		TSharedPtr<c7opt::FRegexHelper> RegHelper = MakeShared<c7opt::FRegexHelper>();
		
		if(Args.Num() > 0)
		{
			RegHelper->AddFromCommandLine(Args[0]);
		}

		// 一些默认的
		if(!RegHelper->HasData())
		{
			RegHelper->AddStr("/Mesh/Flora/");
			RegHelper->AddStr("/Foliage/");
			RegHelper->AddStr("/Environment/Mesh/Props/");
		}
		
		TArray<AActor*> PendingActors;
		for(FActorIterator It(World); It; ++It)
		{
			// 如果comp全是editoronly，那么actor也得标记成editoronly
			bool bDirty = false;
			if(It->IsEditorOnly())
			{
				continue;
			}

			if (!It->GetRootComponent())
			{
				continue;
			}

			if (It->GetRootComponent()->Mobility != EComponentMobility::Static)
			{
				continue;
			}

			FString ActorName = It->GetActorLabel();
			if (ActorName.Contains("landscape"))
			{
				continue;
			}

			// 跳过HLODActor
			if (It->IsA<AWorldPartitionHLOD>())
			{
				continue;
			}
			
			It->ForEachComponent<UStaticMeshComponent>(false, [&bDirty](UStaticMeshComponent* Comp)
			{
				if(Comp->IsEditorOnly())
				{
					return;
				}
				if(Comp->Mobility != EComponentMobility::Static)
				{
					return;
				}
				if(FOptCmdMgrFoliageHelper::IsFoliage(Comp) || FOptCmdMgrFoliageHelper::IsProps(Comp))
				{
					Comp->bIsEditorOnly = true;
					bDirty = true;
				}
			});
			if(bDirty)
			{
				It->MarkPackageDirty();
				UE_LOG(LogTemp, Log, TEXT("liubo, del.foliage:%s/%s, %s"), *It->GetFolderPath().ToString(), *It->GetActorLabel(), *It->GetFullName());
			}
		}
#endif
	}));


// 转成简单碰撞
FAutoConsoleCommand OptC7OptPhySimple(TEXT("c7.opt.phy.simple"), TEXT("c7.opt.phy.simple"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
		{
		bool bAll = false;
		if(Args.Num() > 0)
		{
			bAll = FCString::Atoi(*Args[0]) > 0;
		}
		auto World = GEditor->GetEditorWorldContext().World();
		for(FActorIterator It(World); It; ++It)
		{
			if(It->IsEditorOnly())
			{
				continue;
			}
			
			It->ForEachComponent<UStaticMeshComponent>(false, [bAll](UStaticMeshComponent* Comp)
			{
				if(Comp->IsEditorOnly())
				{
					return;
				}
				
				if(Comp->GetStaticMesh() && Comp->GetStaticMesh()->GetBodySetup())
				{
					UPackage* Pkg = Cast<UPackage>(Comp->GetStaticMesh()->GetOuter());
					if(Pkg && Pkg->GetName().Contains("/Engine/"))
					{
						return;
					}
					
					auto Body = Comp->GetStaticMesh()->GetBodySetup();
					if(bAll || Body->AggGeom.GetElementCount() > 0)
					{
						Body->CollisionTraceFlag = CTF_UseSimpleAsComplex;
						
						Body->MarkPackageDirty();
						Comp->GetStaticMesh()->MarkPackageDirty();						
						// Comp->GetOwner()->MarkPackageDirty();
						UE_LOG(LogTemp, Log, TEXT("liubo, simple mesh: %s"), *Body->GetFullName());
					}
				}
			});
		}

		}));


// 植被，关掉碰撞
FAutoConsoleCommand OptC7OptPhyFoliageDisable(TEXT("c7.opt.phy.foliage.disable"), TEXT("c7.opt.phy.foliage.disable"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
		{
		
		bool bAll = false;
		if(Args.Num() > 0)
		{
			bAll = FCString::Atoi(*Args[0]) > 0;
		}

		static FName NAME_NOCOLLSION("NoCollision");
		static FName NAME_FOLIAGE("Foliage");
		static FName NAME_NOCOLLSION_LIUBO("liubo_NoCollision");
		
		auto World = GEditor->GetEditorWorldContext().World();
		for(FActorIterator It(World); It; ++It)
		{
			if(It->IsEditorOnly())
			{
				continue;
			}
			int DirtyCount = 0;
			It->ForEachComponent<UStaticMeshComponent>(false, [bAll, &DirtyCount](UStaticMeshComponent* Comp)
			{
				if(Comp->IsEditorOnly())
				{
					return;
				}
				
				if(Comp->GetStaticMesh() && Comp->GetStaticMesh()->GetBodySetup())
				{
					if(Comp->ComponentEditorTags.Contains(NAME_NOCOLLSION_LIUBO))
					{
						return;
					}
					
					
					UPackage* Pkg = Cast<UPackage>(Comp->GetStaticMesh()->GetOuter());
					if(!Pkg)
					{
						return;
					}
					
					auto PkgName = Pkg->GetName(); 
					if(PkgName.Contains("/Engine/"))
					{
						return;
					}
					
					bool bFoliage = PkgName.Contains("Environment/Mesh/Flora");
					bFoliage |= (Comp->GetStaticMesh()->LODGroup == NAME_FOLIAGE);
					
					if(bFoliage)
					{
						Comp->ComponentEditorTags.Add(NAME_NOCOLLSION_LIUBO);
						Comp->SetCollisionProfileName(NAME_NOCOLLSION);
						Comp->MarkPackageDirty();
						DirtyCount++;
					}
				}
			});
			if(DirtyCount > 0)
			{
				UE_LOG(LogTemp, Log, TEXT("liubo, Disable Foliage Collision:%s, %s"), *It->GetName(), *It->GetActorLabel());				
			}
		}

		}));

// 植被，资产，去掉碰撞，设置成nocollision
FAutoConsoleCommand OptC7OptPhyFoliageAssetDisable(TEXT("c7.opt.phy.foliageasset.disable"), TEXT("c7.opt.phy.foliageasset.disable"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
		{
		
		bool bAll = false;
		if(Args.Num() > 0)
		{
			bAll = FCString::Atoi(*Args[0]) > 0;
		}

		static FName NAME_NOCOLLSION("NoCollision");
		static FName NAME_FOLIAGE("Foliage");
		static FName NAME_NOCOLLSION_LIUBO("liubo_NoCollision");

		TSet<UStaticMesh*> Meshes;
		auto World = GEditor->GetEditorWorldContext().World();
		for(FActorIterator It(World); It; ++It)
		{
			if(It->IsEditorOnly())
			{
				continue;
			}
			It->ForEachComponent<UStaticMeshComponent>(false, [bAll, &Meshes](UStaticMeshComponent* Comp)
			{
				if(Comp->IsEditorOnly())
				{
					return;
				}
				
				if(Comp->GetStaticMesh() && Comp->GetStaticMesh()->GetBodySetup())
				{	
					UPackage* Pkg = Cast<UPackage>(Comp->GetStaticMesh()->GetOuter());
					if(!Pkg)
					{
						return;
					}
					
					auto PkgName = Pkg->GetName(); 
					if(PkgName.Contains("/Engine/"))
					{
						return;
					}
					
					bool bFoliage = PkgName.Contains("Environment/Mesh/Flora");
					bFoliage |= (Comp->GetStaticMesh()->LODGroup == NAME_FOLIAGE);
					
					if(bFoliage)
					{
						Meshes.Add(Comp->GetStaticMesh());
					}
				}
			});
		}

		// 处理资产，删掉碰撞信息
		for(auto Mesh : Meshes)
		{
			auto Body = Mesh->GetBodySetup();
			if(!Body)
			{
				continue;
			}
			if(Mesh->AssetEditorTags.Contains(NAME_NOCOLLSION_LIUBO))
			{
				continue;
			}

			bool bDirty = false;
			if(Body->CollisionTraceFlag != CTF_UseSimpleAsComplex)
			{
				Body->CollisionTraceFlag = CTF_UseSimpleAsComplex;
				bDirty = true;
			}
			// todo. 待验证，是否会退化成直接使用模型，作为碰撞
			if(Body->AggGeom.GetElementCount() > 0)
			{						
				Body->RemoveSimpleCollision();
				bDirty = true;
			}			
			if(Body->DefaultInstance.GetCollisionProfileName() != NAME_NOCOLLSION)
			{
				Body->DefaultInstance.SetCollisionProfileName(NAME_NOCOLLSION);
				bDirty = true;
			}
			
			if(bDirty)
			{
				Mesh->AssetEditorTags.Add(NAME_NOCOLLSION_LIUBO);
				Mesh->MarkPackageDirty();
				UE_LOG(LogTemp, Log, TEXT("liubo, disable mesh asset collision: %s"), *Mesh->GetFullName());				
			}
		}

		}));

namespace c7phy
{
	static bool IsValidMesh(const UStaticMesh* StaticMesh)
	{
		if(!StaticMesh)
		{
			return false;
		}
		UPackage* Pkg = Cast<UPackage>(StaticMesh->GetOuter());
		if(!Pkg)
		{
			return false;
		}
		return true;
	}
	
	static bool IsEngineMesh(const UStaticMesh* StaticMesh)
	{
		if(!StaticMesh)
		{
			return false;
		}
		
		UPackage* Pkg = Cast<UPackage>(StaticMesh->GetOuter());
		if(!Pkg)
		{
			return false;
		}
					
		auto PkgName = Pkg->GetName(); 
		if(PkgName.Contains("/Engine/"))
		{
			return true;
		}
		
		return false;
	}
	static bool IsFoliageMesh(const UStaticMesh* StaticMesh)
	{
		if(!StaticMesh)
		{
			return false;
		}
		
		UPackage* Pkg = Cast<UPackage>(StaticMesh->GetOuter());
		if(!Pkg)
		{
			return false;
		}
		
		static FName NAME_FOLIAGE("Foliage");
		auto PkgName = Pkg->GetName();
		
		bool bFoliage = PkgName.Contains("Environment/Mesh/Flora");
		bFoliage |= (StaticMesh->LODGroup == NAME_FOLIAGE);

		return bFoliage;
	}
	static void RefreshCollisionChange1(UStaticMesh* StaticMesh)
	{
		if(!StaticMesh)
		{
			return;
		}
		
		StaticMesh->CreateNavCollision(/*bIsUpdate=*/true);

		for (FThreadSafeObjectIterator Iter(UStaticMeshComponent::StaticClass()); Iter; ++Iter)
		{
			UStaticMeshComponent* StaticMeshComponent = Cast<UStaticMeshComponent>(*Iter);
			if (StaticMeshComponent->GetStaticMesh() == StaticMesh)
			{
				// it needs to recreate IF it already has been created
				if (StaticMeshComponent->IsPhysicsStateCreated())
				{
					StaticMeshComponent->RecreatePhysicsState();
				}
			}
		}
	}
	static void MakeConvex(UStaticMesh* StaticMesh)
	{					
		uint32 InHullCount = 4;
		int32 InMaxHullVerts = 16;
		uint32 InHullPrecision = 100000;
						
		FStaticMeshLODResources& LODModel = StaticMesh->GetRenderData()->LODResources[0];
		int32 NumVerts = LODModel.VertexBuffers.StaticMeshVertexBuffer.GetNumVertices();
		TArray<FVector3f> Verts;
		Verts.SetNumUninitialized(NumVerts);
		for(int32 i=0; i<NumVerts; i++)
		{
			const FVector3f& Vert = LODModel.VertexBuffers.PositionVertexBuffer.VertexPosition(i);
			Verts[i] = Vert;
		}
						
		// Grab all indices
		TArray<uint32> AllIndices;
		LODModel.IndexBuffer.GetCopy(AllIndices);

		// Only copy indices that have collision enabled
		TArray<uint32> CollidingIndices;
		for(const FStaticMeshSection& Section : LODModel.Sections)
		{
			if(Section.bEnableCollision)
			{
				for (uint32 IndexIdx = Section.FirstIndex; IndexIdx < Section.FirstIndex + (Section.NumTriangles * 3); IndexIdx++)
				{
					CollidingIndices.Add(AllIndices[IndexIdx]);
				}
			}
		}
						
						
		UBodySetup* bs = StaticMesh->GetBodySetup();
		if(bs)
		{
			bs->RemoveSimpleCollision();
		}
		else
		{
			// Otherwise, create one here.
			StaticMesh->CreateBodySetup();
			bs = StaticMesh->GetBodySetup();
		}

		// Run actual util to do the work (if we have some valid input)
		if(Verts.Num() >= 3 && CollidingIndices.Num() >= 3)
		{
			auto DecomposeMeshToHullsAsync = CreateIDecomposeMeshToHullAsync();
			DecomposeMeshToHullsAsync->DecomposeMeshToHullsAsyncBegin(bs, MoveTemp(Verts), MoveTemp(CollidingIndices), InHullCount, InMaxHullVerts, InHullPrecision);
			while (DecomposeMeshToHullsAsync)
			{
				if (DecomposeMeshToHullsAsync->IsComplete())
				{
					DecomposeMeshToHullsAsync->Release();
					DecomposeMeshToHullsAsync = nullptr;
				}
							
				FPlatformProcess::Sleep(0.1f);
			}
			//DecomposeMeshToHulls(bs, Verts, CollidingIndices, InHullCount, InMaxHullVerts, InHullPrecision);
		}
		
		RefreshCollisionChange1(StaticMesh);
		StaticMesh->bCustomizedCollision = true;	//mark the static mesh for collision customization
	}
	
}

// 复杂碰撞转成简单碰撞
FAutoConsoleCommand OptC7OptPhyComplexToSimple(TEXT("c7.opt.phy.complex2simple"), TEXT("c7.opt.phy.complex2simple"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
		{
			TSet<ECollisionTraceFlag> Flags;
			if(Args.Num() > 0)
			{
				// 0;1;2;3
				TArray<FString> Arrs;
				Args[0].ParseIntoArray(Arrs, TEXT(";"));
				for(auto Arr : Arrs)
				{
					Flags.Add((ECollisionTraceFlag)FCString::Atoi(*Arr));				
				}
			}
			else
			{
				Flags.Add(CTF_UseSimpleAndComplex);
				Flags.Add(CTF_UseComplexAsSimple);			
			}
		
			auto World = GEditor->GetEditorWorldContext().World();
			TSet<UStaticMesh*> Meshes;
		
			for(FActorIterator It(World); It; ++It)
			{
				if(It->IsEditorOnly())
				{
					continue;
				}
				
				It->ForEachComponent<UStaticMeshComponent>(false, [&Meshes, Flags](UStaticMeshComponent* Comp)
				{
					if(Comp->IsEditorOnly())
					{
						return;
					}
					
					if(!c7phy::IsValidMesh(Comp->GetStaticMesh()))
					{
						return;
					}
					Meshes.Add(Comp->GetStaticMesh());
					
				});
			}

			// 处理模型
			for(auto Mesh : Meshes)
			{
				if(!c7phy::IsValidMesh(Mesh))
				{
					continue;
				}
				
				if(Mesh && Mesh->GetBodySetup())
				{ 
					UPackage* Pkg = Cast<UPackage>(Mesh->GetOuter());
					if(Pkg && Pkg->GetName().Contains("/Engine/"))
					{
						continue;
					}

					if(Pkg && !Pkg->GetName().StartsWith("/Game/"))
					{
						continue;
					}
						
					if(c7phy::IsFoliageMesh(Mesh))
					{
						continue;
					}
					
					auto StaticMesh = Mesh;	
					auto Body = Mesh->GetBodySetup();

					// 把不是simple的，全部改成simple
					if(Flags.Contains(Body->CollisionTraceFlag))
					{
						Body->CollisionTraceFlag = CTF_UseSimpleAsComplex;

						// 如果没有简单碰撞，那么自动生成
						if(Body->AggGeom.GetElementCount() == 0)
						{
							c7phy::MakeConvex(StaticMesh);
						}
							
						Body->MarkPackageDirty();
						UE_LOG(LogTemp, Log, TEXT("liubo, simple mesh: %s"), *Body->GetFullName());
					}
				}
			}
		}));

// 复杂碰撞转成简单碰撞-自动根据类型刷新
FAutoConsoleCommand OptC7OptPhyComplexToSimpleAuto(TEXT("c7.opt.phy.complex2simple.auto"), TEXT("c7.opt.phy.complex2simple.auto"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
		{
			TSet<ECollisionTraceFlag> Flags;
			int32 MaxTris = 2000;
			if(Args.Num() > 0)
			{
				// 0;1;2;3;2000
				TArray<FString> Arrs;
				Args[0].ParseIntoArray(Arrs, TEXT(";"));

				for (int32 i = 0; i < Arrs.Num() - 1; i++)
				{
					Flags.Add((ECollisionTraceFlag)FCString::Atoi(*Arrs[i]));
				}

				if (Arrs.Num() > 0)
				{
					MaxTris = FCString::Atoi(*Arrs[Arrs.Num() - 1]);
				}
			}
			else
			{
				Flags.Add(CTF_UseDefault);
				Flags.Add(CTF_UseSimpleAndComplex);
				Flags.Add(CTF_UseComplexAsSimple);			
			}
		
			auto World = GEditor->GetEditorWorldContext().World();
			TSet<UStaticMesh*> Meshes;
		
			for(FActorIterator It(World); It; ++It)
			{
				if(It->IsEditorOnly())
				{
					continue;
				}
				
				It->ForEachComponent<UStaticMeshComponent>(false, [&Meshes, Flags](UStaticMeshComponent* Comp)
				{
					if(Comp->IsEditorOnly())
					{
						return;
					}
					
					if(!c7phy::IsValidMesh(Comp->GetStaticMesh()))
					{
						return;
					}
					Meshes.Add(Comp->GetStaticMesh());
					
				});
			}

			// 处理模型
			for(auto Mesh : Meshes)
			{
				if(!c7phy::IsValidMesh(Mesh))
				{
					continue;
				}
				
				if(Mesh && Mesh->GetBodySetup())
				{ 
					UPackage* Pkg = Cast<UPackage>(Mesh->GetOuter());
					if(Pkg && Pkg->GetName().Contains("/Engine/"))
					{
						continue;
					}

					if(Pkg && !Pkg->GetName().StartsWith("/Game/"))
					{
						continue;
					}
						
					if(c7phy::IsFoliageMesh(Mesh))
					{
						continue;
					}
					
					auto StaticMesh = Mesh;	
					auto Body = Mesh->GetBodySetup();
					
					if(Body->CollisionTraceFlag == CTF_UseComplexAsSimple)
					{
						int32 NumTris = Mesh->GetNumTriangles(0);
						if(NumTris >= MaxTris)
						{
							if(Body->AggGeom.GetElementCount() == 0 )
							{
								Body->CollisionTraceFlag = CTF_UseSimpleAsComplex;
								c7phy::MakeConvex(StaticMesh);
								Body->MarkPackageDirty();
								UE_LOG(LogTemp, Log, TEXT("convert simple mesh: %s"), *Body->GetFullName());	
							}
							else
							{
								Body->CollisionTraceFlag = CTF_UseSimpleAsComplex;
								Body->MarkPackageDirty();
								UE_LOG(LogTemp, Log, TEXT("complexmodel use simple mesh: %s"), *Body->GetFullName());	
							}
						}
						else
						{
							UE_LOG(LogTemp, Log, TEXT("use originalcomplex mesh: %s"), *Body->GetFullName());
						}
					}
					else if(Body->CollisionTraceFlag == CTF_UseSimpleAndComplex||Body->CollisionTraceFlag == CTF_UseDefault)
					{
						if(Body->AggGeom.GetElementCount() == 0 )
						{
							UE_LOG(LogTemp, Log, TEXT("no collision: %s"), *Body->GetFullName());
						}
						else
						{
							Body->CollisionTraceFlag = CTF_UseSimpleAsComplex;
							Body->MarkPackageDirty();
							UE_LOG(LogTemp, Log, TEXT("use originalsimple mesh: %s"), *Body->GetFullName());	
						}
					
						UE_LOG(LogTemp, Log, TEXT("default use simpleAndComplex mesh: %s"), *Body->GetFullName());
					}
					else
					{
						UE_LOG(LogTemp, Log, TEXT("default original use simple mesh: %s"), *Body->GetFullName());
					}
				}
			}
		}));

// 分割地图贴图到uasset中
FAutoConsoleCommand OptC7EditorSplitLandscapeTexture(TEXT("c7.editor.landscape.split_texture"), TEXT("c7.editor.landscape.split_texture"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		TArray<ALandscape*> Objs;
		auto Sel = GEditor->GetSelectedActors();
		Sel->GetSelectedObjects(Objs);
		for(auto Obj : Objs)
		{
			if(!Obj || !Obj->GetLevel() || !Obj->GetLevel()->GetPackage())
			{
				continue;
			}
			
			bool bSaveTexInMap = false;
			FString LevelPackageName = Obj->GetLevel()->GetPackage()->GetPathName();
			ULevel* Level = Obj->GetTypedOuter<ULevel>();
			FString LevelName = FPaths::GetBaseFilename(Level ? Level->GetPathName() : LevelPackageName);
			if(LevelPackageName.StartsWith("/Game/"))
			{
		
			}
			else
			{
				LevelPackageName = FString("/Game") + LevelPackageName;
			}
			if(!LevelPackageName.StartsWith("/Game/"))
			{
				bSaveTexInMap = true;
			}
			else
			{
				LevelPackageName = FPaths::GetPath(LevelPackageName);
				LevelPackageName = LevelPackageName / FString("BuiltData") / LevelName;
			}
			if(bSaveTexInMap)
			{
				continue;
			}

			TMap<UTexture2D*, UTexture2D*> OldNewMap;
			Obj->ForEachComponent<ULandscapeComponent>(false, [LevelPackageName, &OldNewMap](ULandscapeComponent* Comp)
			{
				{
					auto Tex = Comp->GetHeightmap();
					if(Tex)
					{
						if(!Tex->IsAsset())
						{
							if(OldNewMap.Contains(Tex))
							{
								Comp->SetHeightmap(OldNewMap[Tex]);
								Comp->MarkPackageDirty();
							}
							else
							{
								FString TexName = Tex->GetName();
								FString PackageName = LevelPackageName / TexName;
								IKgLandscapeEdToolsModule* LandscapeEdToolsModule = kg_module::IKgModuleMgr::Get()->GetModule<IKgLandscapeEdToolsModule>("KgLandscapeEdTools");
								UTexture2D* NewTexture = nullptr;
								if(LandscapeEdToolsModule)
								{			
									NewTexture = LandscapeEdToolsModule->TSaveAssetAs<UTexture2D>(Tex, PackageName);
								}
								if(NewTexture)
								{
									OldNewMap.Add(Tex, NewTexture);
									Comp->SetHeightmap(NewTexture);
									Comp->MarkPackageDirty();
								}								
							}							
						}						
					}
				}
				{
					auto ArrTex = Comp->GetWeightmapTextures();
					TArray<UTexture2D*> NewArr;
					for(auto Tex : ArrTex)
					{
						if(Tex)
						{
							if(!Tex->IsAsset())
							{
								if(OldNewMap.Contains(Tex))
								{
									ArrTex.Add(OldNewMap[Tex]);
								}
								else
								{
									FString TexName = Tex->GetName();
									FString PackageName = LevelPackageName / TexName;
									IKgLandscapeEdToolsModule* LandscapeEdToolsModule = kg_module::IKgModuleMgr::Get()->GetModule<IKgLandscapeEdToolsModule>("KgLandscapeEdTools");
									UTexture2D* NewTexture = nullptr;
									if(LandscapeEdToolsModule)
									{			
										NewTexture = LandscapeEdToolsModule->TSaveAssetAs<UTexture2D>(Tex, PackageName);
									}
									if(NewTexture)
									{
										OldNewMap.Add(Tex, NewTexture);
										ArrTex.Add(NewTexture);										
									}								
								}							
							}						
						}	
					}
					Comp->SetWeightmapTextures(NewArr);
					Comp->MarkPackageDirty();
				}				
			});
		}
	}));

// 特殊处理一下ProxyMesh
FAutoConsoleCommand OptC7OptPhyProxyMesh(TEXT("c7.opt.phy.proxymesh.simple"), TEXT("c7.opt.phy.proxymesh.simple"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		bool bAll = false;
		if(Args.Num() > 0)
		{
			bAll = FCString::Atoi(*Args[0]) > 0;
		}
		
		int Mode = 0; // 0，无碰撞；1，简单；2，复杂
		if(Args.Num() > 1)
		{
			Mode = FCString::Atoi(*Args[1]);
		}

		// 模型路径：
		TSharedPtr<c7opt::FRegexHelper> RegHelper = MakeShared<c7opt::FRegexHelper>();
		
		if(Args.Num() >  2)
		{
			RegHelper->AddFromCommandLine(Args[2]);
		}
		RegHelper->AddDefault("/Game/.*/ProxyMesh/");
				
		
		auto World = GEditor->GetEditorWorldContext().World();
		for(FActorIterator It(World); It; ++It)
		{
			if(It->IsEditorOnly())
			{
				continue;
			}
			
			It->ForEachComponent<UStaticMeshComponent>(false, [bAll, Mode, RegHelper](UStaticMeshComponent* Comp)
			{
				if(Comp->IsEditorOnly())
				{
					return;
				}
				
				if(Comp->GetStaticMesh() && Comp->GetStaticMesh()->GetBodySetup())
				{
					UPackage* Pkg = Cast<UPackage>(Comp->GetStaticMesh()->GetOuter());
					if(Pkg && Pkg->GetName().Contains("/Engine/"))
					{
						return;
					}

					// 过滤文件！
					if(!RegHelper->IsMatch(Pkg->GetPathName()))
					{
						return;
					}
					
					auto Body = Comp->GetStaticMesh()->GetBodySetup();
					if(bAll || Body->AggGeom.GetElementCount() > 0)
					{
						if(Mode == 1)
						{
							Body->CollisionTraceFlag = CTF_UseSimpleAsComplex;
							Body->DefaultInstance.SetCollisionProfileName(TEXT("Default"));		
							
						}
						else if(Mode == 2)
						{
							Body->CollisionTraceFlag = CTF_UseComplexAsSimple;
							Body->DefaultInstance.SetCollisionProfileName(TEXT("Default"));							
						}
						else
						{
							Body->CollisionTraceFlag = CTF_UseDefault;
							Body->DefaultInstance.SetCollisionProfileName(TEXT("NoCollision"));							
						}
						
						Body->MarkPackageDirty();
						Comp->GetStaticMesh()->MarkPackageDirty();						
						// Comp->GetOwner()->MarkPackageDirty();
						UE_LOG(LogTemp, Log, TEXT("liubo, simple mesh: %s"), *Body->GetFullName());
					}
				}
			});
		}
	}));

// 清理小的物件：KGHLODAutoGroupBuilderSettings



// 测试string
FAutoConsoleCommand OptC7ShadowProxyGen1(TEXT("c7.shadow.proxy.gen1"), TEXT("c7.shadow.proxy.gen1"),
	FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		auto World = GEditor->GetEditorWorldContext().World();
		FString MatKeyworld = Args[0];
		FName SpecName("ConvertToShadowProxy");
		FName NoCollision("NoCollision");
		FName BlockAll("BlockAll");

		TArray<AActor*> PendingActors;
		for(FActorIterator It(World); It; ++It)
		{
			bool bFind = false;
			It->ForEachComponent<UStaticMeshComponent>(false, [SpecName, NoCollision, &bFind](UStaticMeshComponent* Comp)
			{
				if(Comp->ComponentEditorTags.Contains(SpecName))
				{
					if(Comp->GetCollisionProfileName() == NoCollision)
					{
						Comp->SetCollisionProfileName(NoCollision);
						bFind = true;						
					}
				}
			});
			
			if(bFind)
			{
				It->MarkPackageDirty();
			}
			if(It->GetClass()->GetName().Contains("ShadowProxyMeshActor"))
			{
				It->ForEachComponent<UStaticMeshComponent>(false, [BlockAll, &bFind](UStaticMeshComponent* Comp)
				{
					if(!Comp->GetStaticMesh())
					{
						return;
					}
					
					auto Body = Comp->GetStaticMesh()->GetBodySetup();
					if(Body)
					{
						Body->CollisionTraceFlag = CTF_UseComplexAsSimple;
						Body->DefaultInstance.SetCollisionProfileName(BlockAll);						
						Body->MarkPackageDirty();
						Comp->GetStaticMesh()->MarkPackageDirty();						
						// Comp->GetOwner()->MarkPackageDirty();
						UE_LOG(LogTemp, Log, TEXT("liubo, Complex mesh: %s"), *Body->GetFullName());
					}
				});				
			}
		}
	

	}));
