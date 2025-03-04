// Fill out your copyright notice in the Description page of Project Settings.

#include "UI/C7Map/C7MapTagLayer.h"
#include "Kismet/GameplayStatics.h"
#include "Components/CanvasPanel.h"
#include "Components/CanvasPanelSlot.h"
#include "Components/Widget.h"
#include "UI/C7Map/C7MapTagBase.h"
#include "UI/C7Map/C7MapTagWidget.h"
#include "MapCommon.h"

#include "C7MapTagEdgeWidget.h"

#include "GameFramework/Character.h"


FVector2d UC7MapTagLayer::WorldLocToWidgetLocRaw(const FVector& InWorldLoc)
{
	//相机以Z轴负方向为Up，Y轴正方向为Right
	FVector Up = CameraRotation.RotateVector(FVector(0,0,-1));
	//FVector Forward = CameraRotation.RotateVector(FVector(1,0,0));
	FVector Right = CameraRotation.RotateVector(FVector(0,1,0));
	FVector WorldVec = InWorldLoc - CameraLocation;
	FVector2d ProjectedLoc = FVector2d(WorldVec.Dot(Right), WorldVec.Dot(Up));
	FVector2d MapWidgetSize = MapWorldSize* WorldSizeToWidgetSizeRatio;
	FVector2d WorldPosDelta = ProjectedLoc + MapWorldSize / 2;
	FVector2d res = FVector2D((WorldPosDelta.X / MapWorldSize.X) * MapWidgetSize.X, (WorldPosDelta.Y / MapWorldSize.Y) * MapWidgetSize.Y);
	return res;
}


void UC7MapTagLayer::WorldLocToWidgetLocRaw_XY(const FVector& InWorldLoc,float& X, float& Y)
{
	FVector2d MapWidgetSize = MapWorldSize* WorldSizeToWidgetSizeRatio;
	FVector2d WorldPosDelta =  FVector2D(InWorldLoc) - (MapWorldCenter - FVector2D(MapWorldSize.X,MapWorldSize.Y)/2);

	X = (WorldPosDelta.X/MapWorldSize.X) * MapWidgetSize.X ;
	Y = (WorldPosDelta.Y/MapWorldSize.Y) * MapWidgetSize.Y;
}


FVector2D UC7MapTagLayer::GetTagWidgetLocationByID(const int32 TaskID)
{
	TSharedPtr<FMapTagRunningData> Task = GetTaskById(TaskID);
	if (Task.IsValid())
	{
		return 	Task->WidgetLoc;;
	}
	return FVector2D(0,0);
}

void UC7MapTagLayer::Init(int32 InTagDisplayMode)
{
	// PanelSize = GetCachedGeometry().GetLocalSize();
	// PanelTolerancePadding =PanelSize * (ToleranceScale-1)/2;
	TagDisplayMode  = InTagDisplayMode;

}

void UC7MapTagLayer::SetConstrainInCanvasMode(FVector4& InEdgePadding)
{
	EdgeMode = EMapEdgeMode::CONSTRAIN_IN_CANVAS;
	EdgePadding = InEdgePadding;
}

void UC7MapTagLayer::SetConstrainInCircleMode(float Radius)
{
	EdgeMode = EMapEdgeMode::CONSTRAIN_IN_CIRCLE;
	ConstrainRadius = Radius;
}

void UC7MapTagLayer::Uninit()
{
	ClearMap();
	MapTagPool.ClearUp();
}

void UC7MapTagLayer::ClearMap()
{
	ClearTagWidgets();
	MapWorldCenter = FVector2d();
	MapWorldSize =  FVector2d();
	WorldSizeToWidgetSizeRatio = 0;
	MapWidgetSizeRaw = FVector2d();
	MapMaxScale = 0;
	MapMinScale = 0;
	LayerData.Reset();
}

TSharedPtr<FMapTagRunningData> UC7MapTagLayer::GetTaskById(const int32 ID)
{
	if (TSharedPtr<FMapTagRunningData>* Task = MapStaticTasks.Find(ID))
	{
		return *Task;
	}
	if (TSharedPtr<FMapTagRunningData>* Task = MapTickTasks.Find(ID))
	{
		return *Task;
	}
	return nullptr;
}

void UC7MapTagLayer::ClearTagWidgets()
{
	PendingMapTasks.Reset();
	MapTickTasks.Append(MapStaticTasks);
	for(auto Taskpair : MapTickTasks)
	{
		TSharedPtr<FMapTagRunningData> Task = Taskpair.Value;
		if (!Task.IsValid())
		{
			return;
		}
	
		if (Task->TagWidget.IsValid())
		{
			ReturnWidgetToPool(Task->TagData.TagWidgetPath, Task->TagWidget.Get());
			Task->TagWidget.Reset();
		}
	
		if (Task->EdgeWidget.IsValid())
		{
			ReturnEdgeTaskWidget(Cast<UC7MapTagEdgeWidget>(Task->EdgeWidget.Get()));
			Task->EdgeWidget.Reset();
		}
		
		if (Task->SelectionWidget.IsValid())
		{
			ReturnWidgetToPool(Task->DisplayData.SelectionWidgetPath, 	Task->SelectionWidget.Get());
			Task->SelectionWidget.Reset();
		}
	}
	MapTickTasks.Reset();
	MapStaticTasks.Reset();
}



void UC7MapTagLayer::SetMap(int32 MapID,
							int32 PlaneID, 
							const FVector CameraLoc,
							const FRotator CameraRot,
							const FVector2D& NewMapWorldSize,
							float  InWorldSizeToWidgetSizeRatio,
							float InMapMaxScale,
							float InMapMinScale,
							TArray<FVector>& InLayerData,
							TSet<FName>& LDNames)
	
