#include "C7RecastNavMeshGenetator.h"
#include <NavigationSystem.h>
#include "EngineUtils.h"
#include "AI/Navigation/NavAreaBase.h"

FC7RecastGeometryCache::FC7RecastGeometryCache(const uint8* Memory)
{
	Header = *((FHeader*)Memory);
	Verts = (FVector::FReal*)(Memory + sizeof(FRecastGeometryCache));
	Indices = (int32*)(Memory + sizeof(FRecastGeometryCache) + (sizeof(FVector::FReal) * Header.NumVerts * 3));
}

void FC7RecastNavMeshGenerator::GrowConvexHull(const float ExpandBy, const TArray<FVector>& Verts, TArray<FVector>& OutResult) const
{
	if (Verts.Num() < 3)
	{
		return;
	}

	struct FSimpleLine
	{
		FVector P1, P2;

		FSimpleLine() {}

		FSimpleLine(FVector Point1, FVector Point2)
			: P1(Point1), P2(Point2)
		{

		}
		static FVector Intersection(const FSimpleLine& Line1, const FSimpleLine& Line2)
		{
			const float A1 = Line1.P2.X - Line1.P1.X;
			const float B1 = Line2.P1.X - Line2.P2.X;
			const float C1 = Line2.P1.X - Line1.P1.X;

			const float A2 = Line1.P2.Y - Line1.P1.Y;
			const float B2 = Line2.P1.Y - Line2.P2.Y;
			const float C2 = Line2.P1.Y - Line1.P1.Y;

			const float Denominator = A2 * B1 - A1 * B2;
			if (Denominator != 0)
			{
				const float t = (B1 * C2 - B2 * C1) / Denominator;
				return Line1.P1 + t * (Line1.P2 - Line1.P1);
			}

			return FVector::ZeroVector;
		}
	};

	TArray<FVector> AllVerts(Verts);
	AllVerts.Add(Verts[0]);
	AllVerts.Add(Verts[1]);

	const int32 VertsCount = AllVerts.Num();
	const FQuat Rotation90(FVector(0, 0, 1), FMath::DegreesToRadians(90));

	float RotationAngle = MAX_FLT;
	for (int32 Index = 0; Index < VertsCount - 2; ++Index)
	{
		const FVector& V1 = AllVerts[Index + 0];
		const FVector& V2 = AllVerts[Index + 1];
		const FVector& V3 = AllVerts[Index + 2];

		const FVector V01 = (V1 - V2).GetSafeNormal();
		const FVector V12 = (V2 - V3).GetSafeNormal();
		const FVector NV1 = Rotation90.RotateVector(V01);
		const float d = FVector::DotProduct(NV1, V12);

		if (d < 0)
		{
			RotationAngle = -90;
			break;
		}
		else if (d > 0)
		{
			RotationAngle = 90;
			break;
		}
	}

	if (RotationAngle >= BIG_NUMBER)
	{
		return;
	}

	const float ExpansionThreshold = 2 * ExpandBy;
	const float ExpansionThresholdSQ = ExpansionThreshold * ExpansionThreshold;
	const FQuat Rotation(FVector(0, 0, 1), FMath::DegreesToRadians(RotationAngle));
	FSimpleLine PreviousLine;
	OutResult.Reserve(Verts.Num());
	for (int32 Index = 0; Index < VertsCount - 2; ++Index)
	{
		const FVector& V1 = AllVerts[Index + 0];
		const FVector& V2 = AllVerts[Index + 1];
		const FVector& V3 = AllVerts[Index + 2];

		FSimpleLine Line1;
		if (Index > 0)
		{
			Line1 = PreviousLine;
		}
		else
		{
			const FVector V01 = (V1 - V2).GetSafeNormal();
			const FVector N1 = Rotation.RotateVector(V01).GetSafeNormal();
			const FVector MoveDir1 = N1 * ExpandBy;
			Line1 = FSimpleLine(V1 + MoveDir1, V2 + MoveDir1);
		}

		const FVector V12 = (V2 - V3).GetSafeNormal();
		const FVector N2 = Rotation.RotateVector(V12).GetSafeNormal();
		const FVector MoveDir2 = N2 * ExpandBy;
		const FSimpleLine Line2(V2 + MoveDir2, V3 + MoveDir2);

		const FVector NewPoint = FSimpleLine::Intersection(Line1, Line2);
		if (NewPoint == FVector::ZeroVector)
		{
			OutResult.Add(V2 + MoveDir2);
		}
		else
		{
			const FVector VectorToNewPoint = NewPoint - V2;
			const float DistToNewVector = VectorToNewPoint.SizeSquared2D();
			if (DistToNewVector > ExpansionThresholdSQ)
			{
				const FVector HelpPos = V2 + VectorToNewPoint.GetSafeNormal2D() * ExpandBy * 1.4142;
				OutResult.Add(HelpPos);
			}
			else
			{
				OutResult.Add(NewPoint);
			}
		}

		PreviousLine = Line2;
	}
}

void FC7RecastNavMeshGenerator::TransformVertexSoupToRecast(const TArray<FVector>& VertexSoup, TNavStatArray<FVector>& Verts, TNavStatArray<int32>& Faces) const
{
	if (VertexSoup.Num() == 0)
	{
		return;
	}

	check(VertexSoup.Num() % 3 == 0);

	const int32 StaticFacesCount = VertexSoup.Num() / 3;
	int32 VertsCount = Verts.Num();
	const FVector* Vertex = VertexSoup.GetData();

	for (int32 k = 0; k < StaticFacesCount; ++k, Vertex += 3)
	{
		Verts.Add(Unreal2RecastPoint(Vertex[0]));
		Verts.Add(Unreal2RecastPoint(Vertex[1]));
		Verts.Add(Unreal2RecastPoint(Vertex[2]));
		Faces.Add(VertsCount + 2);
		Faces.Add(VertsCount + 1);
		Faces.Add(VertsCount + 0);

		VertsCount += 3;
	}
}

