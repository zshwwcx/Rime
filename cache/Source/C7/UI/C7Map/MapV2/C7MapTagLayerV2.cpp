#include "C7MapTagLayerV2.h"
#include "Components/CanvasPanelSlot.h"
#include "Kismet/KismetMathLibrary.h"

UC7MapTagLayerV2::UC7MapTagLayerV2(const FObjectInitializer& Initializer)
	: Super(Initializer), EntryWidgetPool(*this)
{

}

void UC7MapTagLayerV2::AdaptOverlappingCircles()
{
	EdgeList.Sort([&](const FString& A, const FString& B) {
		return MapTagInfoData[A].Offset.X <= MapTagInfoData[B].Offset.X;
	});
	for (int I = 0; I < EdgeList.Num(); I++)
	{
		auto TaskA = EdgeList[I];
		FMapTagInfo& TagInfoDataA = MapTagInfoData[TaskA];
		for (int J = I + 1; J < EdgeList.Num(); J++)
		{
			auto TaskB = EdgeList[J];
			FMapTagInfo& TagInfoDataB = MapTagInfoData[TaskB];
			auto SquaredLen = (TagInfoDataA.Offset - TagInfoDataB.Offset).SquaredLength();
			//UE_LOG(LogTemp, Warning, TEXT("SquaredLen %f"), SquaredLen);
			auto NearSquaredLength = PanelMapEdgeType == EMapShowTypeOnEdge::ShowOnEdgeByRectangle ? 0.002 : 0.0003;
			auto NearLength = PanelMapEdgeType == EMapShowTypeOnEdge::ShowOnEdgeByRectangle ? 0.0447 : 0.0173;
			if (SquaredLen < NearSquaredLength)
			{
				auto Len = FMath::Sqrt(SquaredLen);
				//UE_LOG(LogTemp, Warning, TEXT("too near %f"), Len);
				if (TObjectPtr<UCanvasPanelSlot> CanvasPanelSlot = Cast<UCanvasPanelSlot>(TagInfoDataA.MyUserWidget->Slot))
				{
					if(PanelMapEdgeType == EMapShowTypeOnEdge::ShowOnEdgeByRectangle && FMath::IsNearlyEqual(TagInfoDataA.Offset.X, TagInfoDataB.Offset.X))
					{
						if (TagInfoDataA.Offset.Y < TagInfoDataB.Offset.Y)
						{
							FVector2D ConvertedOffset = TagInfoDataA.Offset;
							ConvertedOffset.Y = ConvertedOffset.Y  - (NearLength - Len);
							CanvasPanelSlot->SetAnchors(FAnchors(ConvertedOffset.X, ConvertedOffset.Y, ConvertedOffset.X, ConvertedOffset.Y));
							TagInfoDataA.Offset = ConvertedOffset;
						}
						else
						{
							FVector2D ConvertedOffset = TagInfoDataA.Offset;
							ConvertedOffset.Y = ConvertedOffset.Y + (NearLength - Len);
							CanvasPanelSlot->SetAnchors(FAnchors(ConvertedOffset.X, ConvertedOffset.Y, ConvertedOffset.X, ConvertedOffset.Y));
							TagInfoDataA.Offset = ConvertedOffset;
						}
					}
					else
					{
						if (TagInfoDataA.Offset.X < TagInfoDataB.Offset.X)
						{
							FVector2D ConvertedOffset = TagInfoDataA.Offset - (NearLength - Len);
							CanvasPanelSlot->SetAnchors(FAnchors(ConvertedOffset.X, ConvertedOffset.Y, ConvertedOffset.X, ConvertedOffset.Y));
							TagInfoDataA.Offset = ConvertedOffset;
						}
						else
						{
							FVector2D ConvertedOffset = TagInfoDataA.Offset + (NearLength - Len);
							CanvasPanelSlot->SetAnchors(FAnchors(ConvertedOffset.X, ConvertedOffset.Y, ConvertedOffset.X, ConvertedOffset.Y));
							TagInfoDataA.Offset = ConvertedOffset;
						}
					}
				}
			}
		}
	}
}

