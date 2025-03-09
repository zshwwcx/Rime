ITEM_SOURCE_GM_CODE                                           = 99999          -- GM操作
ITEM_SOURCE_KG_GM                                             = 100000         -- 快手GM后台操作

-- 背包道具操作相关
ITEM_SOURCE_ITEM_EXPIRE                                       = 100001         -- 物品过期
ITEM_SOURCE_SYNTHESIS                                         = 100002         -- 物品合成
ITEM_SOURCE_CHANGE_ITEM_BAG                                   = 100003         -- 改变物品的背包
ITEM_SOURCE_INIT_GET_ITEM                                     = 100004         -- 初始化获取物品
ITEM_SOURCE_USE_ITEM                                          = 100005         -- 物品使用
ITEM_SOURCE_OPEN_CHEST                                        = 100006         -- 打开宝箱
ITEM_SOURCE_DISCOUNTED_SALE                                   = 100007         -- 售卖物品
ITEM_SOURCE_DECOMPOSE                                         = 100008         -- 分解物品
ITEM_SOURCE_TAKE_BACK_FROM_TEMP_BAG                           = 100009         -- 临时背包取出
ITEM_SOURCE_STORE_TO_WARE_HOUSE                               = 100010         -- 存进仓库
ITEM_SOURCE_TAKE_FROM_WARE_HOUSE                              = 100011         -- 从仓库取出
ITEM_SOURCE_UNLOCK_WARE_HOUSE_PAGE                            = 100012         -- 解锁仓库页签
ITEM_SOURCE_UNLOCK_WARE_HOUSE_SLOT                            = 100013         -- 解锁仓库格子
ITEM_SOURCE_COLLECTION                                        = 100014         -- 采集物
ITEM_SOURCE_DROP                                              = 100015         -- 掉落物
ITEM_SOURCE_AUCTION                                           = 100016         -- 副本拍卖
ITEM_SOURCE_ROLL                                              = 100017         -- 副本Roll点
ITEM_SOURCE_CLEAN_UP_INVENTORY                                = 100018         -- 整理背包
ITEM_SOURCE_ENLARGE_SLOT                                      = 100019         -- 扩充背包格子
ITEM_SOURCE_AUCTION_DIVIDEND                                  = 100020         -- 副本拍卖分红
ITEM_SOURCE_DISCARD                                           = 100021         -- 丢弃物品
ITEM_SOURCE_GUILD_BLESS                                       = 100022         -- 公会晚间活动祈福
ITEM_SOURCE_GUILD_NIGHT_HANG                                  = 100023         -- 公会挂机活动
ITEM_SOURCE_GUILD_ANSWER                                      = 100024         -- 公会答题成功
ITEM_SOURCE_OPEN_BOX                                          = 100025         -- 打开Box
ITEM_SOURCE_BAG_FULL                                          = 100026         -- 背包已满或背包中该物品已有数量达到上限
ITEM_SOURCE_DROP_FORGET_ITEM                                  = 100027         -- 忘记捡的贵重东西
ITEM_SOURCE_RANK                                              = 100028         -- 排行榜
ITEM_SOURCE_GUILD_BID                                         = 100029         -- 公会拍卖成功发道具
ITEM_SOURCE_WORLD_BID                                         = 100030         -- 世界拍卖成功发道具
ITEM_SOURCE_FREEZE_PACK										  = 100031		   -- 冷静期物品堆叠
ITEM_SOURCE_WILL_BE_AUTO_DECOMPOSE							  = 100032		   -- 即将被自动分解的物品，给客户端做表现的区分
ITEM_SOURCE_BOUND                                             = 100033         -- 道具绑定

-- 聊天
ITEM_SOURCE_CHAT_COLOURFONT                                   = 110001         -- 聊天多彩字体
ITEM_SOURCE_CHAT_LOUD_SPEAKER                                 = 110002         -- 聊天喇叭
ITEM_SOURCE_WORLD_CHAT_COST_MONEY                             = 110003         -- 世界聊天消耗货币
ITEM_SOURCE_CHAT_EXPOSE_COST_MONEY                            = 110004         -- 揭露消耗货币
ITEM_SOURCE_CHAT_ANON_DROP                                    = 110005         -- 匿名聊天掉落

