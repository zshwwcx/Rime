#include "AssetDeduplicateManager.h"

#include "FileHelpers.h"
#include "ObjectTools.h"
#include "AssetRegistry/AssetRegistryModule.h"
#include "AssetDeduplicate/DataModel/AssetDeduplicateSettings.h"
#include "Misc/ScopedSlowTask.h"

#define LOCTEXT_NAMESPACE "AssetDeduplicateManager"

FAssetDeduplicateManager::FAssetDeduplicateManager()
{
	auto& AssetRegistryModule = FModuleManager::Get().GetModuleChecked<FAssetRegistryModule>("AssetRegistry");
	IAssetRegistry& AssetRegistry = AssetRegistryModule.GetRegistry();
	TArray<FAssetData> OutAssetData;
	AssetRegistry.GetAssetsByClass(UAssetDeduplicateSettings::StaticClass()->GetClassPathName(), OutAssetData);

	if (OutAssetData.Num() > 0)
	{
		Settings = Cast<UAssetDeduplicateSettings>(OutAssetData[0].GetAsset());
	}
	else
	{
		UPackage* Package = CreatePackage(TEXT("/Game/Editor/AssetDeduplicate/Settings"));
		Settings = DuplicateObject<UAssetDeduplicateSettings>(GetDefault<UAssetDeduplicateSettings>(), Package, "Settings");
		Settings->ClearFlags(RF_AllFlags);
		Settings->SetFlags(RF_Public | RF_Standalone | RF_Transactional);
		Settings->MarkPackageDirty();
	}

	if (Settings != nullptr)
	{
		Settings->AddToRoot();
	}
}

FAssetDeduplicateManager::~FAssetDeduplicateManager()
{
	if (Settings.IsValid())
	{
		Settings->RemoveFromRoot();
	}
}

void FAssetDeduplicateManager::AddReferencedObjects(FReferenceCollector& Collector)
{
}

FString FAssetDeduplicateManager::GetReferencerName() const
{
	return TEXT("FAssetDeduplicateManager");
}

TStatId FAssetDeduplicateManager::GetStatId() const
{
	RETURN_QUICK_DECLARE_CYCLE_STAT(FAssetDeduplicateManager, STATGROUP_Tickables);
}

void FAssetDeduplicateManager::Tick(float DeltaTime)
{
}

// Function to calculate centroid of the vertices
FVector3f CalculateCentroid(const TArray<FVector3f>& Vertices)
{
	FVector3f Centroid(0, 0, 0);

	for (const FVector3f& Vertex : Vertices)
	{
		Centroid += Vertex;
	}

	Centroid /= Vertices.Num(); // Average position

	return Centroid;
}

// Normalize translation (move the mesh's centroid to the origin)
void NormalizeTranslation(TArray<FVector3f>& Vertices)
{
	FVector3f Centroid = CalculateCentroid(Vertices);

	for (FVector3f& Vertex : Vertices)
	{
		Vertex -= Centroid;
	}
}

// Normalize scale (fit the mesh into a unit cube)
void NormalizeScale(TArray<FVector3f>& Vertices)
{
	FVector3f Min(FLT_MAX, FLT_MAX, FLT_MAX);
	FVector3f Max(-FLT_MAX, -FLT_MAX, -FLT_MAX);

	// Calculate the bounding box
	for (const FVector3f& Vertex : Vertices)
	{
		Min = Min.ComponentMin(Vertex);
		Max = Max.ComponentMax(Vertex);
	}

	FVector3f BoundingSize = Max - Min;
	float MaxDimension = FMath::Max3(BoundingSize.X, BoundingSize.Y, BoundingSize.Z);

	// Scale the vertices so the mesh fits into a unit cube
	for (FVector3f& Vertex : Vertices)
	{
		Vertex /= MaxDimension;
	}
}


FMatrix ComputeCovarianceMatrix(const TArray<FVector3f>& Vertices)
{
	FVector3f Mean(0, 0, 0);
	int32 NumVertices = Vertices.Num();

	// Step 1: Compute the mean position
	for (const FVector3f& Vertex : Vertices)
	{
		Mean += Vertex;
	}
	Mean /= NumVertices;

	// Step 2: Compute the covariance matrix
	FMatrix CovarianceMatrix = FMatrix::Identity;
	for (const FVector3f& Vertex : Vertices)
	{
		FVector3f Centered = Vertex - Mean;

		CovarianceMatrix.M[0][0] += Centered.X * Centered.X; // Cov(X, X)
		CovarianceMatrix.M[0][1] += Centered.X * Centered.Y; // Cov(X, Y)
		CovarianceMatrix.M[0][2] += Centered.X * Centered.Z; // Cov(X, Z)
		CovarianceMatrix.M[1][0] += Centered.Y * Centered.X; // Cov(Y, X)
		CovarianceMatrix.M[1][1] += Centered.Y * Centered.Y; // Cov(Y, Y)
		CovarianceMatrix.M[1][2] += Centered.Y * Centered.Z; // Cov(Y, Z)
		CovarianceMatrix.M[2][0] += Centered.Z * Centered.X; // Cov(Z, X)
		CovarianceMatrix.M[2][1] += Centered.Z * Centered.Y; // Cov(Z, Y)
		CovarianceMatrix.M[2][2] += Centered.Z * Centered.Z; // Cov(Z, Z)
	}

	// CovarianceMatrix /= NumVertices; // Normalize by the number of vertices
	
	return CovarianceMatrix;
}


