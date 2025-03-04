#pragma once
#include "CoreMinimal.h"
#include "Blueprint/UserWidgetPool.h"
#include "Components/CanvasPanel.h"
#include "C7MapTagLayerV2.generated.h"

UENUM(BlueprintType)
enum class EMapTagType : uint8
{
	None,
	Static,
	FollowActor,
	Dynamic,
};

UENUM(BlueprintType)
enum class EMapEdgeType : uint8
{
	None,
	ShowOnEdge
};

UENUM(BlueprintType)
enum class EMapShowTypeOnEdge : uint8
{
	ShowOnEdgeByCircle,
	ShowOnEdgeByRectangle
};

UENUM(BlueprintType)
enum class EMapDisplayState : uint8
{
	None,
	Edge,
	Center
};

UENUM(BlueprintType)
enum class EMapRotateType : uint8
{
	Identity,
	RotateByActor
};

USTRUCT(BlueprintType)
struct FMapTagInfo
{
	GENERATED_BODY()
	UPROPERTY(EditAnyWhere, BlueprintReadWrite)
	FString TaskID = "";

	UPROPERTY(EditAnyWhere, BlueprintReadWrite)
	EMapTagType MapTagType = EMapTagType::Static;

	UPROPERTY(EditAnyWhere, BlueprintReadWrite)
	EMapEdgeType MapEdgeType = EMapEdgeType::None;

	//reg Static
	UPROPERTY(EditAnyWhere, BlueprintReadWrite)
	FVector StaticLocation;
	//end reg

	//reg FollowActor
	UPROPERTY(EditAnyWhere, BlueprintReadWrite)
	TWeakObjectPtr<AActor> Follower;
	//end reg
	UPROPERTY(EditAnyWhere, BlueprintReadWrite)
	EMapRotateType MapRotateType = EMapRotateType::Identity;

	UPROPERTY(EditAnyWhere, BlueprintReadWrite)
	TSubclassOf<UUserWidget> TemplateWidgetType = nullptr;


	UPROPERTY(EditAnyWhere, BlueprintReadWrite)
	int32 TypeID = -1;

	//这两个属性只有C++需要
	TObjectPtr<UUserWidget> MyUserWidget = nullptr;
	EMapDisplayState DisplayState = EMapDisplayState::None;

	UPROPERTY(EditAnyWhere, BlueprintReadWrite)
	FVector2D ShowRatioInterval = FVector2D(.0f, 1.0f);

	UPROPERTY(EditAnyWhere, BlueprintReadWrite)
	int32 ZOrder = 0;

	UPROPERTY(EditAnyWhere, BlueprintReadWrite)
	FVector2D Offset;

};

USTRUCT(BlueprintType)
struct FMapEdgeRotateInfo {

	GENERATED_BODY()

	UPROPERTY()
	FString TaskID = "";

	UPROPERTY()
	TWeakObjectPtr<UWidget> RotateWidget = nullptr;

	UPROPERTY()
	float Offset = 90.0f;

	FMapEdgeRotateInfo() = default;

	FMapEdgeRotateInfo(FString TaskID, UWidget* _RotateWidget, float _Offset) : TaskID(TaskID), RotateWidget(_RotateWidget),
		Offset(_Offset) {}
};


DECLARE_DYNAMIC_MULTICAST_DELEGATE_FourParams(FOnMapTagInitializedDynamic, UUserWidget*, Widget, int32, TypeID, FString, TaskID, bool, bInEdge);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_ThreeParams(FOnMapTagRemovedDynamic, UUserWidget*, Widget, int32, TypeID, FString, TaskID);

UCLASS(meta = (ShortTooltip = "Specialized for calculate transform of Map Tags, should only be used in MapSystem"))
class UC7MapTagLayerV2 : public UCanvasPanel, public FTickableGameObject
{
	GENERATED_BODY()
public:
	UC7MapTagLayerV2(const FObjectInitializer& Initializer);

	bool bViewportStatChanged = false;
	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	FVector CameraLocation;
	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	FRotator CameraRotation;
	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	FVector2D CameraViewportSize;
	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	float ViewportScale = 1.0f;
	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	FVector2D CurrentCenterLocation;
	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	float CurrentRotationByClockWise = .0f;
	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	float ConstraintRadius;
	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	FVector4 ConstraintRectangle;
	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	EMapShowTypeOnEdge PanelMapEdgeType = EMapShowTypeOnEdge::ShowOnEdgeByRectangle;