void UC7MapTagLayerV2::Tick(float DeltaTime)
{

	if (CenterActor.IsValid())
	{
		SetCurrentCenterLocation(GetWorldOffsetByWorldLocation(CenterActor->GetActorLocation()));
	}

	if (bViewportStatChanged)//那就压根不用PendingUpdateList了，直接全刷
	{
		for (TMap<FString, FMapTagInfo>::TIterator Iter = MapTagInfoData.CreateIterator(); Iter; ++Iter)
		{
			PendingUpdateList.Add(Iter->Key);
		}
		bViewportStatChanged = false;
	}
		
	for (auto TaskID : PendingUpdateList)
	{
		if (MapTagInfoData.Find(TaskID))
		{
			if (MapTagInfoData[TaskID].MapTagType == EMapTagType::FollowActor && !MapTagInfoData[TaskID].Follower.IsValid())
			{
				PendingRemoveList.Add(TaskID);
				continue;
			}
			UpdateSingleTagByID(TaskID);
		}
	}
	PendingUpdateList.Empty();
	for (auto TaskID : FollowUpdateList)
	{
		if (MapTagInfoData.Find(TaskID))
		{
			UpdateSingleTagByID(TaskID);
		}
	}
	for (auto TaskID : PendingRemoveList)
	{
		RemoveSingleTag(TaskID);
	}
	PendingRemoveList.Empty();

	for (auto RotateWidgetInfo : RotateWidgetList)
	{
		ResetEdgeWidgetShear(RotateWidgetInfo.Value);
	}

	AdaptOverlappingCircles();
}

void UC7MapTagLayerV2::ResetEdgeWidgetShear(FMapEdgeRotateInfo& MapEdgeRotateInfo)
{
	if (FMapTagInfo* TagInfo = MapTagInfoData.Find(MapEdgeRotateInfo.TaskID))
	{
		if (TagInfo->DisplayState == EMapDisplayState::Edge && MapEdgeRotateInfo.RotateWidget.IsValid())
		{
			float Shear = MapEdgeRotateInfo.Offset - GetWidgetShearByTaskID(MapEdgeRotateInfo.TaskID) / UE_DOUBLE_PI * 180.f;
			MapEdgeRotateInfo.RotateWidget->SetRenderTransformAngle(Shear);
		}
	}
}


void UC7MapTagLayerV2::SetViewportScale(float _ViewportScale) {
	if (!FMath::IsNearlyZero(_ViewportScale - ViewportScale))
	{
		bViewportStatChanged = true;
	}
	ViewportScale = _ViewportScale;
}

void UC7MapTagLayerV2::SetCurrentCenterLocation(FVector2D _CurrentCenterLocation) {
	if (!(CurrentCenterLocation - _CurrentCenterLocation).IsNearlyZero())
	{
		bViewportStatChanged = true;
		//UE_LOG(LogTemp, Warning, TEXT("lizhemian, bViewportStatChanged"))
	}
	//UE_LOG(LogTemp, Warning, TEXT("lizhemian, CurrentCenterLocation"))
	CurrentCenterLocation = _CurrentCenterLocation;
}

EMapDisplayState UC7MapTagLayerV2::GetNewMapDisplayState(FMapTagInfo& _MapTagInfoData)
{
	FVector2D WidgetOffset = GetWidgetOffsetByMapTagInfo(_MapTagInfoData);
	if (ViewportScale > _MapTagInfoData.ShowRatioInterval.Y || ViewportScale < _MapTagInfoData.ShowRatioInterval.X)
	{
		return EMapDisplayState::None;
	}
	else if (PanelMapEdgeType == EMapShowTypeOnEdge::ShowOnEdgeByRectangle &&
		InRectangle(WidgetOffset) && _MapTagInfoData.MapEdgeType == EMapEdgeType::ShowOnEdge)
	{
		return EMapDisplayState::Center;
	}
	else if (PanelMapEdgeType == EMapShowTypeOnEdge::ShowOnEdgeByRectangle &&
		!InRectangle(WidgetOffset) && _MapTagInfoData.MapEdgeType == EMapEdgeType::ShowOnEdge)
	{
		return EMapDisplayState::Edge;
	}
	else if (PanelMapEdgeType == EMapShowTypeOnEdge::ShowOnEdgeByCircle &&
		InCircle(WidgetOffset) && _MapTagInfoData.MapEdgeType == EMapEdgeType::ShowOnEdge)
	{
		return EMapDisplayState::Center;
	}
	else if (PanelMapEdgeType == EMapShowTypeOnEdge::ShowOnEdgeByCircle &&
		!InCircle(WidgetOffset) && _MapTagInfoData.MapEdgeType == EMapEdgeType::ShowOnEdge)
	{
		return EMapDisplayState::Edge;
	}
	else if (PanelMapEdgeType == EMapShowTypeOnEdge::ShowOnEdgeByCircle &&
		InCircle(WidgetOffset) && _MapTagInfoData.MapEdgeType == EMapEdgeType::None)
	{
		return EMapDisplayState::Center;
	}
	else if (InCenter(WidgetOffset) && _MapTagInfoData.MapEdgeType == EMapEdgeType::None)
	{
		return EMapDisplayState::Center;
	}
	else
	{
		return EMapDisplayState::None;
	}
	// return EMapDisplayState::None;
}