void FC7RecastNavMeshGenerator::ExportGeomToOBJFile(const FString& InFileName, const TNavStatArray<FVector::FReal>& GeomCoords,
													const TNavStatArray<int32>& GeomFaces, const FString& AdditionalData) const
{
	FString FileName = InFileName;

	FArchive* FileAr = IFileManager::Get().CreateDebugFileWriter(*FileName);
	if (FileAr != NULL)
	{
		for (int32 Index = 0; Index < GeomCoords.Num(); Index += 3)
		{
			FString LineToSave = FString::Printf(TEXT("v %f %f %f\n"), GeomCoords[Index + 0], GeomCoords[Index + 1], GeomCoords[Index + 2]);
			auto AnsiLineToSave = StringCast<ANSICHAR>(*LineToSave);
			FileAr->Serialize((ANSICHAR*)AnsiLineToSave.Get(), AnsiLineToSave.Length());
		}

		for (int32 Index = 0; Index < GeomFaces.Num(); Index += 3)
		{
			FString LineToSave = FString::Printf(TEXT("f %d %d %d\n"), GeomFaces[Index + 0] + 1, GeomFaces[Index + 1] + 1, GeomFaces[Index + 2] + 1);
			auto AnsiLineToSave = StringCast<ANSICHAR>(*LineToSave);
			FileAr->Serialize((ANSICHAR*)AnsiLineToSave.Get(), AnsiLineToSave.Length());
		}

		auto AnsiAdditionalData = StringCast<ANSICHAR>(*AdditionalData);
		FileAr->Serialize((ANSICHAR*)AnsiAdditionalData.Get(), AnsiAdditionalData.Length());
		FileAr->Close();
	}
}

