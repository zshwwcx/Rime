#include "C7LandscapeSplineActor.h"
#include "Components/SceneComponent.h"
#include "LandscapeSplineControlPoint.h"


AC7LandscapeSplineActor::AC7LandscapeSplineActor() : Super()
{
	RootComponent = CreateDefaultSubobject<USceneComponent>(TEXT("Root Component"));

	SplineComponents.Empty();

	bIsEditorOnlyActor = false;

#if WITH_EDITOR
	EditorTags.AddUnique("KGScene_EditorDrawActor");
#endif
}

void AC7LandscapeSplineActor::AddSplineComponent(FString name)
{
	USplineComponent* Spline = NewObject<USplineComponent>(this, USplineComponent::StaticClass(), FName(*name));
	Spline->RegisterComponentWithWorld(GetWorld());
	Spline->ClearSplinePoints(true);
	if (nullptr != Spline)
	{
		SplineComponents.Add(Spline);
	}
}

void AC7LandscapeSplineActor::CalControlPointGroup()
{

}

void AC7LandscapeSplineActor::GenerateSpline()
{
#if WITH_EDITOR
	if (Landscape != nullptr) 
	{
		for (int i = 0; i < SplineComponents.Num(); ++i)
		{
			SplineComponents[i]->ClearSplinePoints(true);
		}
		SplineComponents.Empty();
		int SplineCnt = 0;
		TSet<class ULandscapeSplineSegment*> VisLandscapeSplineSegment;

		ULandscapeSplinesComponent* LandscapeSpline = Landscape->GetSplinesComponent();
		if (bWithWorldPartition)
		{ 
			TArray<TScriptInterface<ILandscapeSplineInterface>> LSSI = Landscape->GetLandscapeInfo()->GetSplineActors();

			for (int l = 0; l < LSSI.Num(); ++l)
			{ 
				if (ULandscapeSplinesComponent* LandscapeSplinesComponent = Cast<ULandscapeSplinesComponent>(LSSI[l]->GetSplinesComponent()))
				{ 
					TArray<TObjectPtr<ULandscapeSplineSegment>> LandscapeSplineSegment0 = LandscapeSplinesComponent->Segments;

					VisLandscapeSplineSegment.Empty();
					TArray<TObjectPtr<ULandscapeSplineSegment>> FirstNodeList;

					for (int i = 0; i < LandscapeSplineSegment0.Num(); i++)
					{
						if (LandscapeSplineSegment0[i]->LayerName == ExcludeLayer)
						{
							continue;
						}

						if (!VisLandscapeSplineSegment.Contains(LandscapeSplineSegment0[i]))
						{
							TArray<ULandscapeSplineSegment*> SegmentsToProcess;
							SegmentsToProcess.Add(LandscapeSplineSegment0[i]);
							VisLandscapeSplineSegment.Add(LandscapeSplineSegment0[i]);

							bool Found = false;
							while (SegmentsToProcess.Num() > 0)
							{
								ULandscapeSplineSegment* Segment = SegmentsToProcess.Pop();
								for (const FLandscapeSplineSegmentConnection& SegmentConnection : Segment->Connections)
								{
									if (!Found && 1 == SegmentConnection.ControlPoint->ConnectedSegments.Num())
									{
										FirstNodeList.Add(Segment);
										Found = true;
									}

									for (const FLandscapeSplineConnection& Connection : SegmentConnection.ControlPoint->ConnectedSegments)
									{
										if (Connection.Segment->LayerName == ExcludeLayer)
										{
											continue;
										}

										if (!VisLandscapeSplineSegment.Contains(Connection.Segment))
										{
											SegmentsToProcess.Add(Connection.Segment);
											VisLandscapeSplineSegment.Add(Connection.Segment);
										}
									}
								}
							}
							if (!Found)
							{
								FirstNodeList.Add(LandscapeSplineSegment0[i]);
								Found = true;
							}
						}
					}

					// for circle
					if (FirstNodeList.IsEmpty() && LandscapeSplinesComponent->Segments.Num() > 0 && 
						LandscapeSplinesComponent->Segments[0]->LayerName != ExcludeLayer)
					{
						FirstNodeList.Add(LandscapeSplinesComponent->Segments[0]);
					}

					VisLandscapeSplineSegment.Empty();
					TSet<class ULandscapeSplineSegment*> LineRooter;
					for (int i = 0; i < FirstNodeList.Num(); ++i)
					{
						LineRooter.Empty();
						VisLandscapeSplineSegment.Empty();
						FString LayerNameTemp = FirstNodeList[i]->LayerName.ToString();
						AddSplineComponent("Spline_" + FString::FromInt(SplineCnt++) + FString("_") + FirstNodeList[i]->LayerName.ToString());
						USplineComponent* CurSpline = SplineComponents[SplineComponents.Num() - 1];

						TArray<ULandscapeSplineSegment*> SegmentsToProcess;
						SegmentsToProcess.Add(FirstNodeList[i]);

						VisLandscapeSplineSegment.Add(FirstNodeList[i]);
						
						while (SegmentsToProcess.Num() > 0)
						{
							ULandscapeSplineSegment* Segment = SegmentsToProcess.Pop();
							Segment->UpdateSplinePoints(false, false);
							
							for (const FLandscapeSplineSegmentConnection& SegmentConnection : Segment->Connections)
							{
								for (const FLandscapeSplineConnection& Connection : SegmentConnection.ControlPoint->ConnectedSegments)
								{
									if (!VisLandscapeSplineSegment.Contains(Connection.Segment))
									{
										SegmentsToProcess.Add(Connection.Segment);
										VisLandscapeSplineSegment.Add(Connection.Segment);
									}
								}
							}
						}

						if (VisLandscapeSplineSegment.Num() > 0)
						{
							TArray<ULandscapeSplineSegment*> VisLandscapeSplineSegmentArr = VisLandscapeSplineSegment.Array();
							FVector LastPoint = FVector::ZeroVector;
							ULandscapeSplineSegment* Segment = FirstNodeList[i];

							LineRooter.Add(FirstNodeList[i]);
							for (int j = FirstNodeList[i]->GetPoints().Num() - 1; j >= 0; --j)
							{
								CurSpline->AddSplinePoint(Segment->GetPoints()[j].Center + LandscapeSplinesComponent->GetOwner()->GetActorLocation(), ESplineCoordinateSpace::World, true);

								// set width
								int SplinePointNum = CurSpline->GetNumberOfSplinePoints() - 1;
								float Width = Segment->GetPoints()[j].Width;
								CurSpline->SetScaleAtSplinePoint(SplinePointNum, FVector(Width, 1.0, 1.0));

								UE_LOG(LogTemp, Log, TEXT("PCG Road %s Width %f"), *Segment->GetName(), Width);

								LastPoint = Segment->GetPoints()[j].Center;
							}

							int TotalSegment = VisLandscapeSplineSegmentArr.Num();
							TArray<bool> VisIndex;
							VisIndex.Init(false, TotalSegment);
							VisIndex[0] = true;

							while (--TotalSegment > 0)
							{
								for (int k = 0; k < VisLandscapeSplineSegmentArr.Num(); ++k)
								{
									if (!VisIndex[k] && !LineRooter.Contains(VisLandscapeSplineSegmentArr[k]))
									{
										int SegmentPointNum = VisLandscapeSplineSegmentArr[k]->GetPoints().Num();
										Segment = VisLandscapeSplineSegmentArr[k];
										if (VisLandscapeSplineSegmentArr[k]->GetPoints()[0].Center == LastPoint)
										{
											for (int j = 0; j < SegmentPointNum; ++j)
											{
												CurSpline->AddSplinePoint(Segment->GetPoints()[j].Center + LandscapeSplinesComponent->GetOwner()->GetActorLocation(), ESplineCoordinateSpace::World, true);

												// set width
												int SplinePointNum = CurSpline->GetNumberOfSplinePoints() - 1;
												float Width = Segment->GetPoints()[j].Width;
												CurSpline->SetScaleAtSplinePoint(SplinePointNum, FVector(Width, 1.0, 1.0));

												UE_LOG(LogTemp, Log, TEXT("PCG Road %s Width %f"), *Segment->GetName(), Width);

												LastPoint = Segment->GetPoints()[j].Center;
											}

											VisIndex[k] = true;
											LineRooter.Add(VisLandscapeSplineSegmentArr[k]);
										}
										else if (VisLandscapeSplineSegmentArr[k]->GetPoints()[SegmentPointNum - 1].Center == LastPoint)
										{
											for (int j = SegmentPointNum - 1; j >= 0; --j)
											{
												CurSpline->AddSplinePoint(Segment->GetPoints()[j].Center + LandscapeSplinesComponent->GetOwner()->GetActorLocation(), ESplineCoordinateSpace::World, true);

												// set width
												int SplinePointNum = CurSpline->GetNumberOfSplinePoints() - 1;
												float Width = Segment->GetPoints()[j].Width;
												CurSpline->SetScaleAtSplinePoint(SplinePointNum, FVector(Width, 1.0, 1.0));

												UE_LOG(LogTemp, Log, TEXT("PCG Road %s Width %f"), *Segment->GetName(), Width);

												LastPoint = Segment->GetPoints()[j].Center;
											}

											VisIndex[k] = true;
											LineRooter.Add(VisLandscapeSplineSegmentArr[k]);
										}
									}
								}
							}
						}
					}
				}
			}
		}
		else
		{ 
			TArray<TObjectPtr<ULandscapeSplineSegment>> LandscapeSplineSegments = LandscapeSpline->Segments;

			VisLandscapeSplineSegment.Empty();
			TArray<TObjectPtr<ULandscapeSplineSegment>> FirstNodeList;

			for (int i = 0; i < LandscapeSplineSegments.Num(); i++)
			{
				if (LandscapeSplineSegments[i]->LayerName == ExcludeLayer)
				{
					continue;
				}

				if (!VisLandscapeSplineSegment.Contains(LandscapeSplineSegments[i]))
				{ 
					TArray<ULandscapeSplineSegment*> SegmentsToProcess;
					SegmentsToProcess.Add(LandscapeSplineSegments[i]);
					VisLandscapeSplineSegment.Add(LandscapeSplineSegments[i]);

					bool Found = false;
					while (SegmentsToProcess.Num() > 0)
					{
						ULandscapeSplineSegment* Segment = SegmentsToProcess.Pop();
						for (const FLandscapeSplineSegmentConnection& SegmentConnection : Segment->Connections)
						{
							if (!Found && 1 == SegmentConnection.ControlPoint->ConnectedSegments.Num())
							{
								FirstNodeList.Add(Segment);
								Found = true;
							}

							for (const FLandscapeSplineConnection& Connection : SegmentConnection.ControlPoint->ConnectedSegments)
							{
								if (Connection.Segment->LayerName == ExcludeLayer)
								{
									continue;
								}

								if (!VisLandscapeSplineSegment.Contains(Connection.Segment))
								{
									SegmentsToProcess.Add(Connection.Segment);
									VisLandscapeSplineSegment.Add(Connection.Segment);
								}
							}
						}
					}
				}
			}

			// for circle
			if (FirstNodeList.IsEmpty() && LandscapeSpline->Segments.Num() > 0 &&
				LandscapeSpline->Segments[0]->LayerName != ExcludeLayer)
			{
				FirstNodeList.Add(LandscapeSpline->Segments[0]);
			}

			VisLandscapeSplineSegment.Empty();
			TSet<class ULandscapeSplineSegment*> LineRooter;
			for (int i = 0; i < FirstNodeList.Num(); ++i)
			{
				LineRooter.Empty();
				AddSplineComponent("Spline_" + FString::FromInt(SplineCnt++) + FString("_") + FirstNodeList[i]->LayerName.ToString());
				USplineComponent* CurSpline = SplineComponents[SplineComponents.Num() - 1];

				TArray<ULandscapeSplineSegment*> SegmentsToProcess;
				SegmentsToProcess.Add(FirstNodeList[i]);

				VisLandscapeSplineSegment.Add(FirstNodeList[i]);
				
				while (SegmentsToProcess.Num() > 0)
				{
					ULandscapeSplineSegment* Segment = SegmentsToProcess.Pop();
					Segment->UpdateSplinePoints(false, false);
					for (const FLandscapeSplineSegmentConnection& SegmentConnection : Segment->Connections)
					{
						for (const FLandscapeSplineConnection& Connection : SegmentConnection.ControlPoint->ConnectedSegments)
						{
							if (!VisLandscapeSplineSegment.Contains(Connection.Segment))
							{
								SegmentsToProcess.Add(Connection.Segment);
								VisLandscapeSplineSegment.Add(Connection.Segment);
							}
						}
					}
				}

				if (VisLandscapeSplineSegment.Num() > 0)
				{
					TArray<ULandscapeSplineSegment*> VisLandscapeSplineSegmentArr = VisLandscapeSplineSegment.Array();
					FVector LastPoint = FVector::ZeroVector;
					ULandscapeSplineSegment* Segment = FirstNodeList[i];

					LineRooter.Add(FirstNodeList[i]);
					for (int j = FirstNodeList[i]->GetPoints().Num() - 1; j >= 0; --j)
					{
						CurSpline->AddSplinePoint(Segment->GetPoints()[j].Center + Landscape->GetActorLocation(), ESplineCoordinateSpace::World, true);

						// set width
						int SplinePointNum = CurSpline->GetNumberOfSplinePoints() - 1;
						float Width = Segment->GetPoints()[j].Width;
						CurSpline->SetScaleAtSplinePoint(SplinePointNum, FVector(Width, 1.0, 1.0));

						UE_LOG(LogTemp, Log, TEXT("PCG Road %s Width %f"), *Segment->GetName(), Width);

						LastPoint = Segment->GetPoints()[j].Center;
					}

					int TotalSegment = VisLandscapeSplineSegmentArr.Num();
					TArray<bool> VisIndex;
					VisIndex.Init(false, TotalSegment);
					VisIndex[0] = true;

					while (--TotalSegment > 0)
					{ 
						for (int k = 0; k < VisLandscapeSplineSegmentArr.Num(); ++k)
						{
							if (!VisIndex[k] && !LineRooter.Contains(VisLandscapeSplineSegmentArr[k]))
							{
								int SegmentPointNum = VisLandscapeSplineSegmentArr[k]->GetPoints().Num();
								Segment = VisLandscapeSplineSegmentArr[k];
								if (VisLandscapeSplineSegmentArr[k]->GetPoints()[0].Center == LastPoint)
								{
									for (int j = 0; j < SegmentPointNum; ++j)
									{
										CurSpline->AddSplinePoint(Segment->GetPoints()[j].Center + Landscape->GetActorLocation(), ESplineCoordinateSpace::World, true);

										// set width
										int SplinePointNum = CurSpline->GetNumberOfSplinePoints() - 1;
										float Width = Segment->GetPoints()[j].Width;
										CurSpline->SetScaleAtSplinePoint(SplinePointNum, FVector(Width, 1.0, 1.0));

										UE_LOG(LogTemp, Log, TEXT("PCG Road %s Width %f"), *Segment->GetName(), Width);

										LastPoint = Segment->GetPoints()[j].Center;
									}

									VisIndex[k] = true;
									LineRooter.Add(VisLandscapeSplineSegmentArr[k]);
								}
								else if (VisLandscapeSplineSegmentArr[k]->GetPoints()[SegmentPointNum - 1].Center == LastPoint)
								{
									for (int j = SegmentPointNum - 1; j >= 0; --j)
									{
										CurSpline->AddSplinePoint(Segment->GetPoints()[j].Center + Landscape->GetActorLocation(), ESplineCoordinateSpace::World, true);

										// set width
										int SplinePointNum = CurSpline->GetNumberOfSplinePoints() - 1;
										float Width = Segment->GetPoints()[j].Width;
										CurSpline->SetScaleAtSplinePoint(SplinePointNum, FVector(Width, 1.0, 1.0));

										UE_LOG(LogTemp, Log, TEXT("PCG Road %s Width %f"), *Segment->GetName(), Width);

										LastPoint = Segment->GetPoints()[j].Center;
									}

									VisIndex[k] = true;
									LineRooter.Add(VisLandscapeSplineSegmentArr[k]);
								}
							}
						}
					}
				}

			}
		}
	}
#endif
}