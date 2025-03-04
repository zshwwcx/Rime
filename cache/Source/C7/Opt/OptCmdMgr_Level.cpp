#include "Opt/OptCmdMgr.h"

#include "JsonObjectConverter.h"
#include "KgEngineUtils.h"
#include "LandscapeComponent.h"
#include "NiagaraComponent.h"
#include "NiagaraSystem.h"
#include "OptFunctionLibrary.h"
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
#include "Engine/LevelStreamingDynamic.h"
#include "Engine/TextureCube.h"
#include "Engine/TextureRenderTarget2D.h"
#include "Engine/VolumeTexture.h"
#include "Kismet/GameplayStatics.h"
#include "ProfilingDebugging/HealthSnapshot.h"
#include "GameFramework/SaveGame.h"
#include "Particles/ParticleSystem.h"
#include "PhysicsEngine/BodySetup.h"
#include "Rendering/SkeletalMeshRenderData.h"
#include "WorldPartition/WorldPartitionRuntimeLevelStreamingCell.h"
#include "WorldPartition/HLOD/HLODActor.h"
#include "WorldPartition/WorldPartitionLevelStreamingDynamic.h"

namespace c7_mem
{
	// FArchiveFindAllRefs
	class FKGArchiveFindDirectRefs : public FArchiveUObject
	{
	public:
		/**
		 * Constructor
		 *
		 * @param	Src		the object to serialize which may contain a references
		 */
		FKGArchiveFindDirectRefs(UObject* Src)
		{
			// use the optimized RefLink to skip over properties which don't contain object references
			ArIsObjectReferenceCollector = true;

			ArIgnoreArchetypeRef = false;
			ArIgnoreOuterRef = true;
			ArIgnoreClassRef = false;

			Src->Serialize(*this);
		}

		virtual FString GetArchiveName() const override { return TEXT("FKGArchiveFindDirectRefs"); }

		/** List of all direct references from the Object passed to the constructor **/
		TArray<TWeakObjectPtr<UObject>> References;

	private:
		/** Serialize a reference **/
		FArchive& operator<<(class UObject*& Obj)
		{
			if (Obj)
			{
				References.AddUnique(Obj);
			}
			return *this;
		}
	};

	class FFindAssetsHelper
	{
	public:
		FFindAssetsHelper()
		{
		}

		void FindInActor(AActor* Actor)
		{
			if (!Actor)
			{
				return;
			}

			if (IsProcessed(Actor))
			{
				return;
			}
			Processed.Add(Actor);
			RootActor = Actor;
			
			Push(Actor);
			TArray<UPrimitiveComponent*> Prims;
			Actor->GetComponents(Prims);
			for (auto It : Prims)
			{
				Find(It);
			}
			Pop(Actor);
			check(TopStack.Num() == 0);
		}
		
		void FindInComponent(UActorComponent* Comp)
		{
			if (!Comp)
			{
				return;
			}

			if (IsProcessed(Comp))
			{
				return;
			}
			Processed.Add(Comp);
			RootActor = Comp;

			Find(Comp);
			check(TopStack.Num() == 0);
		}

		void Find(UObject* Prim)
		{
			if (!Prim)
			{
				return;
			}
			if (IsProcessed(Prim))
			{
				return;
			}
			Processed.Add(Prim);

			Push(Prim);
			ON_SCOPE_EXIT
			{			
				Pop(Prim);
			};
			
			FKGArchiveFindDirectRefs Archive(Prim);
			for (auto Element : Archive.References)
			{
				if (!Element.IsValid())
				{
					continue;
				}

				if (Element->IsA<UTexture>())
				{
					PushAssets(Element.Get());
					Assets.Add(Element);
				}
				else if (Element->IsA<UBodySetup>())
				{
					PushAssets(Element.Get());
					Assets.Add(Element);
				}
				else if (Element->IsA<UMaterialInterface>())
				{
					PushAssets(Element.Get());
					Assets.Add(Element);
					Find(Element.Get());
				}
				else if (Element->IsA<UStaticMesh>())
				{
					PushAssets(Element.Get());
					Assets.Add(Element);
					Find(Element.Get());
				}
				else if (Element->IsA<USkinnedAsset>())
				{
					PushAssets(Element.Get());
					Assets.Add(Element);
					Find(Element.Get());
				}
				else
				{
					if (Element->IsA<UFXSystemAsset>())
					{
						Find(Element.Get());
					}
					else if (Element->IsA<UActorComponent>())
					{
						// 相同的outer，就嵌套！
						if (RootActor.IsValid() && IsSameOuter(Element.Get(), RootActor.Get()))
						{
							Find(Element.Get());
						}
					}
					else if (IsSameOuter(Element.Get(), Prim))
					{
						// outer能够一样，就嵌套找！
						Find(Element.Get());
					}
					else
					{
						volatile int xxx = 0;
						xxx++;
						// 不知道的UObject
					}
				}
			}
		}

		bool IsProcessed(UObject* Obj) const
		{
			return OtherIgnore.Contains(Obj) || Processed.Contains(Obj);
		}

		static bool IsSameOuter(UObject* Obj, UObject* Root)
		{
			if (!Obj || !Root)
			{
				return false;
			}

			while (Obj && Obj != Root)
			{
				Obj = Obj->GetOuter();
			}
			return Obj == Root;
		}

		void PushAssets(UObject* Obj)
		{
			if(!Obj)
			{
				return;
			}
			
			check(TopStack.Num() > 0);
			TopStack.Top()->Assets.Push(Obj);
		}
		void Push(UObject* Obj)
		{
			auto One = MakeShared<FNode>();
			One->Refer = Obj;
			
			if(TopStack.Num() == 0)
			{
				// 只有一个跟节点！
				check(!TreeRoot.IsValid());
				
				TreeRoot = One;
				TopStack.Push(One);
			}
			else
			{
				// 挂到上一个节点的底下
				TopStack.Last()->Referred.Push(One);

				// 指针指向此节点！
				TopStack.Push(One);
			}
		}
		void Pop(UObject* Obj)
		{
			auto One = TopStack.Pop();
			check(One->Refer == Obj);
		}

		struct FNode
		{
			// 引用者
			TWeakObjectPtr<UObject> Refer = nullptr;
			TArray<TWeakObjectPtr<UObject>> Assets;

			// 被引用的
			TArray<TSharedPtr<FNode>> Referred;
		};

		TSharedPtr<FNode> TreeRoot;
		TArray<TSharedPtr<FNode>> TopStack;
		
		TArray<TWeakObjectPtr<UObject>> Assets;
		TSet<TWeakObjectPtr<UObject>> OtherIgnore;
		TSet<TWeakObjectPtr<UObject>> Processed;
		TWeakObjectPtr<UObject> RootActor = nullptr;
	};

	class FLevelAssetDumperUtils
	{
	public:
		template <class T>
		static TArray<TWeakObjectPtr<T>> ToArray(const TArray<T*>& Objs)
		{
			TArray<TWeakObjectPtr<T>> Ret;
			for (auto It : Objs)
			{
				Ret.Add(It);
			}
			return Ret;
		}

		static FString ShortLevelPath(const FString& LevelPathName)
		{
			int Idx = -1;
			if (LevelPathName.FindChar('.', Idx))
			{
				return LevelPathName.Mid(0, Idx);
			}

			return LevelPathName;
		}

		static SIZE_T AssetGetMemorySize(UObject* Asset)
		{
			if (!Asset)
			{
				return 0;
			}

			if (Asset->IsA<UTexture>())
			{
				auto Tex = Cast<UTexture>(Asset);
				return Tex->CalcTextureMemorySizeEnum(TMC_ResidentMips);
			}

			return Asset->GetResourceSizeBytes(EResourceSizeMode::Exclusive);
		}
	};


	struct FAssetMetaInfo
	{
	public:
		enum class EMetaType
		{
			None,
			Texture,
			Mesh,
		};
		static const EMetaType ClassType = EMetaType::None;

	public:
		EMetaType MetaType = EMetaType::None;

	public:
		template <class T>
		T* CastTo()
		{
			if (MetaType == T::ClassType)
			{
				return (T*)this;
			}
			return nullptr;
		}

		static bool IsTextureMeta(FAssetMetaInfo* Ptr)
		{
			if (!Ptr)
			{
				return false;
			}
			return Ptr->MetaType == FAssetMetaInfo::EMetaType::Texture;
		}

		static bool IsMeshMeta(FAssetMetaInfo* Ptr)
		{
			if (!Ptr)
			{
				return false;
			}
			return Ptr->MetaType == FAssetMetaInfo::EMetaType::Mesh;
		}
	};

	struct FTextureMetaInfo : FAssetMetaInfo
	{
		static const EMetaType ClassType = EMetaType::Texture;

		int32 CurSizeX = 0;
		int32 CurSizeY = 0;
		int32 CurrentSize = 0;

		int32 MaxAllowedSizeX = 0;
		int32 MaxAllowedSizeY = 0;
		int32 MaxAllowedSize = 0;

