#ifndef C7_RECAST_UTILS__
#define C7_RECAST_UTILS__

#include <inttypes.h>
#include "Detour/DetourNavMesh.h"
#include "Detour/DetourNavMeshQuery.h"
#include "Detour/DetourNavMeshQuery.h"
#include "DetourTileCache/DetourTileCache.h"
#include "NavigationSystem.h"
#include "NavMesh/RecastNavMesh.h"

namespace C7RecastUtils
{
	struct NavMeshSetHeader
	{
		int32_t Magic;
		int32_t Version;
		int32_t NumTiles;
		dtNavMeshParams Params;
	};

	struct NavMeshTileHeader
	{
		dtTileRef TileRef;
		int32_t DataSize;
	};

	struct TileCacheSetHeader
	{
		int magic;
		int version;
		int numTiles;
		dtNavMeshParams meshParams;
		dtTileCacheParams cacheParams;
	};

	struct TileCacheTileHeader
	{
		dtCompressedTileRef tileRef; // unused
		int dataSize;

	};
	static const int NAVMESHSET_MAGIC = 'M' << 24 | 'S' << 16 | 'E' << 8 | 'T'; //'MSET';
	static const int NAVMESHSET_VERSION = 1;

	static const int TILECACHESET_MAGIC = 'T' << 24 | 'S' << 16 | 'E' << 8 | 'T'; //'TSET';
	static const int TILECACHESET_VERSION = 1;
	
	void SerializedtNavMesh(const char* Path, const dtNavMesh* NavMesh);
	void SerializeRecastNavMesh(const char* Path, ARecastNavMesh* NavMesh);
};

#endif