TArray<FVector3f> FAssetDeduplicateManager::ExtractMeshPoints(UStaticMesh* Mesh, bool bIgnoreTranslate, bool bIgnoreScale) const
{
	if (!Mesh || !Mesh->GetRenderData())
	{
		UE_LOG(LogTemp, Error, TEXT("StaticMesh is null or RenderData is missing!"));
		return {};
	}
	
	FStaticMeshLODResources& LODResource = Mesh->GetRenderData()->LODResources[0];
	const FPositionVertexBuffer& VertexBuffer = LODResource.VertexBuffers.PositionVertexBuffer;
    TArray<FVector3f> Vertices;
	Vertices.Reserve(VertexBuffer.GetNumVertices());

	for (uint32 i = 0; i < VertexBuffer.GetNumVertices(); i++)
	{
		const FVector3f& VertexPosition = VertexBuffer.VertexPosition(i);
		Vertices.Add(VertexPosition);
	}

	if (bIgnoreTranslate)
		NormalizeTranslation(Vertices);
	
	if (bIgnoreScale)
		NormalizeScale(Vertices);

	return Vertices;
}

uint32 HashFVector3fArray(const TArray<FVector3f>& VectorArray, float Precision, float Offset)
{
	TArray<uint32> ProcessedValues;    
	for (const FVector3f& Vec : VectorArray)
	{
		ProcessedValues.Add(FMath::RoundToInt((Vec.X + Offset) / Precision));
		ProcessedValues.Add(FMath::RoundToInt((Vec.Y + Offset) / Precision));
		ProcessedValues.Add(FMath::RoundToInt((Vec.Z + Offset) / Precision));
	}
    
	return FCrc::MemCrc32(ProcessedValues.GetData(), ProcessedValues.Num() * sizeof(uint32));
}

void FAssetDeduplicateManager::GetCandidateGroup(TMap<int32, FCandidateAssetGroup>& Groups) const
{
	TArray<FAssetData> OutAssetData;
	auto& AssetRegistryModule = FModuleManager::Get().GetModuleChecked<FAssetRegistryModule>("AssetRegistry");
	const IAssetRegistry& AssetRegistry = AssetRegistryModule.GetRegistry();
	if (Settings->SearchType == EAssetDeduplicateSearchType::Level && !Settings->Level.IsNull())
	{
		FARFilter Filter;
		Filter.ClassPaths.Add(UStaticMesh::StaticClass()->GetClassPathName());
		TArray<FAssetData> AssetDatas;
		AssetRegistry.GetAssets(Filter, AssetDatas);
		TMap<FName, FAssetData*> SMPackageNames;
		SMPackageNames.Reserve(AssetDatas.Num());
		for (int i = 0; i < AssetDatas.Num(); i++)
		{
			const FAssetData& AssetData = AssetDatas[i];
			SMPackageNames.Emplace(AssetData.PackageName, &AssetDatas[i]);
		}
		
		FName WorldName = Settings->Level.ToSoftObjectPath().GetLongPackageFName();
		TSet<FName> DependencySet = {WorldName};
		TArray<FName> PackageNamesToProcess = {WorldName};
		TArray<FAssetIdentifier> AssetDependencies;
		while (PackageNamesToProcess.Num() > 0)
		{
			const FName PackageName = PackageNamesToProcess.Pop(false);
			AssetDependencies.Reset();
			AssetRegistry.GetDependencies(FAssetIdentifier(PackageName), AssetDependencies);
			for (const FAssetIdentifier& Dependency : AssetDependencies)
			{
				bool bIsAlreadyInSet = false;
				FName NewPackageName = Dependency.PackageName;
				DependencySet.Add(NewPackageName, &bIsAlreadyInSet);
				if (bIsAlreadyInSet == false)
				{
					if (SMPackageNames.Contains(NewPackageName))
					{
						OutAssetData.Add(*SMPackageNames[NewPackageName]);
					}
					PackageNamesToProcess.Add(NewPackageName);
				}
			}
		}
	}
	else
	{
		FARFilter Filter;
		Filter.PackagePaths = Settings->StaticMeshPaths;
		Filter.ClassPaths.Add(UStaticMesh::StaticClass()->GetClassPathName());
		Filter.bRecursivePaths = true;
		AssetRegistry.GetAssets(Filter, OutAssetData);
	}
	
	const int32 TotalNumber = OutAssetData.Num();
	FScopedSlowTask SlowTask(TotalNumber, FText::FromString(TEXT("Start Grouping Assets...")), true);
	SlowTask.MakeDialog(true);
	
	const uint32 GCInterval = Settings->GCInterval;
	for(int i = 0; i < TotalNumber; i++)
	{
		if (i > 0 && i % GCInterval == 0)
		{
			CollectGarbage(RF_NoFlags, true);
			if (SlowTask.ShouldCancel())
				return;
			SlowTask.EnterProgressFrame(GCInterval, FText::FromString(FString::Printf(TEXT("Grouping Assets %d/%d"), i, TotalNumber)));
		}
		
		FAssetData& AssetData = OutAssetData[i];
		const int32 VertexCount = AssetData.GetTagValueRef<int32>(TEXT("Vertices"));
		const int32 TriangleCount = AssetData.GetTagValueRef<int32>(TEXT("Triangles"));
		const uint32 Combine = HashCombine(VertexCount, TriangleCount);
		
		if (!Groups.Contains(Combine))
		{
			FCandidateAssetGroup Group = FCandidateAssetGroup();
			Group.VertexNumber = VertexCount;
			Group.TriangleNumber = TriangleCount;
			Groups.Add(Combine, Group);
		}

		Groups[Combine].Meshes.Add(AssetData);
	}

	for (auto It = Groups.CreateIterator(); It; ++It)
	{
		if (It.Value().Meshes.Num() == 1)
			It.RemoveCurrent();
	}
	
	CollectGarbage(RF_NoFlags, true);
}

