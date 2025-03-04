#include "Opt/OptCmdMgr.h"

#include "JsonObjectConverter.h"
#include "LandscapeComponent.h"
#include "VirtualShadowMapDefinitions.h"
#include "AssetRegistry/AssetRegistryModule.h"
#include "Blueprint/WidgetTree.h"
#include "Chaos/TriangleMeshImplicitObject.h"
#include "Components/CanvasPanel.h"
#include "Components/InstancedStaticMeshComponent.h"
#include "Components/SplineComponent.h"
#include "Elements/Framework/TypedElementRegistry.h"
#include "GameFramework/GameUserSettings.h"
#include "Materials/MaterialInstance.h"
#include "Engine/LevelStreaming.h"
#include "Kismet/GameplayStatics.h"
#include "ProfilingDebugging/HealthSnapshot.h"
#include "GameFramework/SaveGame.h"
#include "PhysicsEngine/BodySetup.h"
#include "WorldPartition/HLOD/HLODActor.h"

namespace c7_phys
{
	class FC7DumpPhysInfo
	{
	public:
		FString CompName;
		FString ClassName;
		FString AssetName;
		int MemSize = 0;
		int BodyCount = 0;
		int ShapeCount = 0;
	};

	static int GetPhysMemory(UBodySetup* BodySetup)
	{
		int Bytes = 0;
		if (!BodySetup)
		{
			return Bytes;
		}

		for (const auto& Geo : BodySetup->AggGeom.ConvexElems)
		{
			if (!Geo.GetChaosConvexMesh())
			{
				continue;
			}

			TArray<uint8> Data;
			FMemoryWriter MemAr(Data);
			Chaos::FChaosArchive ChaosAr(MemAr);
			Geo.GetChaosConvexMesh()->Serialize(ChaosAr);
			Bytes += Data.Num();
		}
		for (const auto& Geo : BodySetup->TriMeshGeometries)
		{
			if (!Geo)
			{
				continue;
			}

			TArray<uint8> Data;
			FMemoryWriter MemAr(Data);
			Chaos::FChaosArchive ChaosAr(MemAr);
			Geo->Serialize(ChaosAr);
			Bytes += Data.Num();
		}
		return Bytes;
	}