		TEnumAsByte<enum TextureGroup> TextureGroup = TEXTUREGROUP_MAX;
	};

	struct FMeshMetaInfo : FAssetMetaInfo
	{
		static const EMetaType ClassType = EMetaType::Mesh;

		int32 Triangles = 0;
		int32 Vertics = 0;
		int32 LodCount = 0;
	};

	class FAssetMetaInfoFactory
	{
	public:
		static TSharedPtr<FAssetMetaInfo> AssetMakeMetaData(UObject* Asset)
		{
			if (!Asset)
			{
				return nullptr;
			}

			if (Asset->IsA<UTexture>())
			{
				// 分辨率, lod
				auto Tex = Cast<UTexture>(Asset);

				UTexture2D* Texture2D = Cast<UTexture2D>(Tex);
				UTexture2DArray* Texture2DArray = Cast<UTexture2DArray>(Tex);

				int32 MaxResLODBias = Tex->GetCachedLODBias();;
				int32 MaxAllowedSizeX = FMath::Max<int32>(static_cast<int32>(Tex->GetSurfaceWidth()) >> MaxResLODBias, 1);
				int32 MaxAllowedSizeY = FMath::Max<int32>(static_cast<int32>(Tex->GetSurfaceHeight()) >> MaxResLODBias, 1);
				int32 DroppedMips = MaxResLODBias;
				int32 CurSizeX = FMath::Max<int32>(static_cast<int32>(Tex->GetSurfaceWidth()) >> DroppedMips, 1);
				int32 CurSizeY = FMath::Max<int32>(static_cast<int32>(Tex->GetSurfaceHeight()) >> DroppedMips, 1);

				int32 MaxAllowedSize = Tex->CalcTextureMemorySizeEnum(TMC_AllMipsBiased);
				int32 CurrentSize = Tex->CalcTextureMemorySizeEnum(TMC_ResidentMips);

				if (Texture2D != nullptr)
				{
					auto NumMips = Texture2D->GetNumMips();
					MaxResLODBias = NumMips - Texture2D->GetNumMipsAllowed(false);
					MaxAllowedSizeX = FMath::Max<int32>(Texture2D->GetSizeX() >> MaxResLODBias, 1);
					MaxAllowedSizeY = FMath::Max<int32>(Texture2D->GetSizeY() >> MaxResLODBias, 1);
					DroppedMips = Texture2D->GetNumMips() - Texture2D->GetNumResidentMips();
					CurSizeX = FMath::Max<int32>(Texture2D->GetSizeX() >> DroppedMips, 1);
					CurSizeY = FMath::Max<int32>(Texture2D->GetSizeY() >> DroppedMips, 1);
				}
				else if (Texture2DArray != nullptr)
				{
					DroppedMips = Texture2DArray->GetNumMips() - FKgEngineUtils::GetNumResidentMips(Texture2DArray);
					CurSizeX = FMath::Max<int32>(Texture2DArray->GetSizeX() >> DroppedMips, 1);
					CurSizeY = FMath::Max<int32>(Texture2DArray->GetSizeY() >> DroppedMips, 1);
				}

				TSharedPtr<FTextureMetaInfo> TextureMeta = MakeShared<FTextureMetaInfo>();
				TextureMeta->MetaType = FAssetMetaInfo::EMetaType::Texture;
				TextureMeta->CurSizeX = CurSizeX;
				TextureMeta->CurSizeY = CurSizeY;
				TextureMeta->CurrentSize = CurrentSize;
				TextureMeta->MaxAllowedSizeX = MaxAllowedSizeX;
				TextureMeta->MaxAllowedSizeY = MaxAllowedSizeY;
				TextureMeta->MaxAllowedSize = MaxAllowedSize;
				TextureMeta->TextureGroup = Tex->LODGroup;
				return TextureMeta;
			}
			else if (Asset->IsA<UStaticMesh>())
			{
				// 顶点数目, lod
				auto Sm = Cast<UStaticMesh>(Asset);
				if (Sm->GetRenderData() && Sm->GetRenderData()->GetCurrentFirstLOD(0))
				{
					auto LodInfo = Sm->GetRenderData()->GetCurrentFirstLOD(0);
					TSharedPtr<FMeshMetaInfo> MeshMetaInfo = MakeShared<FMeshMetaInfo>();
					MeshMetaInfo->MetaType = FAssetMetaInfo::EMetaType::Mesh;
					MeshMetaInfo->Vertics = LodInfo->GetNumVertices();
					MeshMetaInfo->Triangles = LodInfo->GetNumTriangles();
					MeshMetaInfo->LodCount = Sm->GetRenderData()->LODResources.Num();
					return MeshMetaInfo;
				}
			}
			else if (Asset->IsA<USkinnedAsset>())
			{
				// 顶点数目, lod
				auto Skm = Cast<USkinnedAsset>(Asset);
				if (Skm->GetResourceForRendering() && Skm->GetResourceForRendering()->GetPendingFirstLOD(0))
				{
					auto LodInfo = Skm->GetResourceForRendering()->GetPendingFirstLOD(0);
					TSharedPtr<FMeshMetaInfo> MeshMetaInfo = MakeShared<FMeshMetaInfo>();
					MeshMetaInfo->MetaType = FAssetMetaInfo::EMetaType::Mesh;
					MeshMetaInfo->Vertics = LodInfo->GetNumVertices();
					MeshMetaInfo->Triangles = LodInfo->GetTotalFaces();
					MeshMetaInfo->LodCount = Skm->GetResourceForRendering()->LODRenderData.Num();
					return MeshMetaInfo;
				}
			}
			
			return nullptr;
		}
	};

	struct FAssetInfo
	{
		// 有可能非法
		TWeakObjectPtr<UObject> Ptr;

		FString AssetName;
		SIZE_T Memory = 0;

		// 不关心的，都放在meta中
		TSharedPtr<FAssetMetaInfo> MetaInfo;

		// tag约定格式是：小写字母+下划线；可以存kv格式；
		// 多个tag拼凑时，用';'分割（不要用','，与csv冲突）
		TArray<FString> Tags;

		FString GetClassName() const
		{
			if (Ptr.IsValid())
			{
				return Ptr->GetClass()->GetClassPathName().ToString();
			}
			return "";
		}

		void Build()
		{
			if (Ptr.IsValid())
			{
				Memory = FLevelAssetDumperUtils::AssetGetMemorySize(Ptr.Get());
				MetaInfo = FAssetMetaInfoFactory::AssetMakeMetaData(Ptr.Get());
			}
		}

		// 增量
		void IncreBuild()
		{
			if (Memory == 0)
			{
				Build();
			}
		}

		bool IsA(FAssetMetaInfo::EMetaType T) const
		{
			return MetaInfo && MetaInfo->MetaType == T;
		}

		template <class T>
		TSharedPtr<T> GetMetaInfo()
		{
			if (!MetaInfo)
			{
				return nullptr;
			}
			if (MetaInfo->MetaType != T::ClassType)
			{
				return nullptr;
			}

			return StaticCastSharedPtr<T>(MetaInfo);
		}

		void FillOwnerInfo(ULevel* Level, AActor* Actor, const TArray<UObject*>& Referers)
		{
			FillTags(Level, Actor, Referers);
		}
		
		void FillTags(ULevel* Level, AActor* Actor, const TArray<UObject*>& Referers)
		{			
			if(Actor)
			{
				if(Actor->IsA<AWorldPartitionHLOD>())
				{
					Tags.AddUnique("hlod");
				}
				else if(Actor->IsA<ACharacter>())
				{
					Tags.AddUnique("character");
				}
			}

			if(Level)
			{			
				if(Level->IsPersistentLevel())
				{
					Tags.AddUnique("dynamic");
				}
				else
				{
					Tags.AddUnique("level");
					Tags.AddUnique("static");	
				}	
			}

			// 如果是被特效引用
			for(auto Obj : Referers)
			{
				if(Obj && Obj->IsA<UNiagaraSystem>())
				{
					UNiagaraSystem* Ns = Cast<UNiagaraSystem>(Obj);
					if(Ns)
					{
						if(Ns->GetEffectType())
						{
							// 譬如：NET_Monster, NET_Level
							Tags.AddUnique(FString::Printf(TEXT("effect_type=%s"), *Ns->GetEffectType()->GetName()));
						}
					}
					Tags.AddUnique("effect");
					// 如果是场景中的，算场景特效！
					if(Level->IsPersistentLevel())
					{
						Tags.AddUnique("level_effect");
					}					
				}
			}
		}

		void MarkUI()
		{
			Tags.AddUnique("ui");
		}
	};

	struct FLevelInfo
	{
		FString LevelName;
		FString CellName;
		FString StreamingType;

		// 特别注意key有可能失效，所以务必在单帧内消化掉。
		TMap<AActor*, TArray<TSharedPtr<FAssetInfo>>> ActorAssets;
	};