void UC7MapTagLayerV2::UpdateSingleTagByID(FString TaskID)
{
	FMapTagInfo& TagInfoData = MapTagInfoData[TaskID];
	EMapDisplayState NewState = GetNewMapDisplayState(TagInfoData);
	if (NewState == EMapDisplayState::None && TagInfoData.DisplayState == EMapDisplayState::None)
	{
		return;
	}
	else if (NewState == EMapDisplayState::Center && TagInfoData.DisplayState == EMapDisplayState::Center)
	{
		FVector2D WidgetOffset = GetWidgetOffsetByMapTagInfo(TagInfoData);
		if (TObjectPtr<UCanvasPanelSlot> CanvasPanelSlot = Cast<UCanvasPanelSlot>(TagInfoData.MyUserWidget->Slot))
		{
			CanvasPanelSlot->SetAnchors(FAnchors(WidgetOffset.X, WidgetOffset.Y, WidgetOffset.X, WidgetOffset.Y));
			CanvasPanelSlot->SetAlignment(FVector2D(0.5f, 0.5f));
			CanvasPanelSlot->SetAutoSize(true);
			CanvasPanelSlot->SetZOrder(TagInfoData.ZOrder);
		}
		return;
	}
	else if (NewState == EMapDisplayState::Edge && TagInfoData.DisplayState == EMapDisplayState::Edge)
	{
		FVector2D WidgetOffset = GetWidgetOffsetByMapTagInfo(TagInfoData);
		if (TObjectPtr<UCanvasPanelSlot> CanvasPanelSlot = Cast<UCanvasPanelSlot>(TagInfoData.MyUserWidget->Slot))
		{
			if (TagInfoData.MapEdgeType == EMapEdgeType::ShowOnEdge && PanelMapEdgeType == EMapShowTypeOnEdge::ShowOnEdgeByCircle)
			{
				FVector2D Origin(0.5f, 0.5f);
				FVector2D ConvertedOffset = ConstraintRadius * (WidgetOffset - Origin).GetSafeNormal() + Origin;
				CanvasPanelSlot->SetAnchors(FAnchors(ConvertedOffset.X, ConvertedOffset.Y, ConvertedOffset.X, ConvertedOffset.Y));
				CanvasPanelSlot->SetAlignment(FVector2D(0.5f, 0.5f));
				CanvasPanelSlot->SetAutoSize(true);
				CanvasPanelSlot->SetZOrder(TagInfoData.ZOrder);
				EdgeList.AddUnique(TaskID);
				TagInfoData.Offset = ConvertedOffset;
			}
			else if (TagInfoData.MapEdgeType == EMapEdgeType::ShowOnEdge && PanelMapEdgeType == EMapShowTypeOnEdge::ShowOnEdgeByRectangle)
			{
				FVector2D Origin(0.5f, 0.5f);
				float Radians = FMath::IsNearlyZero(0.5f - ConstraintRectangle.Y) ? UE_DOUBLE_PI / 2.f : FMath::Atan((0.5f - ConstraintRectangle.X) / (0.5f - ConstraintRectangle.Y));
				float Cosine = FMath::Cos(Radians);
				float Sine = FMath::Sin(Radians);
				FVector2D DirectionVec = (WidgetOffset - Origin).GetSafeNormal();//实际上这个单位向量已经足够大了，要Clamp的范围内，最大向量也就是||(0.5, 0.5)|| = sqrt(2) / 2
				DirectionVec = DirectionVec.Y <= -Cosine ? FMath::Abs((0.5f - ConstraintRectangle.Y) / DirectionVec.Y) * DirectionVec :
					DirectionVec.Y >= Cosine ? FMath::Abs((0.5f - ConstraintRectangle.W) / DirectionVec.Y) * DirectionVec :
					DirectionVec.X < -Sine ? FMath::Abs((0.5f - ConstraintRectangle.X) / DirectionVec.X) * DirectionVec :
					DirectionVec.X > Sine ? FMath::Abs((0.5f - ConstraintRectangle.Z) / DirectionVec.X) * DirectionVec : DirectionVec;
				FVector2D ConvertedOffset = DirectionVec + Origin;
				CanvasPanelSlot->SetAnchors(FAnchors(ConvertedOffset.X, ConvertedOffset.Y, ConvertedOffset.X, ConvertedOffset.Y));
				CanvasPanelSlot->SetAlignment(FVector2D(0.5f, 0.5f));
				CanvasPanelSlot->SetAutoSize(true);
				CanvasPanelSlot->SetZOrder(TagInfoData.ZOrder);
				EdgeList.AddUnique(TaskID);
				TagInfoData.Offset = ConvertedOffset;
			}
		}
		return;
	}
	if (TagInfoData.DisplayState != EMapDisplayState::None)
	{
		OnMapTagRemovedDynamic.Broadcast(TagInfoData.MyUserWidget, TagInfoData.TypeID, TagInfoData.TaskID);
		RemoveChild(TagInfoData.MyUserWidget);
		ReturnWidgetToPool(TagInfoData.MyUserWidget);
		TagInfoData.MyUserWidget = nullptr;
		TagInfoData.DisplayState = EMapDisplayState::None;
		EdgeList.Remove(TaskID);
	}
	if (NewState == EMapDisplayState::Center)
	{
		TObjectPtr<UUserWidget> MyUserWidget = GetWidgetFromPool(TagInfoData.TemplateWidgetType);
		TagInfoData.MyUserWidget = MyUserWidget;
		TagInfoData.DisplayState = EMapDisplayState::Center;
		AddChild(MyUserWidget);
		OnMapTagInitializedDynamic.Broadcast(TagInfoData.MyUserWidget, TagInfoData.TypeID, TagInfoData.TaskID, false);
		FVector2D WidgetOffset = GetWidgetOffsetByMapTagInfo(TagInfoData);
		if (TObjectPtr<UCanvasPanelSlot> CanvasPanelSlot = Cast<UCanvasPanelSlot>(TagInfoData.MyUserWidget->Slot))
		{
			CanvasPanelSlot->SetAnchors(FAnchors(WidgetOffset.X, WidgetOffset.Y, WidgetOffset.X, WidgetOffset.Y));
			CanvasPanelSlot->SetAlignment(FVector2D(0.5f, 0.5f));
			CanvasPanelSlot->SetAutoSize(true);
			CanvasPanelSlot->SetZOrder(TagInfoData.ZOrder);
		}
	}
	else if (NewState == EMapDisplayState::Edge)
	{
		TObjectPtr<UUserWidget> MyUserWidget = GetWidgetFromPool(TagInfoData.TemplateWidgetType);
		TagInfoData.MyUserWidget = MyUserWidget;
		TagInfoData.DisplayState = EMapDisplayState::Edge;
		AddChild(MyUserWidget);
		OnMapTagInitializedDynamic.Broadcast(TagInfoData.MyUserWidget, TagInfoData.TypeID, TagInfoData.TaskID, true);
		FVector2D WidgetOffset = GetWidgetOffsetByMapTagInfo(TagInfoData);
		if (TObjectPtr<UCanvasPanelSlot> CanvasPanelSlot = Cast<UCanvasPanelSlot>(TagInfoData.MyUserWidget->Slot))
		{
			if (TagInfoData.MapEdgeType == EMapEdgeType::ShowOnEdge && PanelMapEdgeType == EMapShowTypeOnEdge::ShowOnEdgeByCircle)
			{
				FVector2D Origin(0.5f, 0.5f);
				FVector2D ConvertedOffset = ConstraintRadius * (WidgetOffset - Origin).GetSafeNormal() + Origin;
				CanvasPanelSlot->SetAnchors(FAnchors(ConvertedOffset.X, ConvertedOffset.Y, ConvertedOffset.X, ConvertedOffset.Y));
				CanvasPanelSlot->SetAlignment(FVector2D(0.5f, 0.5f));
				CanvasPanelSlot->SetAutoSize(true);
				CanvasPanelSlot->SetZOrder(TagInfoData.ZOrder);
				EdgeList.AddUnique(TaskID);
				TagInfoData.Offset = ConvertedOffset;
			}
			else if (TagInfoData.MapEdgeType == EMapEdgeType::ShowOnEdge && PanelMapEdgeType == EMapShowTypeOnEdge::ShowOnEdgeByRectangle)
			{
				FVector2D Origin(0.5f, 0.5f);
				float Radians = FMath::IsNearlyZero(0.5f - ConstraintRectangle.Y) ? UE_DOUBLE_PI / 2.f : FMath::Atan((0.5f - ConstraintRectangle.X) / (0.5f - ConstraintRectangle.Y));
				float Cosine = FMath::Cos(Radians);
				float Sine = FMath::Sin(Radians);
				FVector2D DirectionVec = (WidgetOffset - Origin).GetSafeNormal();//实际上这个单位向量已经足够大了，要Clamp的范围内，最大向量也就是||(0.5, 0.5)|| = sqrt(2) / 2
				DirectionVec = DirectionVec.Y <= -Cosine ? FMath::Abs((0.5f - ConstraintRectangle.Y) / DirectionVec.Y) * DirectionVec :
					DirectionVec.Y >= Cosine ? FMath::Abs((0.5f - ConstraintRectangle.W) / DirectionVec.Y) * DirectionVec :
					DirectionVec.X < -Sine ? FMath::Abs((0.5f - ConstraintRectangle.X) / DirectionVec.X) * DirectionVec :
					DirectionVec.X > Sine ? FMath::Abs((0.5f - ConstraintRectangle.Z) / DirectionVec.X) * DirectionVec : DirectionVec;
				FVector2D ConvertedOffset = DirectionVec + Origin;
				CanvasPanelSlot->SetAnchors(FAnchors(ConvertedOffset.X, ConvertedOffset.Y, ConvertedOffset.X, ConvertedOffset.Y));
				CanvasPanelSlot->SetAlignment(FVector2D(0.5f, 0.5f));
				CanvasPanelSlot->SetAutoSize(true);
				CanvasPanelSlot->SetZOrder(TagInfoData.ZOrder);
				EdgeList.AddUnique(TaskID);
				TagInfoData.Offset = ConvertedOffset;
			}
		}
	}

}