{
	CurrentMapID = MapID;
	CurrentPlaneID = PlaneID;
	ClearTagWidgets();
	MapWorldCenter = FVector2D(CameraLoc.X, CameraLoc.Y);
	CameraLocation = CameraLoc;
	CameraRotation = CameraRot;
	MapWorldSize = NewMapWorldSize;
	WorldSizeToWidgetSizeRatio = InWorldSizeToWidgetSizeRatio;
	MapWidgetSizeRaw = MapWorldSize * InWorldSizeToWidgetSizeRatio;
	MapMaxScale = InMapMaxScale;
	MapMinScale = InMapMinScale;
	LayerData = InLayerData;
	if (GetMapTagsDelegate.IsBound())
	{
		TArray<int32> Tags = GetMapTagsDelegate.Execute(MapID);
		AddMapTasks( Tags);
	}
	CurrentLDNames = LDNames;
}

void UC7MapTagLayer::AddMapTask(int32 TaskID)
{
	PendingMapTasks.Add(TaskID);
}

void UC7MapTagLayer::AddMapTasks(TArray<int32> Tasks)
{
	if (GenerateRunningDataDelegate.IsBound())
	{
		PendingMapTasks.Append(Tasks);
	}
}

void UC7MapTagLayer::ProcessPendingTasks()
{
	if (GenerateRunningDataDelegate.IsBound() && PendingMapTasks.Num()>0)
	{
		TArray<TSharedPtr<FMapTagRunningData>> UpdatedTasks;
		FMapTagRunningData NewTaskData;

		TArray<FMapTagRunningData> RunningData = GenerateRunningDataDelegate.Execute(PendingMapTasks,TagDisplayMode);
		PendingMapTasks.Reset();
		
		TMap<int32,FMapTagRunningData> TempTaskMap;
		
		for (FMapTagRunningData& Task:RunningData)
		{
			if (!Task.TagData.TagIconPath.IsNone())
			{
				Task.TagData.IconObj = TSoftObjectPtr<UObject>(Task.TagData.TagIconPath.ToString());
			}
	
			if (Task.TagData.FollowType == ETagFollowType::FOLLOW_ACTOR || Task.TagData.FollowType == ETagFollowType::BOTH)
			{
				FMapTagRunningData CopyTask = Task;
				TSharedPtr<FMapTagRunningData> TaskPtr = MakeShared<FMapTagRunningData>(CopyTask);
				MapTickTasks.Add(Task.TagData.TagID,TaskPtr);
				UpdatedTasks.Add(TaskPtr);
			}
			else
			{
				FMapTagRunningData CopyTask = Task;
				TSharedPtr<FMapTagRunningData> TaskPtr = MakeShared<FMapTagRunningData>(CopyTask);
				MapStaticTasks.Add(Task.TagData.TagID,TaskPtr);
				UpdatedTasks.Add(TaskPtr);
			}
		}
		UpdateTags(UpdatedTasks);
	}
}

void UC7MapTagLayer::RemoveMapTask(int32 TaskID)
{
	PendingMapTasks.Remove(TaskID);
	
	TSharedPtr<FMapTagRunningData> Task = GetTaskById(TaskID);
	if (!Task.IsValid())
	{
		return;
	}
	
	if (Task->TagWidget.IsValid())
	{
		ReturnWidgetToPool(Task->TagData.TagWidgetPath, Task->TagWidget.Get());
		Task->TagWidget.Reset();
	}
	
	if (Task->EdgeWidget.IsValid())
	{
		ReturnEdgeTaskWidget(Cast<UC7MapTagEdgeWidget>(Task->EdgeWidget.Get()));
		Task->EdgeWidget.Reset();
	}


	if (Task->SelectionWidget.IsValid())
	{
		ReturnWidgetToPool(Task->DisplayData.SelectionWidgetPath, 	Task->SelectionWidget.Get());
		Task->SelectionWidget.Reset();
	}
	
	MapTickTasks.Remove(TaskID);
	MapStaticTasks.Remove(TaskID);
}

bool UC7MapTagLayer::IsInConstrainCircle(const FVector2D& WidgetLoc)
{
	FVector2d LocDiff  =WidgetLoc- PanelSize/2;
	return LocDiff.Size()< ConstrainRadius;
}



bool UC7MapTagLayer::IsInConstrainSquare(const FVector2D& WidgetLoc,bool bUsePadding,const FVector2D& WidgetSize)
{
	FVector2D Padding = FVector2D(0,0);
	if (bUsePadding)
	{
		Padding = PanelTolerancePadding;
	}
	 
	
	if (WidgetLoc.X < 0 - Padding.X - WidgetSize.X || WidgetLoc.Y<0 - Padding.X - WidgetSize.Y)
	{
		return false;
	}
	if (WidgetLoc.X > PanelSize.X+ Padding.X + WidgetSize.X  || WidgetLoc.Y > PanelSize.Y + Padding.Y + WidgetSize.Y  )
	{
		return false;
	}
	return true;
}





inline bool InScaleRange(const float & MapCurrentScaleRatio,const float & HideRatio,const float& 
ShowRatio)
{
	return MapCurrentScaleRatio <= HideRatio && MapCurrentScaleRatio >=ShowRatio;
}

inline bool InDistRange(const FVector & TagLocation,const float & ShowDist,const float& HideDist,
UWorld* World)
{
	if (ShowDist < 0 && HideDist<0)
	{
		return true;
	}
	if (ACharacter* MainCharacter = UGameplayStatics::GetPlayerCharacter(World,0))
	{
		float Dist = (FVector2d(MainCharacter->GetActorLocation()) - FVector2d(TagLocation)).Size();
		bool InShowDist;
		bool InHideDist;
		if (ShowDist > 0)
		{
			InShowDist = Dist > ShowDist;
		}else
		{
			InShowDist = true;
		}
		if (HideDist > 0)
		{
			InHideDist = Dist < HideDist;
		}else
		{
			InHideDist = true;
		}
		return InShowDist && InHideDist;
	}
	return false;
}


