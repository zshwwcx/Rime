#include "C7RecastUtils.h"
#include <cstdio>
#include <cstdlib>
#include <DetourTileCache/DetourTileCache.h>
#include <Recast/Recast.h>
#include <Navmesh/RecastNavMeshGenerator.h>

#pragma warning (disable:4996)

void C7RecastUtils::SerializedtNavMesh(const char* Path, const dtNavMesh* NavMesh)
{
	using namespace C7RecastUtils;
	if (!NavMesh) 
	{
		return;
	}

	std::FILE* FilePtr = std::fopen(Path, "wb");
	if (!FilePtr)
	{
		return;
	}

	NavMeshSetHeader Header;
	Header.Magic = 'M' << 24 | 'S' << 16 | 'E' << 8 | 'T';
	Header.Version = 1;
	Header.NumTiles = 0;

	for (int i = 0; i < NavMesh->getMaxTiles(); ++i)
	{
		const dtMeshTile* Tile = NavMesh->getTile(i);
		if (!Tile || !Tile->header || !Tile->dataSize) continue;
		Header.NumTiles++;
	}
	std::memcpy(&Header.Params, NavMesh->getParams(), sizeof(dtNavMeshParams));
	std::fwrite(&Header, sizeof(NavMeshSetHeader), 1, FilePtr);

	for (int i = 0; i < NavMesh->getMaxTiles(); ++i)
	{
		const dtMeshTile* tile = NavMesh->getTile(i);
		if (!tile || !tile->header || !tile->dataSize) continue;

		NavMeshTileHeader tileHeader;
		tileHeader.TileRef = NavMesh->getTileRef(tile);
		tileHeader.DataSize = tile->dataSize;
		std::fwrite(&tileHeader, sizeof(tileHeader), 1, FilePtr);

		std::fwrite(tile->data, tile->dataSize, 1, FilePtr);
	}

	std::fclose(FilePtr);
}

void C7RecastUtils::SerializeRecastNavMesh(const char* Path, ARecastNavMesh* mesh)
{
	if (!mesh) return;

	std::FILE* fp = std::fopen(Path, "wb");
	if (!fp)
		return;

	const dtNavMesh* RecastdtNavMesh = mesh->GetRecastMesh();
	FRecastNavMeshGenerator* Generator = static_cast<FRecastNavMeshGenerator*>(mesh->GetGenerator());
	if (Generator->HasDirtyTiles()) {
		Generator->EnsureBuildCompletion();
	}
	dtTileCacheParams tcparams;
	memset(&tcparams, 0, sizeof(tcparams));
	rcVcopy(tcparams.orig, RecastdtNavMesh->m_orig);
	tcparams.cs = mesh->NavMeshResolutionParams->CellSize;
	tcparams.ch = mesh->NavMeshResolutionParams->CellHeight;
	tcparams.width = (int)(RecastdtNavMesh->m_tileWidth / mesh->NavMeshResolutionParams->CellSize);
	tcparams.height = (int)(RecastdtNavMesh->m_tileHeight / mesh->NavMeshResolutionParams->CellSize);
	tcparams.walkableHeight = RecastdtNavMesh->m_params.walkableHeight;
	tcparams.walkableRadius = RecastdtNavMesh->m_params.walkableRadius;
	tcparams.walkableClimb = RecastdtNavMesh->m_params.walkableClimb;
	tcparams.maxSimplificationError = mesh->MaxSimplificationError;
	tcparams.maxTiles = RecastdtNavMesh->m_maxTiles;
	tcparams.maxObstacles = 128;
	tcparams.detailSampleDist = Generator->GetConfig().detailSampleDist;
	tcparams.detailSampleMaxError = Generator->GetConfig().detailSampleMaxError;
	tcparams.minRegionArea = Generator->GetConfig().minRegionArea;
	tcparams.mergeRegionArea = Generator->GetConfig().mergeRegionArea;
	tcparams.regionChunkSize = Generator->GetConfig().regionChunkSize;
	tcparams.regionPartitioning = Generator->GetConfig().regionPartitioning;

	// 构建TileCacheHeader
	TileCacheSetHeader header;
	header.magic = TILECACHESET_MAGIC;
	header.version = TILECACHESET_VERSION;
	header.numTiles = 0;
	for (int i = 0; i < RecastdtNavMesh->getMaxTiles(); ++i)
	{
		const dtMeshTile* Tile = RecastdtNavMesh->getTile(i);
		if (!Tile || !Tile->header || Tile->dataSize == 0) continue;
		header.numTiles++;
	}
	memcpy(&header.cacheParams, &tcparams, sizeof(dtTileCacheParams));
	memcpy(&header.meshParams, RecastdtNavMesh->getParams(), sizeof(dtNavMeshParams));
	fwrite(&header, sizeof(TileCacheSetHeader), 1, fp);

	// 存储tiles
	for (int i = 0; i < RecastdtNavMesh->getMaxTiles(); ++i)
	{
		const dtMeshTile* Tile = RecastdtNavMesh->getTile(i);
		if (!Tile || !Tile->header || Tile->dataSize == 0) continue;
		TArray<FNavMeshTileData> tileCacheLayers = mesh->GetTileCacheLayers(Tile->header->x, Tile->header->y);
		for (const FNavMeshTileData& tileData : tileCacheLayers) {
			// tileCacheLayers是根据tx和ty拿到的，所以会出现layer上的重复，这边就先这样判定下layer相同，来去重
			if (tileData.IsValid() && tileData.LayerIndex == Tile->header->layer) {
				TileCacheTileHeader tileHeader;
				tileHeader.tileRef = 0;
				tileHeader.dataSize = tileData.DataSize;
				fwrite(&tileHeader, sizeof(TileCacheTileHeader), 1, fp);
				fwrite(const_cast<unsigned char*>(tileData.GetData()), tileData.DataSize, 1, fp);
			}
		}
	}
	fclose(fp);
}