void FC7RecastNavMeshGenerator::C7ExportNavigationData(const FString& FileName) const
{
	const UNavigationSystemV1* NavSys = FNavigationSystem::GetCurrent<UNavigationSystemV1>(GetWorld());
	const FNavigationOctree* NavOctree = NavSys ? NavSys->GetNavOctree() : NULL;
	if (NavOctree == NULL)
	{
		UE_LOG(LogNavigation, Error, TEXT("Failed to export navigation data due to %s being NULL"), NavSys == NULL ? TEXT("NavigationSystem") : TEXT("NavOctree"));
		return;
	}

	const double StartExportTime = FPlatformTime::Seconds();

	FString CurrentTimeStr = FDateTime::Now().ToString();
	for (int32 Index = 0; Index < NavSys->NavDataSet.Num(); ++Index)
	{
		// feed data from octtree and mark for rebuild				
		TNavStatArray<FVector::FReal> CoordBuffer;
		TNavStatArray<int32> IndexBuffer;
		const ARecastNavMesh* NavData = Cast<const ARecastNavMesh>(NavSys->NavDataSet[Index]);
		if (NavData)
		{
			const bool bUseVirtualGeometryFilteringAndDirtying = NavData->bUseVirtualGeometryFilteringAndDirtying;

			struct FAreaExportData
			{
				FConvexNavAreaData Convex;
				uint8 AreaId;
			};
			TArray<FAreaExportData> AreaExport;

			NavOctree->FindElementsWithBoundsTest(TotalNavBounds,
				[this, NavData, &IndexBuffer, &CoordBuffer, &AreaExport, bUseVirtualGeometryFilteringAndDirtying](const FNavigationOctreeElement& Element)
				{
					const bool bExportGeometry = Element.Data->HasGeometry() && (
						bUseVirtualGeometryFilteringAndDirtying ?
						ShouldGenerateGeometryForOctreeElement(Element, NavData->GetConfig()) :
						Element.ShouldUseGeometry(NavData->GetConfig())
						);

					TArray<FTransform> InstanceTransforms;
					Element.Data->NavDataPerInstanceTransformDelegate.ExecuteIfBound(Element.Bounds.GetBox(), InstanceTransforms);

					if (bExportGeometry && Element.Data->CollisionData.Num())
					{
						const int32 NumInstances = FMath::Max(InstanceTransforms.Num(), 1);
						FC7RecastGeometryCache CachedGeometry(Element.Data->CollisionData.GetData());
						IndexBuffer.Reserve(IndexBuffer.Num() + (CachedGeometry.Header.NumFaces * 3) * NumInstances);
						CoordBuffer.Reserve(CoordBuffer.Num() + (CachedGeometry.Header.NumVerts * 3) * NumInstances);

						if (InstanceTransforms.Num() == 0)
						{
							for (int32 i = 0; i < CachedGeometry.Header.NumFaces * 3; i++)
							{
								IndexBuffer.Add(CachedGeometry.Indices[i] + CoordBuffer.Num() / 3);
							}
							for (int32 i = 0; i < CachedGeometry.Header.NumVerts * 3; i++)
							{
								CoordBuffer.Add(CachedGeometry.Verts[i]);
							}
						}
						for (const FTransform& InstanceTransform : InstanceTransforms)
						{
							for (int32 i = 0; i < CachedGeometry.Header.NumFaces * 3; i++)
							{
								IndexBuffer.Add(CachedGeometry.Indices[i] + CoordBuffer.Num() / 3);
							}

							FMatrix LocalToRecastWorld = InstanceTransform.ToMatrixWithScale() * Unreal2RecastMatrix();

							for (int32 i = 0; i < CachedGeometry.Header.NumVerts * 3; i += 3)
							{
								// collision cache stores coordinates in recast space, convert them to unreal and transform to recast world space
								FVector WorldRecastCoord = LocalToRecastWorld.TransformPosition(Recast2UnrealPoint(&CachedGeometry.Verts[i]));

								CoordBuffer.Add(WorldRecastCoord.X);
								CoordBuffer.Add(WorldRecastCoord.Y);
								CoordBuffer.Add(WorldRecastCoord.Z);
							}
						}
					}
					else
					{
						for (const FAreaNavModifier& AreaMod : Element.Data->Modifiers.GetAreas())
						{
							ENavigationShapeType::Type ShapeType = AreaMod.GetShapeType();

							if (ShapeType == ENavigationShapeType::Convex || ShapeType == ENavigationShapeType::InstancedConvex)
							{
								FAreaExportData ExportInfo;
								ExportInfo.AreaId = NavData->GetAreaID(AreaMod.GetAreaClass());

								auto AddAreaExportDataFunc = [&](const FConvexNavAreaData& InConvexNavAreaData)
								{
									TArray<FVector> ConvexVerts;

									const TArray<FVector> Points = UE::LWC::ConvertArrayType<FVector>(ExportInfo.Convex.Points);
									GrowConvexHull(NavData->AgentRadius, Points, ConvexVerts);
									if (ConvexVerts.Num())
									{
										ExportInfo.Convex.MinZ -= NavData->GetCellHeight(ENavigationDataResolution::Default);
										ExportInfo.Convex.MaxZ += NavData->GetCellHeight(ENavigationDataResolution::Default);

										ExportInfo.Convex.Points = UE::LWC::ConvertArrayType<FVector>(ConvexVerts);

										AreaExport.Add(ExportInfo);
									}
								};

								if (ShapeType == ENavigationShapeType::Convex)
								{
									AreaMod.GetConvex(ExportInfo.Convex);
									AddAreaExportDataFunc(ExportInfo.Convex);
								}
								else // ShapeType == ENavigationShapeType::InstancedConvex
								{
									for (const FTransform& InstanceTransform : InstanceTransforms)
									{
										AreaMod.GetPerInstanceConvex(InstanceTransform, ExportInfo.Convex);
										AddAreaExportDataFunc(ExportInfo.Convex);
									}
								}
							}
						}
					}
				});

			UWorld* NavigationWorld = GetWorld();
			for (int32 LevelIndex = 0; LevelIndex < NavigationWorld->GetNumLevels(); ++LevelIndex)
			{
				const ULevel* const Level = NavigationWorld->GetLevel(LevelIndex);
				if (Level == NULL)
				{
					continue;
				}

				const TArray<FVector>* LevelGeom = Level->GetStaticNavigableGeometry();
				if (LevelGeom != NULL && LevelGeom->Num() > 0)
				{
					TNavStatArray<FVector> Verts;
					TNavStatArray<int32> Faces;
					// For every ULevel in World take its pre-generated static geometry vertex soup
					TransformVertexSoupToRecast(*LevelGeom, Verts, Faces);

					IndexBuffer.Reserve(IndexBuffer.Num() + Faces.Num());
					CoordBuffer.Reserve(CoordBuffer.Num() + Verts.Num() * 3);
					for (int32 i = 0; i < Faces.Num(); i++)
					{
						IndexBuffer.Add(Faces[i] + CoordBuffer.Num() / 3);
					}
					for (int32 i = 0; i < Verts.Num(); i++)
					{
						CoordBuffer.Add(Verts[i].X);
						CoordBuffer.Add(Verts[i].Y);
						CoordBuffer.Add(Verts[i].Z);
					}
				}
			}


			FString AreaExportStr;
			for (int32 i = 0; i < AreaExport.Num(); i++)
			{
				const FAreaExportData& ExportInfo = AreaExport[i];
				AreaExportStr += FString::Printf(TEXT("\nAE %d %d %f %f\n"),
					ExportInfo.AreaId, ExportInfo.Convex.Points.Num(), ExportInfo.Convex.MinZ, ExportInfo.Convex.MaxZ);

				for (int32 iv = 0; iv < ExportInfo.Convex.Points.Num(); iv++)
				{
					FVector Pt = Unreal2RecastPoint(ExportInfo.Convex.Points[iv]);
					AreaExportStr += FString::Printf(TEXT("Av %f %f %f\n"), Pt.X, Pt.Y, Pt.Z);
				}
			}

			FString AdditionalData;

			if (AreaExport.Num())
			{
				AdditionalData += "# Area export\n";
				AdditionalData += AreaExportStr;
				AdditionalData += "\n";
		}

			AdditionalData += "# RecastDemo specific data\n";
#if 0
			// use this bounds to have accurate navigation data bounds
			const FVector Center = Unreal2RecastPoint(NavData->GetBounds().GetCenter());
			FVector Extent = FVector(NavData->GetBounds().GetExtent());
			Extent = FVector(Extent.X, Extent.Z, Extent.Y);
#else
			// this bounds match navigation bounds from level
			FBox RCNavBounds = Unreal2RecastBox(TotalNavBounds);
			const FVector Center = RCNavBounds.GetCenter();
			const FVector Extent = RCNavBounds.GetExtent();
#endif
			const FBox Box = FBox::BuildAABB(Center, Extent);
			AdditionalData += FString::Printf(
				TEXT("rd_bbox %7.7f %7.7f %7.7f %7.7f %7.7f %7.7f\n"),
				Box.Min.X, Box.Min.Y, Box.Min.Z,
				Box.Max.X, Box.Max.Y, Box.Max.Z
			);

			const FRecastNavMeshGenerator* CurrentGen = static_cast<const FRecastNavMeshGenerator*>(NavData->GetGenerator());
			check(CurrentGen);
			AdditionalData += FString::Printf(TEXT("# AgentHeight\n"));
			AdditionalData += FString::Printf(TEXT("rd_agh %5.5f\n"), CurrentGen->GetConfig().AgentHeight);
			AdditionalData += FString::Printf(TEXT("# AgentRadius\n"));
			AdditionalData += FString::Printf(TEXT("rd_agr %5.5f\n"), CurrentGen->GetConfig().AgentRadius);

			AdditionalData += FString::Printf(TEXT("# Cell Size\n"));
			AdditionalData += FString::Printf(TEXT("rd_cs %5.5f\n"), CurrentGen->GetConfig().cs);
			AdditionalData += FString::Printf(TEXT("# Cell Height\n"));
			AdditionalData += FString::Printf(TEXT("rd_ch %5.5f\n"), CurrentGen->GetConfig().ch);

			AdditionalData += FString::Printf(TEXT("# Agent max climb\n"));
			AdditionalData += FString::Printf(TEXT("rd_amc %d\n"), (int)CurrentGen->GetConfig().AgentMaxClimb);
			AdditionalData += FString::Printf(TEXT("# Agent max slope\n"));
			AdditionalData += FString::Printf(TEXT("rd_ams %5.5f\n"), CurrentGen->GetConfig().walkableSlopeAngle);

			AdditionalData += FString::Printf(TEXT("# Region min size\n"));
			AdditionalData += FString::Printf(TEXT("rd_rmis %d\n"), (uint32)FMath::Sqrt(static_cast<float>(CurrentGen->GetConfig().minRegionArea)));
			AdditionalData += FString::Printf(TEXT("# Region merge size\n"));
			AdditionalData += FString::Printf(TEXT("rd_rmas %d\n"), (uint32)FMath::Sqrt(static_cast<float>(CurrentGen->GetConfig().mergeRegionArea)));

			AdditionalData += FString::Printf(TEXT("# Max edge len\n"));
			AdditionalData += FString::Printf(TEXT("rd_mel %d\n"), CurrentGen->GetConfig().maxEdgeLen);

			AdditionalData += FString::Printf(TEXT("# Perform Voxel Filtering\n"));
			AdditionalData += FString::Printf(TEXT("rd_pvf %d\n"), CurrentGen->GetConfig().bPerformVoxelFiltering);
			AdditionalData += FString::Printf(TEXT("# Generate Detailed Mesh\n"));
			AdditionalData += FString::Printf(TEXT("rd_gdm %d\n"), CurrentGen->GetConfig().bGenerateDetailedMesh);
			AdditionalData += FString::Printf(TEXT("# MaxPolysPerTile\n"));
			AdditionalData += FString::Printf(TEXT("rd_mppt %d\n"), CurrentGen->GetConfig().MaxPolysPerTile);
			AdditionalData += FString::Printf(TEXT("# maxVertsPerPoly\n"));
			AdditionalData += FString::Printf(TEXT("rd_mvpp %d\n"), CurrentGen->GetConfig().maxVertsPerPoly);
			AdditionalData += FString::Printf(TEXT("# Tile size\n"));
			AdditionalData += FString::Printf(TEXT("rd_ts %d\n"), CurrentGen->GetConfig().tileSize);

			AdditionalData += FString::Printf(TEXT("\n"));

			const FString FilePathName = FileName;
			ExportGeomToOBJFile(FilePathName, CoordBuffer, IndexBuffer, AdditionalData);
		}
	}
	UE_LOG(LogNavigation, Log, TEXT("ExportNavigation time: %.3f sec ."), FPlatformTime::Seconds() - StartExportTime);
}