	UFUNCTION()
	void SetCameraLocation(FVector& _CameraLocation) {
		if (!(CameraLocation - _CameraLocation).IsNearlyZero())
		{
			bViewportStatChanged = true;
		}
		CameraLocation = _CameraLocation;
	}
	UFUNCTION()
	FVector GetCameraLocation() const {
		return CameraLocation;
	}
	UFUNCTION()
	void SetCameraRotation(FRotator& _CameraRotation) {
		if (!(CameraRotation - _CameraRotation).IsNearlyZero())
		{
			bViewportStatChanged = true;
		}
		CameraRotation = _CameraRotation;
	}
	UFUNCTION()
	FRotator GetCameraRotation() const {
		return CameraRotation;
	}
	UFUNCTION()
	void SetCameraViewportSize(FVector2D& _CameraViewportSize) {
		if (!(CameraViewportSize - _CameraViewportSize).IsNearlyZero())
		{
			bViewportStatChanged = true;
		}
		CameraViewportSize = _CameraViewportSize;
	}
	UFUNCTION()
	FVector2D GetCameraViewportSize() const {
		return CameraViewportSize;
	}

	UFUNCTION()
	void SetViewportScale(float _ViewportScale);
	UFUNCTION()
	float GetViewportScale() const {
		return ViewportScale;
	}
	UFUNCTION()
	void SetCurrentCenterLocation(FVector2D _CurrentCenterLocation);
	UFUNCTION()
	FVector2D GetCurrentCenterLocation() const {
		return CurrentCenterLocation;
	}

private:

	void AdaptOverlappingCircles();

	virtual void Tick(float DeltaTime) override;

	virtual bool IsTickable() const override { return true; }

	virtual TStatId GetStatId() const override {
		return GetStatID();
	}

	UPROPERTY(Transient)
	FUserWidgetPool EntryWidgetPool;

public:
	//UFUNCTION()
	TObjectPtr<UUserWidget> GetWidgetFromPool(TSubclassOf<UUserWidget> WidgetType);

	//UFUNCTION()
	void ReturnWidgetToPool(TObjectPtr<UUserWidget> UserWidget);

	virtual void ReleaseSlateResources(bool  bReleaseChildren) override;


	//几个上下文之间的关系：WidgetOffset [0,1]x[0,1],只是CanvasPanel上Slot的范围
	//WorldOffset, 在相机平面上的Offset, 值域CameraViewportSize
	//WorldLocation，原本的世界位置[-\Infinity, \Infinity]^3
	UFUNCTION(BlueprintCallable)
	FVector2D GetWidgetOffsetByMapTagInfo(FMapTagInfo MapTagInfo);

	UFUNCTION(BlueprintCallable)
	FVector2D GetWidgetPosByMapTagInfo(FMapTagInfo MapTagInfo);

	UFUNCTION(BlueprintCallable)
	FVector2D GetWidgetOffsetByWorldLocation(FVector Location);
	UFUNCTION(BlueprintCallable)
	FVector2D GetWorldOffsetByWorldLocation(FVector Location);
	UFUNCTION(BlueprintCallable)
	FVector2D DeprojectWidgetOffsetToWorldLocation(FVector2D WidgetOffset);

	UFUNCTION(BlueprintCallable)
	FVector2D GetWidgetOffsetByCenterAndWorldLocation(FVector& Location);
	UFUNCTION(BlueprintCallable)
	TArray<FString> ReqTaskNearByByTaskID(FString TaskID, float ToleranceDistance);
	UFUNCTION(BlueprintCallable)
	float GetWidgetShearByWorldRotation(const FRotator& Rotation);
	UFUNCTION(BlueprintCallable)
	float GetWidgetShearByTaskID(FString TaskID);

	UFUNCTION(BlueprintCallable)
	FVector2D GetWidgetPosByTaskID(FString TaskID);