void FAssetDeduplicateManager::CompareGroup(TArray<FSameAssetGroup>& Results, const FCandidateAssetGroup& Group)
{
	TArray<TArray<FVector3f>> VertexDataList;
	// TArray<TArray<uint32>> VertexHashList;
	if (Group.Meshes.Num() == 1)
		return;

	for(int i = 0; i < Group.Meshes.Num(); i++)
	{				
		const FAssetData& AssetData = Group.Meshes[i];
		const TArray<FVector3f>& Vectors = ExtractMeshPoints(Cast<UStaticMesh>(AssetData.GetAsset()), Settings->bIgnoreTranslate, Settings->bIgnoreScale);
		VertexDataList.Add(Vectors);
				
		if (i % 100 == 0)
			CollectGarbage(RF_NoFlags, true);
	}

	// int64 SkipNumber = 0;
	TSet<int32> GroupedIndices;
	for(int i = 0; i < VertexDataList.Num(); i++)
	{
		if (GroupedIndices.Contains(i))
			continue;
				
		const TArray<FVector3f>& VertexDataI = VertexDataList[i];
		FSameAssetGroup SameGroup = FSameAssetGroup();
		SameGroup.VertexNumber = Group.VertexNumber; 
		SameGroup.TriangleNumber = Group.TriangleNumber; 
		SameGroup.SameMeshes.Add(Group.Meshes[i].GetSoftObjectPath());

		for(int j = i + 1; j < VertexDataList.Num(); j++)
		{
			if (GroupedIndices.Contains(j))
				continue;
					
			const TArray<FVector3f>& VertexDataJ = VertexDataList[j];
			if (VertexDataI.Num() != VertexDataJ.Num())
				continue;
			
			bool bIsSame = true;
			for(int k = 0; k < VertexDataI.Num(); k++)
			{
				if ((VertexDataI[k] - VertexDataJ[k]).Size() > Settings->Tolerance)
				{
					bIsSame = false;
					break;
				}
			}

			if (bIsSame)
			{
				GroupedIndices.Add(j);
				SameGroup.SameMeshes.Add(Group.Meshes[j].GetSoftObjectPath());
			}
		}

		if (SameGroup.SameMeshes.Num() > 1)
		{
			// UE_LOG(LogTemp, Log, TEXT("Find Same Meshes in Groups %d/%d"), SameGroup.SameMeshes.Num(), VertexDataList.Num());
			Results.Add(SameGroup);
		}
	}
			
	CollectGarbage(RF_NoFlags, true);
}