-- 礼金
ITEM_SOURCE_SEND_RED_PACKET                                   = 115001         -- 发红包
ITEM_SOURCE_RECEIVE_RED_PACKET                                = 115002         -- 领取红包
ITEM_SOURCE_RETURN_RED_PACKET                                 = 115003         -- 退还红包

-- 好友
ITEM_SOURCE_FRIEND_CIRCLE_VOICE_SIGNATURE                     = 120001         -- 朋友圈设置语音签名奖励
ITEM_SOURCE_FRIEND_CIRCLE_UPLOAD_PHOTO                        = 120002         -- 朋友圈上传头像奖励
ITEM_SOURCE_FRIEND_CIRCLE_UNLOCK                              = 120003         -- 朋友圈解锁被人心情
ITEM_SOURCE_FRIEND_CIRCLE_GIFT_PUT                            = 120004         -- 某圈礼物投放
ITEM_SOURCE_RELATION_CHANGE_BLESSING                          = 120005         -- 关系改变
ITEM_SOURCE_GIVE_GIFT                                         = 120100         -- 给玩家送礼

-- 工会
ITEM_SOURCE_GUILD_WAGE                                        = 130001         -- 工会每周工资
ITEM_SOURCE_GUILD_ESTABLISH                                   = 130002         -- 建立工会
ITEM_SOURCE_GUILD_RENAME                                      = 130003         -- 工会改名
ITEM_SOURCE_GUILD_SET_BADGE_FRAME                             = 130004         -- 设置工会勋章
ITEM_SOURCE_GUILD_EXERCISE                                    = 130005         -- 公会训练
ITEM_SOURCE_QUIT_GUILD                                        = 130006         -- 离开公会
ITEM_SOURCE_SEND_GUILD_MAIL                                   = 130007         -- 公会邮件
ITEM_SOURCE_GUILD_DANCE_REWARD                                = 130008         -- 公会舞会奖励
ITEM_SOURCE_GUILD_VOYAGE                                      = 130009         -- 公会任务相关
ITEM_SOURCE_GUILD_LEAGUE_SETTLEMENT                           = 130010         -- 公会联赛结算

-- 伙伴
ITEM_SOURCE_FELLOW_COMBINE                                    = 130101         -- 伙伴合成
ITEM_SOURCE_FELLOW_UP_LEVEL                                   = 130102         -- 伙伴升级
ITEM_SOURCE_FELLOW_FIRST_STAR_UP                              = 130103         -- 伙伴大突破
ITEM_SOURCE_FELLOW_SECOND_STAR_UP                             = 130104         -- 伙伴小突破
ITEM_SOURCE_FELLOW_GACHA_SINGLE                               = 130105         -- 伙伴抽卡单抽
ITEM_SOURCE_FELLOW_GACHA_TEN                                  = 130106         -- 伙伴抽卡10连抽
ITEM_SOURCE_FELLOW_LV_BACK_ITEM                               = 130107         -- 伙伴抽卡10连抽

--装备
ITEM_SOURCE_EQUIP_BASEPROP_ENHANCE                            = 130201         -- 装备攻击装基础属性重置
ITEM_SOURCE_EQUIP_BASEPROP_ENHANCE_MAX                        = 130202         -- 装备攻击装基础属性一键补齐
ITEM_SOURCE_EQUIP_RANDOMPROP_ENHANCE                          = 130203         -- 装备攻击装随机词条洗练
ITEM_SOURCE_EQUIP_RANDOMPROP_BATCH_ENHANCE                    = 130204         -- 装备攻击装随机词条5连洗练
ITEM_SOURCE_EQUIP_FIXEDPROP_EXTRACT                           = 130205         -- 装备攻击装固定属性提取
ITEM_SOURCE_EQUIP_FIXEDPROP_APPLY                             = 130206         -- 装备攻击装固定属性应用
ITEM_SOURCE_EQUIP_FIXEDPROP_CONSUME                           = 130207         -- 装备攻击装消耗词缀球
ITEM_SOURCE_EQUIP_BODY_ENHANCE_ACTIVE                         = 130208         -- 装备攻击装部位激活
ITEM_SOURCE_EQUIP_BODY_ENHANCE_REFINE                         = 130209         -- 装备攻击装部位精炼
ITEM_SOURCE_EQUIP_DEF_BASE_PROPS_ENHANCE                      = 130210         -- 装备防御装基础属性提升
ITEM_SOURCE_EQUIP_DEF_BASE_PROPS_POMOTE                       = 130211         -- 装备防御装基础属性突破
ITEM_SOURCE_EQUIP_DEF_ADVANCE_PROPS_RESET                     = 130212         -- 装备防御装高级属性重置
ITEM_SOURCE_EQUIP_ATK_FIXEDPROP_EXTRACT                       = 130213         -- 词缀球提取
ITEM_SOURCE_EQUIP_PUTOFF                                      = 130214         -- 脱装备
ITEM_SOURCE_EQUIP_PUTON                                       = 130215         -- 穿装备
ITEM_SOURCE_EQUIP_FIXEDPROP_SWAP                              = 130216         -- 装备固定属性交换
ITEM_SOURCE_EQUIP_RANDOMPROP_UP                               = 130217         -- 装备随机属性概率提升
ITEM_SOURCE_EQUIP_RANDOMPROP_DOWN                             = 130218         -- 装备随机属性概率降低
ITEM_SOURCE_EQUIP_RANDOMPROP_ALL_RESET                        = 130219         -- 装备随机属性概率全部重置
ITEM_SOURCE_EQUIP_ADVANCEPROP_ENHANCE                         = 130220         -- 装备高级属性洗练通用属性提升
ITEM_SOURCE_EQUIP_RANDOMPROP_CHANGE                           = 130221         -- 圣膏涂抹装备随机词条
ITEM_SOURCE_EQUIP_RANDOMPROP_SELECT                           = 130222         -- 选择装备随机词条
ITEM_SOURCE_EQUIP_FIXEDPROP_REQ_CHANGE                        = 130223         -- 要求更换固定词条