	UFUNCTION(BlueprintCallable)
	FVector2D CircleConvert(FVector2D WidgetOffset)
	{
		FVector2D Origin(0.5f, 0.5f);
		FVector2D ConvertedOffset = ConstraintRadius * (WidgetOffset - Origin).GetSafeNormal() + Origin;
		return ConvertedOffset;
	}
	UFUNCTION(BlueprintCallable)
	FVector2D RectangleConvert(FVector2D WidgetOffset)
	{
		FVector2D Origin(0.5f, 0.5f);
		FVector2D DirectionVec = (WidgetOffset - Origin).GetSafeNormal();
		DirectionVec = DirectionVec.X < (-0.5f + ConstraintRectangle.X) ? (-0.5f + ConstraintRectangle.X) / DirectionVec.X * DirectionVec :
			DirectionVec.Y >(0.5f - ConstraintRectangle.Y) ? (0.5f - ConstraintRectangle.Y) / DirectionVec.Y * DirectionVec :
			DirectionVec.X > (0.5f - ConstraintRectangle.Z) ? (0.5f - ConstraintRectangle.Z) / DirectionVec.X * DirectionVec :
			(-0.5f + ConstraintRectangle.W) / DirectionVec.Y * DirectionVec;
		FVector2D ConvertedOffset = DirectionVec + Origin;
		return ConvertedOffset;
	}
	UFUNCTION(BlueprintCallable)
	void SetData(TMap<FString, FMapTagInfo> _MapTagInfoData);

	UFUNCTION(BlueprintCallable)
	void SetTaskShowEdgeType(FString TaskID, EMapEdgeType ShowOnEdgeType);

	UFUNCTION(BlueprintCallable)
	void RetargetTagLocation(FString TaskID, FVector Location);

	UFUNCTION(BlueprintCallable)
	void ReSetTaskTypeToFollowActor(FString TaskID, AActor* Actor);

	UFUNCTION(BlueprintCallable)
	void ReSetTaskTypeToStatic(FString TaskID);

	UFUNCTION(BlueprintCallable)
	void AddSingleTag(FMapTagInfo _MapTagInfo);

	UFUNCTION(BlueprintCallable)
	void ClearAllTags();

	UFUNCTION(BlueprintCallable)
	void BatchAddTags(TMap<FString, FMapTagInfo> _MapTagInfos);

	UFUNCTION(BlueprintCallable)
	void BatckRemoveTags(TArray<FString> TaskIDs);

	UFUNCTION(BlueprintCallable)
	void RemoveSingleTag(FString TaskID);

	void UpdateSingleTagByID(FString TaskID);

	UPROPERTY(Transient)
	TMap <FString, FMapTagInfo> MapTagInfoData;

	UPROPERTY(Transient)
	TArray<FString> EdgeList;

	UPROPERTY(Transient)
	TArray<FString> PendingUpdateList;

	UPROPERTY(Transient)
	TArray<FString> PendingRemoveList;

	UPROPERTY(Transient)
	TArray<FString> FollowUpdateList;

	UPROPERTY(Transient)
	TMap<FString, FMapEdgeRotateInfo> RotateWidgetList;

	UPROPERTY(Transient)
	TWeakObjectPtr<AActor> CenterActor;//小地图中使用，中心位置由Actor位置决定

	UFUNCTION(BlueprintCallable)
	void SetCenterActor(AActor* _CenterActor);

	UFUNCTION(BlueprintCallable)
	void ResetCenterActor();

	UFUNCTION(BlueprintCallable)
	void RegisterWidgetRotateInEdge(FString TaskID, UWidget* Widget, float Offset);

	UFUNCTION(BlueprintCallable)
	void UnRegisterWidgetRotateInEdge(FString TaskID);

	void ResetEdgeWidgetShear(FMapEdgeRotateInfo& MapEdgeRotateInfo);

	UPROPERTY(BlueprintAssignable, Category = Events)
	FOnMapTagInitializedDynamic OnMapTagInitializedDynamic;
	UPROPERTY(BlueprintAssignable, Category = Events)
	FOnMapTagRemovedDynamic OnMapTagRemovedDynamic;

	bool InRectangle(FVector2D WidgetOffset)
	{
		return WidgetOffset.X > ConstraintRectangle.X && WidgetOffset.Y > ConstraintRectangle.Y && WidgetOffset.X < (1.0f - ConstraintRectangle.Z) && WidgetOffset.Y < (1.0f - ConstraintRectangle.W);
	}

	bool InCircle(FVector2D WidgetOffset)
	{
		return (WidgetOffset - FVector2D(0.5f, 0.5f)).Length() < ConstraintRadius;
	}
	bool static InCenter(FVector2D WidgetOffset)
	{
		return WidgetOffset.X > 0.0f && WidgetOffset.Y > 0.0f && WidgetOffset.X < 1.0f && WidgetOffset.Y < 1.0f;
	}

	EMapDisplayState GetNewMapDisplayState(FMapTagInfo& MapTagInfoData);

};