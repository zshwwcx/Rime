#include "C7MapCompositeTexture.h"
#include "Engine/CanvasRenderTarget2D.h"
#include "Engine/AssetManager.h"
#include "Engine/StreamableManager.h"

#include "Runtime/Engine/Classes/Engine/Canvas.h"


UC7MapCompositeTexture::UC7MapCompositeTexture()
{
	OnCanvasRenderTargetUpdate.AddDynamic(this, &UC7MapCompositeTexture::PerformMerge);
}

void UC7MapCompositeTexture::PerformMerge(UCanvas* Canvas, int32 Width, int32 Height)
{
	for (int32 i = 0; i < Textures.Num(); ++i)
	{
		float Row = FMath::Floor(i/ColumnNum);
		float Column = i - Row * ColumnNum;
		UTexture* LayerTex = Textures[i];
		
		if (LayerTex)
		{
			Canvas->SetDrawColor(FColor::White);

			Canvas->DrawTile(LayerTex,  Column*TextureSizeEach.X, Row*TextureSizeEach.Y, 
			TextureSizeEach.X , TextureSizeEach.Y, 0, 0, TextureSizeEach.X, TextureSizeEach.Y,
			EBlendMode::BLEND_Opaque);
		}
		else
		{
			// float X = Column*TextureSizeEach.X;
			// float Y = Row*TextureSizeEach.Y;
			// float XL =  TextureSizeEach.X;
			// float YL =  TextureSizeEach.Y;
			//
			// float MyClipX =Canvas-> OrgX +Canvas-> ClipX;
			// float MyClipY =Canvas-> OrgY + Canvas->ClipY;
			// float w = X + XL > MyClipX ? MyClipX - X : XL;
			// float h = Y + YL > MyClipY ? MyClipY - Y : YL;
			// FCanvasTileItem TileItem( FVector2D( X, Y ), GTransparentBlackTexture,  FVector2D(w, h ),  
			// FVector2D(0, 0),
			// FVector2D(1, 1),
			// FColor::White );
			// TileItem.BlendMode = FCanvas::BlendToSimpleElementBlend(EBlendMode::BLEND_Opaque);
			// Canvas->DrawItem( TileItem );
		}
	}
}


void UC7MapCompositeTexture::Update(const TArray<UTexture2D*>& InTextures,const FVector2D& 
InTextureSize,int32 InRowNum,int32 InColumnNum)
{
	if (Textures.Num() <= 0)
	{
		return;
	}
	
	Textures = InTextures;
	TextureSizeEach = InTextureSize;
	RowNum = InRowNum;
	ColumnNum = InColumnNum;
	
	UpdateResource();
}

// UC7MapCompositeTexture* UC7MapCompositeTexture::Create(UObject* WorldContextObject, const TArray<UTexture2D*>& Layers)
// {
// 	TArray<FColor> Colors;
// 	return UC7MapCompositeTexture::Create(WorldContextObject, Layers, Colors);
// }

UC7MapCompositeTexture* UC7MapCompositeTexture::Create(UObject* WorldContextObject, const TArray<UTexture2D*>& Textures,const FVector2D& InTextureSize,int32 InRowNum,int32 InColumnNum)
{
	if (Textures.Num() <= 0)
	{
		return nullptr;
	}

	UTexture2D* BaseTexture = Textures[0];

	UC7MapCompositeTexture* RenderTarget = Cast<UC7MapCompositeTexture>
	(UCanvasRenderTarget2D::CreateCanvasRenderTarget2D(WorldContextObject, UC7MapCompositeTexture::StaticClass(),InTextureSize.X*InRowNum, InTextureSize.Y*InColumnNum));
	RenderTarget->RenderTargetFormat = ETextureRenderTargetFormat::RTF_RGBA8;
	RenderTarget->OverrideFormat = PF_R8G8B8A8; // Force use PF_R8G8B8A8 instead of PF_B8G8R8A8
	RenderTarget->ClearColor = FLinearColor::Transparent;
	RenderTarget->Textures.Append(Textures);
	RenderTarget->TextureSizeEach = InTextureSize;
	RenderTarget->RowNum = InRowNum;
	RenderTarget->ColumnNum = InColumnNum;
	RenderTarget->UpdateResource();
	return RenderTarget;
}

uint32 UC7MapCompositeTexture::CalcTextureMemorySizeEnum(ETextureMipCount Enum) const
{
	// Calculate size based on format.  All mips are resident on render targets so we always return the same value.
	EPixelFormat Format = GetFormat();
	int32 BlockSizeX = GPixelFormats[Format].BlockSizeX;
	int32 BlockSizeY = GPixelFormats[Format].BlockSizeY;
	int32 BlockBytes = GPixelFormats[Format].BlockBytes;
	int32 NumBlocksX = (SizeX + BlockSizeX - 1) / BlockSizeX;
	int32 NumBlocksY = (SizeY + BlockSizeY - 1) / BlockSizeY;
	int32 NumBytes = NumBlocksX * NumBlocksY * BlockBytes;
	return NumBytes;
}


//
// void UC7MapCompositeTexture::CancelImageStreaming()
// {
// 	if (StreamingHandle.IsValid())
// 	{
// 		StreamingHandle->CancelHandle();
// 		StreamingHandle.Reset();
// 	}
//
// 	LoadPaths.Reset();
// }
//
//
// void UC7MapCompositeTexture::RequestAsyncLoad(TArray<FSoftObjectPath>& Paths)
// {
// 	CancelImageStreaming();
//
// 	Paths = LoadPaths;
// 	TWeakObjectPtr<UC7MapCompositeTexture> WeakThis(this);
// 	// StreamingObjectPath = SoftObject.ToSoftObjectPath();
// 	StreamingHandle = UAssetManager::GetStreamableManager().RequestAsyncLoad(
// 		Paths,
// 		[WeakThis]() {
// 			if (UC7MapCompositeTexture* StrongThis = WeakThis.Get())
// 			{
// 				StrongThis->UpdateResource();
// 			}
// 		});
// }