void FAssetDeduplicateManager::RunDetect()
{
	if (Settings->StaticMeshPaths.Num() == 0)
		return;
	
	TMap<int32, FCandidateAssetGroup> Groups;

	GetCandidateGroup(Groups);

	TArray<FSameAssetGroup>& Results = Settings->ResultGroups;
	Results.Reset();
	{
		FScopedSlowTask SlowTask(Groups.Num(), FText::FromString(TEXT("Processing Groups...")), true);
		SlowTask.MakeDialog(true);

		int32 GroupIndex = 0;
		for (auto Pair : Groups)
		{
			if (SlowTask.ShouldCancel())
				break;
			SlowTask.EnterProgressFrame(1, FText::FromString(FString::Printf(TEXT("Compare in Groups %d/%d"), ++GroupIndex, Groups.Num())));
			CompareGroup(Results, Pair.Value);
		}
	}
	
	Results.Sort([](const FSameAssetGroup& A, const FSameAssetGroup& B)
	{
		return A.SameMeshes.Num() > B.SameMeshes.Num(); 
	});
	
	// write to file
	if (!Settings->OutputCSVPath.FilePath.IsEmpty())
	{
		FString OutputFilePath = FPaths::ConvertRelativePathToFull(*Settings->OutputCSVPath.FilePath);
		FPlatformFileManager::Get().GetPlatformFile().CreateDirectoryTree(*FPaths::GetPath(OutputFilePath));

		TArray<FString> GroupStrings;
		for (const FSameAssetGroup& Group : Results)
		{
			TArray<FString> AssetPaths;
			for (auto Path : Group.SameMeshes)
			{
				AssetPaths.Add(Path.ToString());
			}
			GroupStrings.Add(FString::Join(AssetPaths, TEXT("\n")));
		}
		FFileHelper::SaveStringToFile(FString::Join(GroupStrings, TEXT("\n\n")), *OutputFilePath);
	}
}

void FAssetDeduplicateManager::RunResultFilter()
{
	FScopedSlowTask SlowTask(Settings->ResultGroups.Num(), FText::FromString(TEXT("Filtering...")), true);
	SlowTask.MakeDialog(true);

	uint32 GCCount = 0;
	
	Settings->FilteredGroups.Reset();
	for (const auto& ResultGroup : Settings->ResultGroups)
	{
		SlowTask.EnterProgressFrame(1);
		if (SlowTask.ShouldCancel())
			return;

		if (GCCount > Settings->GCInterval)
		{
			GCCount = 0;
			CollectGarbage(RF_NoFlags, true);
		}
		
		if (ResultGroup.VertexNumber < Settings->MinVertexNumber)
			continue;

		if (ResultGroup.SameMeshes.Num() < 2)
			continue;

		if (Settings->bHasSomeReference)
		{
			const FAssetRegistryModule& AssetRegistryModule = FModuleManager::LoadModuleChecked<FAssetRegistryModule>("AssetRegistry");
			const IAssetRegistry& AssetRegistry = AssetRegistryModule.Get();
			TArray<FAssetDependency> OutReferences;
			FString SettingPath = Settings.IsValid() ? Settings->GetPackage()->GetPathName() : FString();
			int HasReferenceNumber = 0;
			for(int i = 1; i < ResultGroup.SameMeshes.Num(); i++)
			{	
				OutReferences.Reset();
				AssetRegistry.GetReferencers(ResultGroup.SameMeshes[i].GetLongPackageFName(), OutReferences);
				for (auto OutReference : OutReferences)
				{
					if (OutReference.AssetId.PackageName == SettingPath)
						continue;
					HasReferenceNumber++;
					break;
				}
			}
			if (HasReferenceNumber < 2)
				continue;
		}

		if (!Settings->bCompletelySame && !Settings->bOnlyMaterialNotSame)
		{
			Settings->FilteredGroups.Add(ResultGroup);
			continue;
		}
		
		GCCount += ResultGroup.SameMeshes.Num();
		for(int j = 0; j < ResultGroup.SameMeshes.Num(); j++)
		{
			UStaticMesh* StandardMesh = Cast<UStaticMesh>(ResultGroup.SameMeshes[j].TryLoad());
			if (!StandardMesh)
				continue;

			bool bFoundSame = false;		
			for(int i = j + 1; i < ResultGroup.SameMeshes.Num(); i++)
			{
				GCCount++;
				UStaticMesh* StaticMesh = Cast<UStaticMesh>(ResultGroup.SameMeshes[i].TryLoad());
				if (StaticMesh == nullptr)
					continue;

				bool bMaterialNotSame = false;
				if (AreStaticMeshesIdentical(StandardMesh, StaticMesh, bMaterialNotSame))
				{
					if (Settings->bCompletelySame && !bMaterialNotSame ||
						Settings->bOnlyMaterialNotSame && bMaterialNotSame)
					{
						bFoundSame = true;
						break;
					}
				}
			}

			if (bFoundSame)
			{
				Settings->FilteredGroups.Add(ResultGroup);
				break;
			}
		}

	}
}