	struct FMapInfo
	{
		TMap<FString, TSharedPtr<FLevelInfo>> Levels;
		TMap<FString, TSharedPtr<FAssetInfo>> AssetDatabase;
		TSet<TSharedPtr<FAssetInfo>> OtherAssetSet;
	};

	class FMapLevelCellInfo
	{
	public:
		void Collect(UWorld* World)
		{			
			for (TObjectIterator<UWorldPartitionRuntimeLevelStreamingCell> It; It; ++It)
			{
				if (It->GetOuterWorld() == World)
				{
					Cells.Add(*It);
					if (It->GetLevelStreaming())
					{
						StreamingDict.Add(It->GetLevelStreaming(), *It);
					}
				}
			}
			
			Cells.Sort([](const UWorldPartitionRuntimeLevelStreamingCell& A, const UWorldPartitionRuntimeLevelStreamingCell& B)
			{
				if (A.GetCurrentState() == B.GetCurrentState())
				{
					return (int)A.GetIsHLOD() < (int)B.GetIsHLOD();
				}
				return A.GetCurrentState() > B.GetCurrentState();
			});
		}
		
		UWorldPartitionRuntimeLevelStreamingCell* FindCell(ULevelStreaming* SLevel)
		{
			ULevelStreamingDynamic* Other = Cast<ULevelStreamingDynamic>(SLevel);
			return Other ? StreamingDict.FindOrAdd(Other) : nullptr;
		}
		
		TArray<UWorldPartitionRuntimeLevelStreamingCell*> Cells;
		TMap<ULevelStreamingDynamic*, UWorldPartitionRuntimeLevelStreamingCell*> StreamingDict;
	};
	
	class FLevelAssetMapWatcher
	{
	public:
		void RecordLevel(ULevelStreaming* LevelStreaming, ULevel* Level, UWorldPartitionRuntimeLevelStreamingCell* Cell)
		{
			if (!Level)
			{
				return;
			}

			auto Actors = Level->Actors;

			for (auto It : Actors)
			{
				if (!It)
				{
					continue;
				}

				FFindAssetsHelper AssetsHelper;
				AssetsHelper.FindInActor(It);

				// Record(Level, LevelStreaming, Cell, It, AssetsHelper.Assets);
				RecordImpl(Level, LevelStreaming, Cell, It, AssetsHelper.TreeRoot);
			}
		}

		// 收集其他信息
		void CollectOthers(UWorld* World)
		{
			// 收集outer不是Actor的特效
			CollectOtherNiagara(World);

			// 收集UI
			CollectUI(World);

			// 收集Editor的贴图
			CollectEditorTexture(World);
		}
		void CollectOtherNiagara(UWorld* World)
		{			
			for( TObjectIterator<UNiagaraComponent> It; It; ++It )
			{
				UNiagaraComponent* Comp = *It;
				if(Comp->GetWorld() != World)
				{
					continue;
				}
				
				// 如果outer不是actor，按理应该没有！！
				if(!Comp->GetTypedOuter<AActor>())
				{
					// 认为Owner是WorldSetting
					auto WorldSettings = World->GetWorldSettings();
					
					FFindAssetsHelper AssetsHelper;
					AssetsHelper.FindInComponent(Comp);

					RecordImpl(World->PersistentLevel, nullptr, nullptr, WorldSettings, AssetsHelper.TreeRoot);
				}
			}
		}
		void CollectUI(UWorld* World)
		{
			// UI贴图
			for( TObjectIterator<UTexture> It; It; ++It )
			{				
				UTexture* Texture = *It;
				if(Texture->LODGroup == TEXTUREGROUP_UI)
				{
					// 查找引用
#if WITH_EDITOR
					
					EReferenceChainSearchMode SearchModeFlags = EReferenceChainSearchMode::FullChain;
					// FReferenceChainSearch RefChainSearch(SkeletonClass, EReferenceChainSearchMode::Shortest | EReferenceChainSearchMode::ExternalOnly);
					FReferenceChainSearch RefChainSearch(Texture, SearchModeFlags);
					auto Chains = RefChainSearch.GetReferenceChains();

					// 如果引用关系的outer不是world，那么就是editor独有的
					bool bFind = false;
					for(auto Chain : Chains)
					{
						if(bFind)
						{
							break;
						}
						auto Obj = Chain->GetRootNode()->ObjectInfo->TryResolveObject();
						if(Obj && Obj->GetWorld() == World)
						{
							bFind = true;
							break;
						}
						for(int NodeIdx = 0; NodeIdx < Chain->Num(); NodeIdx++)
						{
							UObject* Obj2 = Chain->GetNode(NodeIdx)->ObjectInfo->TryResolveObject();
							if(Obj2 && Obj2->GetWorld() == World)
							{
								bFind = true;
								break;
							}
						}
					}
					// editor独有的
					if(!bFind)
					{
						continue;
					}
#endif
					
					auto AssetPath = Texture->GetPathName();
					auto& Ptr = MapInfo.AssetDatabase.FindOrAdd(AssetPath);
					if (Ptr == nullptr)
					{
						Ptr = MakeShared<FAssetInfo>();
						Ptr->AssetName = AssetPath;
					}
					if (Ptr->Ptr != Texture)
					{
						Ptr->Ptr = Texture;
					}
					Ptr->MarkUI();

					// 放到其他里面
					MapInfo.OtherAssetSet.Add(Ptr);
				}
			}
		}
		void CollectEditorTexture(UWorld* World)
		{
#if WITH_EDITOR			
			// UI贴图
			for( TObjectIterator<UTexture> It; It; ++It )
			{				
				UTexture* Texture = *It;

				// 检查是否是被gameplay地图引用的
				auto AssetPath = Texture->GetPathName();
				if(MapInfo.AssetDatabase.Find(AssetPath) != nullptr)
				{
					continue;
				}

				// 如果是editor独有的贴图
				{
					auto& Ptr = EditorMapInfo.AssetDatabase.FindOrAdd(AssetPath);
					if (Ptr == nullptr)
					{
						Ptr = MakeShared<FAssetInfo>();
						Ptr->AssetName = AssetPath;
					}
					if (Ptr->Ptr != Texture)
					{
						Ptr->Ptr = Texture;
					}

					TArray<UObject*> Refers;	
					Ptr->FillOwnerInfo(nullptr, nullptr, Refers);
					Ptr->Tags.AddUnique("editor");

					// 放到其他里面
					EditorMapInfo.OtherAssetSet.Add(Ptr);
				}
			}
#endif
		}

		void Build()
		{
			for (auto Kv : MapInfo.AssetDatabase)
			{
				if (Kv.Value)
				{
					Kv.Value->Build();
				}
			}
			for (auto Kv : EditorMapInfo.AssetDatabase)
			{
				if (Kv.Value)
				{
					Kv.Value->Build();
				}
			}
		}

	private:
		void Record(ULevel* Level, ULevelStreaming* LevelStreaming, UWorldPartitionRuntimeLevelStreamingCell* Cell, AActor* Owner, const TArray<UObject*>& Assets)
		{
			Record(Level, LevelStreaming, Cell, Owner, FLevelAssetDumperUtils::ToArray(Assets));
		}

		void Record(ULevel* Level, ULevelStreaming* LevelStreaming, UWorldPartitionRuntimeLevelStreamingCell* Cell, AActor* Owner, const TArray<TWeakObjectPtr<UObject>>& Assets)
		{
			RecordImpl(Level, LevelStreaming, Cell, Owner, Assets);
		}

		void RecordImpl(ULevel* InLevel, ULevelStreaming* LevelStreaming, UWorldPartitionRuntimeLevelStreamingCell* Cell, AActor* Owner, const TArray<TWeakObjectPtr<UObject>>& Assets)
		{
			const FString& Level = InLevel->GetPathName();
			const FString& CellName = Cell ? *Cell->GetDebugName() : TEXT("None");
			auto& LevelInfo = MapInfo.Levels.FindOrAdd(Level);
			if (LevelInfo == nullptr)
			{
				LevelInfo = MakeShared<FLevelInfo>();
				LevelInfo->StreamingType = "None";
				if(LevelStreaming)
				{
					if(InLevel->IsPersistentLevel())
					{
						LevelInfo->StreamingType = "persistent";
					}
					else if(Cell && Cell->GetIsHLOD())
					{
						LevelInfo->StreamingType = "HLOD";
						if(Cell->IsAlwaysLoaded() || !LevelStreaming->IsA<ULevelStreamingDynamic>())
						{
							LevelInfo->StreamingType = "HLOD-AlwaysLoad";
						}
					}
					else if(LevelStreaming->IsA<ULevelStreamingDynamic>())
					{
						LevelInfo->StreamingType = "dynamic";						
					}
					else
					{
						LevelInfo->StreamingType = "static";
					}
				}
			}

			if (LevelInfo->LevelName != Level)
			{
				LevelInfo->LevelName = Level;

				int Idx = -1;
				if (LevelInfo->LevelName.FindChar('.', Idx))
				{
					LevelInfo->LevelName = Level.Mid(0, Idx);
				}

				LevelInfo->CellName = CellName;
			}
			for (auto Asset : Assets)
			{
				if (!Asset.IsValid())
				{
					continue;
				}

				auto AssetPath = Asset->GetPathName();
				auto& Ptr = MapInfo.AssetDatabase.FindOrAdd(AssetPath);
				if (Ptr == nullptr)
				{
					Ptr = MakeShared<FAssetInfo>();
					Ptr->AssetName = AssetPath;
				}
				if (Ptr->Ptr != Asset)
				{
					Ptr->Ptr = Asset;
				}

				// 追加一些额外信息
				TArray<UObject*> Refers;
				Ptr->FillOwnerInfo(InLevel, Owner, Refers);
				
				
				auto& OwnerAssets = LevelInfo->ActorAssets.FindOrAdd(Owner);
				OwnerAssets.AddUnique(Ptr);
			}
		}
		