--SDK充值
ITEM_SOURCE_SDK_PUBLICATION_PAY                               = 130301         --版署版本SDK充值

--任务
ITEM_SOURCE_TASK_TRIGGER_SEND                                 = 140001         -- 任务触发事件发放
ITEM_SOURCE_TASK_RECYCLE                                      = 140002         -- 任务回收
ITEM_SOURCE_AF_TASK_REMOVE_ITEM                               = 140003         -- 任务flowchart删除任务道具
ITEM_SOURCE_QUEST_ADD_ITEM_NO_REMINDER                        = 140004         -- 任务发放道具超发部分reminder屏蔽
ITEM_SOURCE_QUEST_ADD_ITEM_NO_REWARD                          = 140005         -- 任务发放道具不显示发放界面
ITEM_SOURCE_QUEST_ADD_ITEM_NO_REMINDER_AND_NO_REWARD          = 140006         -- 任务发放道具超发部分reminder屏蔽同时不显示发放界面
ITEM_SOURCE_SEND_TASK_REWARD                                  = 140007         -- 任务发放奖励
ITEM_SOURCE_DUNGEON_SUPPORT                                   = 140008         -- 副本援助奖励
ITEM_SOURCE_CONVERT_TASK_REWARD                               = 140009         -- 任务转换奖励
ITEM_SOURCE_DUNGEON_SUPPORT_REFUSE                            = 140010         -- 副本援助拒绝奖励

--成就
ITEM_SOURCE_ACHIEVEMENT_LEVEL_ONE_TRIGGER_SEND                = 140101         -- 发放某个成就等级奖励
ITEM_SOURCE_ACHIEVEMENT_LEVEL_ALL_TRIGGER_SEND                = 140102         -- 一键发放成就等级奖励
ITEM_SOURCE_ACHIEVEMENT_ONE_TRIGGER_SEND                      = 140103         -- 发放单个成就奖励
ITEM_SOURCE_ACHIEVEMENT_ALL_TRIGGER_SEND                      = 140104         -- 一键领取成就奖励

--随机商店
ITEM_SOURCE_REFRESH_SHOP_BUY                                  = 150001         -- 随机商店购买
ITEM_SOURCE_REFRESH_SHOP_REFRESH                              = 150002         -- 随机商店刷新

--商城
ITEM_SOURCE_MALL_EXCHANGE_ACTIVE							  = 150101         -- 商城货币兑换

--基础商店
ITEM_SOURCE_BASIC_SHOP_BUY									  = 150201         -- 基础商店购买

--邮件
ITEM_SOURCE_MAIL								              = 150301         -- 领取邮件

--邮件
ITEM_SOURCE_SKILL_UPGRADE							          = 150401         -- 技能升级

--传送
ITEM_SOURCE_SKILL_TELEPORT							          = 150501         -- 传送消耗