void UC7MapTagLayerV2::SetCenterActor(AActor* _CenterActor)
{
	CenterActor = _CenterActor;
}

void UC7MapTagLayerV2::ResetCenterActor()
{
	CenterActor.Reset();
}

void UC7MapTagLayerV2::RegisterWidgetRotateInEdge(FString TaskID, UWidget* Widget, float Offset)
{
	RotateWidgetList.Add(
		TaskID, FMapEdgeRotateInfo(TaskID, Widget, Offset)
	);
}

void UC7MapTagLayerV2::UnRegisterWidgetRotateInEdge(FString TaskID)
{
	RotateWidgetList.Remove(TaskID);
}

TObjectPtr<UUserWidget> UC7MapTagLayerV2::GetWidgetFromPool(TSubclassOf<UUserWidget> WidgetType)
{
	return EntryWidgetPool.GetOrCreateInstance(WidgetType);
}

void UC7MapTagLayerV2::ReturnWidgetToPool(TObjectPtr<UUserWidget> UserWidget)
{
	EntryWidgetPool.Release(UserWidget, true);
}


FVector2D UC7MapTagLayerV2::GetWidgetOffsetByMapTagInfo(FMapTagInfo MapTagInfo)
{
	FVector WorldLocation(.0f, .0f, .0f);
	if (MapTagInfo.MapTagType == EMapTagType::Static) 
	{
		WorldLocation = MapTagInfo.StaticLocation;

	}
	else if (MapTagInfo.Follower.IsValid()) 
	{
		WorldLocation = MapTagInfo.Follower->K2_GetActorLocation();
	}
	//相机以Z轴负方向为Up，Y轴正方向为Right
	FVector Up = CameraRotation.RotateVector(FVector(0, 0, -1));
	//FVector Forward = CameraRotation.RotateVector(FVector(1,0,0));
	FVector Right = CameraRotation.RotateVector(FVector(0, 1, 0));
	FVector WorldVec = WorldLocation - CameraLocation;
	FVector2d ProjectedLoc = FVector2d(WorldVec.Dot(Right), WorldVec.Dot(Up)) + CameraViewportSize * 0.5f;

	FVector2D ViewportRectangleLeftUp = CurrentCenterLocation - CameraViewportSize * ViewportScale * 0.5f;
	//FVector2D ViewportRectangleRightDown = CurrentCenterLocation + CameraViewportSize * ViewportScale;

	FVector2D ViewportPosition = ProjectedLoc - ViewportRectangleLeftUp;
	FVector2D res = FVector2D(ViewportPosition.X / CameraViewportSize.X / ViewportScale, ViewportPosition.Y / CameraViewportSize.Y / ViewportScale);
	return res;

}