bool UC7MapTagLayer::IsInConstrainArea(const TSharedPtr<FMapTagRunningData> Task,bool UsePadding)
{
	//Check In Show Area
	if(EdgeMode==EMapEdgeMode::CONSTRAIN_IN_CIRCLE )
	{
		if (ShouldKeepOnEdge(Task))
		{
			return IsInConstrainCircle(Task->WidgetScreenLoc);
		}
	}

	if (Task->TagData.bOverrideSize)
	{
		return IsInConstrainSquare(Task->WidgetScreenLoc,UsePadding,Task->TagData.SizeOverrideType == 
		ESizeOverrideType::WIDGET_SIZE ? Task->TagData.SizeOverride : Task->TagData.SizeOverride * WorldSizeToWidgetSizeRatio);
	}else
	{
		return IsInConstrainSquare(Task->WidgetScreenLoc,UsePadding,FVector2D(0,0));
	}
}

bool UC7MapTagLayer::ShouldShow(const TSharedPtr<FMapTagRunningData> Task,bool UsePadding)
{
	
	if(!Task->bValidScreenLoc)
	{
		return false;
	}
	
	if (!IsInConstrainArea(Task,UsePadding))
	{
		return false;	
	}
	if (! InDistRange(Task->TagData.WorldLoc,Task->DisplayData.ShowDistance,Task->DisplayData.HideDistance,GetWorld()))
	{
		return false;
	}

	if (Task->bSelected || Task->bTraced)
	{
		return true;
	}
	
	if ( MapDisplayMode == EMapDisplayMode::SCALE_RATIO && !InScaleRange(CurrentScaleRatio, Task->DisplayData.HideRatio, Task->DisplayData.ShowRatio))
	{
		return false;
	}
	
	
	return true;
}

bool UC7MapTagLayer::ShouldKeepOnEdge(const TSharedPtr<FMapTagRunningData> Task)
{
	if(!Task->bValidScreenLoc)
	{
		return false;
	}
	
	switch (Task->DisplayData.KeepOnEdgeType)
	{
		case EKeepOnEdgeType::NONE:
			return false;
		case EKeepOnEdgeType::ALWAYS:
			return true;
		case EKeepOnEdgeType::ON_SELECTED:
			return Task->bSelected;
		case EKeepOnEdgeType::ON_TRACE:
			return Task->bTraced;
		case EKeepOnEdgeType::ON_TRACE_OR_SELECTED:
			return Task->bTraced || Task->bSelected;
		default:
			return false;
	}
}

inline bool UC7MapTagLayer::IsInSameMap(const TSharedPtr<FMapTagRunningData> Task)
{
	return Task->TagData.MapID == CurrentMapID &&																			//判断MapID
		(
			Task->TagData.PlaneID == -1 ||																						//PlaneID == -1 不计算位面，任何位面都显示
			(Task->TagData.PlaneID == -2 && !Task->TagData.LDName.IsNone()&&CurrentLDNames.Contains(Task->TagData.LDName)) ||	//PlaneID == -2 通过LD Name判断
			(Task->TagData.PlaneID >=0 && Task->TagData.PlaneID == CurrentPlaneID)												//PlaneID>=0 正常判断PlaneID
		);
}





void UC7MapTagLayer::UpdateTagScreenLocation(TSharedPtr<FMapTagRunningData> Task,bool bUpdateStatic)
{

	if(!IsInSameMap(Task))
	{
		Task->bValidScreenLoc = false;
		return;
	}
	

	if (Task->TagData.FollowType == ETagFollowType::FOLLOW_ACTOR || Task->TagData.FollowType == ETagFollowType::BOTH)
	{
		if (Task->TagData.FollowActor.IsValid())
		{
			Task->TagData.WorldLoc  = Task->TagData.FollowActor->K2_GetActorLocation();
			Task->TagData.bWorldLocValid = true;
			Task->bWidgetLocValid = false;
		}else
		{
			Task->TagData.FollowActor.Reset();
			if (Task->TagData.FollowType == ETagFollowType::FOLLOW_ACTOR)
			{
				Task->TagData.bWorldLocValid = false;
			}
		}
	}


	if (Task->TagData.FollowType == ETagFollowType::INVALID)
	{
		Task->bWidgetLocValid = false;
	}
	else
	{
		if (Task->TagData.bWorldLocValid)
		{
			Task->bWidgetLocValid = true;
			Task->LayerID =  GetLayerID(Task->TagData.WorldLoc);
			Task->WidgetLoc = WorldLocToWidgetLocRaw(Task->TagData.WorldLoc);
		}
		else
		{
			Task->bWidgetLocValid = false;
		}
	}

	if(	Task->LayerID !=CurrentLayerID)
	{
		Task->bValidScreenLoc = false;
		return;
	}

	
	if (Task->bWidgetLocValid)
	{
		if (MapDisplayMode ==EMapDisplayMode::SCALE_RATIO)
		{
			FVector2d TaskWidgetLocFromCenter = Task->WidgetLoc -MapWidgetSizeRaw/2;
			TaskWidgetLocFromCenter = TaskWidgetLocFromCenter.GetRotated(CurrentMapCenterRoation);
			Task->WidgetLoc = TaskWidgetLocFromCenter + MapWidgetSizeRaw/2;
			FVector2d WidgetLocFromScreenCenter =  Task->WidgetLoc * CurrentMapScale - CurrentScreenCenterLoc;
			WidgetLocFromScreenCenter = WidgetLocFromScreenCenter.GetRotated(CurrentScreenCenterRotation);
			Task->WidgetScreenLoc =  PanelSize/2 + WidgetLocFromScreenCenter;
			Task->WidgetCoord = Task->WidgetScreenLoc/PanelSize;
			Task->bValidScreenLoc = true;
		}
		else
		{
			FVector2D MapTopLeaftPos =  /*MapWorldCenter*/WorldLocToWidgetLocRaw(CameraLocation) - MapWorldSize / 2;
			FVector2D WorldPosOnMap = WorldLocToWidgetLocRaw(Task->TagData.WorldLoc) - MapTopLeaftPos;

			Task->WidgetCoord =  WorldPosOnMap /MapWorldSize;
			Task->WidgetScreenLoc =  Task->WidgetCoord * PanelSize;
			Task->bValidScreenLoc = true;
		}

	}else
	{
		Task->bValidScreenLoc = false;
	}
}

