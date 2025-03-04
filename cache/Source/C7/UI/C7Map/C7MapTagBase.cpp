// Fill out your copyright notice in the Description page of Project Settings.

#include "UI/C7Map/C7MapTagBase.h"
#include "MapCommon.h"
#include "C7MapTagLayer.h"



void UC7MapTagBase::InitTagWidget()
{
}

void UC7MapTagBase::UnInitTagWidget()
{
	if (OnClicked.IsBound())
	{
		OnClicked.Unbind();
	}
}

void UC7MapTagBase::SetTask(TSharedPtr<FMapTagRunningData> InTask)
{
	if (InTask.IsValid())
	{
		CurrentTagTaskID = InTask->TagData.TagID;
	}
}