	// dump 物理模块的内存
	FAutoConsoleCommand OptC7DumpPhys(TEXT("c7.mem.dump.phys"), TEXT("c7.mem.dump.phys"),
	                                  FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	                                  {
		                                  auto InWorld = FOptHelper::GetGameWorld();
		                                  if (!InWorld)
		                                  {
			                                  return;
		                                  }

		                                  UE_LOG(LogTemp, Log,
		                                         TEXT("liubo, phys, DumpFormat, Comp=ActorPath, ClassName, AssetPath, MemSize, BodyCount, ShapeCount"
		                                         ));

		                                  TSet<UBodySetup*> BodySetups;
		                                  TSet<FPhysicsActorHandle> Processed;
		                                  TArray<TSharedPtr<FC7DumpPhysInfo>> FinalPhysInfos;
		                                  int FinalMemBytes = 0;

		                                  // primitive的
		                                  {
			                                  TArray<TSharedPtr<FC7DumpPhysInfo>> PhysInfos;
			                                  int32 BodiesTotal = 0;
			                                  int32 ShapesTotal = 0;
			                                  int BytesTotal = 0;
			                                  for (TObjectIterator<UPrimitiveComponent> It; It; ++It)
			                                  {
				                                  const UWorld* ComponentWorld = It->GetWorld();
				                                  if (ComponentWorld != InWorld || !ComponentWorld)
				                                  {
					                                  continue;
				                                  }

				                                  if (It->ShouldCreatePhysicsState())
				                                  {
					                                  const FString ComponentName = It->GetPathName(
						                                  It->GetOwner() ? It->GetOwner()->GetOuter() : nullptr);

					                                  TArray<FBodyInstance*> Bodies;
					                                  Bodies.Add(&It->BodyInstance);

					                                  if (It->IsA<USkeletalMeshComponent>())
					                                  {
						                                  USkeletalMeshComponent* Skel = Cast<USkeletalMeshComponent>(*It);
						                                  Bodies.Append(Skel->Bodies);
					                                  }
					                                  else if (It->IsA<UInstancedStaticMeshComponent>())
					                                  {
						                                  auto ISMComponent = Cast<UInstancedStaticMeshComponent>(*It);
						                                  Bodies.Append(ISMComponent->InstanceBodies);
					                                  }

					                                  if (Bodies.Num() == 0)
					                                  {
						                                  continue;
					                                  }

					                                  int32 NumValidInstanceBodies = 0;
					                                  int32 NumInstanceShapes = 0;
					                                  int32 Bytes = 0;
					                                  TArray<FPhysicsShapeHandle> Shapes;
					                                  for (const FBodyInstance* Body : Bodies)
					                                  {
						                                  if (!Body)
						                                  {
							                                  continue;
						                                  }

						                                  if (Processed.Contains(Body->ActorHandle))
						                                  {
							                                  continue;
						                                  }
						                                  Processed.Add(Body->ActorHandle);
						                                  BodySetups.Add(Body->GetBodySetup());

						                                  ++NumValidInstanceBodies;

						                                  Shapes.Reset();
						                                  FPhysicsCommand::ExecuteRead(Body->ActorHandle,
						                                                               [&Body, &Shapes, &NumInstanceShapes, &Bytes](
						                                                               const FPhysicsActorHandle& Actor)
						                                                               {
							                                                               Shapes.Reset();
							                                                               if (FPhysicsInterface::IsDisabled(Actor))
							                                                               {
								                                                               return;
							                                                               }
							                                                               Body->GetAllShapes_AssumesLocked(Shapes);
							                                                               for (auto& Shape : Shapes)
							                                                               {
								                                                               if (!Shape.IsValid())
								                                                               {
									                                                               continue;
								                                                               }
								                                                               TArray<uint8> Data;
								                                                               FMemoryWriter MemAr(Data);
								                                                               Chaos::FChaosArchive ChaosAr(MemAr);
								                                                               auto One = Shape.Shape->GetGeometry();
							                                                               	   One->Serialize(ChaosAr);
								                                                               // const_cast<Chaos::FImplicitObject*>(One.Get())->
									                                                              //  Serialize(ChaosAr);
								                                                               Bytes += Data.Num();
							                                                               }

							                                                               NumInstanceShapes += Shapes.Num();
						                                                               });

						                                  // 如果没有读取到，那么尝试
						                                  if (false && Shapes.Num() == 0)
						                                  {
							                                  Bytes += GetPhysMemory(Body->GetBodySetup());
						                                  }
					                                  }

					                                  UObject* Mesh = nullptr;
					                                  if (It->IsA<UStaticMeshComponent>())
					                                  {
						                                  Mesh = Cast<UStaticMeshComponent>(*It)->GetStaticMesh();
					                                  }
					                                  else if (It->IsA<USkeletalMeshComponent>())
					                                  {
						                                  Mesh = Cast<USkeletalMeshComponent>(*It)->GetSkeletalMeshAsset();
					                                  }

					                                  auto One = MakeShared<FC7DumpPhysInfo>();
					                                  One->CompName = *ComponentName;
					                                  One->ClassName = *It->GetClass()->GetName();
					                                  One->AssetName = Mesh ? *Mesh->GetPathName() : TEXT("None");
					                                  One->MemSize = Bytes;
					                                  One->BodyCount = NumValidInstanceBodies;
					                                  One->ShapeCount = NumInstanceShapes;
					                                  PhysInfos.Add(One);

					                                  BodiesTotal += NumValidInstanceBodies;
					                                  ShapesTotal += NumInstanceShapes;
					                                  BytesTotal += Bytes;
				                                  }
			                                  }
			                                  FinalMemBytes += BytesTotal;
			                                  FinalPhysInfos.Append(PhysInfos);

			                                  PhysInfos.Sort([](const TSharedPtr<FC7DumpPhysInfo>& A, const TSharedPtr<FC7DumpPhysInfo>& B)
			                                  {
				                                  return A->MemSize > B->MemSize;
			                                  });

			                                  for (auto One : PhysInfos)
			                                  {
				                                  UE_LOG(LogTemp, Log, TEXT("liubo, phys, Prim, Comp=%s, %s, %s, %d, %d, %d"),
				                                         *One->CompName,
				                                         *One->ClassName,
				                                         *One->AssetName,
				                                         One->MemSize,
				                                         One->BodyCount,
				                                         One->ShapeCount);
			                                  }

			                                  UE_LOG(LogTemp, Log, TEXT("liubo, phys, Prim, BodiesTotal=%d, ShapesTotal=%d, BytesTotal=%d"),
			                                         BodiesTotal, ShapesTotal, BytesTotal);
		                                  }

		                                  // 其他的
		                                  {
			                                  TArray<TSharedPtr<FC7DumpPhysInfo>> PhysInfos;
			                                  int32 BodiesTotal = 0;
			                                  int32 ShapesTotal = 0;
			                                  int BytesTotal = 0;
			                                  // dump ubodysetup的
			                                  for (TObjectIterator<UBodySetup> It; It; ++It)
			                                  {
				                                  // 处理过了
				                                  if (BodySetups.Contains(*It))
				                                  {
					                                  continue;
				                                  }
				                                  UBodySetup* Body = *It;
				                                  int32 Bytes = GetPhysMemory(Body);

				                                  if (Bytes <= 0)
				                                  {
					                                  continue;
				                                  }

				                                  auto One = MakeShared<FC7DumpPhysInfo>();
				                                  One->CompName = Body->GetFullName();
				                                  One->ClassName = TEXT("BodySetup");
				                                  One->AssetName = Body->GetPathName();
				                                  One->MemSize = Bytes;
				                                  One->BodyCount = 0;
				                                  One->ShapeCount = 0;
				                                  PhysInfos.Add(One);

				                                  BytesTotal += Bytes;
			                                  }
			                                  FinalMemBytes += BytesTotal;
			                                  FinalPhysInfos.Append(PhysInfos);

			                                  PhysInfos.Sort([](const TSharedPtr<FC7DumpPhysInfo>& A, const TSharedPtr<FC7DumpPhysInfo>& B)
			                                  {
				                                  return A->MemSize > B->MemSize;
			                                  });

			                                  for (auto One : PhysInfos)
			                                  {
				                                  UE_LOG(LogTemp, Log, TEXT("liubo, phys, Body=%s, %s, %s, %d, %d, %d"),
				                                         *One->CompName,
				                                         *One->ClassName,
				                                         *One->AssetName,
				                                         One->MemSize,
				                                         One->BodyCount,
				                                         One->ShapeCount);
			                                  }
			                                  UE_LOG(LogTemp, Log, TEXT("liubo, phys, Body, BytesTotal=%d"), BytesTotal);
		                                  }

		                                  // 分类计算
		                                  TMap<FString, int> CategorySize;
		                                  for (auto It : FinalPhysInfos)
		                                  {
			                                  auto& V = CategorySize.FindOrAdd(It->ClassName, 0);
			                                  V += It->MemSize;
		                                  }
	                                  	
		                                  for (auto It : CategorySize)
		                                  {
			                                  UE_LOG(LogTemp, Log, TEXT("liubo, phys, Category=%s, Memory=%d"), *It.Key, It.Value);
		                                  }

		                                  UE_LOG(LogTemp, Log, TEXT("liubo, phys, Final, TotalMemory=%d"), FinalMemBytes);
	                                  }));


	// 通用的
	FAutoConsoleCommand OptC7OptPhyEnable(TEXT("c7.opt.phy.enable"), TEXT("c7.opt.phy.enable"),
	                                      FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	                                      {
		                                      bool bEnable = true;
		                                      int PrimType = 0; // 0 all, 1 mesh, 2 skeletal mesh
		                                      if (Args.Num() > 0)
		                                      {
			                                      bEnable = FCString::Atoi(*Args[0]) > 0;
		                                      }
		                                      if (Args.Num() > 1)
		                                      {
			                                      PrimType = FCString::Atoi(*Args[1]);
		                                      }

		                                      auto World = FOptHelper::GetGameWorld();
		                                      for (FActorIterator It(World); It; ++It)
		                                      {
			                                      TArray<UPrimitiveComponent*> CompList;
			                                      It->GetComponents(CompList);

			                                      CompList.RemoveAll([PrimType](UPrimitiveComponent* Prim)
			                                      {
				                                      if (PrimType == 1)
				                                      {
					                                      return Prim->IsA<UStaticMeshComponent>();
				                                      }
				                                      else if (PrimType == 2)
				                                      {
					                                      return Prim->IsA<USkeletalMeshComponent>();
				                                      }
				                                      return false;
			                                      });

			                                      for (auto Comp : CompList)
			                                      {
				                                      // 如果是引擎模型，跳过
				                                      if (Comp->IsA<UStaticMeshComponent>())
				                                      {
					                                      auto MeshComp = Cast<UStaticMeshComponent>(Comp);
					                                      if (MeshComp->GetStaticMesh() && MeshComp->GetStaticMesh()->GetOuter()
						                                      && MeshComp->GetStaticMesh()->GetOuter()->GetPackage()
						                                      && MeshComp->GetStaticMesh()->GetOuter()->GetPackage()->GetName().Contains("/Engine/"))
					                                      {
						                                      continue;
					                                      }
				                                      }
				                                      Comp->SetCollisionEnabled(
					                                      bEnable ? ECollisionEnabled::QueryAndPhysics : ECollisionEnabled::NoCollision);
			                                      }
		                                      }
	                                      }));

	FAutoConsoleCommand OptC7OptPhyDump(TEXT("c7.opt.phy.dump"), TEXT("c7.opt.phy.dump"),
	                                    FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	                                    {
		                                    auto World = FOptHelper::GetGameWorld();
		                                    TArray<UPrimitiveComponent*> PhysCompList;
		                                    for (FActorIterator It(World); It; ++It)
		                                    {
			                                    TArray<UPrimitiveComponent*> CompList;
			                                    It->GetComponents(CompList);

			                                    for (auto Comp : CompList)
			                                    {
				                                    if (Comp->IsPhysicsStateCreated())
				                                    {
					                                    PhysCompList.Add(Comp);
				                                    }
				                                    Comp->GetAllPhysicsObjects();
			                                    }
		                                    }
		                                    int Cnt = 0;
		                                    int64 AllocSize = 0;
		                                    TSet<UBodySetup*> BodySets;
		                                    for (auto Comp : PhysCompList)
		                                    {
			                                    auto Body = Comp->GetBodySetup();
			                                    if (Body)
			                                    {
				                                    AllocSize += Body->AggGeom.GetAllocatedSize();
				                                    BodySets.Add(Body);
				                                    UE_LOG(LogTemp, Log, TEXT("liubo, Actor BodySetup=%s"), *Body->GetFullName());
			                                    }
			                                    Cnt += Comp->GetAllPhysicsObjects().Num();
		                                    }
		                                    UE_LOG(LogTemp, Log, TEXT("liubo, PhysCount=%d, BoydCount=%d, AllocSize=%lld"), PhysCompList.Num(), Cnt,
		                                           AllocSize);

		                                    TArray<UBodySetup*> OtherBodyList;
		                                    for (FThreadSafeObjectIterator It; It; ++It)
		                                    {
			                                    if (It->IsA<UBodySetup>())
			                                    {
				                                    auto Body = Cast<UBodySetup>(*It);
				                                    if (!BodySets.Contains(Body))
				                                    {
					                                    OtherBodyList.Add(Body);
				                                    }
			                                    }
		                                    }

		                                    AllocSize = 0;
		                                    TMap<ECollisionTraceFlag, int> CollisionMap;
		                                    for (auto Body : OtherBodyList)
		                                    {
			                                    UE_LOG(LogTemp, Log, TEXT("liubo, Other BodySetup=%s"), *Body->GetFullName());
			                                    AllocSize += Body->AggGeom.GetAllocatedSize();

			                                    if (!CollisionMap.Find(Body->CollisionTraceFlag))
			                                    {
				                                    CollisionMap.Add(Body->CollisionTraceFlag, 0);
			                                    }
			                                    else
			                                    {
				                                    CollisionMap[Body->CollisionTraceFlag] = CollisionMap[Body->CollisionTraceFlag] + 1;
			                                    }
		                                    }
		                                    UE_LOG(LogTemp, Log, TEXT("liubo, Other PhysCount=%d, AllocSize=%lld"), OtherBodyList.Num(), AllocSize);
		                                    for (auto Kv : CollisionMap)
		                                    {
			                                    UE_LOG(LogTemp, Log, TEXT("liubo, Other Body, Flag=%d, Count=%d"), Kv.Key, Kv.Value);
		                                    }
	                                    }));


	FAutoConsoleCommand OptC7OptPhyRemove(TEXT("c7.opt.phy.remove"), TEXT("c7.opt.phy.remove"),
	                                      FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	                                      {
		                                      int Mode = 0;
		                                      if (Args.Num() == 1)
		                                      {
			                                      Mode = FCString::Atoi(*Args[0]);
		                                      }
		                                      auto World = FOptHelper::GetGameWorld();
		                                      TArray<UPrimitiveComponent*> PhysCompList;
		                                      for (FActorIterator It(World); It; ++It)
		                                      {
			                                      TArray<UPrimitiveComponent*> CompList;
			                                      It->GetComponents(CompList);

			                                      for (auto Comp : CompList)
			                                      {
				                                      if (Comp->IsPhysicsStateCreated())
				                                      {
					                                      PhysCompList.Add(Comp);
				                                      }
				                                      Comp->GetAllPhysicsObjects();
			                                      }
		                                      }
		                                      TSet<UBodySetup*> BodySets;
		                                      for (auto Comp : PhysCompList)
		                                      {
			                                      auto Body = Comp->GetBodySetup();
			                                      if (Body)
			                                      {
				                                      BodySets.Add(Body);
			                                      }
		                                      }

		                                      TArray<UBodySetup*> OtherBodyList;
		                                      for (FThreadSafeObjectIterator It; It; ++It)
		                                      {
			                                      if (It->IsA<UBodySetup>())
			                                      {
				                                      auto Body = Cast<UBodySetup>(*It);
				                                      if (!BodySets.Contains(Body))
				                                      {
					                                      OtherBodyList.Add(Body);
				                                      }
			                                      }
		                                      }

		                                      for (auto Body : BodySets)
		                                      {
			                                      if (Body && Body->GetOuter() && Body->GetOuter()->GetPackage()
				                                      && Body->GetOuter()->GetPackage()->GetName().Contains("/Engine/"))
			                                      {
				                                      continue;
			                                      }

			                                      Body->ClearPhysicsMeshes();
			                                      Body->RemoveSimpleCollision();
		                                      }

		                                      // 原始的，也给删掉
		                                      if (Mode != 1)
		                                      {
			                                      for (auto Body : OtherBodyList)
			                                      {
				                                      if (Body && Body->GetOuter() && Body->GetOuter()->GetPackage()
					                                      && Body->GetOuter()->GetPackage()->GetName().Contains("/Engine/"))
				                                      {
					                                      continue;
				                                      }

				                                      Body->ClearPhysicsMeshes();
				                                      Body->RemoveSimpleCollision();
			                                      }
		                                      }
	                                      }));
}