rcHeightfield* FC7RecastNavMeshGenerator::C7ExportHeightfield() const
{
	UWorld* NavigationWorld = GEditor->GetEditorWorldContext().World();
	const UNavigationSystemV1* NavSys = FNavigationSystem::GetCurrent<UNavigationSystemV1>(NavigationWorld);
	const FNavigationOctree* NavOctree = NavSys ? NavSys->GetNavOctree() : NULL;
	if (NavOctree == NULL)
	{
		UE_LOG(LogNavigation, Error, TEXT("Failed to export navigation data due to %s being NULL"), NavSys == NULL ? TEXT("NavigationSystem") : TEXT("NavOctree"));
		return nullptr;
	}

	FString CurrentTimeStr = FDateTime::Now().ToString();
	for (int32 Index = 0; Index < NavSys->NavDataSet.Num(); ++Index)
	{
		// feed data from octtree and mark for rebuild				
		TNavStatArray<FVector::FReal> CoordBuffer;
		TNavStatArray<int32> IndexBuffer;
		const ARecastNavMesh* NavData = Cast<const ARecastNavMesh>(NavSys->NavDataSet[Index]);
		if (NavData)
		{
			FNavDataConfig NavDataConfig = NavData->GetConfig();

			const bool bUseVirtualGeometryFilteringAndDirtying = NavData->bUseVirtualGeometryFilteringAndDirtying;

			struct FAreaExportData
			{
				FConvexNavAreaData Convex;
				uint8 AreaId;
			};
			TArray<FAreaExportData> AreaExport;

			NavOctree->FindElementsWithBoundsTest(TotalNavBounds,
				[this, NavData, &IndexBuffer, &CoordBuffer, &AreaExport, bUseVirtualGeometryFilteringAndDirtying](const FNavigationOctreeElement& Element)
				{
					const bool bExportGeometry = Element.Data->HasGeometry() && (
						bUseVirtualGeometryFilteringAndDirtying ?
						ShouldGenerateGeometryForOctreeElement(Element, NavData->GetConfig()) :
						Element.ShouldUseGeometry(NavData->GetConfig())
						);

					TArray<FTransform> InstanceTransforms;
					Element.Data->NavDataPerInstanceTransformDelegate.ExecuteIfBound(Element.Bounds.GetBox(), InstanceTransforms);

					if (bExportGeometry && Element.Data->CollisionData.Num())
					{
						const int32 NumInstances = FMath::Max(InstanceTransforms.Num(), 1);
						FC7RecastGeometryCache CachedGeometry(Element.Data->CollisionData.GetData());
						IndexBuffer.Reserve(IndexBuffer.Num() + (CachedGeometry.Header.NumFaces * 3) * NumInstances);
						CoordBuffer.Reserve(CoordBuffer.Num() + (CachedGeometry.Header.NumVerts * 3) * NumInstances);

						if (InstanceTransforms.Num() == 0)
						{
							for (int32 i = 0; i < CachedGeometry.Header.NumFaces * 3; i++)
							{
								IndexBuffer.Add(CachedGeometry.Indices[i] + CoordBuffer.Num() / 3);
							}
							for (int32 i = 0; i < CachedGeometry.Header.NumVerts * 3; i++)
							{
								CoordBuffer.Add(CachedGeometry.Verts[i]);
							}
						}
						for (const FTransform& InstanceTransform : InstanceTransforms)
						{
							for (int32 i = 0; i < CachedGeometry.Header.NumFaces * 3; i++)
							{
								IndexBuffer.Add(CachedGeometry.Indices[i] + CoordBuffer.Num() / 3);
							}

							FMatrix LocalToRecastWorld = InstanceTransform.ToMatrixWithScale() * Unreal2RecastMatrix();

							for (int32 i = 0; i < CachedGeometry.Header.NumVerts * 3; i += 3)
							{
								// collision cache stores coordinates in recast space, convert them to unreal and transform to recast world space
								FVector WorldRecastCoord = LocalToRecastWorld.TransformPosition(Recast2UnrealPoint(&CachedGeometry.Verts[i]));

								CoordBuffer.Add(WorldRecastCoord.X);
								CoordBuffer.Add(WorldRecastCoord.Y);
								CoordBuffer.Add(WorldRecastCoord.Z);
							}
						}
					}
					else
					{
						for (const FAreaNavModifier& AreaMod : Element.Data->Modifiers.GetAreas())
						{
							ENavigationShapeType::Type ShapeType = AreaMod.GetShapeType();

							if (ShapeType == ENavigationShapeType::Convex || ShapeType == ENavigationShapeType::InstancedConvex)
							{
								FAreaExportData ExportInfo;
								ExportInfo.AreaId = NavData->GetAreaID(AreaMod.GetAreaClass());

								auto AddAreaExportDataFunc = [&](const FConvexNavAreaData& InConvexNavAreaData)
								{
									TArray<FVector> ConvexVerts;

									const TArray<FVector> Points = UE::LWC::ConvertArrayType<FVector>(ExportInfo.Convex.Points);
									GrowConvexHull(NavData->AgentRadius, Points, ConvexVerts);
									if (ConvexVerts.Num())
									{
										ExportInfo.Convex.MinZ -= NavData->GetCellHeight(ENavigationDataResolution::Default);
										ExportInfo.Convex.MaxZ += NavData->GetCellHeight(ENavigationDataResolution::Default);

										ExportInfo.Convex.Points = UE::LWC::ConvertArrayType<FVector>(ConvexVerts);

										AreaExport.Add(ExportInfo);
									}
								};

								if (ShapeType == ENavigationShapeType::Convex)
								{
									AreaMod.GetConvex(ExportInfo.Convex);
									AddAreaExportDataFunc(ExportInfo.Convex);
								}
								else // ShapeType == ENavigationShapeType::InstancedConvex
								{
									for (const FTransform& InstanceTransform : InstanceTransforms)
									{
										AreaMod.GetPerInstanceConvex(InstanceTransform, ExportInfo.Convex);
										AddAreaExportDataFunc(ExportInfo.Convex);
									}
								}
							}
						}
					}
				});

			for (int32 LevelIndex = 0; LevelIndex < NavigationWorld->GetNumLevels(); ++LevelIndex)
			{
				const ULevel* const Level = NavigationWorld->GetLevel(LevelIndex);
				if (Level == NULL)
				{
					continue;
				}

				const TArray<FVector>* LevelGeom = Level->GetStaticNavigableGeometry();
				if (LevelGeom != NULL && LevelGeom->Num() > 0)
				{
					TNavStatArray<FVector> Verts;
					TNavStatArray<int32> Faces;
					// For every ULevel in World take its pre-generated static geometry vertex soup
					TransformVertexSoupToRecast(*LevelGeom, Verts, Faces);

					IndexBuffer.Reserve(IndexBuffer.Num() + Faces.Num());
					CoordBuffer.Reserve(CoordBuffer.Num() + Verts.Num() * 3);
					for (int32 i = 0; i < Faces.Num(); i++)
					{
						IndexBuffer.Add(Faces[i] + CoordBuffer.Num() / 3);
					}
					for (int32 i = 0; i < Verts.Num(); i++)
					{
						CoordBuffer.Add(Verts[i].X);
						CoordBuffer.Add(Verts[i].Y);
						CoordBuffer.Add(Verts[i].Z);
					}
				}
			}

			/* 生成到高度场步骤 */
			FBox Bounds = NavData->GetBounds();
			FVector BoundMin(Bounds.Min.X, Bounds.Min.Y, Bounds.Min.Z);
			FVector BoundMax(Bounds.Max.X, Bounds.Max.Y, Bounds.Max.Z);

			FVector Tmp;
			if (CoordBuffer.Num() < 3) {
				return nullptr;
			}
			BoundMin.Set(CoordBuffer[0], CoordBuffer[1], CoordBuffer[2]);
			BoundMax.Set(CoordBuffer[0], CoordBuffer[1], CoordBuffer[2]);
			for (int i = 0;i < CoordBuffer.Num();i+=3) {
				Tmp.Set(CoordBuffer[i], CoordBuffer[i + 1], CoordBuffer[i + 2]);
				BoundMin.X = FMath::Min(BoundMin.X, Tmp.X);
				BoundMin.Y = FMath::Min(BoundMin.Y, Tmp.Y);
				BoundMin.Z = FMath::Min(BoundMin.Z, Tmp.Z);
				BoundMax.X = FMath::Max(BoundMax.X, Tmp.X);
				BoundMax.Y = FMath::Max(BoundMax.Y, Tmp.Y);
				BoundMax.Z = FMath::Max(BoundMax.Z, Tmp.Z);
			}

			const int32 NumVerts = CoordBuffer.Num() / 3;
			const int32 NumFaces = IndexBuffer.Num() / 3;

			// Config
			int GridWidth = int((BoundMax.X - BoundMin.X) / VOX::GetCellSize() + 0.5f);
			int GridHeight = int((BoundMax.Z - BoundMin.Z) / VOX::GetCellSize() + 0.5f);

			int TileWeight = int((BoundMax.X - BoundMin.X) / VOX::GetTileSize() + 0.5f);
			int TileHeight = int((BoundMax.Y - BoundMin.Y) / VOX::GetTileSize() + 0.5f);

			// int WalkableClimb = FMath::CeilToInt(NavData->AgentMaxStepHeight / CellHeight);
			// int WalkableHeight = FMath::CeilToInt(NavData->AgentHeight / CellHeight);

			int WalkableClimb = 5;
			int WalkableHeight = 18;

			// SoloMesh形式
			rcContext DummyCtx(false);
			TNavStatArray<uint8> RasterizeGeomRecastTriAreas;
			RasterizeGeomRecastTriAreas.AddZeroed(NumFaces);

			// 分配高度场
			rcHeightfield* RasterizeHF = rcAllocHeightfield();
			rcCreateHeightfield(&DummyCtx, *RasterizeHF, GridWidth, GridHeight, &BoundMin.X, &BoundMin.X, VOX::GetCellSize(), VOX::GetCellHeight());

			// 标记可行走的三角形
			rcMarkWalkableTriangles(&DummyCtx, 90,
				CoordBuffer.GetData(), NumVerts, IndexBuffer.GetData(), NumFaces,
				RasterizeGeomRecastTriAreas.GetData());

			// 光栅化
			rcRasterizeTriangles(&DummyCtx,
				CoordBuffer.GetData(), NumVerts,
				IndexBuffer.GetData(), RasterizeGeomRecastTriAreas.GetData(), NumFaces,
				*RasterizeHF, WalkableClimb, 0, nullptr);

			// 标记很薄的不可行走Span,为后续合并做准备
			rcFilterLowHangingWalkableObstacles(&DummyCtx, WalkableClimb, *RasterizeHF);

			FRecastBuildConfig TileConfig;
			
			// 标记突出/凹陷/边界的Span
			rcFilterLedgeSpans(&DummyCtx, WalkableHeight, FMath::FloorToInt(WalkableClimb * 2.0),
				(rcNeighborSlopeFilterMode)TileConfig.LedgeSlopeFilterMode, TileConfig.maxStepFromWalkableSlope,
				TileConfig.ch, *RasterizeHF);

			// 标记很薄的可行走Span，为后续合并准备
			rcFilterWalkableLowHeightSpans(&DummyCtx, WalkableHeight, *RasterizeHF);

			return RasterizeHF;
		}
	}

	return nullptr;
}

