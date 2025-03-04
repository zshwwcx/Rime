#pragma once

struct FCandidateAssetGroup;
struct FSameAssetGroup;
class UAssetDeduplicateSettings;

class FAssetDeduplicateManager : public FGCObject, FTickableEditorObject
{
public:
	FAssetDeduplicateManager();
	virtual ~FAssetDeduplicateManager() override;
	
	virtual void AddReferencedObjects(FReferenceCollector& Collector) override;
	virtual FString GetReferencerName() const override;
	virtual TStatId GetStatId() const override;
	virtual void Tick(float DeltaTime) override;

	TArray<FVector3f> ExtractMeshPoints(UStaticMesh* Mesh, bool bIgnoreTranslate, bool bIgnoreScale) const;
	void RunDetect();
	void RunResultFilter();
	void RunReference();
	void DoReplace(UStaticMesh* ReplaceMesh, TArray<FSoftObjectPath> OtherMeshPaths);
	void SeeMoreDetails(FSameAssetGroup* Data);

	TWeakObjectPtr<UAssetDeduplicateSettings> Settings;

private:
	bool bRunning;
	TArray<FAssetData> AssetList;
	TArray<FCandidateAssetGroup> CandidateGroups;
	int CurrentIndex;

	void GetCandidateGroup(TMap<int32, FCandidateAssetGroup>& Groups) const;
	void CompareGroup(TArray<FSameAssetGroup>& Results, const FCandidateAssetGroup& Group);
	
	static void ReplaceStaticMeshComponent(UStaticMesh* ReplaceMesh, const TArray<UStaticMesh*>& Others, UObject* ActorComponent);
	bool AreStaticMeshesIdentical(UStaticMesh* MeshA, UStaticMesh* MeshB, bool& bOutOnlyMaterialNotSame, FString* OutMessage = nullptr);
};