		void RecordImpl(ULevel* InLevel, ULevelStreaming* LevelStreaming, UWorldPartitionRuntimeLevelStreamingCell* Cell, AActor* Owner, const TSharedPtr<FFindAssetsHelper::FNode> Tree)
		{
			if(!InLevel)
			{
				return;
			}
			
			const FString& Level = InLevel->GetPathName();
			const FString& CellName = Cell ? *Cell->GetDebugName() : TEXT("None");
			auto& LevelInfo = MapInfo.Levels.FindOrAdd(Level);
			if (LevelInfo == nullptr)
			{
				LevelInfo = MakeShared<FLevelInfo>();
				LevelInfo->StreamingType = "None";
				if(LevelStreaming)
				{
					if(InLevel->IsPersistentLevel())
					{
						LevelInfo->StreamingType = "persistent";
					}
					else if(Cell && Cell->GetIsHLOD())
					{
						LevelInfo->StreamingType = "HLOD";
						if(Cell->IsAlwaysLoaded() || !LevelStreaming->IsA<ULevelStreamingDynamic>())
						{
							LevelInfo->StreamingType = "HLOD-AlwaysLoad";
						}
					}
					else if(LevelStreaming->IsA<ULevelStreamingDynamic>())
					{
						LevelInfo->StreamingType = "dynamic";						
					}
					else
					{
						LevelInfo->StreamingType = "static";
					}
				}
			}

			if (LevelInfo->LevelName != Level)
			{
				LevelInfo->LevelName = Level;

				int Idx = -1;
				if (LevelInfo->LevelName.FindChar('.', Idx))
				{
					LevelInfo->LevelName = Level.Mid(0, Idx);
				}

				LevelInfo->CellName = CellName;
			}

			TArray<UObject*> Refers;
			RecursiveSet(Refers, Tree, InLevel, Owner, LevelInfo);			
		}
		
		// 递归遍历树结构
		void RecursiveSet(TArray<UObject*>& Refers, TSharedPtr<FFindAssetsHelper::FNode> Root, ULevel* InLevel,
				AActor* Owner, TSharedPtr<FLevelInfo> LevelInfo)
		{			
			if(!Root)
			{
				return;
			}
		
			Refers.Push(Root->Refer.Get());
			ON_SCOPE_EXIT
			{
				Refers.Pop();
			};
			
			for(auto Node : Root->Referred)
			{				
				for (auto Asset : Node->Assets)
				{
					if (!Asset.IsValid())
					{
						continue;
					}

					auto AssetPath = Asset->GetPathName();
					auto& Ptr = MapInfo.AssetDatabase.FindOrAdd(AssetPath);
					if (Ptr == nullptr)
					{
						Ptr = MakeShared<FAssetInfo>();
						Ptr->AssetName = AssetPath;
					}
					if (Ptr->Ptr != Asset)
					{
						Ptr->Ptr = Asset;
					}

					// 追加一些额外信息
					Ptr->FillOwnerInfo(InLevel, Owner, Refers);
				
				
					auto& OwnerAssets = LevelInfo->ActorAssets.FindOrAdd(Owner);
					OwnerAssets.AddUnique(Ptr);
				}
				
				for(auto Child : Node->Referred)
				{
					RecursiveSet(Refers, Child, InLevel, Owner, LevelInfo);
				}
			}
		}

	public:
		FMapInfo MapInfo;
		FMapInfo EditorMapInfo;
	};


	// 打印csv格式的信息
	class FLevelAssetDumpPoliceCsvFormat
	{
	public:
		FLevelAssetDumpPoliceCsvFormat(const FLevelAssetMapWatcher& InOwner)
			: Owner(InOwner)
		{
		}
		const FLevelAssetMapWatcher& Owner;

		void DumpCsv(const FString& MapName1)
		{
			// 构建dump信息
			auto MapName = FLevelAssetDumperUtils::ShortLevelPath(MapName1);
			MapName = MapName.Replace(TEXT("/Game"), TEXT("")).Replace(TEXT("/"), TEXT("_"));
			auto PathName = FPaths::ProjectSavedDir() / TEXT("LevelMemoryInfo") / (TEXT("LevelAsset-") + MapName);

			TArray<FString> Contents;
			TArray<FString> LevelAssets;
			TArray<FString> LevelCategoryInfo;

			TMap<UClass*, TSet<TSharedPtr<FAssetInfo>>> MapAssetMap;
			int MapPrimitiveCount = 0;
			int MapActorCount = 0;
			int LevelCount = 0;

			for (const auto& It : Owner.MapInfo.Levels)
			{
				if (It.Value->CellName.StartsWith(TEXT("None")))
				{
					volatile int xxx = 0;
					xxx++;
				}

				TMap<UClass*, TSet<TSharedPtr<FAssetInfo>>> CategoryAssets;
				int PrimitiveCount = 0;
				int ActorCount = 0;
				for (auto Actor : It.Value->ActorAssets)
				{
					TArray<UPrimitiveComponent*> Prims;
					Actor.Key->GetComponents(Prims);
					PrimitiveCount += Prims.Num();
					ActorCount++;

					for (auto Asset : Actor.Value)
					{
						if (!Asset.IsValid() || !Asset->Ptr.IsValid())
						{
							continue;
						}

						Append(Contents, It.Value->LevelName, It.Value->CellName, Actor.Key, Asset.Get());

						{
							auto& Set = CategoryAssets.FindOrAdd(Asset->Ptr->GetClass());
							Set.Add(Asset);
						}
						{
							auto& Set = MapAssetMap.FindOrAdd(Asset->Ptr->GetClass());
							Set.Add(Asset);
						}
					}
				}

				MapPrimitiveCount += PrimitiveCount;
				MapActorCount += ActorCount;
				if (PrimitiveCount > 0)
				{
					LevelCount++;
				}


				for (auto Kv : CategoryAssets)
				{
					SIZE_T AssetSize = 0;
					for (auto Asset : Kv.Value)
					{
						AppendLevelAsset(LevelAssets, It.Value->LevelName, It.Value->CellName, Asset.Get());
						AssetSize += Asset->Memory;
					}

					LevelCategoryInfo.Add(FString::Printf(TEXT("%s, %s, %s, %lld"), *It.Value->LevelName, *It.Value->CellName, *Kv.Key->GetClassPathName().ToString(), AssetSize));
				}
				LevelCategoryInfo.Add(FString::Printf(TEXT("%s, %s, %s, %d"), *It.Value->LevelName, *It.Value->CellName, TEXT("Actor"), ActorCount));
				LevelCategoryInfo.Add(FString::Printf(TEXT("%s, %s, %s, %d"), *It.Value->LevelName, *It.Value->CellName, TEXT("PrimitiveComponent"), PrimitiveCount));
			}

			// 整个地图的情况
			{
				LevelCategoryInfo.Add(FString::Printf(TEXT("Map, None, Level, %d"), Owner.MapInfo.Levels.Num()));

				for (auto Kv : MapAssetMap)
				{
					SIZE_T MapAssetSize = 0;
					for (auto Asset : Kv.Value)
					{
						MapAssetSize += Asset->Memory;
					}

					LevelCategoryInfo.Add(FString::Printf(TEXT("%s, %s, %s, %lld"), TEXT("Map"), TEXT("None"), *Kv.Key->GetClassPathName().ToString(), MapAssetSize));
				}

				LevelCategoryInfo.Add(FString::Printf(TEXT("%s, %s, %s, %d"), TEXT("Map"), TEXT("None"), TEXT("ActorComponent"), MapActorCount));

				LevelCategoryInfo.Add(FString::Printf(TEXT("%s, %s, %s, %d"), TEXT("Map"), TEXT("None"), TEXT("PrimitiveComponent"), MapPrimitiveCount));
			}

			{
				auto FileName = PathName + TEXT("-detail.csv");
				Contents.Insert("Level, Cell, Owner, AssetType, AssetSize, AssetPath", 0);
				FFileHelper::SaveStringArrayToFile(Contents, *FileName);
			}
			{
				auto FileName = PathName + TEXT("-total.csv");
				LevelAssets.Insert("Level, Cell, AssetType, AssetSize, AssetPath", 0);
				FFileHelper::SaveStringArrayToFile(LevelAssets, *FileName);
			}
			{
				auto FileName = PathName + TEXT("-category.csv");
				LevelCategoryInfo.Insert("Level, Cell, AssetType, AssetSize, AssetPath", 0);
				FFileHelper::SaveStringArrayToFile(LevelCategoryInfo, *FileName);
			}
		}