void FAssetDeduplicateManager::RunReference()
{
	FString FilePath = Settings->OutputCSVPath.FilePath;
	if (FilePath.IsEmpty())
		return;
	FString OutputFilePath = FPaths::ConvertRelativePathToFull(*FilePath);
	FPlatformFileManager::Get().GetPlatformFile().CreateDirectoryTree(*FPaths::GetPath(OutputFilePath));

	TArray<FString> OutputStringArray;
	OutputStringArray.Reserve(Settings->ResultGroups.Num() * 2);
	
	TMap<FString, FString> ObjectTypes;
	{
		int32 TotalNumber = Settings->ResultGroups.Num();
		FScopedSlowTask SlowTask(TotalNumber, FText::GetEmpty(), true);
		SlowTask.MakeDialog(true);
	
		const FAssetRegistryModule& AssetRegistryModule = FModuleManager::LoadModuleChecked<FAssetRegistryModule>("AssetRegistry");
		const IAssetRegistry& AssetRegistry = AssetRegistryModule.Get();
		TArray<FAssetDependency> OutReferences;
		for (const FSameAssetGroup& Group : Settings->ResultGroups)
		{
			SlowTask.EnterProgressFrame(1, FText::FromString(TEXT("Processing Groups")));
			for (const FSoftObjectPath& MeshPath : Group.SameMeshes)
			{
				UStaticMesh* Mesh = Cast<UStaticMesh>(MeshPath.TryLoad());
				if (!Mesh)
					continue;

				OutReferences.Reset();
				AssetRegistry.GetReferencers(MeshPath.GetAssetPath().GetPackageName(), OutReferences);

				if (OutReferences.Num() == 0)
					continue;

				// OutputStringArray.Add(MeshPath.ToString());
				for (const FAssetDependency& AssetDependency : OutReferences)
				{
					if (SlowTask.ShouldCancel())
						return;
				
					if (AssetDependency.AssetId.IsPackage() && !ObjectTypes.Contains(AssetDependency.AssetId.PackageName.ToString()))
					{
						ObjectTypes.Add(AssetDependency.AssetId.PackageName.ToString(), FString());
					}
					else
					{
						UE_LOG(LogTemp, Error, TEXT("there is a reference which is not a package"));
					}
				}
			}
		}
	}
	
	{
		FScopedSlowTask SlowTask2(ObjectTypes.Num(), FText::GetEmpty(), true);
		SlowTask2.MakeDialog(true);
	
		int LoadObjectNumber = 0;
		TArray<FString> Keys;
		ObjectTypes.GetKeys(Keys);
		for(const FString& Key : Keys)
		{
			SlowTask2.EnterProgressFrame(1, FText::FromString(TEXT("Processing Packages")));
			if (SlowTask2.ShouldCancel())
			{
				FFileHelper::SaveStringArrayToFile(OutputStringArray, *FilePath);
				return;
			}
				
			if (LoadObjectNumber % Settings->GCInterval == 0)
				CollectGarbage(RF_NoFlags, true);
		
			UPackage* Package = LoadPackage(nullptr, *Key, 0);
			if (Package)
			{
				UObject* Object = Package->FindAssetInPackage();
				if (Object)
				{
					ObjectTypes[Key] = Object->GetClass()->GetName();
					LoadObjectNumber++;
					OutputStringArray.Add(FString::Printf(TEXT("%s,%s"), *Key, *Object->GetClass()->GetName()));
					continue;
				}	
				UE_LOG(LogTemp, Error, TEXT("%s is not a object"), *Key);
			}	
		}
	}
	
	FFileHelper::SaveStringArrayToFile(OutputStringArray, *FilePath);
}

void FAssetDeduplicateManager::ReplaceStaticMeshComponent(UStaticMesh* ReplaceMesh, const TArray<UStaticMesh*>& Others, UObject* ActorComponent)
{
	UStaticMeshComponent* StaticMeshComponent = Cast<UStaticMeshComponent>(ActorComponent);
	UStaticMesh* StaticMesh = StaticMeshComponent->GetStaticMesh();
	if (!StaticMesh || StaticMesh == ReplaceMesh)
		return;

	if (Others.Find(StaticMesh) >= 0)
	{
		UE_LOG(LogTemp, Log, TEXT("[AssetDeduplicate] Replace %s"), *StaticMesh->GetPathName());
		StaticMeshComponent->SetStaticMesh(ReplaceMesh);
		if (ReplaceMesh->GetStaticMaterials() != StaticMesh->GetStaticMaterials() &&
			StaticMeshComponent->GetNumOverrideMaterials() == 0)
		{
			for(int i = 0; i < ReplaceMesh->GetStaticMaterials().Num(); i++)
			{
				StaticMeshComponent->SetMaterial(i, ReplaceMesh->GetMaterial(i));
			}
		}

		ActorComponent->MarkPackageDirty();		
	}
}