void UC7MapTagLayer::SetTaskSelection(int32 TaskID,bool InSelected)
{
	TSharedPtr<FMapTagRunningData> Task = GetTaskById(TaskID);
	if(Task.IsValid())
	{
		if(Task->bSelected != InSelected)
		{
			Task->bSelected = InSelected; 
			if (UC7MapTagWidget* C7TagWiget = Cast<UC7MapTagWidget>(Task->TagWidget))
			{
				C7TagWiget->PlaySelectionAnim(InSelected);
			}
		}
		TArray<TSharedPtr<FMapTagRunningData>> TempTaskMap;
		TempTaskMap.Add(Task);
		UpdateTags(TempTaskMap);
		
	}
}

void UC7MapTagLayer::SetTaskTrace(int32 TaskID,bool bTrace)
{
	TSharedPtr<FMapTagRunningData> Task = GetTaskById(TaskID);
	if(Task.IsValid())
	{
		Task->bTraced = bTrace;
		TWeakObjectPtr<UWidget> Widget = Task->TagWidget;
		if (Widget !=nullptr && Widget.IsValid())
		{
			if (auto TagWidget =Cast<UC7MapTagWidget>(Widget))
			{
				TagWidget->SetTraced(Task->bTraced);
			}
		}


		TArray<TSharedPtr<FMapTagRunningData>> TempTaskMap;
		TempTaskMap.Add(Task);
		UpdateTags(TempTaskMap);
		
	}
}

void UC7MapTagLayer::SetCurrentLayer(int32 InLayerID)
{
	if (CurrentLayerID !=InLayerID )
	{
		CurrentLayerID = InLayerID;
		bForceRefreshNextTick = true;
	}

}


void UC7MapTagLayer::RepositionTag(int32 TaskID, const FVector& NewWorldLoc,int32 NewMapID,int32 NewPlaneID)
{
	TSharedPtr<FMapTagRunningData> Task = GetTaskById(TaskID);
	if(Task.IsValid()){
		Task->TagData.WorldLoc = NewWorldLoc;
		Task->TagData.MapID = NewMapID;
		Task->TagData.PlaneID = NewPlaneID;
		Task->TagData.bWorldLocValid = true;
		Task->bWidgetLocValid = false;
		Task->bValidScreenLoc = false;

		
		TArray<TSharedPtr<FMapTagRunningData>> TempTaskMap;
		TempTaskMap.Add(Task);
		UpdateTags(TempTaskMap);
	}
}

void UC7MapTagLayer::RepositionTagByActor(int32 TaskID, AActor* Actor)
{
	TSharedPtr<FMapTagRunningData> Task = GetTaskById(TaskID);
	if(Task.IsValid()){
		Task->TagData.FollowActor = Actor;
		Task->bValidScreenLoc = false;
		
		TArray<TSharedPtr<FMapTagRunningData>> TempTaskMap;
		TempTaskMap.Add(Task);
		UpdateTags(TempTaskMap);
	}
}


void UC7MapTagLayer::SetTagVisibility(int32 TaskID, ESlateVisibility NewVisibility)
{
	TSharedPtr<FMapTagRunningData> Task = GetTaskById(TaskID);
	if(Task.IsValid())
	{
		if (NewVisibility != Task->DisplayData.Visibility)
		{
			Task->DisplayData.Visibility = NewVisibility;
			
			if (Task->TagWidget.IsValid())
			{
				Task->TagWidget->SetVisibility(NewVisibility);
			}
		}
	}
}

UWidget* UC7MapTagLayer::GetWidgetFromPool(const FName& WidgetName)
{
	UWidget* PoolWidget = MapTagPool.GetWidgetFromPool(WidgetName);
	if (PoolWidget == nullptr)
	{
		const TSubclassOf<UUserWidget> WidgetType =  LoadObject<UClass>(this, *WidgetName.GetPlainNameString());
		PoolWidget =  CreateWidget(this, WidgetType);
	}
	
	if (UC7MapTagBase* TagWidget = Cast<UC7MapTagBase>(PoolWidget) )
	{
		TagWidget->InitTagWidget();
	}
	
	return PoolWidget;
}

void UC7MapTagLayer::ReturnWidgetToPool(const FName& WidgetName,UWidget* InWidget)
{
	if (UC7MapTagBase* TagWidget = Cast<UC7MapTagBase>(InWidget))
	{
		TagWidget->UnInitTagWidget();
	}
	
	InWidget->RemoveFromParent();
	MapTagPool.ReturnWidgetToPool(WidgetName,InWidget);
}

void UC7MapTagLayer::ActiveTagWidget(TSharedPtr<FMapTagRunningData> InTask,UWidget* Widget)
{
	if ( Widget!=nullptr)
	{
		auto TagWidget = Cast<UC7MapTagBase>(Widget);
		if (TagWidget)
		{
			TagWidget->SetTask(InTask);
		}
	}
}