--元素天赋养成
ITEM_SOURCE_ELE_TALENT_UPGRADE                                = 150601         --天赋树升级
ITEM_SOURCE_ELE_TALENT_NODE_UPGRADE							  = 150602         --天赋树节点升级
ITEM_SOURCE_ELE_TALENT_NODE_RESET							  = 150603         --天赋树节点重置

--封印物
ITEM_SOURCE_SEALED_UPGRADE                                    = 160001         -- 封印物升级
ITEM_SOURCE_SEALED_BREAKTHROUGH                               = 160002         -- 封印物突破
ITEM_SOURCE_SEALED_RANDOM                                     = 160003         -- 封印物洗练
ITEM_SOURCE_SEALED_DECOMPOSE                                  = 160004         -- 封印物分解
ITEM_SOURCE_SEFIROTCORE_CHANGE                                = 160005         -- 源质核心切换
ITEM_SOURCE_SEALED_EQUIP                                      = 160006         -- 封印物装备穿脱
ITEM_SOURCE_SEALED_UPGRADE_GOBACK                             = 160007         -- 封印物回溯
ITEM_SOURCE_SEALED_LOCKSTATE                                  = 160008         -- 封印物锁定

--活动
ITEM_SOURCE_NEWBIE_TASK_REWARD                                = 160101         -- 新人手册任务奖励
ITEM_SOURCE_WORLD_CHANNEL_QUIZ_REWARD                         = 160102         -- 世界频道答题奖励
ITEM_SOURCE_SCHEDULE_REWARD                                   = 160103         -- 扮演手册
ITEM_SOURCE_ACTIVITY_FIRE_REWARD                              = 160104         -- 薪火奖励


-- 角色成长
ITEM_SOURCE_EXP_COMPENSATE                                	  = 160201         -- 等级溢出转化补偿
ITEM_SOURCE_LEVEL_UP_DROP_REWARD                              = 160202         -- 角色升级奖励

--交易所
ITEM_SOURCE_STALL_BUY_IN                                      = 160301         -- 摆摊道具购买
ITEM_SOURCE_STALL_CELL_UNLOCK                                 = 160302         -- 摆摊解锁摊位格子
ITEM_SOURCE_STALL_EXPIRE                                      = 160303         -- 摆摊道具过期
ITEM_SOURCE_STALL_SELL_OUT                                    = 160304         -- 摆摊道具售出
ITEM_SOURCE_STALL_SHIPPING                                    = 160305         -- 摆摊道具上架
ITEM_SOURCE_STALL_WITHDRAW                                    = 160306         -- 摆摊道具下架
ITEM_SOURCE_STALL_BUY_FAIL_RETURN                             = 160307         -- 摆摊道具购买失败返回货币

--货币寄售
ITEM_SOURCE_SELL_MONEY_SOURCE_ID                              = 160501         -- 货币寄售出售货币(扣除金榜)
ITEM_SOURCE_SELL_MONEY_SUCCESS_REWARD_MONEY_ID                = 160502         -- 货币寄售成功发放便士
ITEM_SOURCE_BUY_MONEY_SOURCE_ID                               = 160503         -- 货币寄售购买货币扣钱
ITEM_SOURCE_BUY_MONEY_SUCCESS_REWARD_MONEY_ID                 = 160504         -- 货币寄售购买成功发绑定金
ITEM_SOURCE_SELL_MONEY_TIME_OUT_RETURN_ID                     = 160505         -- 货币寄售出售超时返回
ITEM_SOURCE_TAKE_BACK_MONEY_ID                                = 160506         -- 货币寄售下架返回金榜
ITEM_SOURCE_SELL_MONEY_FAIL_RETURN_SOURCE_ID                  = 160507         -- 货币寄售出售货币失败返回
ITEM_SOURCE_BUY_MONEY_FAIL_RETURN_SOURCE_ID                   = 160508         -- 货币寄售购买货币失败返回

--药师
ITEM_SOURCE_PHARMACIST_EXPLORE_PRESCRIPTION                   = 160601         -- 药师探索药方
ITEM_SOURCE_PHARMACIST_QUICK_MAKE_MEDICINE                    = 160602         -- 药师快速制药