void FAssetDeduplicateManager::DoReplace(UStaticMesh* ReplaceMesh, TArray<FSoftObjectPath> OtherMeshPaths)
{
	if (!ReplaceMesh)
	{
		UE_LOG(LogTemp, Error, TEXT("ReplaceMesh is null"));
		return;
	}
	
	bool bContainReplaceMesh = false;
	TArray<UStaticMesh*> Others;
	for (auto Path : OtherMeshPaths)
	{
		UStaticMesh* Mesh = Cast<UStaticMesh>(Path.TryLoad());
		if (Mesh == ReplaceMesh)
		{
			bContainReplaceMesh = true;
			continue;
		}
		Others.Add(Mesh);
	}

	if (!bContainReplaceMesh)
	{
		UE_LOG(LogTemp, Error, TEXT("ReplaceMesh not in OtherMeshPaths"));
		return;
	}
	
	TArray<UObject*> CompletelySames;
	TArray<UObject*> MaterialNotSames;
	TArray<UObject*> PivotNotSames;	
	
	const TArray<FVector3f>& StandardVertices = ExtractMeshPoints(ReplaceMesh, false, false);
	
	for(int i = Others.Num() - 1; i >= 0; i--)
	{
		const TArray<FVector3f>& Vectors = ExtractMeshPoints(Others[i], false, false);
		if (Vectors.Num() != StandardVertices.Num())
			continue;

		bool bPivotNotSame = false;
		for(int j = 0; j < Vectors.Num(); j++)
		{
			if ((Vectors[j] - StandardVertices[j]).Size() > Settings->Tolerance)
			{
				PivotNotSames.Add(Others[i]);
				bPivotNotSame = true;
				break;
			}
		}
		if (bPivotNotSame)
			continue;

		bool bOutMaterialNotSame = false;
		if (AreStaticMeshesIdentical(ReplaceMesh, Others[i], bOutMaterialNotSame))
		{
			if (bOutMaterialNotSame)
			{
				MaterialNotSames.Add(Others[i]);
			}
			else
			{
				CompletelySames.Add(Others[i]);
			}
		}
	}

	TSharedRef<SWindow> NewWindow = SNew(SWindow)
		.ClientSize(FVector2D(400, 400))
		.SupportsMaximize(false)
		.SupportsMinimize(false);
	
	bool bDelete = false;
	TSet<UObject*> ToDelete = TSet(CompletelySames); 
	TSharedRef<SVerticalBox> List = SNew(SVerticalBox);
	for (UStaticMesh* Mesh : Others)
	{
		if (Mesh == ReplaceMesh)
			continue;

		List->AddSlot()
		[
			SNew(SHorizontalBox)
			+ SHorizontalBox::Slot()
			.AutoWidth()
			[
				SNew(SCheckBox)
				// .IsEnabled_Lambda([&PivotNotSames, Mesh]()
				// {
				// 	return !PivotNotSames.Contains(Mesh);
				// })
				.IsChecked_Lambda([&ToDelete, Mesh]()
				{
					return ToDelete.Contains(Mesh) ? ECheckBoxState::Checked : ECheckBoxState::Unchecked;
				})
				.OnCheckStateChanged_Lambda([&ToDelete, Mesh](ECheckBoxState State)
				{
					if (State == ECheckBoxState::Checked)
						ToDelete.Add(Mesh);
					else
						ToDelete.Remove(Mesh);
				})
			]

			+ SHorizontalBox::Slot()
			[
				SNew(STextBlock)
				.Text(FText::FromString((PivotNotSames.Contains(Mesh) ? TEXT("(Pivot not save) " : TEXT(""))) + Mesh->GetPathName()))
			]
		];
	}

	NewWindow->SetContent(
		SNew(SVerticalBox)

		+ SVerticalBox::Slot()
		.AutoHeight()
		[
			SNew(STextBlock)
			.Text(LOCTEXT("KeepLabel", "Keep:"))
		]

		+ SVerticalBox::Slot()
		.AutoHeight()
		[
			SNew(STextBlock)
			.Text(FText::FromString(ReplaceMesh->GetPathName()))
		]
		
		+ SVerticalBox::Slot()
		.AutoHeight()
		[
			SNew(STextBlock)
			.Text(LOCTEXT("DeletesLabel", "\nDeletes:"))
		]
		
		+ SVerticalBox::Slot()
		.AutoHeight()
		[
			List
		]

		+ SVerticalBox::Slot()
		.AutoHeight()
		.HAlign(HAlign_Right)
		[
			SNew(SHorizontalBox)
			
			+ SHorizontalBox::Slot()
			.AutoWidth()
			.HAlign(HAlign_Right)
			[
				SNew(SButton)
				.Text(LOCTEXT("DeleteAndReplaceLabel", "Replace(Delete)"))
				.OnClicked_Lambda([&NewWindow, &bDelete](){
					bDelete = true;
					NewWindow->RequestDestroyWindow();
					return FReply::Handled();
				})
			]
			
			+ SHorizontalBox::Slot()
			.AutoWidth()
			.HAlign(HAlign_Right)
			[
				SNew(SButton)
				.Text(LOCTEXT("DeleteCancelLabel", "Cancel"))
				.OnClicked_Lambda([&NewWindow](){
					NewWindow->RequestDestroyWindow();
					return FReply::Handled();
				})
			]
		]
		
	);

	FSlateApplication::Get().AddModalWindow(NewWindow, nullptr);
	
	UE_LOG(LogTemp, Log, TEXT("[AssetDeduplicate] %d completely same meshes replaced:"), ToDelete.Num());
	if (ToDelete.Num() > 0 && bDelete)
	{
		for (auto Other : ToDelete)
		{
			UE_LOG(LogTemp, Log, TEXT("[AssetDeduplicate] \t%s"), *Other->GetPathName());
		}
		TArray<UObject*> DeleteArray = ToDelete.Array();
		ObjectTools::FConsolidationResults ConsResults = ObjectTools::ConsolidateObjects(ReplaceMesh, DeleteArray);

		// If the consolidation went off successfully with no failed objects, prompt the user to checkout/save the packages dirtied by the operation
		if ( ConsResults.DirtiedPackages.Num() > 0 && ConsResults.FailedConsolidationObjs.Num() == 0)
		{
			FEditorFileUtils::FPromptForCheckoutAndSaveParams SaveParams;
			SaveParams.bCheckDirty = false;
			SaveParams.bPromptToSave = true;
			SaveParams.bIsExplicitSave = true;

			FEditorFileUtils::PromptForCheckoutAndSave( ObjectPtrDecay(ConsResults.DirtiedPackages), SaveParams);
		}
		// If the consolidation resulted in failed (partially consolidated) objects, do not save, and inform the user no save attempt was made
		else if ( ConsResults.FailedConsolidationObjs.Num() > 0)
		{
			UE_LOG(LogTemp, Warning, TEXT("[AssetDeduplicate] Consolidation failed for %d objects"), ConsResults.FailedConsolidationObjs.Num());
		}
	}
	
	CollectGarbage(RF_NoFlags, true);
}

