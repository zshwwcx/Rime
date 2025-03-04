#pragma once

#include "CoreMinimal.h"
#include "UObject/Object.h"
#include "AssetDeduplicateSettings.generated.h"

class FAssetDeduplicateManager;

USTRUCT()
struct FCandidateAssetGroup
{
	GENERATED_BODY()
	
	UPROPERTY()
	uint32 VertexNumber = 0;

	UPROPERTY()
	uint32 TriangleNumber = 0;
	
	UPROPERTY()
	TArray<FAssetData> Meshes;
};

USTRUCT()
struct FSameAssetReference
{
	GENERATED_BODY()
	
	UPROPERTY(EditAnywhere)
	FSoftObjectPath Asset;

	UPROPERTY(EditAnywhere)
	int32 ReferenceNumber = 0;

	UPROPERTY(EditAnywhere)
	bool bCompletelySame = false;

	UPROPERTY(EditAnywhere)
	bool bHasSameMaterial = false;

	UPROPERTY(VisibleAnywhere)
	FString Message;
};

USTRUCT()
struct FSameAssetGroup
{
	GENERATED_BODY()

	/** 顶点数量 */
	UPROPERTY(EditAnywhere)
	int32 VertexNumber = 0;

	/** 面数 */
	UPROPERTY(EditAnywhere)
	int32 TriangleNumber = 0;

	/** 顶点数据相同的 Mesh */
	UPROPERTY(EditAnywhere)
	TArray<FSoftObjectPath> SameMeshes;

	UPROPERTY(EditAnywhere, meta=(ShowOnlyInnerProperties, ShowInnerProperties))
	TArray<FSameAssetReference> References;
	
	/** 选择并使用该 Mesh 替换掉其他 Mesh */
	UPROPERTY(Transient, EditAnywhere)
	TObjectPtr<UStaticMesh> ReplaceMesh;
};

UENUM()
enum class EAssetDeduplicateSearchType
{
	Paths UMETA(DisplayName="按路径搜索"),
	Level UMETA(DisplayName="按场景搜索"),
};

UCLASS()
class UAssetDeduplicateSettings : public UObject
{
	GENERATED_BODY()

public:
	UAssetDeduplicateSettings(){};

	UPROPERTY(EditAnywhere, Category = "Settings")
	EAssetDeduplicateSearchType SearchType = EAssetDeduplicateSearchType::Level;
	
	/** 静态模型资源路径 */
	UPROPERTY(EditAnywhere, Category = "Settings", meta=(EditCondition="SearchType == EAssetDeduplicateSearchType::Paths", EditConditionHides))
	TArray<FName> StaticMeshPaths;

	/** 所选的场景 */
	UPROPERTY(EditAnywhere, Category = "Settings", meta=(EditCondition="SearchType == EAssetDeduplicateSearchType::Level", EditConditionHides))
	TSoftObjectPtr<UWorld> Level;
	
	/** 对 Pivot 位移进行归一化 */
	UPROPERTY(EditAnywhere, Category = "Settings")
	bool bIgnoreTranslate = false;

	/** 对 Pivot Scale 进行归一化 */
	UPROPERTY(EditAnywhere, Category = "Settings")
	bool bIgnoreScale = false;
	
	/** 精度: 比较两个 float 允许的误差 */
	UPROPERTY(EditAnywhere, Category = "Settings", AdvancedDisplay)
	float Tolerance = 0.0001;
	
	/** 加载 GCInterval 个资产之后, 会进行一次强制GC, 防止内存爆炸. */
	UPROPERTY(EditAnywhere, Category = "Settings", AdvancedDisplay)
	uint32 GCInterval = 100;
	
	UPROPERTY(EditAnywhere, Category = "Settings", AdvancedDisplay)
	FFilePath OutputCSVPath;
	
	UPROPERTY(EditAnywhere, Category = "Results", meta = (Expand))
	TArray<FSameAssetGroup> ResultGroups;

	/** 筛选顶点数大于值的Group */
	UPROPERTY(EditAnywhere, Category = "Filtering Results")
	int32 MinVertexNumber = 0;

	/** Group内是否有仅材质不相同的资产 */
	UPROPERTY(EditAnywhere, Category = "Filtering Results")
	bool bOnlyMaterialNotSame = false;

	/** Group内是否有完全相同的资产 */
	UPROPERTY(EditAnywhere, Category = "Filtering Results")
	bool bCompletelySame = false;

	/** 至少有两个资产有被引用 */
	UPROPERTY(EditAnywhere, Category = "Filtering Results")
	bool bHasSomeReference = true;
	
	UPROPERTY(EditAnywhere, Category = "Filtering Results")
	TArray<FSameAssetGroup> FilteredGroups;
	
	TWeakPtr<FAssetDeduplicateManager> Manager;
};