--世界/公会拍卖
ITEM_SOURCE_WORLD_BID_ITEM_SOURCE_ID                          = 160701         --世界拍卖货币消耗
ITEM_SOURCE_WORLD_BID_ITEM_FAIL_RETURN_SOURCE_ID              = 160702         --世界拍卖失败货币返回
ITEM_SOURCE_BID_PRICE_OVERSHOOT_SOURCE_ID                     = 160703         --价格被超，返回拍卖货币给玩家
ITEM_SOURCE_GUILD_BID_ITEM_SOURCE_ID                          = 160704         --公会拍卖货币消耗
ITEM_SOURCE_GUILD_BID_ITEM_FAIL_RETURN_SOURCE_ID              = 160705         --公会拍卖失败货币返回
ITEM_SOURCE_FINAL_BID_FAIL_SOURCE_ID                          = 160706         --最终拍卖失败，返回拍卖货币给玩家

--扮演玩法
ITEM_SOURCE_ROLE_GRADE_UP_ID                                  = 160801         --扮演玩法角色突破消耗绑定金币
ITEM_SOURCE_ROLE_SKILL_UP_ID                                  = 160802         --扮演玩法角色解锁技能消耗
ITEM_SOURCE_ROLE_LEVEL_UP_ID                                  = 160803         --扮演玩法角色升级
ITEM_SOURCE_ROLE_PAY_FORTUNE                                  = 160804         --扮演玩法占卜付费
ITEM_SOURCE_ROLE_PAY_FORTUNE_ROLLBACK                         = 160805         --扮演玩法占卜付费回滚
ITEM_SOURCE_ROLE_PLAY_JOKER_REWARD                            = 160806         --扮演玩法打赏小丑
ITEM_SOURCE_ROLE_PLAY_JOKER_REWARD_ROLLBACK                   = 160807         --扮演玩法打赏小丑回滚
ITEM_SOURCE_RP_ARBITRATOR_TRIAL_CLEAR_MAIL                    = 160808         --仲裁人清空对方san值邮件
ITEM_SOURCE_RP_ARBITRATOR_TRIAL_ARREST_MAIL                   = 160809         --仲裁人逮捕对方邮件
ITEM_SOURCE_RP_ARBITRATOR_DICE_SUCCESS                        = 160810         --仲裁人奖励
ITEM_SOURCE_RP_SHERIFF_ATTACK_MONSTER                         = 160811         --治安官副本后续奖励
ITEM_SOURCE_RP_ARBITRATOR_WIN_AFTER_DICE                      = 160812         --仲裁人检定失败战斗奖励
ITEM_SOURCE_RP_SHERIFF_CHECK_DEAD                             = 160813         --治安玩法通灵成功后的任务道具
ITEM_SOURCE_RP_ARBITRATOR_BATTLE_WIN_NPC                      = 160814         --仲裁人玩家战胜Npc
--道具提交
ITEM_SOURCE_ITEM_SUBMIT_SOURCE_ID                             = 160901         --通用道具提交消费

ITEM_SOURCE_GUILD_MATERIAL_TASK                               = 161001          --生活材料回收任务奖励

--序列晋升
ITEM_SOURCE_SEQUENCE_PROMOTE_MAKE_MEDICINE                    = 161101          --序列晋升炼制魔药
ITEM_SOURCE_SEQUENCE_USE_PROMOTION_POTION                     = 161102

--时装系统
ITEM_SOURCE_FASHION_REWARD                                    = 161201          --风尚值的奖励
ITEM_SOURCE_FASHION_TRANS                                     = 161202          --时装重复转化
ITEM_SOURCE_FASHION_AROUND_TRANS                              = 161203          --时装周边重复转化  
ITEM_SOURCE_FACE_SLOT_UNLOCK                                  = 161204          --解锁捏脸槽位
ITEM_SOURCE_MAKEUP_SLOT_UNLOCK                                = 161205          --解锁妆容槽位
ITEM_SOURCE_STAIN_SLOT_UNLOCK                                 = 161206          --解锁染色槽位
ITEM_SOURCE_MAKEUP_TRANSLATED                                 = 161207          --妆容重复转化
--大世界探索
ITEM_SOURCE_EXPLORE_SOUL_SUBMIT                               = 161301          --奉献之灵提交
ITEM_SOURCE_GAME_DROP_REWARD                                  = 161302          --和交互物进行交互获取奖励

ITEM_SOURCE_FLOWCHART                                         = 161401          --flowchart

ITEM_SOURCE_NPC_ASK_PRICE                                     = 161501          --npc问价
ITEM_SOURCE_WORLD_BOSS                                        = 161601          --世界Boss

