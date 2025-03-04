// Copyright KuaiShou Games, Inc. All Rights Reserved.
// Author: liubo11@kuaishou.com

#pragma once

#include "CoreTypes.h"
#include "ContentBrowserModule.h"
#include "EditorAssetLibrary.h"
#include "Engine.h"
#include "IContentBrowserSingleton.h"
#include "ILandscapeEdToolsModule.h"
#include "AssetRegistry/AssetRegistryModule.h"
#include "Misc/KgHook.h"


class FKgLandscapeEdToolsModule : public IKgLandscapeEdToolsModule
{
	KG_DECLARE_RTTI(FKgLandscapeEdToolsModule, IKgLandscapeEdToolsModule);
	
public:
	virtual UObject* CreateAsset(UClass* ObjClass, const FString& PackagePath) override;
	virtual void SaveAsset(UObject* NewTexture) override;
	virtual UObject* SaveAssetAs(UObject* OldAsset, const FString& PackageName) override;
};