void UC7MapTagLayer::InnerUpdateTagTask(TSharedPtr<FMapTagRunningData> Task,UWidget* TagWiget,bool bUpdateLoc)
{
	if (TagWiget!=nullptr)
	{
		//Set Tag Position
		UCanvasPanelSlot* TagSlot = Cast<UCanvasPanelSlot>(TagWiget->Slot);
		if (TagSlot && bUpdateLoc)
		{
			TagSlot->SetAnchors(FAnchors(Task->WidgetCoord.X,Task->WidgetCoord.Y,Task->WidgetCoord.X,Task->WidgetCoord.Y));
			TagSlot->SetPosition(Task->TagData.WidgetPositionOffset);
			if (Task->TagData.bOverrideSize)
			{
				if (Task->TagData.bScaleWithMapScale)
				{
					TagSlot->SetSize((Task->TagData.SizeOverrideType == ESizeOverrideType::WIDGET_SIZE ? Task->TagData.SizeOverride : Task->TagData.SizeOverride * WorldSizeToWidgetSizeRatio) *CurrentMapScale);
				}else
				{
					TagSlot->SetSize((Task->TagData.SizeOverrideType == ESizeOverrideType::WIDGET_SIZE ? Task->TagData.SizeOverride : Task->TagData.SizeOverride * WorldSizeToWidgetSizeRatio));
				}
				
			}
			else
			{
				TagSlot->SetAutoSize(true);
			}
			TagSlot->SetAlignment(FVector2D(0.5,0.5));
			TagSlot->SetZOrder(Task->DisplayData.Zorder);
		}

		//Set Tag Rotation
		if (Task->TagData.bRotateWithActor && Task->TagData.FollowActor.IsValid())
		{
			if(auto MapTag = Cast<UC7MapTagWidget>(TagWiget))
			{
				FVector ActorForward = Task->TagData.FollowActor->GetActorForwardVector();
				MapTag->SetRotationAngle(FMath::RadiansToDegrees(ActorForward.HeadingAngle())+CurrentMapCenterRoation);
			}
		}
		else
		{
			if(auto MapTag = Cast<UC7MapTagWidget>(TagWiget))
			{
				MapTag->SetRotationAngle(0);
			}
		}
	}
}

FVector2D UC7MapTagLayer::GetProjectOnEdgeLoc(const FVector2D& WidgetLoc,const FVector2D& WidgetSize)
{
	if(EdgeMode == EMapEdgeMode::CONSTRAIN_IN_CANVAS)
	{
		const FVector2D CenterLoc = PanelSize/2;
		const FVector2D WidgetScreenLocRelativeToScreenCenter = (WidgetLoc - CenterLoc);
		float SacleX = CenterLoc.X/FMath::Abs(WidgetScreenLocRelativeToScreenCenter.X) ;
		float SacleY = CenterLoc.Y/FMath::Abs(WidgetScreenLocRelativeToScreenCenter.Y);
		float Sacle =FMath::Min(SacleX,SacleY);
		FVector2d ScreenEdgeProjectLoc = WidgetScreenLocRelativeToScreenCenter * Sacle + CenterLoc;
		
		ScreenEdgeProjectLoc.X = FMath::Clamp(ScreenEdgeProjectLoc.X,WidgetSize.X/2+ EdgePadding.X,PanelSize.X-WidgetSize.X/2 - EdgePadding.Z);
		ScreenEdgeProjectLoc.Y = FMath::Clamp(ScreenEdgeProjectLoc.Y,WidgetSize.Y/2 + EdgePadding.Y ,PanelSize.Y-WidgetSize.Y/2 - EdgePadding.W);
	
		return ScreenEdgeProjectLoc;
	}
	if(EdgeMode==EMapEdgeMode::CONSTRAIN_IN_CIRCLE)
	{
		const FVector2D CenterLoc = PanelSize/2;
		const FVector2D WidgetScreenLocRelativeToScreenCenter = (WidgetLoc - CenterLoc);
		
		FVector2D ScreenEdgeProjectLoc = CenterLoc + WidgetScreenLocRelativeToScreenCenter.GetSafeNormal()* ConstrainRadius;
		return ScreenEdgeProjectLoc;
	}
	return FVector2D(0,0);
}




void UC7MapTagLayer::InnerUpdateEdgeTask(TSharedPtr<FMapTagRunningData> Task,UWidget* EdgeWiget)
{
	if (IsValid(EdgeWiget))
	{
		UCanvasPanelSlot* TagSlot = Cast<UCanvasPanelSlot>(EdgeWiget->Slot);
		if (TagSlot)
		{
			//Set Edge Task Location
			FVector2d ScreenEdgeProjectLoc = GetProjectOnEdgeLoc( Task->WidgetScreenLoc,EdgeWiget->GetCachedGeometry().GetLocalSize());
			TagSlot->SetPosition(ScreenEdgeProjectLoc);
			
			if ( UC7MapTagEdgeWidget* EdgeTagWiget = Cast<UC7MapTagEdgeWidget>(EdgeWiget))
			{
				//Update Content
				InnerUpdateTagTask(Task,EdgeTagWiget->GetContentWidget(),false);
				
				//Set Arrow Rotation
				const FVector2D CenterLoc = PanelSize/2;
				const FVector2D WidgetScreenLocRelativeToScreenCenter = ( Task->WidgetScreenLoc - CenterLoc);
				float RadAngle =FVector(WidgetScreenLocRelativeToScreenCenter, 0).HeadingAngle();
				EdgeTagWiget->SetArrowRotation(FMath::RadiansToDegrees(RadAngle));
			}
		}
	}
}