-- 收藏品系统
ITEM_SOURCE_COLLECTIBLES                                      = 161701

-- pvp
ITEM_SOURCE_TEAM33_RANK_REWARD                                = 161801          --33段位奖励
ITEM_SOURCE_TEAM55_RANK_REWARD                                = 161802          --55段位奖励
ITEM_SOURCE_TEAM1212_RANK_REWARD                              = 161805          --1212段位奖励

ITEM_SOURCE_PVP_MEDICINE_GET                                  = 161810          --pvp药剂获得
ITEM_SOURCE_PVP_MEDICINE_RECYCLE                              = 161811          --pvp药剂回收


-- 跳舞生活玩法
ITEM_SOURCE_DANCE_LIFE										  = 161901

-- 探索玩法
ITEM_SOURCE_EXPOLRE_STELE									  = 162001          --探索石碑
ITEM_SOURCE_EXPOLRE_AREA									  = 162002          --区域探索

-- 新手引导
ITEM_SOURCE_NEWBIE_GUIDE									  = 162101

-- 爬塔玩法
ITEM_SOURCE_TOWER_CLIMB									      = 162201

-- 家园
ITEM_SOURCE_HOME_FURNITURE_UNLOCK                             = 162301          -- 家园家具解锁
ITEM_SOURCE_HOME_FURNITURE_BUILD                              = 162302          -- 家园家具制造

-- 塔罗小队
ITEM_SOURCE_TAROTTEAM_GET_LEVEL_REWARD                        = 162401          -- 塔罗小队等级奖励
ITEM_SOURCE_TAROTTEAM_GET_WAGE                                = 162402          -- 塔罗小队领工资
ITEM_SOURCE_TAROTTEAM_BE_KICK                                 = 162403          -- 塔罗小队被踢
ITEM_SOURCE_TAROTTEAM_LAUNCH_KICK_LEADER                      = 162404          -- 塔罗小队发起队长弹劾
ITEM_SOURCE_TAROTTEAM_DISBAND                                 = 162405          -- 塔罗小队解散

ITEM_SOURCE_ARRODES_TALK_EVENT                                = 162501          -- 阿罗德斯对话事件


-- 剧情回顾
ITEM_SOURCE_PLOT_RECAP_ONE_REWARD_SEND                        = 162601          -- 发放单个剧情回顾奖励
ITEM_SOURCE_PLOT_RECAP_ALL_REWARD_SEND                        = 162602          -- 发放剧情回顾某类全部奖励
ITEM_SOURCE_PLOT_RECAP_ONE_LEVEL_REWARD_SEND                        = 162603          -- 发放剧情回顾大类单个等级奖励
ITEM_SOURCE_PLOT_RECAP_ALL_LEVEL_REWARD_SEND                        = 162604          -- 发放剧情回顾大类全部等级奖励



function CheckAfterLoadModule(moduleEnv)
    local checkValueMap = {}  -- luacheck: ignore
    for k, v in pairs(moduleEnv) do
        assert(not checkValueMap[v], string.format("value duplicate %s %s ", k, checkValueMap[v]))
        checkValueMap[v] = k
    end
end