	private:
		static FString AssetOtherInfo(FAssetInfo* Asset)
		{
			if (!Asset)
			{
				return "";
			}

			FStringBuilderBase Sb;
			Sb.Append(", ");

			// 分类
			if (Asset->IsA(FAssetMetaInfo::EMetaType::Texture))
			{
				auto Ptr = Asset->GetMetaInfo<FTextureMetaInfo>();
				if (!Ptr)
				{
					return "";
				}

				// 运行时的Width，height，MemorySize
				Sb.Append(FString::FromInt(Ptr->CurSizeX));
				Sb.Append(", ");
				Sb.Append(FString::FromInt(Ptr->CurSizeY));
				Sb.Append(", ");
				Sb.Append(FString::FromInt(Ptr->CurrentSize));

				Sb.Append(", ");
				Sb.Append(UEnum::GetValueAsString(Ptr->TextureGroup));

				// 原始的尺寸、内存
				Sb.Append(", ");
				Sb.Append(FString::FromInt(Ptr->MaxAllowedSizeX));
				Sb.Append(", ");
				Sb.Append(FString::FromInt(Ptr->MaxAllowedSizeY));
				Sb.Append(", ");
				Sb.Append(FString::FromInt(Ptr->MaxAllowedSize));
			}
			else if (Asset->IsA(FAssetMetaInfo::EMetaType::Mesh))
			{
				auto Ptr = Asset->GetMetaInfo<FMeshMetaInfo>();
				if (!Ptr)
				{
					return "";
				}

				Sb.Append(FString::FromInt(Ptr->Triangles));
				Sb.Append(", ");
				Sb.Append(FString::FromInt(Ptr->Vertics));
				Sb.Append(", ");
				Sb.Append(FString::FromInt(Ptr->LodCount));
			}
			else
			{
				return "";
			}
			return Sb.ToString();
		}

		static void Append(TArray<FString>& Contents, const FString& Level, const FString& CellName, AActor* Owner, FAssetInfo* Asset)
		{
			if (!Asset)
			{
				return;
			}
			Contents.Add(FString::Printf(TEXT("%s, %s, %s, %s, %lld, %s%s"), *Level, *CellName, *Owner->GetName(), *Asset->GetClassName(), Asset->Memory, *Asset->AssetName, *AssetOtherInfo(Asset)));
		}

		static void AppendLevelAsset(TArray<FString>& LevelAssets, const FString& Level, const FString& CellName, FAssetInfo* Asset)
		{
			if (!Asset)
			{
				return;
			}

			LevelAssets.Add(FString::Printf(TEXT("%s, %s, %s, %lld, %s%s"), *Level, *CellName, *Asset->GetClassName(), Asset->Memory, *Asset->AssetName, *AssetOtherInfo(Asset)));
		}
	};

	// 提供给BP数据
	class FLevelAssetDumpPoliceBPData
	{
	public:
		FLevelAssetDumpPoliceBPData(const FLevelAssetMapWatcher& InOwner)
			: Owner(InOwner)
		{
		}

		const FLevelAssetMapWatcher& Owner;

		void FillInfo(FMapMemoryInfo& OutMapMemoryInfo)
		{
			TMap<UClass*, TSet<TSharedPtr<FAssetInfo>>> MapAssetMap;
			int MapPrimitiveCount = 0;
			int MapActorCount = 0;
			int LevelCount = 0;

			for (const auto& It : Owner.MapInfo.Levels)
			{
				FLevelMemoryInfo Temp;
				OutMapMemoryInfo.Levels.Add(Temp);

				FLevelMemoryInfo& OutLevelInfo = OutMapMemoryInfo.Levels.Last();
				auto LevelInfo = It.Value;
				if(!LevelInfo)
				{
					continue;
				}

				OutLevelInfo.PathName = LevelInfo->LevelName;
				OutLevelInfo.CellName = LevelInfo->CellName;
				OutLevelInfo.StreamingType = LevelInfo->StreamingType;

				TMap<UClass*, TSet<TSharedPtr<FAssetInfo>>> CategoryAssets;
				int PrimitiveCount = 0;
				int ActorCount = 0;
				for (auto Actor : It.Value->ActorAssets)
				{
					TArray<UPrimitiveComponent*> Prims;
					Actor.Key->GetComponents(Prims);
					PrimitiveCount += Prims.Num();
					ActorCount++;

					for (auto Asset : Actor.Value)
					{
						if (!Asset.IsValid() || !Asset->Ptr.IsValid())
						{
							continue;
						}

						{
							auto& Set = CategoryAssets.FindOrAdd(Asset->Ptr->GetClass());
							Set.Add(Asset);
						}
						{
							auto& Set = MapAssetMap.FindOrAdd(Asset->Ptr->GetClass());
							Set.Add(Asset);
						}
					}
				}

				MapPrimitiveCount += PrimitiveCount;
				MapActorCount += ActorCount;
				if (PrimitiveCount > 0)
				{
					LevelCount++;
				}


				for (auto Kv : CategoryAssets)
				{
					SIZE_T AssetSize = 0;
					for (auto Asset : Kv.Value)
					{
						AssetSize += Asset->Memory;
					}

					{
						FLevelMemoryInfoKv MemoryKv;
						MemoryKv.Key = Kv.Key->GetClassPathName().ToString() + TEXT("-Memory");
						MemoryKv.Value = FString::Printf(TEXT("%lld"), AssetSize);
						MemoryKv.ValueType = "int64";
						OutLevelInfo.AllKvs.Add(MemoryKv);
					}
					{
						FLevelMemoryInfoKv MemoryKv;
						MemoryKv.Key = Kv.Key->GetClassPathName().ToString() + TEXT("-Count");
						MemoryKv.Value = FString::FromInt(Kv.Value.Num());
						MemoryKv.ValueType = "int64";
						OutLevelInfo.AllKvs.Add(MemoryKv);
					}

					if (Kv.Key->IsChildOf(UTexture::StaticClass()))
					{
						OutLevelInfo.TextureCount += Kv.Value.Num();
						OutLevelInfo.TextureMemorySize += AssetSize;
					}
					else if (Kv.Key->IsChildOf(UStaticMesh::StaticClass()))
					{
						OutLevelInfo.StaticMeshCount += Kv.Value.Num();
						OutLevelInfo.StaticMeshMemorySize += AssetSize;
					}
					else if (Kv.Key->IsChildOf(USkeletalMesh::StaticClass()))
					{
						OutLevelInfo.SkeletalMeshCount += Kv.Value.Num();
						OutLevelInfo.SkeletalMeshMemorySize += AssetSize;
					}
				}
				OutLevelInfo.ActorCount = ActorCount;
				OutLevelInfo.PrimitiveCount = PrimitiveCount;
			}

			// 整个地图的情况
			{
				// LevelCategoryInfo.Add(FString::Printf(TEXT("Map, None, Level, %d"), MapInfo.Levels.Num()));

				for (auto Kv : MapAssetMap)
				{
					SIZE_T MapAssetSize = 0;
					for (auto Asset : Kv.Value)
					{
						MapAssetSize += Asset->Memory;
					}


					{
						FLevelMemoryInfoKv MemoryKv;
						MemoryKv.Key = Kv.Key->GetClassPathName().ToString() + TEXT("-Memory");
						MemoryKv.Value = FString::Printf(TEXT("%lld"), MapAssetSize);
						MemoryKv.ValueType = "int64";
						OutMapMemoryInfo.MapTotalInfo.AllKvs.Add(MemoryKv);
					}
					{
						FLevelMemoryInfoKv MemoryKv;
						MemoryKv.Key = Kv.Key->GetClassPathName().ToString() + TEXT("-Count");
						MemoryKv.Value = FString::FromInt(Kv.Value.Num());
						MemoryKv.ValueType = "int64";
						OutMapMemoryInfo.MapTotalInfo.AllKvs.Add(MemoryKv);
					}

					if (Kv.Key->IsChildOf(UTexture::StaticClass()))
					{
						OutMapMemoryInfo.MapTotalInfo.TextureCount += Kv.Value.Num();
						OutMapMemoryInfo.MapTotalInfo.TextureMemorySize += MapAssetSize;
					}
					else if (Kv.Key->IsChildOf(UStaticMesh::StaticClass()))
					{
						OutMapMemoryInfo.MapTotalInfo.StaticMeshCount += Kv.Value.Num();
						OutMapMemoryInfo.MapTotalInfo.StaticMeshMemorySize += MapAssetSize;
					}
					else if (Kv.Key->IsChildOf(USkeletalMesh::StaticClass()))
					{
						OutMapMemoryInfo.MapTotalInfo.SkeletalMeshCount += Kv.Value.Num();
						OutMapMemoryInfo.MapTotalInfo.SkeletalMeshMemorySize += MapAssetSize;
					}
				}

				OutMapMemoryInfo.MapTotalInfo.ActorCount = MapActorCount;
				OutMapMemoryInfo.MapTotalInfo.PrimitiveCount = MapPrimitiveCount;
			}
		}
	};