void UC7MapTagLayer::UpdateTagTasks(const TArray<TSharedPtr<FMapTagRunningData>>& Tasks)
{
	for(auto Task :Tasks)
	{
		if (!Task.IsValid())
		{
			continue;
		}
		if (ShouldShow(Task,true))
		{
		
			if (!Task->TagWidget.IsValid())
			{
				//Generate New follow Task
				Task->TagWidget = GetWidgetFromPool(Task->TagData.TagWidgetPath);
				if (UC7MapTagBase* Tag = Cast<UC7MapTagBase>(Task->TagWidget))
				{
					Tag->OnClicked.BindUObject(this,&UC7MapTagLayer::OnTagClicked);
				}
				
				if (Task->TagWidget.IsValid())
				{
					if (Task->TagWidget->GetParent() != this)
					{
						AddChild(Task->TagWidget.Get());
					}
					Task->TagWidget->SetVisibility(Task->DisplayData.Visibility);
					ActiveTagWidget(Task,Task->TagWidget.Get());
					Task->TagWidget->SetRenderScale(Task->DisplayData.Scale);
				}
			}
			
			InnerUpdateTagTask(Task,Task->TagWidget.Get(),true);
		}
		else
		{
			if (Task->TagWidget.IsValid())
			{
				ReturnWidgetToPool(Task->TagData.TagWidgetPath,Task->TagWidget.Get());
				Task->TagWidget.Reset();
			}
		}
	}
}

void UC7MapTagLayer::ReturnEdgeTaskWidget(UC7MapTagEdgeWidget* EdgeTagWiget)
{
	if(EdgeTagWiget==nullptr)
	{
		return;
	}
	
	UWidget* Content = EdgeTagWiget->ReturnContentWidget();
	UC7MapTagWidget* TagWidget = Cast<UC7MapTagWidget>(Content);
	if (Content!=nullptr && TagWidget!=nullptr)
	{
		TSharedPtr<FMapTagRunningData> ContentTask = GetTaskById(TagWidget->GetCurrentTagTaskID());
		if(ContentTask.IsValid())
		{
			ReturnWidgetToPool(ContentTask->TagData.TagWidgetPath,Content);
		}
	}
	TSharedPtr<FMapTagRunningData> Task = GetTaskById(EdgeTagWiget->GetCurrentTagTaskID());
	if (Task.IsValid())
	{
		ReturnWidgetToPool(Task->DisplayData.EdgeWidgetPath,EdgeTagWiget);
	}
}

void UC7MapTagLayer::UpdateTags(const TArray<TSharedPtr<FMapTagRunningData>>& MapTagTasks)
{
	UpdateTasksScreenLoc(MapTagTasks);
	UpdateTagTasks(MapTagTasks);
	UpdateEdgeTasks(MapTagTasks);
	UpdateSelectionTasks(MapTagTasks);
}

void UC7MapTagLayer::UpdateTasksScreenLoc(const TArray<TSharedPtr<FMapTagRunningData>>& MapTasks)
{
	for(auto Task :MapTasks)
	{
		if (!Task.IsValid())
		{
			continue;
		}
		UpdateTagScreenLocation(Task,false);
	}
}

void UC7MapTagLayer::UpdateEdgeTasks(const TArray<TSharedPtr<FMapTagRunningData>>& MapTasks)
{
	for(auto Task :MapTasks)
	{
		if (!Task.IsValid())
		{
			continue;
		}
		if (ShouldKeepOnEdge(Task) && !Task->DisplayData.EdgeWidgetPath.IsNone())
		{
			if (!IsInConstrainArea(Task,false)&& InDistRange(Task->TagData.WorldLoc,Task->DisplayData.ShowDistance,Task->DisplayData.HideDistance,GetWorld()))
			{
			
				if (!Task->EdgeWidget.IsValid())
				{
					//EdgeTask Not Active Create New EdgeTask
					Task->EdgeWidget = GetWidgetFromPool(Task->DisplayData.EdgeWidgetPath);
					if (UC7MapTagBase* Tag = Cast<UC7MapTagBase>(Task->EdgeWidget))
					{
						Tag->OnClicked.BindUObject(this,&UC7MapTagLayer::OnEdgeTagClicked);
					}

					
					//Set Edge Widget Content
					if ( UC7MapTagEdgeWidget* EdgeTagWiget = Cast<UC7MapTagEdgeWidget>(Task->EdgeWidget))
					{
						if (EdgeTagWiget->HasContentPanel())
						{
							UWidget* ContentWidget = GetWidgetFromPool(Task->TagData.TagWidgetPath);
							if (ContentWidget)
							{
								ContentWidget->RemoveFromParent();
								ContentWidget->SetVisibility(ESlateVisibility::HitTestInvisible);
								ActiveTagWidget(Task,ContentWidget);
								Task->EdgeWidget->SetRenderScale(FVector2D(1,1));
								EdgeTagWiget->SetContentWidget(ContentWidget);
							}
						}
					}

					//Set Widget Slot
					if (Task->EdgeWidget.IsValid())
					{
						if(Task->EdgeWidget->GetParent() == nullptr)
						{
							AddChild(Task->EdgeWidget.Get());
							
							if (UCanvasPanelSlot* TagSlot = Cast<UCanvasPanelSlot>(Task->EdgeWidget->Slot))
							{
								TagSlot->SetAlignment(FVector2D(0.5,0.5));
								TagSlot->SetAutoSize(true);
								TagSlot->SetZOrder(Task->DisplayData.Zorder);
							}
						}
						Task->EdgeWidget->SetVisibility(ESlateVisibility::SelfHitTestInvisible);
						ActiveTagWidget(Task,Task->EdgeWidget.Get());
						Task->EdgeWidget->SetRenderScale(Task->DisplayData.Scale);
					}
				
				}
				
				//Start Update The Task
				InnerUpdateEdgeTask(Task,Task->EdgeWidget.Get());
			}else
			{
				//EdgeTask Not OutSide Panel Remove EdgeTask
				if (Task->EdgeWidget.IsValid())
				{
					ReturnEdgeTaskWidget(Cast<UC7MapTagEdgeWidget>(Task->EdgeWidget));
					Task->EdgeWidget.Reset();
				}
			}
		}
		else
		{
			if (Task->EdgeWidget.IsValid())
			{
				ReturnEdgeTaskWidget(Cast<UC7MapTagEdgeWidget>(Task->EdgeWidget));
				Task->EdgeWidget.Reset();
			}
		}
	}
}