void FAssetDeduplicateManager::SeeMoreDetails(FSameAssetGroup* Data)
{
	if (Data == nullptr)
		return;
	FSameAssetGroup& Group = *Data;
	
	Group.References.Reset();
	UStaticMesh* ReplaceMesh = Group.ReplaceMesh;
	
	FString SettingPath = Settings.IsValid() ? Settings->GetPackage()->GetPathName() : FString();
	for (auto SameMesh : Group.SameMeshes)
	{
		const FAssetRegistryModule& AssetRegistryModule = FModuleManager::LoadModuleChecked<FAssetRegistryModule>("AssetRegistry");
		const IAssetRegistry& AssetRegistry = AssetRegistryModule.Get();
		TArray<FAssetDependency> OutReferences;
		AssetRegistry.GetReferencers(SameMesh.GetLongPackageFName(), OutReferences);
		FSameAssetReference& Reference = Group.References.AddDefaulted_GetRef();
		Reference.Asset = SameMesh;
		for (auto OutReference : OutReferences)
		{
			if (OutReference.AssetId.PackageName == SettingPath)
				continue;
			Reference.ReferenceNumber++;	
		}
		UStaticMesh* OtherMesh = Cast<UStaticMesh>(SameMesh.TryLoad());
		if (OtherMesh)
		{
			bool bOutOnlyMaterialNotSame = false;
			if (this->AreStaticMeshesIdentical(ReplaceMesh, OtherMesh, bOutOnlyMaterialNotSame, &Reference.Message))
			{
				if (bOutOnlyMaterialNotSame)
				{
					Reference.bHasSameMaterial = true;
					Reference.Message = TEXT("材质不同, 其他都相同");
				}
				else
					Reference.bCompletelySame = true;
			}
			else
			{
				Reference.bHasSameMaterial = false;
				Reference.bCompletelySame = false;
			}
		}
	}
}