	// 提供给Bp的接口
	void BpCollectMapMemoryInfo(FMapMemoryInfo& OutMapMemoryInfo)
	{
		UWorld* World = FOptHelper::GetGameWorld();
		if (!World)
		{
			return;
		}

		FMapLevelCellInfo LevelCellInfo;
		LevelCellInfo.Collect(World);

		FLevelAssetMapWatcher Context;
		{
			auto StreamingLevels = World->GetStreamingLevels();
			for (auto SLevel : StreamingLevels)
			{
				UWorldPartitionRuntimeLevelStreamingCell* Cell = LevelCellInfo.FindCell(SLevel);
				Context.RecordLevel(SLevel, SLevel->GetLoadedLevel(), Cell);
			}
			Context.RecordLevel(nullptr, World->PersistentLevel, nullptr);
			Context.CollectOthers(World);
			
			Context.Build();
		}
		
		FLevelAssetDumpPoliceBPData One(Context);
		One.FillInfo(OutMapMemoryInfo);
	}
	
	class FLevelAssetDumpPoliceBPTextureData
	{
	public:
		FLevelAssetDumpPoliceBPTextureData(const FLevelAssetMapWatcher& InOwner)
			: Owner(InOwner)
		{
		}

		const FLevelAssetMapWatcher& Owner;

		void FillInfo(FMapTextureInfo& OutMapMemoryInfo)
		{
			TMap<UClass*, TSet<TSharedPtr<FAssetInfo>>> MapAssetMap;
			int MapPrimitiveCount = 0;
			int MapActorCount = 0;
			int LevelCount = 0;

			for (const auto& It : Owner.MapInfo.Levels)
			{
				FLevelTextureInfo Temp;
				OutMapMemoryInfo.Levels.Add(Temp);

				FLevelTextureInfo& OutLevelInfo = OutMapMemoryInfo.Levels.Last();
				auto LevelInfo = It.Value;
				if(!LevelInfo)
				{
					continue;
				}

				OutLevelInfo.PathName = LevelInfo->LevelName;
				OutLevelInfo.CellName = LevelInfo->CellName;
				OutLevelInfo.StreamingType = LevelInfo->StreamingType;

				TMap<UClass*, TSet<TSharedPtr<FAssetInfo>>> CategoryAssets;
				int PrimitiveCount = 0;
				int ActorCount = 0;
				for (auto Actor : It.Value->ActorAssets)
				{
					TArray<UPrimitiveComponent*> Prims;
					Actor.Key->GetComponents(Prims);
					PrimitiveCount += Prims.Num();
					ActorCount++;

					for (auto Asset : Actor.Value)
					{
						if (!Asset.IsValid() || !Asset->Ptr.IsValid())
						{
							continue;
						}

						{
							auto& Set = CategoryAssets.FindOrAdd(Asset->Ptr->GetClass());
							Set.Add(Asset);
						}
						{
							auto& Set = MapAssetMap.FindOrAdd(Asset->Ptr->GetClass());
							Set.Add(Asset);
						}
					}
				}

				MapPrimitiveCount += PrimitiveCount;
				MapActorCount += ActorCount;
				if (PrimitiveCount > 0)
				{
					LevelCount++;
				}


				for (auto Kv : CategoryAssets)
				{
					SIZE_T AssetSize = 0;
					for (auto Asset : Kv.Value)
					{
						AssetSize += Asset->Memory;

						auto Meta = Asset->GetMetaInfo<FTextureMetaInfo>();
						if(Meta)
						{
							OutLevelInfo.TextureInfos.Push(FPrTextureInfo());
							FPrTextureInfo& One = OutLevelInfo.TextureInfos.Top();
							One.Path = Asset->AssetName;
							One.TextureGroup = UEnum::GetValueAsString(Meta->TextureGroup);
							One.Tags = Asset->Tags;
							One.CurSizeX = Meta->CurSizeX;
							One.CurSizeY = Meta->CurSizeY;
							One.CurrentMemSize = Meta->CurrentSize;
							One.MaxAllowedSizeX = Meta->MaxAllowedSizeX;
							One.MaxAllowedSizeY = Meta->MaxAllowedSizeY;
							One.MaxAllowedMemSize = Meta->MaxAllowedSize;						
						}
					}

					if (Kv.Key->IsChildOf(UTexture::StaticClass()))
					{
						OutLevelInfo.TextureCount += Kv.Value.Num();
						OutLevelInfo.TextureMemorySize += AssetSize;
					}
				}
			}

			// 整个地图的情况
			{
				// LevelCategoryInfo.Add(FString::Printf(TEXT("Map, None, Level, %d"), MapInfo.Levels.Num()));

				for (auto Kv : MapAssetMap)
				{
					SIZE_T MapAssetSize = 0;
					for (auto Asset : Kv.Value)
					{
						MapAssetSize += Asset->Memory;
					}

					if (Kv.Key->IsChildOf(UTexture::StaticClass()))
					{
						OutMapMemoryInfo.MapTotalInfo.TextureCount += Kv.Value.Num();
						OutMapMemoryInfo.MapTotalInfo.TextureMemorySize += MapAssetSize;
					}
				}
			}

			// 追加UI的贴图			
			for (const auto& It : Owner.MapInfo.OtherAssetSet)
			{
				if(!It)
				{
					continue;
				}

				auto Meta = It->GetMetaInfo<FTextureMetaInfo>();
				if(Meta)
				{				
					OutMapMemoryInfo.UITextureInfos.Add(FPrTextureInfo());
					FPrTextureInfo& One = OutMapMemoryInfo.UITextureInfos.Last();
					
					One.Path = It->AssetName;
					One.TextureGroup = UEnum::GetValueAsString(Meta->TextureGroup);
					One.Tags = It->Tags;
					One.CurSizeX = Meta->CurSizeX;
					One.CurSizeY = Meta->CurSizeY;
					One.CurrentMemSize = Meta->CurrentSize;
					One.MaxAllowedSizeX = Meta->MaxAllowedSizeX;
					One.MaxAllowedSizeY = Meta->MaxAllowedSizeY;
					One.MaxAllowedMemSize = Meta->MaxAllowedSize;					
				}
			}
		}
	};
	void BpCollectMapTextureInfo(FMapTextureInfo& OutMapMemoryInfo)
	{
		UWorld* World = FOptHelper::GetGameWorld();
		if (!World)
		{
			return;
		}

		FMapLevelCellInfo LevelCellInfo;
		LevelCellInfo.Collect(World);

		FLevelAssetMapWatcher Context;
		{
			auto StreamingLevels = World->GetStreamingLevels();
			for (auto SLevel : StreamingLevels)
			{
				UWorldPartitionRuntimeLevelStreamingCell* Cell = LevelCellInfo.FindCell(SLevel);
				Context.RecordLevel(SLevel, SLevel->GetLoadedLevel(), Cell);
			}
			Context.RecordLevel(nullptr, World->PersistentLevel, nullptr);
			Context.CollectOthers(World);
			
			Context.Build();
		}
		
		FLevelAssetDumpPoliceBPTextureData One(Context);
		One.FillInfo(OutMapMemoryInfo);
	}

	class FLevelTextureDumpPoliceCsvFormat
	{
	public:
		FLevelTextureDumpPoliceCsvFormat(const FLevelAssetMapWatcher& InOwner)
			: Owner(InOwner)
		{
		}
		const FLevelAssetMapWatcher& Owner;

