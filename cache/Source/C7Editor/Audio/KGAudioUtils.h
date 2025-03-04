#pragma once

class KGAudioUtils
{
public:
	static void BatchAudioActorProcess_InCurrentLevel();
	static void BatchAudioActorProcess_InAllSoundLevel();
	
private:
	// 这里填写内容
	static void SelfDefinedFunc(AActor* Actor);

	template<class T>
	static void ProcessInAllSoundLevels(TFunction<void(AActor* Actor)> Func);

	template<class T>
	static void ProcessInCurrentLevel(TFunction<void(AActor* Actor)> Func);
};