FVector2D UC7MapTagLayerV2::GetWidgetPosByMapTagInfo(FMapTagInfo MapTagInfo)
{
	FVector WorldLocation(.0f, .0f, .0f);
	if (MapTagInfo.MapTagType == EMapTagType::Static)
	{
		WorldLocation = MapTagInfo.StaticLocation;

	}
	else if (MapTagInfo.Follower.IsValid())
	{
		WorldLocation = MapTagInfo.Follower->K2_GetActorLocation();
	}
	return GetWorldOffsetByWorldLocation(WorldLocation);
}

FVector2D UC7MapTagLayerV2::GetWorldOffsetByWorldLocation(FVector Location)
{
	//相机以Z轴负方向为Up，Y轴正方向为Right
	FVector Up = CameraRotation.RotateVector(FVector(0, 0, -1));
	//FVector Forward = CameraRotation.RotateVector(FVector(-1,0,0));右手坐标系
	FVector Right = CameraRotation.RotateVector(FVector(0, 1, 0));
	FVector WorldVec = Location - CameraLocation;
	FVector2d ProjectedLoc = FVector2d(WorldVec.Dot(Right), WorldVec.Dot(Up)) + CameraViewportSize * 0.5f;
	return ProjectedLoc;
}

FVector2D UC7MapTagLayerV2::DeprojectWidgetOffsetToWorldLocation(FVector2D WidgetOffset)
{
	WidgetOffset = WidgetOffset * CameraViewportSize * ViewportScale;
	WidgetOffset += CurrentCenterLocation - CameraViewportSize * ViewportScale * 0.5f;
	FVector2D WorldOffset = WidgetOffset - CameraViewportSize * 0.5f;

	FVector4 LHS(WorldOffset.X, WorldOffset.Y, .0f, .0f);
	FVector Right = CameraRotation.RotateVector(FVector(0, 1, 0));
	FVector Up = CameraRotation.RotateVector(FVector(0, 0, -1));
	FVector Forward = CameraRotation.RotateVector(FVector(-1, 0, 0));
	FMatrix Mat;
	Mat.SetIdentity();
	Mat.SetColumn(0, Right);
	Mat.SetColumn(1, Up);
	Mat.SetColumn(2, Forward);
	FVector4 RHS = Mat.GetTransposed().TransformFVector4(LHS);//正交矩阵，转置就是逆
	FVector RHS3(RHS.X, RHS.Y, RHS.Z);
	RHS3 += CameraLocation;

	return FVector2D(RHS3.X, RHS3.Y);
}