		static FString GetFolder(const FString& AssetPath)
		{
			TArray<FString> Folders;
			AssetPath.ParseIntoArray(Folders, TEXT("/"));
			if(Folders.Num() > 0)
			{
				return Folders[0];
			}
			return "";
		}
		static FString GetCategory(const TSharedPtr<FAssetInfo> Asset, const TSharedPtr<FTextureMetaInfo> Meta)
		{
			if(!Asset || !Meta)
			{
				return "others";
			}
			if(Asset->Tags.Contains("ui"))
			{
				return "ui";
			}
			
			if(Asset->Tags.Contains("hlod"))
			{
				return "hlod";
			}
			
			if(Asset->Tags.Contains("character"))
			{
				return "character";
			}
			
			if(Asset->Tags.Contains("effect"))
			{
				return "effect";
			}
			
			if(Asset->Tags.Contains("level"))
			{
				return "level";
			}
			
			if(Asset->Tags.Contains("editor"))
			{
				return "editor";
			}
			
			return "others";
		}
		void DumpCsv(const FString& MapName1)
		{
#if true
			// 构建dump信息
			auto MapName = FLevelAssetDumperUtils::ShortLevelPath(MapName1);
			MapName = MapName.Replace(TEXT("/Game"), TEXT("")).Replace(TEXT("/"), TEXT("_"));
			auto PathName = FPaths::ProjectSavedDir() / TEXT("LevelMemoryInfo") / (TEXT("MapTexture-") + MapName);

			/*
				全量贴图内存（只需要数值）：
				引擎&插件目录的贴图（详细列表）
				client插件目录的贴图（详细列表）
				WP Loading Range内贴图（详细列表）
				WP每个Grid[0]的贴图（详细列表）
				HLOD的贴图（详细列表）

				经过以上集合的差异子集就是角色、非场景特效、UI贴图内存，按目录进行分类输出（详细列表）

				单独列：输出client、引擎、插件的贴图
				单独列：hlod、character、ui贴图、特效贴图、场景贴图、其他贴图

				表头：场景，cell，贴图名字，目录，分类, TextureGroup，尺寸，内存，Tags
					额外以Editor为单位展示：贴图信息
					额外以Map为单位展示：贴图数目，总内存大小					
				额外一张表，展示依赖关系。只计算editor贴图的
			 */
			// 单独列：输出client、引擎、插件的贴图，加个单独列表示这个信息
			
			TMap<UClass*, TSet<TSharedPtr<FAssetInfo>>> MapAssetMap;

			FStringBuilderBase Sb;
			Sb.Append(FString::Printf(TEXT("Level,Cell,Asset,Folder,Category,TextureGroup,SizeX,SizeY,Memory,CurSizeX,CurSizeY,CurMemory,Tags\n")));

			for (const auto& It : Owner.MapInfo.Levels)
			{
				TMap<UClass*, TSet<TSharedPtr<FAssetInfo>>> CategoryAssets;
				int PrimitiveCount = 0;
				int ActorCount = 0;
				for (auto Actor : It.Value->ActorAssets)
				{
					for (auto Asset : Actor.Value)
					{
						if (!Asset.IsValid() || !Asset->Ptr.IsValid())
						{
							continue;
						}
						
						if(!Asset->IsA(FAssetMetaInfo::EMetaType::Texture))
						{
							continue;
						}
						auto Meta = Asset->GetMetaInfo<FTextureMetaInfo>();
						if(!Meta)
						{
							continue;
						}
						
						Sb.Append(FString::Printf(TEXT("%s,%s,%s,%s,%s,%s,%d,%d,%d,%d,%d,%d,%s\n"),
							*It.Value->LevelName, *It.Value->CellName,
							*Asset->AssetName, *GetFolder(Asset->AssetName),
							*GetCategory(Asset, Meta), *UEnum::GetValueAsString(Meta->TextureGroup),
							Meta->MaxAllowedSizeX, Meta->MaxAllowedSizeY, Meta->MaxAllowedSize,
							Meta->CurSizeX, Meta->CurSizeY, Meta->CurrentSize, *FString::Join(Asset->Tags, TEXT(";")) 
							));

						{
							auto& Set = MapAssetMap.FindOrAdd(Asset->Ptr->GetClass());
							Set.Add(Asset);
						}
					}
				}
			}

			// UI贴图的情况
			{
				for (auto Kv : Owner.MapInfo.OtherAssetSet)
				{
					auto Asset = Kv;
					
					if (!Asset.IsValid() || !Asset->Ptr.IsValid())
					{
						continue;
					}
						
					if(!Asset->IsA(FAssetMetaInfo::EMetaType::Texture))
					{
						continue;
					}
					auto Meta = Asset->GetMetaInfo<FTextureMetaInfo>();
					if(!Meta)
					{
						continue;
					}
						
					Sb.Append(FString::Printf(TEXT("%s,%s,%s,%s,%s,%s,%d,%d,%d,%d,%d,%d,%s\n"),
						TEXT("Other"), TEXT("None"),
						*Asset->AssetName, *GetFolder(Asset->AssetName),
						*GetCategory(Asset, Meta), *UEnum::GetValueAsString(Meta->TextureGroup),
						Meta->MaxAllowedSizeX, Meta->MaxAllowedSizeY, Meta->MaxAllowedSize,
						Meta->CurSizeX, Meta->CurSizeY, Meta->CurrentSize, *FString::Join(Asset->Tags, TEXT(";")) 
						));

					{
						auto& Set = MapAssetMap.FindOrAdd(Asset->Ptr->GetClass());
						Set.Add(Asset);
					}
				}				
			}
			
			// Editor贴图的情况
			{
				for (auto Kv : Owner.EditorMapInfo.AssetDatabase)
				{
					auto Asset = Kv.Value;
					
					if (!Asset.IsValid() || !Asset->Ptr.IsValid())
					{
						continue;
					}
						
					if(!Asset->IsA(FAssetMetaInfo::EMetaType::Texture))
					{
						continue;
					}
					auto Meta = Asset->GetMetaInfo<FTextureMetaInfo>();
					if(!Meta)
					{
						continue;
					}
						
					Sb.Append(FString::Printf(TEXT("%s,%s,%s,%s,%s,%s,%d,%d,%d,%d,%d,%d,%s\n"),
						TEXT("Editor"), TEXT("None"),
						*Asset->AssetName, *GetFolder(Asset->AssetName),
						*GetCategory(Asset, Meta), *UEnum::GetValueAsString(Meta->TextureGroup),
						Meta->MaxAllowedSizeX, Meta->MaxAllowedSizeY, Meta->MaxAllowedSize,
						Meta->CurSizeX, Meta->CurSizeY, Meta->CurrentSize, *FString::Join(Asset->Tags, TEXT(";")) 
						));

					{
						auto& Set = MapAssetMap.FindOrAdd(Asset->Ptr->GetClass());
						Set.Add(Asset);
					}
				}				
			}
			

			// 整个地图的情况
			{
				for (auto Kv : MapAssetMap)
				{
					SIZE_T MapAssetSize = 0;
					SIZE_T MapAssetSize2 = 0;
					for (auto Asset : Kv.Value)
					{
						MapAssetSize += Asset->Memory;
						
						auto Meta = Asset->GetMetaInfo<FTextureMetaInfo>();
						if(Meta)
						{
							MapAssetSize2 += Meta->MaxAllowedSize;
						}
					}

					Sb.Append(FString::Printf(TEXT("%s,%s,%s,%s,%s,%s,%d,%d,%lld,%d,%d,%lld,%s\n"),
						TEXT("Map-TextureTotal"), TEXT("None"),
						*Kv.Key->GetClassPathName().ToString(), TEXT(""),
						TEXT(""), TEXT(""),
						0, 0, MapAssetSize2,
						0, 0, MapAssetSize, TEXT("") 
						));
				}
			}

			{
				auto FileName = PathName + TEXT("-detail.csv");
				FFileHelper::SaveStringToFile(Sb.ToString(), *FileName);
			}
#endif
		}
	};
	
	class FLevelTextureDumpRefInfo
	{
	public:
		FLevelTextureDumpRefInfo(const FLevelAssetMapWatcher& InOwner)
			: Owner(InOwner)
		{
		}
		const FLevelAssetMapWatcher& Owner;

		static FString GetTab(int N)
		{
			FStringBuilderBase Sb;
			while(N > 0)
			{
				N--;
				Sb.Append("\t");
			}
			return Sb.ToString();
		}
		
		void DumpText(const FString& MapName1)
		{
#if true
			// 构建dump信息
			auto MapName = FLevelAssetDumperUtils::ShortLevelPath(MapName1);
			MapName = MapName.Replace(TEXT("/Game"), TEXT("")).Replace(TEXT("/"), TEXT("_"));
			auto PathName = FPaths::ProjectSavedDir() / TEXT("LevelMemoryInfo") / (TEXT("MapTexture-") + MapName);

			FStringBuilderBase Sb;
			
			// Editor贴图的情况
			{
				for (auto Kv : Owner.EditorMapInfo.AssetDatabase)
				{
					auto Asset = Kv.Value;
					
					if (!Asset.IsValid() || !Asset->Ptr.IsValid())
					{
						continue;
					}
						
					if(!Asset->IsA(FAssetMetaInfo::EMetaType::Texture))
					{
						continue;
					}

					// 空三行
					if(Sb.Len() > 0)
					{
						Sb.Append("\n\n\n");	
					}
					
					Sb.Append(Asset->AssetName);
					Sb.Append(" ->\n");

					UObject* Target = Asset->Ptr.Get();
					EReferenceChainSearchMode SearchModeFlags = EReferenceChainSearchMode::FullChain;
					// FReferenceChainSearch RefChainSearch(SkeletonClass, EReferenceChainSearchMode::Shortest | EReferenceChainSearchMode::ExternalOnly);
					FReferenceChainSearch RefChainSearch(Target, SearchModeFlags);
					auto Chains = RefChainSearch.GetReferenceChains();

					// 如果引用关系的outer不是world，那么就是editor独有的
					
					for(auto Chain : Chains)
					{
						int Tab = 1;
						const int32 RootIndex = Chain->Num() - 1;
						const FReferenceChainSearch::FNodeReferenceInfo* ReferenceInfo = Chain->GetReferenceInfo(RootIndex);
						FGCObjectInfo* ReferencerObject = Chain->GetNode(RootIndex)->ObjectInfo;
						{
							UObject* Obj2 = ReferencerObject->TryResolveObject();
							
							Sb.Append(GetTab(Tab));
							Sb.Append(*Obj2->GetFullName());
							Sb.Append("\n");							
						}
						
						for(int NodeIdx = RootIndex - 1; NodeIdx >= 0; NodeIdx--)
						{
							Tab++;
							UObject* Obj2 = Chain->GetNode(NodeIdx)->ObjectInfo->TryResolveObject();
							
							Sb.Append(GetTab(Tab));
							Sb.Append(*Obj2->GetFullName());							
							Sb.Append("\n");
						}
					}
				}				
			}
			
			{
				auto FileName = PathName + TEXT("-refs.txt");
				FFileHelper::SaveStringToFile(Sb.ToString(), *FileName);
			}
#endif
		}
	};
	