void UC7MapTagLayer::InnerUpdateSelectionTask(TSharedPtr<FMapTagRunningData> Task,UWidget* TagWiget,bool bUpdateLoc)
{
	if (TagWiget!=nullptr)
	{
		//Set Tag Position
		UCanvasPanelSlot* TagSlot = Cast<UCanvasPanelSlot>(TagWiget->Slot);
		if (TagSlot && bUpdateLoc)
		{
			TagSlot->SetPosition(Task->WidgetScreenLoc);
			TagSlot->SetAutoSize(true);
			TagSlot->SetAlignment(FVector2D(0.5,0.5));
			TagSlot->SetZOrder(MAP_TAG_SELECTION_Z_ORDER);
		}
	}
}


void UC7MapTagLayer::UpdateSelectionTasks(const TArray<TSharedPtr<FMapTagRunningData>>& MapTasks)
{
	for(auto Task :MapTasks)
	{
		if (!Task.IsValid())
		{
			continue;
		}

		if (Task->bValidScreenLoc && Task->bSelected && 
		IsInConstrainArea(Task,true) && !Task->DisplayData.SelectionWidgetPath.IsNone())
		{
	;
			if (!Task->SelectionWidget.IsValid())
			{
				//Generate New follow Task
				Task->SelectionWidget = GetWidgetFromPool(Task->DisplayData.SelectionWidgetPath);
				if (Task->SelectionWidget != nullptr)
				{
					if(Task->SelectionWidget->GetParent() != this)
					{
						AddChild(Task->SelectionWidget.Get());
					}
					
					Task->SelectionWidget->SetVisibility(ESlateVisibility::HitTestInvisible);
					ActiveTagWidget(Task,Task->SelectionWidget.Get());
				}
			}
			
			InnerUpdateSelectionTask(Task,Task->SelectionWidget.Get(),true);
		}
		else
		{
			if (Task->SelectionWidget.IsValid())
			{
				ReturnWidgetToPool(Task->DisplayData.SelectionWidgetPath,Task->SelectionWidget.Get());
				Task->SelectionWidget.Reset();
			}
		}
	}
}

void UC7MapTagLayer::OnViewScreenChangedByWorldLoc(const FVector& WorldLoc,float NewMapScale,float MapCenterRotation ,float ScreenCenterRotation )
{
  OnViewScreenChanged(WorldLocToWidgetLocRaw(WorldLoc)*CurrentMapScale,NewMapScale,
  MapCenterRotation ,
  ScreenCenterRotation);
}


void UC7MapTagLayer::OnViewScreenChanged(const FVector2D& ScreenCenterOnWidgetLoc,float NewMapScale,float MapCenterRotation ,float ScreenCenterRotation )
{
	bool bViewScreenChanged = false;
	if (CurrentMapCenterRoation != MapCenterRotation)
	{
		CurrentMapCenterRoation = MapCenterRotation;
		bViewScreenChanged= true;
	}

	if (CurrentScreenCenterRotation != ScreenCenterRotation)
	{
		CurrentScreenCenterRotation = ScreenCenterRotation;
		bViewScreenChanged= true;
	}

	
	if (NewMapScale!= CurrentMapScale)
	{
		CurrentMapScale = NewMapScale;
		float MapScaleRatio = 1;
		float ScaleDiff = FMath::Sqrt(MapMaxScale) -FMath::Sqrt(MapMinScale);
		if (ScaleDiff != 0 )
		{
			MapScaleRatio = ( FMath::Sqrt(NewMapScale) -FMath::Sqrt(MapMinScale)) / ScaleDiff;
		}
		CurrentScaleRatio = MapScaleRatio;
		bViewScreenChanged= true;
	}
	if (CurrentScreenCenterLoc != ScreenCenterOnWidgetLoc)
	{
		CurrentScreenCenterLoc = ScreenCenterOnWidgetLoc;
		bViewScreenChanged= true;
	}
	
	if (bViewScreenChanged)
	{
		TArray<TSharedPtr<FMapTagRunningData>> UpdateArray;
		MapStaticTasks.GenerateValueArray(UpdateArray);
		UpdateTags(UpdateArray);
	}

	TArray<TSharedPtr<FMapTagRunningData>> TickUpdateArray;
	MapTickTasks.GenerateValueArray(TickUpdateArray);
	UpdateTags(TickUpdateArray);
	
	
}

void UC7MapTagLayer::OnTagClicked(int32 TaskID)
{
	TSharedPtr<FMapTagRunningData> Task = GetTaskById(TaskID);
	if (OnTagClickedEvent.IsBound() && Task.IsValid())
	{
		TArray<int32> NearByTags;
		if (Task->bValidScreenLoc)
		{
			GetNearByTags(Task->WidgetScreenLoc,ClickToleranceDist,true,NearByTags);
		}
		
		OnTagClickedEvent.Execute(TaskID,NearByTags);
	}
}

void UC7MapTagLayer::OnEdgeTagClicked(int32 TaskID)
{
	TSharedPtr<FMapTagRunningData> Task = GetTaskById(TaskID);
	if (OnEdgeTagClickedEvent.IsBound() && Task.IsValid())
	{
		OnEdgeTagClickedEvent.Execute(TaskID);
	}
}