-- 物品进包时,奖励发放相关需要走掉落,不方便走掉落的在这里配白名单
ADD_ITEM_WITHOUT_DROP_WHITE_LIST = {
    [ITEM_SOURCE_TASK_TRIGGER_SEND] = true,  -- 任务触发事件发放 策划确认不改
    [ITEM_SOURCE_QUEST_ADD_ITEM_NO_REMINDER] = true,  -- 任务发放道具超发部分reminder屏蔽 策划确认不改
    [ITEM_SOURCE_QUEST_ADD_ITEM_NO_REWARD] = true,  -- 任务发放道具不显示发放界面 策划确认不改
    [ITEM_SOURCE_QUEST_ADD_ITEM_NO_REMINDER_AND_NO_REWARD] = true,  -- 任务发放道具超发部分reminder屏蔽同时不显示发放界面 策划确认不改
    [ITEM_SOURCE_EQUIP_RANDOMPROP_ALL_RESET] = true,  -- 装备随机属性概率全部重置，策划确认不改
    [ITEM_SOURCE_SDK_PUBLICATION_PAY] = true,  -- 版署版本SDK充值，策划确认不改
    [ITEM_SOURCE_REFRESH_SHOP_BUY] = true,  -- 随机商店购买，策划确认不改
    [ITEM_SOURCE_OPEN_CHEST] = true,  -- 打开宝箱 有自选宝箱，无法静态生成
    [ITEM_SOURCE_OPEN_BOX] = true,  -- 打开Box 背包满不发送物品
    [ITEM_SOURCE_BASIC_SHOP_BUY] = true, -- 商店购买 不需要 走自己的一套
    [ITEM_SOURCE_GUILD_MATERIAL_TASK] = true,  -- 生活材料回收任务奖励 动态的，不能配
    [ITEM_SOURCE_NPC_ASK_PRICE] = true,  -- npc问价 动态的，不能配
    [ITEM_SOURCE_PHARMACIST_EXPLORE_PRESCRIPTION] = true,  -- 药师探索药方 动态的，不能配
    [ITEM_SOURCE_PHARMACIST_QUICK_MAKE_MEDICINE] = true,  -- 药师快速制药 动态的，不能配
    [ITEM_SOURCE_SYNTHESIS] = true,  -- 物品合成 有绑定关系，不能配
    [ITEM_SOURCE_DECOMPOSE] = true,  -- 分解物品 有绑定关系，不能配
    [ITEM_SOURCE_CONVERT_TASK_REWARD] = true,  -- 任务转换奖励 动态转换，不能配
    [ITEM_SOURCE_GM_CODE] = true,
    [ITEM_SOURCE_KG_GM] = true,
    [ITEM_SOURCE_GUILD_BID] = true,
    [ITEM_SOURCE_WORLD_BID] = true,
    [ITEM_SOURCE_STALL_BUY_IN] = true,
    [ITEM_SOURCE_STALL_WITHDRAW] = true,
    [ITEM_SOURCE_SEALED_RANDOM] = true,
    [ITEM_SOURCE_SEALED_EQUIP] = true,
    [ITEM_SOURCE_SEALED_UPGRADE_GOBACK] = true,
    [ITEM_SOURCE_SEALED_UPGRADE] = true,
    [ITEM_SOURCE_SEALED_BREAKTHROUGH] = true,
    [ITEM_SOURCE_SEALED_RANDOM] = true,
    [ITEM_SOURCE_SEALED_EQUIP] = true,
    [ITEM_SOURCE_SEALED_UPGRADE_GOBACK] = true,
    [ITEM_SOURCE_CHANGE_ITEM_BAG] = true,
    [ITEM_SOURCE_TAKE_BACK_FROM_TEMP_BAG] = true,
    [ITEM_SOURCE_STORE_TO_WARE_HOUSE] = true,
    [ITEM_SOURCE_TAKE_FROM_WARE_HOUSE] = true,
    [ITEM_SOURCE_DROP] = true,
    [ITEM_SOURCE_ROLL] = true,
    [ITEM_SOURCE_AUCTION] = true,
    [ITEM_SOURCE_AUCTION_DIVIDEND] = true,
    [ITEM_SOURCE_CLEAN_UP_INVENTORY] = true,
    [ITEM_SOURCE_DISCARD] = true,
    [ITEM_SOURCE_FREEZE_PACK] = true,
    [ITEM_SOURCE_RECEIVE_RED_PACKET] = true,
    [ITEM_SOURCE_FELLOW_GACHA_SINGLE] = true,
    [ITEM_SOURCE_FELLOW_GACHA_TEN] = true,
    [ITEM_SOURCE_FELLOW_LV_BACK_ITEM] = true,
    [ITEM_SOURCE_EQUIP_PUTOFF] = true,
    [ITEM_SOURCE_EQUIP_PUTON] = true,
    [ITEM_SOURCE_WORLD_BOSS] = true,
    [ITEM_SOURCE_EQUIP_FIXEDPROP_SWAP] = true,
    [ITEM_SOURCE_MAIL] = true,
    [ITEM_SOURCE_ROLE_PAY_FORTUNE] = true,
    [ITEM_SOURCE_ROLE_PLAY_JOKER_REWARD] = true,
    [ITEM_SOURCE_ARRODES_TALK_EVENT] = true,
    [ITEM_SOURCE_ELE_TALENT_NODE_UPGRADE] = true,   --天赋树节点升级(可以重置)
    [ITEM_SOURCE_ELE_TALENT_NODE_RESET] = true,     --天赋树节点重置返回道具
}