	// 以场景为单位，dump内存情况
	FAutoConsoleCommand OptC7DumpLevelMemory(TEXT("c7.dump.level.memory"), TEXT("c7.dump.level.memory"), FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		bool bFull = true;
		UWorld* World = FOptHelper::GetGameWorld();

		FMapLevelCellInfo LevelCellInfo;
		LevelCellInfo.Collect(World);
#if true
		for (auto It : LevelCellInfo.Cells)
		{
			if (!bFull)
			{
				if (It->GetCurrentState() == EWorldPartitionRuntimeCellState::Unloaded)
				{
					continue;
				}
			}
			UE_LOG(LogTemp, Log, TEXT("liubo, wp.streaming, cell=%s, DebugName=%s, IsHlod=%d, CellState=%s, LevelState=%s, CellBound=Center=(%s);Size=(%s)"), *It->GetLevelPackageName().ToString(), *It->GetDebugName(), It->GetIsHLOD(), *UEnum::GetValueAsString(It->GetCurrentState()), It->GetLevelStreaming() ? EnumToString(It->GetLevelStreaming()->GetLevelStreamingState()) : TEXT("None"), *It->GetCellBounds().GetCenter().ToString(), *It->GetCellBounds().GetSize().ToString());
		}

		// 打印非Cell的
		for (TObjectIterator<ULevelStreamingDynamic> It; It; ++It)
		{
			if (It->GetOuterUWorld() == World)
			{
				if (!LevelCellInfo.StreamingDict.Contains(*It))
				{
					UE_LOG(LogTemp, Log, TEXT("liubo, wp.streaming, NoCellInfo. LevelStreaming=%s, LevelState=%s"), *It->GetWorldAssetPackageName(), EnumToString(It->GetLevelStreamingState()));
				}
			}
		}
#endif

		// 遍历World -> 遍历Level -> Actor -> Primitives
		FLevelAssetMapWatcher Context;
		double RecordCostTime = 0;
		double BuildCostTime = 0;
		double DumpCostTime = 0;
		{
			SCOPE_SECONDS_COUNTER(RecordCostTime);
			auto StreamingLevels = World->GetStreamingLevels();
			for (auto SLevel : StreamingLevels)
			{
				UWorldPartitionRuntimeLevelStreamingCell* Cell = LevelCellInfo.FindCell(SLevel);
				Context.RecordLevel(SLevel, SLevel->GetLoadedLevel(), Cell);
			}
			Context.RecordLevel(nullptr, World->PersistentLevel, nullptr);
			Context.CollectOthers(World);
		}
		{
			SCOPE_SECONDS_COUNTER(BuildCostTime);
			Context.Build();
		}
		{
			SCOPE_SECONDS_COUNTER(DumpCostTime);
			FLevelAssetDumpPoliceCsvFormat CsvPolice(Context);
			CsvPolice.DumpCsv(World->GetPathName());
		}
		UE_LOG(LogTemp, Log, TEXT("liubo, done, RecordCostTime=%.2fms, BuildCostTime=%.2fms, DumpCostTime=%.2fms"), RecordCostTime * 1000, BuildCostTime * 1000, DumpCostTime * 1000);
	}));

	
	// 以场景为单位，dump贴图情况
	FAutoConsoleCommand OptC7DumpLevelTexture(TEXT("c7.dump.map.texture"), TEXT("c7.dump.map.texture"), FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		bool bDumpRef = false;
		
		UWorld* World = FOptHelper::GetGameWorld();
		for(auto Arg : Args)
		{
			if(Arg == "-refs")
			{
				bDumpRef = true;
			}
		}

		FMapLevelCellInfo LevelCellInfo;
		LevelCellInfo.Collect(World);

		// 遍历World -> 遍历Level -> Actor -> Primitives
		FLevelAssetMapWatcher Context;
		double RecordCostTime = 0;
		double BuildCostTime = 0;
		double DumpCostTime = 0;
		double DumpRefTime = 0;
		{
			SCOPE_SECONDS_COUNTER(RecordCostTime);
			auto StreamingLevels = World->GetStreamingLevels();
			for (auto SLevel : StreamingLevels)
			{
				UWorldPartitionRuntimeLevelStreamingCell* Cell = LevelCellInfo.FindCell(SLevel);
				Context.RecordLevel(SLevel, SLevel->GetLoadedLevel(), Cell);
			}
			Context.RecordLevel(nullptr, World->PersistentLevel, nullptr);
			Context.CollectOthers(World);
		}
		{
			SCOPE_SECONDS_COUNTER(BuildCostTime);
			Context.Build();
		}
		{
			SCOPE_SECONDS_COUNTER(DumpCostTime);
			FLevelTextureDumpPoliceCsvFormat CsvPolice(Context);
			CsvPolice.DumpCsv(World->GetPathName());
		}

		// dump 引用关系链表
		if(bDumpRef)
		{
			SCOPE_SECONDS_COUNTER(DumpRefTime);
			FLevelTextureDumpRefInfo RefPolice(Context);
			RefPolice.DumpText(World->GetPathName());		
		}
		
		UE_LOG(LogTemp, Log, TEXT("liubo, done, RecordCostTime=%.2fms, BuildCostTime=%.2fms, DumpCostTime=%.2fms, DumpRefTime=%.2fms"),
				RecordCostTime * 1000, BuildCostTime * 1000,
				DumpCostTime * 1000, DumpRefTime * 1000);
	}));

#if false
	static void C7TestRefs(const FString& Cmd)
	{		
		UObject* Object = nullptr;
		auto World = FOptHelper::GetGameWorld();
		if (ParseObject(*Cmd,TEXT("NAME="),Object,nullptr))
		{			
			EReferenceChainSearchMode SearchModeFlags = EReferenceChainSearchMode::FullChain;
			// FReferenceChainSearch RefChainSearch(SkeletonClass, EReferenceChainSearchMode::Shortest | EReferenceChainSearchMode::ExternalOnly);
			FReferenceChainSearch RefChainSearch(Object, SearchModeFlags);
			auto Chains = RefChainSearch.GetReferenceChains();

			// 如果引用关系的outer不是world，那么就是editor独有的
			bool bFind = false;
			for(auto Chain : Chains)
			{
				if(bFind)
				{
					// break;
				}
				auto Obj = Chain->GetRootNode()->ObjectInfo->TryResolveObject();
				UE_LOG(LogTemp, Log, TEXT("liubo, obj root=%s"), *Obj->GetFullName());
				
				if(Obj && Obj->GetWorld() == World)
				{
					bFind = true;
					// break;
				}
				for(int NodeIdx = 0; NodeIdx < Chain->Num(); NodeIdx++)
				{
					UObject* Obj2 = Chain->GetNode(NodeIdx)->ObjectInfo->TryResolveObject();
					UE_LOG(LogTemp, Log, TEXT("liubo, obj Node=%s"), *Obj2->GetFullName());
					if(Obj2 && Obj2->GetWorld() == World)
					{
						bFind = true;
						// break;
					}
				}
			}
			UE_LOG(LogTemp, Log, TEXT("liubo, obj is editor_only?=%d"), bFind ? 0 : 1);
		}
		else
		{
			UE_LOG(LogTemp, Log, TEXT("liubo, can't find obj=%s"), *Cmd);			
		}
	}
	// 以场景为单位，dump贴图情况
	FAutoConsoleCommand OptC7TestRefs(TEXT("c7.test.refs"), TEXT("c7.test.refs"), FConsoleCommandWithArgsDelegate::CreateLambda([](const TArray<FString>& Args)
	{
		if(Args.Num() == 1)
		{
			C7TestRefs(Args[0]);
		}
	}));
#endif
}