FVector2D UC7MapTagLayerV2::GetWidgetOffsetByWorldLocation(FVector Location)
{
	//相机以Z轴负方向为Up，Y轴正方向为Right
	FVector Up = CameraRotation.RotateVector(FVector(0, 0, -1));
	//FVector Forward = CameraRotation.RotateVector(FVector(1,0,0));
	FVector Right = CameraRotation.RotateVector(FVector(0, 1, 0));
	FVector WorldVec = Location - CameraLocation;
	FVector2d ProjectedLoc = FVector2d(WorldVec.Dot(Right), WorldVec.Dot(Up)) + CameraViewportSize * 0.5f;

	FVector2D ViewportRectangleLeftUp = CurrentCenterLocation - CameraViewportSize * ViewportScale * 0.5f;
	//FVector2D ViewportRectangleRightDown = CurrentCenterLocation + CameraViewportSize * ViewportScale;

	FVector2D ViewportPosition = ProjectedLoc - ViewportRectangleLeftUp;
	FVector2D res = FVector2D(ViewportPosition.X / CameraViewportSize.X / ViewportScale, ViewportPosition.Y / CameraViewportSize.Y / ViewportScale);
	return res;
}

FVector2D UC7MapTagLayerV2::GetWidgetOffsetByCenterAndWorldLocation(FVector& Location)
{
	//相机以Z轴负方向为Up，Y轴正方向为Right
	FVector Up = CameraRotation.RotateVector(FVector(0, 0, -1));
	//FVector Forward = CameraRotation.RotateVector(FVector(1,0,0));
	FVector Right = CameraRotation.RotateVector(FVector(0, 1, 0));
	FVector WorldVec = Location - CameraLocation;
	FVector2d ProjectedLoc = FVector2d(WorldVec.Dot(Right), WorldVec.Dot(Up)) + CameraViewportSize * 0.5f;

	//FVector2D _CurrentCenterLocation = CameraViewportSize * ViewportScale * 0.5f;
	FVector2D ViewportRectangleLeftUp(.5f, .5f);// = _CurrentCenterLocation - CameraViewportSize * ViewportScale * 0.5f;
	//FVector2D ViewportRectangleRightDown = CurrentCenterLocation + CameraViewportSize * ViewportScale;

	FVector2D ViewportPosition = ProjectedLoc - ViewportRectangleLeftUp;
	FVector2D res = FVector2D(ViewportPosition.X / CameraViewportSize.X/* / ViewportScale*/, ViewportPosition.Y / CameraViewportSize.Y/* / ViewportScale*/);
	return res;
}