bool FAssetDeduplicateManager::AreStaticMeshesIdentical(UStaticMesh* MeshA, UStaticMesh* MeshB, bool& bOutOnlyMaterialNotSame, FString* OutMessage)
{
    if (!MeshA || !MeshB) return false;
	FString TempMessage;
	if (OutMessage == nullptr)
	{
		OutMessage = &TempMessage;
	}		
	
	UE_LOG(LogTemp, Log, TEXT("[AssetDeduplicate] Compare Between: \n%s and \n%s"), *MeshA->GetPathName(), *MeshB->GetPathName());

    const float Tolerance = Settings.IsValid() ? Settings->Tolerance : 0.0001;
	
	// 比较LOD数量
	if (MeshA->GetNumLODs() != MeshB->GetNumLODs())
	{
		*OutMessage = TEXT("LOD 不同");
		UE_LOG(LogTemp, Warning, TEXT("[AssetDeduplicate] Meshes have different LODs"));
		return false;
	}

    // 比较材质
    if (MeshA->GetStaticMaterials() != MeshB->GetStaticMaterials())
    {
    	*OutMessage = TEXT("材质不同");
	    bOutOnlyMaterialNotSame = true;
    }
	
    // 比较LOD的顶点数据
    for (int32 LODIndex = 0; LODIndex < MeshA->GetNumLODs(); ++LODIndex)
    {
        const FStaticMeshLODResources& LODResourcesA = MeshA->GetRenderData()->LODResources[LODIndex];
        const FStaticMeshLODResources& LODResourcesB = MeshB->GetRenderData()->LODResources[LODIndex];

        if (LODResourcesA.VertexBuffers.PositionVertexBuffer.GetNumVertices() != 
            LODResourcesB.VertexBuffers.PositionVertexBuffer.GetNumVertices())
        {
        	UE_LOG(LogTemp, Warning, TEXT("[AssetDeduplicate] Meshes have different number of vertices"));
    		*OutMessage = TEXT("LOD的顶点数不同");
        	return false;
        }

        // 比较顶点位置
        for (uint32 VertexIndex = 0; VertexIndex < LODResourcesA.VertexBuffers.PositionVertexBuffer.GetNumVertices(); ++VertexIndex)
        {
            if ((LODResourcesA.VertexBuffers.PositionVertexBuffer.VertexPosition(VertexIndex) - 
                LODResourcesB.VertexBuffers.PositionVertexBuffer.VertexPosition(VertexIndex)).Size() > Tolerance)
            {
            	UE_LOG(LogTemp, Warning, TEXT("[AssetDeduplicate] Meshes have different vertex positions"));
    			*OutMessage = TEXT("LOD的顶点位置不同");
            	return false;
            }
        }

        // 比较顶点颜色
        const FColor* ColorBufferA = static_cast<const FColor*>(LODResourcesA.VertexBuffers.ColorVertexBuffer.GetVertexData());
        const FColor* ColorBufferB = static_cast<const FColor*>(LODResourcesB.VertexBuffers.ColorVertexBuffer.GetVertexData());
        for (uint32 VertexIndex = 0; VertexIndex < LODResourcesA.VertexBuffers.ColorVertexBuffer.GetNumVertices(); ++VertexIndex)
        {
            if (ColorBufferA[VertexIndex] != ColorBufferB[VertexIndex])
            {
	            UE_LOG(LogTemp, Warning, TEXT("[AssetDeduplicate] Meshes have different vertex colors"));
    			*OutMessage = TEXT("LOD的顶点色不同");
	            return false;
            }
        }

        // 比较法线
        const FStaticMeshVertexBuffer& VertexBufferA = LODResourcesA.VertexBuffers.StaticMeshVertexBuffer;
        const FStaticMeshVertexBuffer& VertexBufferB = LODResourcesB.VertexBuffers.StaticMeshVertexBuffer;

        for (uint32 VertexIndex = 0; VertexIndex < VertexBufferA.GetNumVertices(); ++VertexIndex)
        {
            if ((VertexBufferA.VertexTangentX(VertexIndex) - VertexBufferB.VertexTangentX(VertexIndex)).Size() > Tolerance ||
                (VertexBufferA.VertexTangentY(VertexIndex) - VertexBufferB.VertexTangentY(VertexIndex)).Size() > Tolerance ||
                (VertexBufferA.VertexTangentZ(VertexIndex) - VertexBufferB.VertexTangentZ(VertexIndex)).Size() > Tolerance)
            {
	            UE_LOG(LogTemp, Warning, TEXT("[AssetDeduplicate] Meshes have different vertex tangents"));
    			*OutMessage = TEXT("LOD的三角面不同");
	            return false;
            }
        }
    }

    // 比较布尔设置
    if (MeshA->IsNaniteEnabled() != MeshB->IsNaniteEnabled() ||
    	MeshA->NaniteSettings != MeshB->NaniteSettings)
    {
    	UE_LOG(LogTemp, Warning, TEXT("[AssetDeduplicate] Meshes have different Nanite settings"));
    	*OutMessage = TEXT("Nanite设置不同");
        return false;
    }

	UE_LOG(LogTemp, Log, TEXT("[AssetDeduplicate] Meshes are identical, materials are%s same"), bOutOnlyMaterialNotSame ? TEXT(" not") : TEXT(""));
    return true;
}
#undef LOCTEXT_NAMESPACE