void UC7MapTagLayer::Tick(float DeltaTime)
{
	SCOPE_CYCLE_COUNTER(STAT_MapTickCenterTick)
	
	ProcessPendingTasks();

	if (IsValid(this) && PanelSize != GetCachedGeometry().GetLocalSize() || bForceRefreshNextTick)
	{
		bForceRefreshNextTick = false;
		PanelSize = GetCachedGeometry().GetLocalSize();
		PanelTolerancePadding = PanelSize * (ToleranceScale-1)/2;
		TArray<TSharedPtr<FMapTagRunningData>> UpdateArray;
		MapStaticTasks.GenerateValueArray(UpdateArray);
		UpdateTags(UpdateArray);
	}

	TArray<TSharedPtr<FMapTagRunningData>> TickUpdateArray;
	MapTickTasks.GenerateValueArray(TickUpdateArray);
	UpdateTags(TickUpdateArray);
}

TStatId UC7MapTagLayer::GetStatId() const
{
	return GetStatID();
}

bool UC7MapTagLayer::IsTickable() const
{
	return true;
}



void UC7MapTagLayer::SetWidgetRotationByActorRot(UWidget* Widget,AActor * Actor,float InitialRotDelta )
{
	if (Actor!= nullptr && Widget!=nullptr && IsValid(Widget) && IsValid(Actor))
	{

		Widget->SetRenderTransformAngle( FMath::RadiansToDegrees(Actor->GetActorForwardVector().HeadingAngle()) + InitialRotDelta);
	}
}

int32 UC7MapTagLayer::GetLayerID(FVector& Location)
{
	for(int i =0;i < LayerData.Num();i+=2)
	{
		if ((i+1) < LayerData.Num())
		{
			const FVector& Minimun = LayerData[i];
			const FVector& Maximun = LayerData[i+1];
			if( Location.X  > Minimun.X &&
				Location.Y  > Minimun.Y &&
				Location.Z  > Minimun.Z &&
				Location.X  < Maximun.X &&
				Location.Y  < Maximun.Y &&
				Location.Z  < Maximun.Z
			)
			{
				return i/2 + 1;
			}
		}
	}
	return 0;
}



inline bool IsClickable(TWeakObjectPtr<UWidget> widget){
	if (widget.IsValid())
	{
		switch (widget->GetVisibility())
		{
		case ESlateVisibility::Collapsed:
			return false;
		case ESlateVisibility::Hidden:
			return false;
		case ESlateVisibility::HitTestInvisible:
			return false;
		case ESlateVisibility::SelfHitTestInvisible:
			return true;
		case ESlateVisibility::Visible:
			return true;
		default:
			return false;
		}
	}
	return false;
}
void UC7MapTagLayer::GetNearByTags(FVector2D& ScreenLocation,float ToleranceDist,bool ClickableOnly,TArray<int32>& OutArray)
{
	OutArray.Empty();
	TMap<int32,float> IDDistMap;
	for (auto KeyPair:MapStaticTasks )
	{
		TSharedPtr<FMapTagRunningData> TagData = KeyPair.Value;
		if ( ShouldShow(TagData,true))
		{
			if (!ClickableOnly ||(ClickableOnly && IsClickable(TagData->TagWidget )))
				{
					float Dist = (TagData->WidgetScreenLoc-ScreenLocation).Size();
					if (Dist < ToleranceDist)
					{
						IDDistMap.Add(TagData->TagData.TagID,Dist);
						OutArray.Add(TagData->TagData.TagID);
					}
				}
		}
	}

	OutArray.Sort([&IDDistMap](const int32& IDA,const int32& IDB)
	{
		float* DistA = IDDistMap.Find(IDA);
		float* DistB = IDDistMap.Find(IDB);

		if (DistA!=nullptr && DistA!=nullptr)
		{
			return *DistA < *DistB;
		}
		return false;
	});

}


void UC7MapTagLayer::UpdateMiniMap(UWidget* MapWidget, UWidget* PlayerWidget,UWidget* SightConeWidget, EMiniMapUpdateRule UpdateRule,float Scale)
{
	APlayerController* PC  = UGameplayStatics::GetPlayerController(this, 0);
	AActor* MainChar  = UGameplayStatics::GetPlayerCharacter(this, 0);
	if (PC== nullptr || MainChar == nullptr)
	{
		return;
	}
	
	float CharAngle = FMath::RadiansToDegrees(MainChar->K2_GetActorRotation().Vector().HeadingAngle());
	float CamAngle = FMath::RadiansToDegrees(PC->K2_GetActorRotation().Vector().HeadingAngle());

	
	if (MapWidget!= nullptr && IsValid(MapWidget)   )
	{
		if (EMiniMapUpdateRule::UPWARD_NORTH == UpdateRule)
		{
			MapWidget->SetRenderTransformAngle(0);
			OnViewScreenChangedByWorldLoc(MainChar->GetActorLocation(),Scale,0,0);
		}
		else if (EMiniMapUpdateRule::PLAYER_FACE_UPWARD  == UpdateRule )
		{
			MapWidget->SetRenderTransformAngle(-CamAngle-90);
			OnViewScreenChangedByWorldLoc(MainChar->GetActorLocation(),Scale,0,-CamAngle-90);
		}
	}

	if (PlayerWidget!= nullptr && IsValid(PlayerWidget)  )
	{
		if (EMiniMapUpdateRule::UPWARD_NORTH == UpdateRule)
		{
			PlayerWidget->SetRenderTransformAngle(CharAngle + 90);
		}
		else if (EMiniMapUpdateRule::PLAYER_FACE_UPWARD  == UpdateRule )
		{
			PlayerWidget->SetRenderTransformAngle(CharAngle+CamAngle+90);
		}
	}

	if (SightConeWidget!= nullptr && IsValid(SightConeWidget)  )
	{
		if (EMiniMapUpdateRule::UPWARD_NORTH == UpdateRule)
		{
			SightConeWidget->SetRenderTransformAngle(CamAngle + 90);
		}
		else if (EMiniMapUpdateRule::PLAYER_FACE_UPWARD  == UpdateRule )
		{
			SightConeWidget->SetRenderTransformAngle(-90);
		}
	}
}