float UC7MapTagLayerV2::GetWidgetShearByWorldRotation(const FRotator& Rotation)
{
	FVector ForwardVector = Rotation.Vector() * 1000;
	FVector2D Triangle = GetWidgetOffsetByWorldLocation(ForwardVector) - GetWidgetOffsetByWorldLocation(FVector::ZeroVector);
	Triangle.Normalize();
	if (Triangle.X > .0f)
	{
		return FMath::Acos(Triangle.Y);
	}
	else// if(Triangle.X < .0f)
	{
		return 2 * UE_DOUBLE_PI - FMath::Acos(Triangle.Y);
	}
	// return .0f;
}


float UC7MapTagLayerV2::GetWidgetShearByTaskID(FString TaskID)
{
	if (MapTagInfoData.Find(TaskID))
	{
		FVector2D Pos = GetWidgetOffsetByMapTagInfo(MapTagInfoData[TaskID]);
		Pos.Y = 1 - Pos.Y;
		FVector2D Triangle = FVector2D(0.5f, 0.5f) - Pos;
		Triangle.Normalize();
		if (Triangle.Y > .0f)
		{
			return FMath::Acos(Triangle.X);
		}
		else if (Triangle.Y < .0f)
		{
			return 2 * UE_DOUBLE_PI - FMath::Acos(Triangle.X);
		}
		/*
		else if (Triangle.Y > 0)
		{
			return .0f;
		}
		else
		{
			return UE_DOUBLE_PI;
		}*/

	}
	return .0f;
}

FVector2D UC7MapTagLayerV2::GetWidgetPosByTaskID(FString TaskID)
{
	FMapTagInfo* It = MapTagInfoData.Find(TaskID);
	if (It)
	{
		FVector2D Pos = GetWidgetPosByMapTagInfo(*It);
		return Pos;
	}
	return FVector2D(0, 0);
}

void UC7MapTagLayerV2::SetData(TMap<FString, FMapTagInfo> _MapTagInfoData)
{
	EdgeList.Empty();
	for (TMap<FString, FMapTagInfo>::TIterator Iter = MapTagInfoData.CreateIterator(); Iter; ++Iter)
	{
		OnMapTagRemovedDynamic.Broadcast(Iter->Value.MyUserWidget, Iter->Value.TypeID, Iter->Value.TaskID);
		RemoveChild(Iter->Value.MyUserWidget);
		Iter->Value.MyUserWidget = nullptr;
		ReturnWidgetToPool(Iter->Value.MyUserWidget);
	}
	MapTagInfoData = _MapTagInfoData;
	PendingUpdateList.Empty();
	FollowUpdateList.Empty();
	for (TMap<FString, FMapTagInfo>::TIterator Iter = MapTagInfoData.CreateIterator(); Iter; ++Iter)
	{
		if (Iter->Value.MapTagType == EMapTagType::FollowActor)
		{
			FollowUpdateList.Add(Iter->Key);
		}
		else
		{
			PendingUpdateList.Add(Iter->Key);
		}
	}
}

void UC7MapTagLayerV2::AddSingleTag(FMapTagInfo _MapTagInfo)
{
	if (MapTagInfoData.Find(_MapTagInfo.TaskID))
	{
		_MapTagInfo.MyUserWidget = MapTagInfoData[_MapTagInfo.TaskID].MyUserWidget;
		_MapTagInfo.DisplayState = MapTagInfoData[_MapTagInfo.TaskID].DisplayState;
		MapTagInfoData[_MapTagInfo.TaskID] = _MapTagInfo;
	}
	else
	{
		MapTagInfoData.Add(_MapTagInfo.TaskID, _MapTagInfo);
	}
	if (_MapTagInfo.MapTagType == EMapTagType::FollowActor)
	{
		FollowUpdateList.Add(_MapTagInfo.TaskID);
	}
	else
	{
		PendingUpdateList.Add(_MapTagInfo.TaskID);
	}
}