void FC7RecastNavMeshGenerator::C7ExportHeightfieldToVoxelActorWithTiles()
{
	UWorld* NavigationWorld = GEditor->GetEditorWorldContext().World();
	const UNavigationSystemV1* NavSys = FNavigationSystem::GetCurrent<UNavigationSystemV1>(NavigationWorld);
	const FNavigationOctree* NavOctree = NavSys ? NavSys->GetNavOctree() : NULL;
	if (NavOctree == NULL) {
		UE_LOG(LogNavigation, Error, TEXT("Failed to export navigation data due to %s being NULL."), NavSys == NULL ? TEXT("NavigationSystem") : TEXT("NavOctree"));
		return;
	}

	AC7VoxelActor* VA = nullptr;
	for (TActorIterator<AActor> It(NavigationWorld, AC7VoxelActor::StaticClass()); It; ++It) {
		if (AC7VoxelActor* Actor = Cast<AC7VoxelActor>(*It)) {
			if (IsValid(Actor)) {
				VA = Actor;
				break;
			}
		}
	}
	if (VA == nullptr) {
		return;
	}

	FString CurrentTimeStr = FDateTime::Now().ToString();
	for (int32 Index = 0; Index < NavSys->NavDataSet.Num(); ++Index)
	{
		// feed data from octtree and mark for rebuild				
		TNavStatArray<FVector::FReal> CoordBuffer;
		TNavStatArray<int32> IndexBuffer;
		const ARecastNavMesh* NavData = Cast<const ARecastNavMesh>(NavSys->NavDataSet[Index]);
		if (NavData)
		{
			FNavDataConfig NavDataConfig = NavData->GetConfig();

			const bool bUseVirtualGeometryFilteringAndDirtying = NavData->bUseVirtualGeometryFilteringAndDirtying;

			struct FAreaExportData
			{
				FConvexNavAreaData Convex;
				uint8 AreaId;
			};
			TArray<FAreaExportData> AreaExport;

			NavOctree->FindElementsWithBoundsTest(TotalNavBounds,
				[this, NavData, &IndexBuffer, &CoordBuffer, &AreaExport, bUseVirtualGeometryFilteringAndDirtying](const FNavigationOctreeElement& Element)
				{
					const bool bExportGeometry = Element.Data->HasGeometry() && (
						bUseVirtualGeometryFilteringAndDirtying ?
						ShouldGenerateGeometryForOctreeElement(Element, NavData->GetConfig()) :
						Element.ShouldUseGeometry(NavData->GetConfig())
						);

					TArray<FTransform> InstanceTransforms;
					Element.Data->NavDataPerInstanceTransformDelegate.ExecuteIfBound(Element.Bounds.GetBox(), InstanceTransforms);

					if (bExportGeometry && Element.Data->CollisionData.Num())
					{
						const int32 NumInstances = FMath::Max(InstanceTransforms.Num(), 1);
						FC7RecastGeometryCache CachedGeometry(Element.Data->CollisionData.GetData());
						IndexBuffer.Reserve(IndexBuffer.Num() + (CachedGeometry.Header.NumFaces * 3) * NumInstances);
						CoordBuffer.Reserve(CoordBuffer.Num() + (CachedGeometry.Header.NumVerts * 3) * NumInstances);

						if (InstanceTransforms.Num() == 0)
						{
							for (int32 i = 0; i < CachedGeometry.Header.NumFaces * 3; i++)
							{
								IndexBuffer.Add(CachedGeometry.Indices[i] + CoordBuffer.Num() / 3);
							}
							for (int32 i = 0; i < CachedGeometry.Header.NumVerts * 3; i++)
							{
								CoordBuffer.Add(CachedGeometry.Verts[i]);
							}
						}
						for (const FTransform& InstanceTransform : InstanceTransforms)
						{
							for (int32 i = 0; i < CachedGeometry.Header.NumFaces * 3; i++)
							{
								IndexBuffer.Add(CachedGeometry.Indices[i] + CoordBuffer.Num() / 3);
							}

							FMatrix LocalToRecastWorld = InstanceTransform.ToMatrixWithScale() * Unreal2RecastMatrix();

							for (int32 i = 0; i < CachedGeometry.Header.NumVerts * 3; i += 3)
							{
								// collision cache stores coordinates in recast space, convert them to unreal and transform to recast world space
								FVector WorldRecastCoord = LocalToRecastWorld.TransformPosition(Recast2UnrealPoint(&CachedGeometry.Verts[i]));

								CoordBuffer.Add(WorldRecastCoord.X);
								CoordBuffer.Add(WorldRecastCoord.Y);
								CoordBuffer.Add(WorldRecastCoord.Z);
							}
						}
					}
					else
					{
						for (const FAreaNavModifier& AreaMod : Element.Data->Modifiers.GetAreas())
						{
							ENavigationShapeType::Type ShapeType = AreaMod.GetShapeType();

							if (ShapeType == ENavigationShapeType::Convex || ShapeType == ENavigationShapeType::InstancedConvex)
							{
								FAreaExportData ExportInfo;
								ExportInfo.AreaId = NavData->GetAreaID(AreaMod.GetAreaClass());

								auto AddAreaExportDataFunc = [&](const FConvexNavAreaData& InConvexNavAreaData)
								{
									TArray<FVector> ConvexVerts;

									const TArray<FVector> Points = UE::LWC::ConvertArrayType<FVector>(ExportInfo.Convex.Points);
									GrowConvexHull(NavData->AgentRadius, Points, ConvexVerts);
									if (ConvexVerts.Num())
									{
										ExportInfo.Convex.MinZ -= NavData->GetCellHeight(ENavigationDataResolution::Default);
										ExportInfo.Convex.MaxZ += NavData->GetCellHeight(ENavigationDataResolution::Default);

										ExportInfo.Convex.Points = UE::LWC::ConvertArrayType<FVector>(ConvexVerts);

										AreaExport.Add(ExportInfo);
									}
								};

								if (ShapeType == ENavigationShapeType::Convex)
								{
									AreaMod.GetConvex(ExportInfo.Convex);
									AddAreaExportDataFunc(ExportInfo.Convex);
								}
								else // ShapeType == ENavigationShapeType::InstancedConvex
								{
									for (const FTransform& InstanceTransform : InstanceTransforms)
									{
										AreaMod.GetPerInstanceConvex(InstanceTransform, ExportInfo.Convex);
										AddAreaExportDataFunc(ExportInfo.Convex);
									}
								}
							}
						}
					}
				});

			for (int32 LevelIndex = 0; LevelIndex < NavigationWorld->GetNumLevels(); ++LevelIndex)
			{
				const ULevel* const Level = NavigationWorld->GetLevel(LevelIndex);
				if (Level == NULL)
				{
					continue;
				}

				const TArray<FVector>* LevelGeom = Level->GetStaticNavigableGeometry();
				if (LevelGeom != NULL && LevelGeom->Num() > 0)
				{
					TNavStatArray<FVector> Verts;
					TNavStatArray<int32> Faces;
					// For every ULevel in World take its pre-generated static geometry vertex soup
					TransformVertexSoupToRecast(*LevelGeom, Verts, Faces);

					IndexBuffer.Reserve(IndexBuffer.Num() + Faces.Num());
					CoordBuffer.Reserve(CoordBuffer.Num() + Verts.Num() * 3);
					for (int32 i = 0; i < Faces.Num(); i++)
					{
						IndexBuffer.Add(Faces[i] + CoordBuffer.Num() / 3);
					}
					for (int32 i = 0; i < Verts.Num(); i++)
					{
						CoordBuffer.Add(Verts[i].X);
						CoordBuffer.Add(Verts[i].Y);
						CoordBuffer.Add(Verts[i].Z);
					}
				}
			}

			/* 生成到高度场步骤 */
			FBox Bounds = NavData->GetBounds();
			FVector BoundMin(Bounds.Min.X, Bounds.Min.Y, Bounds.Min.Z);
			FVector BoundMax(Bounds.Max.X, Bounds.Max.Y, Bounds.Max.Z);

			FVector Tmp;
			if (CoordBuffer.Num() < 3) {
				return;
			}
			BoundMin.Set(CoordBuffer[0], CoordBuffer[1], CoordBuffer[2]);
			BoundMax.Set(CoordBuffer[0], CoordBuffer[1], CoordBuffer[2]);
			for (int i = 0;i < CoordBuffer.Num();i+=3) {
				Tmp.Set(CoordBuffer[i], CoordBuffer[i + 1], CoordBuffer[i + 2]);
				BoundMin.X = FMath::Min(BoundMin.X, Tmp.X);
				BoundMin.Y = FMath::Min(BoundMin.Y, Tmp.Y);
				BoundMin.Z = FMath::Min(BoundMin.Z, Tmp.Z);
				BoundMax.X = FMath::Max(BoundMax.X, Tmp.X);
				BoundMax.Y = FMath::Max(BoundMax.Y, Tmp.Y);
				BoundMax.Z = FMath::Max(BoundMax.Z, Tmp.Z);
			}

			const int32 NumVerts = CoordBuffer.Num() / 3;
			const int32 NumFaces = IndexBuffer.Num() / 3;

			// 初始化构建上下文
			VoxContext BuildContex;
			BuildContex.BoundMin = BoundMin;
			BuildContex.BoundMax = BoundMax;

			if (!VA->InitBuildTileVox(&BuildContex)) {
				UE_LOG(LogNavigation, Error, TEXT("InitBuildTileVox error."));
				return;
			}

			// TileMesh形式
			rcContext DummyCtx(false);

			TNavStatArray<uint8> RasterizeGeomRecastTriAreas;
			RasterizeGeomRecastTriAreas.AddZeroed(NumFaces);

			// 标记可行走的三角形
			rcMarkWalkableTriangles(&DummyCtx, 90,
				CoordBuffer.GetData(), NumVerts, IndexBuffer.GetData(), NumFaces,
				RasterizeGeomRecastTriAreas.GetData());

			// TODO:Tile外层增加一圈Cell,防止边界意外出现缺失,需要在转换体素场景时修正这部分数据,暂未处理.
			bool AddTileEdge = false;

			// 控制Tile总数量,防死循环
			for (int tNum = 0; tNum < BuildContex.TileCountW * BuildContex.TileCountH; tNum++) {
				FVector TileBoundMin = BoundMin;
				FVector TileBoundMax = BoundMin;
				TileBoundMax.Z = BoundMax.Z;
				
				if (AddTileEdge) {
					TileBoundMin.X += BuildContex.TileSize * BuildContex.BuildingTileIndexX - BuildContex.CellSize;
					TileBoundMin.Y += BuildContex.TileSize * BuildContex.BuildingTileIndexY - BuildContex.CellSize;
					TileBoundMax.X += BuildContex.TileSize * (BuildContex.BuildingTileIndexX + 1) + BuildContex.CellSize;
					TileBoundMax.Y += BuildContex.TileSize * (BuildContex.BuildingTileIndexY + 1) + BuildContex.CellSize;
				}
				else {
					TileBoundMin.X += BuildContex.TileSize * BuildContex.BuildingTileIndexX;
					TileBoundMin.Y += BuildContex.TileSize * BuildContex.BuildingTileIndexY;
					TileBoundMax.X += BuildContex.TileSize * (BuildContex.BuildingTileIndexX + 1);
					TileBoundMax.Y += BuildContex.TileSize * (BuildContex.BuildingTileIndexY + 1);
				}

				// 分配高度场
				rcHeightfield* RasterizeHF = rcAllocHeightfield();
				if (!RasterizeHF) {
					UE_LOG(LogNavigation, Error, TEXT("rcAllocHeightfield error: can't alloc memory."));
					return;
				}
				if (AddTileEdge) {
					rcCreateHeightfield(&DummyCtx, *RasterizeHF,
						BuildContex.CellCount + 2, BuildContex.CellCount + 2,
						&TileBoundMin.X, &TileBoundMax.X, BuildContex.CellSize, BuildContex.CellHeight);
				}
				else {
					rcCreateHeightfield(&DummyCtx, *RasterizeHF,
						BuildContex.CellCount, BuildContex.CellCount,
						&TileBoundMin.X, &TileBoundMax.X, BuildContex.CellSize, BuildContex.CellHeight);
				}

				// 光栅化
				rcRasterizeTriangles(&DummyCtx,
					CoordBuffer.GetData(), NumVerts,
					IndexBuffer.GetData(), RasterizeGeomRecastTriAreas.GetData(), NumFaces,
					*RasterizeHF, BuildContex.WalkableClimb, 0, nullptr);

				// 标记很薄的不可行走Span,为后续合并做准备
				rcFilterLowHangingWalkableObstacles(&DummyCtx, BuildContex.WalkableClimb, *RasterizeHF);

				FRecastBuildConfig TileConfig;			
				// 标记突出/凹陷/边界的Span(Bound边界不认为是行走边界)
				rcFilterLedgeSpans(&DummyCtx, BuildContex.WalkableHeight, FMath::FloorToInt(BuildContex.WalkableClimb * 2.0),
					(rcNeighborSlopeFilterMode)TileConfig.LedgeSlopeFilterMode, TileConfig.maxStepFromWalkableSlope,
					TileConfig.ch, *RasterizeHF);

				// 标记很薄的可行走Span，为后续合并准备
				rcFilterWalkableLowHeightSpans(&DummyCtx, BuildContex.WalkableHeight, *RasterizeHF);

				BuildContex.SolidHF = RasterizeHF;

				// do build
				bool BuildFinish = false;
				if (!VA->ProcessBuildTileVox(&BuildContex)) {
					// UE_LOG(LogNavigation, Error, TEXT("ProcessBuildTileVox error at TileX:%d, TileY:%d."), BuildContex.BuildingTileIndexX, BuildContex.BuildingTileIndexY);
					BuildFinish = true;
				}

				rcFreeHeightField(RasterizeHF);
				BuildContex.SolidHF = nullptr;
				if (BuildFinish) {
					break;
				}
			}

			if (!VA->FinishBuildTileVox(&BuildContex)) {
				UE_LOG(LogNavigation, Error, TEXT("FinishBuildTileVox error."));
				return;
			}

			return;
		}
	}

	return;
}