void UC7MapTagLayerV2::ClearAllTags()
{
	for (TMap<FString, FMapTagInfo>::TIterator Iter = MapTagInfoData.CreateIterator(); Iter; ++Iter)
	{
		if (Iter->Value.MyUserWidget)
		{
			OnMapTagRemovedDynamic.Broadcast(Iter->Value.MyUserWidget, Iter->Value.TypeID, Iter->Value.TaskID);
			RemoveChild(Iter->Value.MyUserWidget);
			ReturnWidgetToPool(Iter->Value.MyUserWidget);
		}
		FollowUpdateList.Remove(Iter->Key);
		PendingUpdateList.Remove(Iter->Key);
	}

	RotateWidgetList.Empty();
	MapTagInfoData.Empty();
	EdgeList.Empty();
}

void UC7MapTagLayerV2::RemoveSingleTag(FString TaskID)
{
	if (MapTagInfoData.Find(TaskID))
	{
		if (MapTagInfoData[TaskID].MyUserWidget)
		{
			OnMapTagRemovedDynamic.Broadcast(MapTagInfoData[TaskID].MyUserWidget, MapTagInfoData[TaskID].TypeID, MapTagInfoData[TaskID].TaskID);
			RemoveChild(MapTagInfoData[TaskID].MyUserWidget);
			ReturnWidgetToPool(MapTagInfoData[TaskID].MyUserWidget);
		}
		MapTagInfoData.Remove(TaskID);
		FollowUpdateList.Remove(TaskID);
		RotateWidgetList.Remove(TaskID);
		EdgeList.Remove(TaskID);
	}
}

void UC7MapTagLayerV2::BatchAddTags(TMap<FString, FMapTagInfo> _MapTagInfos)
{
	for (TMap<FString, FMapTagInfo>::TIterator Iter = MapTagInfoData.CreateIterator(); Iter; ++Iter)
	{
		AddSingleTag(Iter->Value);
	}
}


void UC7MapTagLayerV2::BatckRemoveTags(TArray<FString> TaskIDs)
{
	for (int32 Index = 0; Index < TaskIDs.Num(); ++Index)
	{
		RemoveSingleTag(TaskIDs[Index]);
	}
}

TArray<FString> UC7MapTagLayerV2::ReqTaskNearByByTaskID(FString TaskID, float ToleranceDistance)
{
	TArray<FString> OutTasks;
	if (!MapTagInfoData.Find(TaskID) || MapTagInfoData[TaskID].MapTagType != EMapTagType::Static)
	{
		return OutTasks;
	}
	FVector2D TargetLocation = GetWidgetOffsetByWorldLocation(MapTagInfoData[TaskID].StaticLocation);
	for (TMap<FString, FMapTagInfo>::TIterator Iter = MapTagInfoData.CreateIterator(); Iter; ++Iter)
	{
		if (Iter->Value.MapTagType != EMapTagType::Static)
		{
			continue;
		}
		if ((GetWidgetOffsetByWorldLocation(Iter->Value.StaticLocation) - TargetLocation).Size() < ToleranceDistance)
		{
			OutTasks.Add(Iter->Key);
		}
	}
	return OutTasks;
}

void UC7MapTagLayerV2::ReleaseSlateResources(bool bReleaseChildren)
{
	Super::ReleaseSlateResources(bReleaseChildren);
	EntryWidgetPool.ResetPool();
}

void UC7MapTagLayerV2::RetargetTagLocation(FString TaskID, FVector Location)
{
	if (MapTagInfoData.Find(TaskID))
	{
		MapTagInfoData[TaskID].StaticLocation = Location;
		PendingUpdateList.Add(TaskID);
	}
}

void UC7MapTagLayerV2::ReSetTaskTypeToFollowActor(FString TaskID, AActor* Actor)
{
	if (MapTagInfoData.Find(TaskID))
	{
		MapTagInfoData[TaskID].MapTagType = EMapTagType::FollowActor;
		MapTagInfoData[TaskID].Follower = Actor;
		PendingUpdateList.Add(TaskID);
	}
}

void UC7MapTagLayerV2::ReSetTaskTypeToStatic(FString TaskID)
{
	if (MapTagInfoData.Find(TaskID))
	{
		MapTagInfoData[TaskID].MapTagType = EMapTagType::Static;
		MapTagInfoData[TaskID].Follower.Reset();
		PendingUpdateList.Add(TaskID);
	}
}

void UC7MapTagLayerV2::SetTaskShowEdgeType(FString TaskID, EMapEdgeType ShowOnEdgeType)
{
	if (MapTagInfoData.Find(TaskID))
	{
		MapTagInfoData[TaskID].MapEdgeType = ShowOnEdgeType;
		PendingUpdateList.Add(TaskID);
	}
}
