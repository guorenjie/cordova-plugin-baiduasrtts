/********* CDVBaiduasrtts.m Cordova Plugin Implementation *******/

#import <Cordova/CDV.h>
#import "BDSEventManager.h"
#import "BDSASRDefines.h"
#import "BDSASRParameters.h"
#import "BDSWakeupDefines.h"
#import "BDSWakeupParameters.h"
#import "BDSSpeechSynthesizer.h"
#import <AVFoundation/AVFoundation.h>


@interface CDVBaiduasrtts : CDVPlugin<BDSClientASRDelegate,BDSSpeechSynthesizerDelegate> {
    // Member variables go here.
    NSString* API_KEY;
    NSString* SECRET_KEY;
    NSString* APP_ID;
    NSString* callbackId;
    NSInteger sentenceID;//语音合成语句标识
}

@property (strong, nonatomic) BDSEventManager *asrEventManager;
@property (strong, nonatomic) BDSEventManager *wakeupEventManager;
@property (strong, nonatomic) NSBundle *bdsClientBundle;
@property(nonatomic, strong) NSFileHandle *fileHandler;

- (void)initTTSconfig:(CDVInvokedUrlCommand *)command;
- (void)wakeup:(CDVInvokedUrlCommand *)command;
- (void)sleep:(CDVInvokedUrlCommand *)command;
- (void)startSpeechRecognize:(CDVInvokedUrlCommand *)command;
- (void)closeSpeechRecognize:(CDVInvokedUrlCommand *)command;
- (void)cancelSpeechRecognize:(CDVInvokedUrlCommand *)command;
- (void)addEventListener:(CDVInvokedUrlCommand *)command;
- (void)synthesizeSpeech:(CDVInvokedUrlCommand *)command;
- (void)stopSpeak:(CDVInvokedUrlCommand *)command;


@end

@implementation CDVBaiduasrtts

- (void)pluginInitialize {
    NSLog(@"初始化。。。。。");
    

    [self.commandDelegate runInBackground:^{
        // 创建语音识别对象
        self.asrEventManager = [BDSEventManager createEventManagerWithName:BDS_ASR_NAME];
        // 创建语音唤醒对象
        self.wakeupEventManager = [BDSEventManager createEventManagerWithName:BDS_WAKEUP_NAME];
        CDVViewController *viewController = (CDVViewController *)self.viewController;
        self->APP_ID = [viewController.settings objectForKey:@"baiduasrttsappid"];
        self->API_KEY = [viewController.settings objectForKey:@"baiduasrttsapikey"];
        self->SECRET_KEY = [viewController.settings objectForKey:@"baiduasrttssecretkey"];
        
    }];
}

- (NSInteger)checkMicPermission {
    NSInteger flag = 0;
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    switch (authStatus) {
        case AVAuthorizationStatusNotDetermined:
        //没有询问是否开启麦克风
        flag = 1;
        break;
        case AVAuthorizationStatusRestricted:
        //未授权，家长限制
        flag = 0;
        break;
        case AVAuthorizationStatusDenied:
        //玩家未授权
        flag = 0;
        break;
        case AVAuthorizationStatusAuthorized:
        //玩家授权
        flag = 2;
        break;
        default:
        break;
    }
    NSString *wwFlag = [NSString stringWithFormat:@"%ld",(long)flag];
    NSLog(@"语音权限状态");
    NSLog(@"%@", wwFlag);
    return flag;
}

- (void)sendEvent:(NSDictionary *)dict {
    NSLog(@"sendEvent callbackId  %@", callbackId);
    if (!callbackId) return;
    
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dict];
    [result setKeepCallback:[NSNumber numberWithBool:YES]];
    [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    
}

- (void)printLogTextView:(NSString *)logString
{
    NSLog(@"%@", logString);
}

- (NSDictionary *)parseLogToDic:(NSString *)logString
{
    NSArray *tmp = NULL;
    NSMutableDictionary *logDic = [[NSMutableDictionary alloc] initWithCapacity:3];
    NSArray *items = [logString componentsSeparatedByString:@"&"];
    for (NSString *item in items) {
        tmp = [item componentsSeparatedByString:@"="];
        if (tmp.count == 2) {
            [logDic setObject:tmp.lastObject forKey:tmp.firstObject];
        }
    }
    return logDic;
}



- (void)initTTSconfig:(CDVInvokedUrlCommand *)command {
    //空方法，调用它是为了初始化插件
    NSLog(@"启动。TTS version info: %@", [BDSSpeechSynthesizer version]);
    
}

- (void)wakeup:(CDVInvokedUrlCommand *)command {
    NSLog(@"开启唤醒");
    [self.commandDelegate runInBackground:^{
        [self configWakeupClient];
        [self.wakeupEventManager setParameter:nil forKey:BDS_WAKEUP_AUDIO_FILE_PATH];
        [self.wakeupEventManager setParameter:nil forKey:BDS_WAKEUP_AUDIO_INPUT_STREAM];
        [self.wakeupEventManager sendCommand:BDS_WP_CMD_LOAD_ENGINE];
        [self.wakeupEventManager sendCommand:BDS_WP_CMD_START];
        
        NSLog(@"wakeup callbackId  %@", self->callbackId);
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"wakeup"];
        [result setKeepCallback:[NSNumber numberWithBool:YES]];
        [self.commandDelegate sendPluginResult:result callbackId:self->callbackId];
        
    }];
    
}
- (void)configWakeupClient {
    [self.wakeupEventManager setDelegate:self];
    [self.wakeupEventManager setParameter:APP_ID forKey:BDS_WAKEUP_APP_CODE];
    [self configWakeupSettings];
}

- (void)configWakeupSettings {
    NSString* dat = [[NSBundle mainBundle] pathForResource:@"bds_easr_basic_model" ofType:@"dat"];
    NSString* words = [[NSBundle mainBundle] pathForResource:@"bds_easr_wakeup_words" ofType:@"dat"];
    [self.wakeupEventManager setParameter:dat forKey:BDS_WAKEUP_DAT_FILE_PATH];
    [self.wakeupEventManager setParameter:words forKey:BDS_WAKEUP_WORDS_FILE_PATH];

}
- (void)sleep:(CDVInvokedUrlCommand *)command {
    NSLog(@"停止唤醒");
    [self.commandDelegate runInBackground:^{
        [self.wakeupEventManager sendCommand:BDS_WP_CMD_STOP];
        [self.wakeupEventManager sendCommand:BDS_WP_CMD_UNLOAD_ENGINE];
        self->callbackId = command.callbackId;
        NSLog(@"sleep callbackId  %@", self->callbackId);
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"sleep"];
        [result setKeepCallback:[NSNumber numberWithBool:YES]];
        [self.commandDelegate sendPluginResult:result callbackId:self->callbackId];
    }];
    
}
- (void)startSpeechRecognize:(CDVInvokedUrlCommand*)command
{
    NSLog(@"开始识别。。。。。。。。");
    [self.commandDelegate runInBackground:^{
        if ([self checkMicPermission] == 0) {
            NSLog(@"没有权限");
            self->callbackId = command.callbackId;
            NSLog(@"startSpeechRecognize 没有权限 callbackId  %@", self->callbackId);
            
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"startSpeechRecognize"];
            [result setKeepCallback:[NSNumber numberWithBool:YES]];
            [self.commandDelegate sendPluginResult:result callbackId:self->callbackId];
        } else {
            NSLog(@"发送指令：启动识别");
            [self initAsrEventManager];
            // 发送指令：启动识别
            [self.asrEventManager sendCommand:BDS_ASR_CMD_START];
            self->callbackId = command.callbackId;
            NSLog(@"startSpeechRecognize callbackId  %@", self->callbackId);
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"startSpeechRecognize"];
            [result setKeepCallback:[NSNumber numberWithBool:YES]];
            [self.commandDelegate sendPluginResult:result callbackId:self->callbackId];
        }
    }];
    
}
- (void)initAsrEventManager {
    
    // 设置语音识别代理
    [self.asrEventManager setDelegate:self];
    NSLog(@"%@", APP_ID);
    // 参数配置：在线身份验证
    [self.asrEventManager setParameter:@[API_KEY, SECRET_KEY] forKey:BDS_ASR_API_SECRET_KEYS];
    NSLog(@"完成身份验证 ");
    //设置 APPID
    [self.asrEventManager setParameter:APP_ID forKey:BDS_ASR_OFFLINE_APP_CODE];
    NSLog(@"完成 设置 APPID ");
    //设置提示音
    [self.asrEventManager setParameter:@(EVRPlayToneAll) forKey:BDS_ASR_PLAY_TONE];
    //屏蔽了setActive接口的调用(不屏蔽的话就算走录音机关闭回调仍然有几率打断后续的语音合成)
    [self.asrEventManager setParameter:@(YES) forKey:BDS_ASR_DISABLE_AUDIO_OPERATION];
    //配置端点检测（二选一）
    //[self configModelVAD];
     [self configDNNMFE];
    NSLog(@"完成 配置端点检测 ");
        [self.asrEventManager setParameter:@"1537" forKey:BDS_ASR_PRODUCT_ID];
    // ---- 语义与标点 -----
    // [self enableNLU];
        [self enablePunctuation];
    // ------------------------
    NSLog(@"全部完成配置");
}

- (void)configModelVAD {
    NSString *modelVAD_filepath = [[NSBundle mainBundle] pathForResource:@"bds_easr_basic_model" ofType:@"dat"];
    
    //NSString *modelVAD_filepath = [self.bdsClientBundle pathForResource:@"bds_easr_basic_model" ofType:@"dat"];
    [self.asrEventManager setParameter:modelVAD_filepath forKey:BDS_ASR_MODEL_VAD_DAT_FILE];
    [self.asrEventManager setParameter:@(YES) forKey:BDS_ASR_ENABLE_MODEL_VAD];
    
    [self.asrEventManager setParameter:@(YES) forKey:BDS_ASR_ENABLE_NLU];
    
    [self.asrEventManager setParameter:@"15361" forKey:BDS_ASR_PRODUCT_ID];
}

- (void)configDNNMFE {
    NSString *mfe_dnn_filepath = [[NSBundle mainBundle] pathForResource:@"bds_easr_mfe_dnn" ofType:@"dat"];
    
    //NSString *mfe_dnn_filepath = [self.bdsClientBundle pathForResource:@"bds_easr_mfe_dnn" ofType:@"dat"];
    [self.asrEventManager setParameter:mfe_dnn_filepath forKey:BDS_ASR_MFE_DNN_DAT_FILE];
    NSString *cmvn_dnn_filepath = [[NSBundle mainBundle] pathForResource:@"bds_easr_mfe_cmvn" ofType:@"dat"];
    
    //NSString *cmvn_dnn_filepath = [self.bdsClientBundle pathForResource:@"bds_easr_mfe_cmvn" ofType:@"dat"];
    [self.asrEventManager setParameter:cmvn_dnn_filepath forKey:BDS_ASR_MFE_CMVN_DAT_FILE];
    // 自定义静音时长
    //    [self.asrEventManager setParameter:@(501) forKey:BDS_ASR_MFE_MAX_SPEECH_PAUSE];
    //    [self.asrEventManager setParameter:@(500) forKey:BDS_ASR_MFE_MAX_WAIT_DURATION];
}
- (NSBundle *)bdsClientBundle {
    if (!_bdsClientBundle) {
        NSString *strResourcesBundle = [[NSBundle mainBundle] pathForResource:@"bds_easr_basic_model" ofType:@"dat"];
        //NSLog(@"strResourcesBundle,的路径：%@",strResourcesBundle)；
         NSLog(@"%@ 输出strResourcesBundle字符串\n", strResourcesBundle);
        _bdsClientBundle = [NSBundle bundleWithPath:strResourcesBundle];
    }
    
    return _bdsClientBundle;
}

- (void) enableNLU {
    // ---- 开启语义理解 -----
    [self.asrEventManager setParameter:@(YES) forKey:BDS_ASR_ENABLE_NLU];
    [self.asrEventManager setParameter:@"15373" forKey:BDS_ASR_PRODUCT_ID];
}

- (void) enablePunctuation {
    // ---- 关闭标点输出 -----
    [self.asrEventManager setParameter:@(YES) forKey:BDS_ASR_DISABLE_PUNCTUATION];
    // 普通话标点
    //    [self.asrEventManager setParameter:@"1537" forKey:BDS_ASR_PRODUCT_ID];
    // 英文标点
//    [self.asrEventManager setParameter:@"1737" forKey:BDS_ASR_PRODUCT_ID];
    
}

- (void)closeSpeechRecognize:(CDVInvokedUrlCommand *)command {
    NSLog(@"停止识别");
    [self.commandDelegate runInBackground:^{
        [self.asrEventManager sendCommand:BDS_ASR_CMD_STOP];
//        self->callbackId = command.callbackId;
        NSLog(@"closeSpeechRecognize callbackId  %@", self->callbackId);
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"closeSpeechRecognize"];
        [result setKeepCallback:[NSNumber numberWithBool:YES]];
        [self.commandDelegate sendPluginResult:result callbackId:self->callbackId];
    }];
    
}

- (void)cancelSpeechRecognize:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        [self.asrEventManager sendCommand:BDS_ASR_CMD_CANCEL];
//        self->callbackId = command.callbackId;
        NSLog(@"cancelSpeechRecognize callbackId  %@", self->callbackId);
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"cancelSpeechRecognize"];
        [result setKeepCallback:[NSNumber numberWithBool:YES]];
        [self.commandDelegate sendPluginResult:result callbackId:self->callbackId];
    }];
    
}


- (void)synthesizeSpeech:(CDVInvokedUrlCommand *)command {
    NSLog(@"开始语音合成...");
    [BDSSpeechSynthesizer setLogLevel:BDS_PUBLIC_LOG_VERBOSE];
    [[BDSSpeechSynthesizer sharedInstance] setSynthesizerDelegate:self];
    [self configureOnlineTTS];
    // [self configureOfflineTTS];
    // 获取传来的参数
    NSString* speech_test = [command.arguments objectAtIndex:0];
    NSLog(@"合成文本：%@", speech_test);
    //string长度小于60，直接朗读，否则分割朗读；
    NSString *temp = nil;
    if([speech_test length]<60){
        NSError *err = nil;
        sentenceID = [[BDSSpeechSynthesizer sharedInstance] speakSentence: speech_test withError:&err];
        NSLog(@"sentenceID:%ld error:%@",(long)sentenceID,err);
    }else{
        NSInteger lastStrLength = [speech_test length]%60;
        for(int i =0; i < [speech_test length]-lastStrLength; i+=60) {
            temp = [speech_test substringWithRange:NSMakeRange(i, 60)];
            NSLog(@"当前合成的语句是第%d句，内容是:%@",i+1,temp);
            NSError *err = nil;
            sentenceID = [[BDSSpeechSynthesizer sharedInstance] speakSentence: temp withError:&err];
            NSLog(@"sentenceID:%ld error:%@",(long)sentenceID,err);
        }
        NSString *lastString = [speech_test substringFromIndex:speech_test.length-lastStrLength];
        NSLog(@"当前合成的语句是最后一句，内容是:%@",lastString);
        NSError *err = nil;
        sentenceID = [[BDSSpeechSynthesizer sharedInstance] speakSentence: lastString withError:&err];
        NSLog(@"sentenceID:%ld error:%@",(long)sentenceID,err);
    }
    
//    self->callbackId = command.callbackId;
    NSLog(@"synthesizeSpeech callbackId  %@", self->callbackId);
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"synthesizeSpeech"];
    [result setKeepCallback:[NSNumber numberWithBool:YES]];
    [self.commandDelegate sendPluginResult:result callbackId:self->callbackId];
    
}
-(void)configureOnlineTTS{
    
    [[BDSSpeechSynthesizer sharedInstance] setApiKey:API_KEY withSecretKey:SECRET_KEY];
    [[AVAudioSession sharedInstance]setCategory:AVAudioSessionCategoryPlayback error:nil];
//    [[BDSSpeechSynthesizer sharedInstance] setSynthParam:@(NO) forKey:BDS_SYNTHESIZER_PARAM_ENABLE_AVSESSION_MGMT];
//    [[BDSSpeechSynthesizer sharedInstance] setSynthParam:@(NO) forKey:BDS_SYNTHESIZER_PARAM_AUDIO_SESSION_CATEGORY_OPTIONS];

    [[BDSSpeechSynthesizer sharedInstance] setSynthParam:@(BDS_SYNTHESIZER_SPEAKER_DYY) forKey:BDS_SYNTHESIZER_PARAM_SPEAKER];
    //    [[BDSSpeechSynthesizer sharedInstance] setSynthParam:@(10) forKey:BDS_SYNTHESIZER_PARAM_ONLINE_REQUEST_TIMEOUT];
}

-(void)configureOfflineTTS{
    
    NSError *err = nil;
    // 在这里选择不同的离线音库（请在XCode中Add相应的资源文件），同一时间只能load一个离线音库。根据网络状况和配置，SDK可能会自动切换到离线合成。
    NSString* offlineEngineSpeechData = [[NSBundle mainBundle] pathForResource:@"Chinese_And_English_Speech_Female" ofType:@"dat"];
    
    NSString* offlineChineseAndEnglishTextData = [[NSBundle mainBundle] pathForResource:@"Chinese_And_English_Text" ofType:@"dat"];
    
    NSString* offlineEngineLicenseFile = [[NSBundle mainBundle] pathForResource:@"offline_engine_tmp_license" ofType:@"dat"];
    
    err = [[BDSSpeechSynthesizer sharedInstance]  loadOfflineEngine:offlineChineseAndEnglishTextData speechDataPath:offlineEngineSpeechData licenseFilePath:offlineEngineLicenseFile
        withAppCode:APP_ID];

    if(err){
        NSLog(@"失败：Offline TTS init failed");
        return;
    }
    //[TTSConfigViewController loadedAudioModelWithName:@"Chinese female" forLanguage:@"chn"];
    //[TTSConfigViewController loadedAudioModelWithName:@"English female" forLanguage:@"eng"];
}
- (void)loadOfflineEngine
{
    [self configOfflineClient];
    [self.asrEventManager sendCommand:BDS_ASR_CMD_LOAD_ENGINE];
}

- (void)unLoadOfflineEngine
{
    [self.asrEventManager sendCommand:BDS_ASR_CMD_UNLOAD_ENGINE];
}
- (void)configOfflineClient {
    // 离线仅可识别自定义语法规则下的词
    NSString* gramm_filepath = [[NSBundle mainBundle] pathForResource:@"bds_easr_gramm" ofType:@"dat"];
    NSString* lm_filepath = [[NSBundle mainBundle] pathForResource:@"bds_easr_basic_model" ofType:@"dat"];;
    NSString* wakeup_words_filepath = [[NSBundle mainBundle] pathForResource:@"bds_easr_wakeup_words" ofType:@"dat"];;
    [self.asrEventManager setDelegate:self];
    [self.asrEventManager setParameter:APP_ID forKey:BDS_ASR_OFFLINE_APP_CODE];
    [self.asrEventManager setParameter:lm_filepath forKey:BDS_ASR_OFFLINE_ENGINE_DAT_FILE_PATH];
    // 请在 (官网)[http://speech.baidu.com/asr] 参考模板定义语法，下载语法文件后，替换BDS_ASR_OFFLINE_ENGINE_GRAMMER_FILE_PATH参数
    [self.asrEventManager setParameter:gramm_filepath forKey:BDS_ASR_OFFLINE_ENGINE_GRAMMER_FILE_PATH];
    [self.asrEventManager setParameter:wakeup_words_filepath forKey:BDS_ASR_OFFLINE_ENGINE_WAKEUP_WORDS_FILE_PATH];
    
}

- (void)stopSpeak:(CDVInvokedUrlCommand *)command {
    NSLog(@"停止语音合成");
    [[BDSSpeechSynthesizer sharedInstance] cancel];
    NSLog(@"stopSpeak callbackId  %@", self->callbackId);
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"stopSpeak"];
    [result setKeepCallback:[NSNumber numberWithBool:YES]];
    [self.commandDelegate sendPluginResult:result callbackId:self->callbackId];
    
}

- (void)addEventListener:(CDVInvokedUrlCommand *)command {
    NSLog(@"您好，开始监听回调了");
    
    [self.commandDelegate runInBackground:^{
        self->callbackId = command.callbackId;
        NSLog(@"addEventListener %@", self->callbackId);
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
        [result setKeepCallback:[NSNumber numberWithBool:YES]];
        [self.commandDelegate sendPluginResult:result callbackId:self->callbackId];
    }];
}

- (NSString *)getDescriptionForDic:(NSDictionary *)dic {
    if (dic) {
        return [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:dic
                                                                              options:NSJSONWritingPrettyPrinted
                                                                                error:nil] encoding:NSUTF8StringEncoding];
    }
    return nil;
}

#pragma mark - 语音唤醒回调
- (void)WakeupClientWorkStatus:(int)workStatus obj:(id)aObj
{
    NSLog(@"语音唤醒代理");
    switch (workStatus) {
        case EWakeupEngineWorkStatusStarted: {
            [self printLogTextView:@"WAKEUP CALLBACK: Started.\n"];
            break;
        }
        case EWakeupEngineWorkStatusStopped: {
            [self printLogTextView:@"WAKEUP CALLBACK: Stopped.\n"];
            NSDictionary *dict = @{
                                   @"type": @"sleep",
                                   @"message": @"ok"
                                   };
            [self sendEvent:dict];
            break;
        }
        case EWakeupEngineWorkStatusLoaded: {
            [self printLogTextView:@"WAKEUP CALLBACK: Loaded.\n"];
            break;
        }
        case EWakeupEngineWorkStatusUnLoaded: {
            [self printLogTextView:@"WAKEUP CALLBACK: UnLoaded.\n"];
            break;
        }
        case EWakeupEngineWorkStatusTriggered: {
            //命中
            [self printLogTextView:[NSString stringWithFormat:@"WAKEUP CALLBACK: Triggered - %@.\n", (NSString *)aObj]];
            NSDictionary *dict = @{
                                   @"type": @"wakeup",
                                   @"message": (NSString *)aObj
                                   };
            [self sendEvent:dict];
            break;
        }
        case EWakeupEngineWorkStatusError: {
            [self printLogTextView:[NSString stringWithFormat:@"WAKEUP CALLBACK: encount error - %@.\n", (NSError *)aObj]];
            NSDictionary *dict = @{
                                   @"type": @"error",
                                   @"message": @"语音唤醒错误"
                                   };
            [self sendEvent:dict];
            break;
        }
            
        default:
            break;
    }
}

#pragma mark - 语音识别回调

- (void)VoiceRecognitionClientWorkStatus:(int)workStatus obj:(id)aObj {
    NSLog(@"语音识别代理");
    switch (workStatus) {
        case EVoiceRecognitionClientWorkStatusNewRecordData: {
            NSLog(@"录音数据回调 EVoiceRecognitionClientWorkStatusNewRecordData");
                       [self.fileHandler writeData:(NSData *)aObj];
            break;
        }
        
        case EVoiceRecognitionClientWorkStatusStartWorkIng: {
            NSLog(@"识别开始");
            NSDictionary *logDic = [self parseLogToDic:aObj];
            [self printLogTextView:[NSString stringWithFormat:@"CALLBACK: start vr, log: %@\n", logDic]];
            NSDictionary *dict = @{
                                   @"type": @"asrReady",
                                   @"message": @"ok"
                                   };
            [self sendEvent:dict];
            break;
        }
        case EVoiceRecognitionClientWorkStatusStart: {
            NSLog(@"检查到用户开始说话");
            NSDictionary *dict = @{
                                   @"type": @"asrBegin",
                                   @"message": @"ok"
                                   };
            [self sendEvent:dict];
            break;
        }
        case EVoiceRecognitionClientWorkStatusEnd: {
            NSLog(@"asrEnd:本地声音采集结束，等待识别结果返回并结束录音");
            NSDictionary *dict = @{
                                   @"type": @"asrEnd",
                                   @"message": @"ok"
                                   };
            [self sendEvent:dict];
            
            break;
        }
        case EVoiceRecognitionClientWorkStatusFlushData: {
            NSLog(@"语音实时识别结果");
            //新增best_result属性，等于results_recognition的值，为了android、ios返回值一致方便js处理
            NSMutableDictionary * a=[NSMutableDictionary dictionaryWithDictionary:(NSDictionary *)aObj];
            [a setValue:[a objectForKey:@"results_recognition"][0] forKey:@"best_result"];
            
            NSData *data=[NSJSONSerialization dataWithJSONObject:a options:NSJSONWritingPrettyPrinted error:nil];
            NSString *str=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
            NSLog(@"CALLBACK: partial result - %@.\n\n", str);
            
            if (aObj && [aObj isKindOfClass:[NSDictionary class]]) {
                NSDictionary *dict = @{
                                       @"type": @"asrPartialResult",
                                       @"message" :str
                                       };
                
                [self sendEvent:dict];
            }
            break;
        }
        case EVoiceRecognitionClientWorkStatusFinish: {
            NSLog(@"语音校正结果");
            [self printLogTextView:[NSString stringWithFormat:@"CALLBACK: asr finish - %@.\n\n", [self getDescriptionForDic:aObj]]];
            
            if (aObj && [aObj isKindOfClass:[NSDictionary class]]) {
                NSDictionary *dict = @{
                                       @"type": @"asrFinalResult",
                                       @"message" :[self getDescriptionForDic:aObj]
                                       };
                
                [self sendEvent:dict];
            }
            NSDictionary *dict = @{
                                   @"type": @"asrFinish",
                                   @"message": @"ok"
                                   };
            [self sendEvent:dict];
            
            break;
        }
        case EVoiceRecognitionClientWorkStatusMeterLevel: {
            NSLog(@"当前音量回调");
            break;
        }
        case EVoiceRecognitionClientWorkStatusCancel: {
            NSLog(@"识别取消");
            NSDictionary *dict = @{
                                   @"type": @"asrCancel",
                                   @"message": @"ok"
                                   };
            [self sendEvent:dict];
            break;
        }
        case EVoiceRecognitionClientWorkStatusError: {
            NSLog(@"识别发生错误");
            //NSLog(@"");
            [self printLogTextView:[NSString stringWithFormat:@"CALLBACK: encount error - %@.\n", (NSError *)aObj]];
            if (!callbackId) return;
            
            NSDictionary *dict = @{
                                @"type": @"asrError",
                                @"message": @"语音识别错误"
                                };
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:dict];
            [self.commandDelegate sendPluginResult:result callbackId:callbackId];
            break;
        }
        case EVoiceRecognitionClientWorkStatusLoaded: {
            NSLog(@"离线引擎加载");
            [self printLogTextView:@"CALLBACK: offline engine loaded.\n"];
            break;
        }
        case EVoiceRecognitionClientWorkStatusUnLoaded: {
            NSLog(@"离线引擎卸载");
            [self printLogTextView:@"CALLBACK: offline engine unLoaded.\n"];
            break;
        }
        case EVoiceRecognitionClientWorkStatusChunkThirdData: {
            [self printLogTextView:[NSString stringWithFormat:@"CALLBACK: 识别结果中的第三方数据: %lu\n", (unsigned long)[(NSData *)aObj length]]];
            break;
        }
        case EVoiceRecognitionClientWorkStatusChunkNlu: {
            NSString *nlu = [[NSString alloc] initWithData:(NSData *)aObj encoding:NSUTF8StringEncoding];
            [self printLogTextView:[NSString stringWithFormat:@"CALLBACK: 识别结果中的语义结果: %@\n", nlu]];
            NSLog(@"%@", nlu);
            NSDictionary *dict = @{
                                       @"type": @"asrNluResult",
                                       @"message" :nlu
                                       };
                
            [self sendEvent:dict];
            
            break;
        }
        case EVoiceRecognitionClientWorkStatusChunkEnd: {
            [self printLogTextView:[NSString stringWithFormat:@"CALLBACK: Chunk end, sn: %@.\n", aObj]];
            
            break;
        }
        case EVoiceRecognitionClientWorkStatusFeedback: {
            NSDictionary *logDic = [self parseLogToDic:aObj];
            [self printLogTextView:[NSString stringWithFormat:@"CALLBACK 识别过程反馈的打点数据: %@\n", logDic]];
            break;
        }
        case EVoiceRecognitionClientWorkStatusRecorderEnd: {
            [self printLogTextView:@"CALLBACK: 录音机关闭.\n"];
            break;
        }
        case EVoiceRecognitionClientWorkStatusLongSpeechEnd: {
            [self printLogTextView:@"CALLBACK: 长语音结束状态.\n"];
            break;
        }
        default:
        break;
    }
}

#pragma mark - 语音合成回调
- (void)synthesizerStartWorkingSentence:(NSInteger)SynthesizeSentence{
    NSLog(@"开始合成新的语句，语句对应的ID %ld", SynthesizeSentence);
    
}

- (void)synthesizerFinishWorkingSentence:(NSInteger)SynthesizeSentence{
    NSLog(@"合成结束，语句对应的ID： %ld", SynthesizeSentence);
}

- (void)synthesizerSpeechStartSentence:(NSInteger)SpeakSentence{
    NSLog(@"播放开始，语句对应的ID： %ld", SpeakSentence);
}

- (void)synthesizerSpeechEndSentence:(NSInteger)SpeakSentence{
    NSLog(@"播放完成，语句对应的ID： %ld", SpeakSentence);
    //播放结束
    if(SpeakSentence==sentenceID){
        [BDSSpeechSynthesizer releaseInstance];
        NSLog(@"释放语音合成实例");
        NSDictionary *dict = @{
                                @"type": @"ttsfinish",
                                @"message": @"语音朗读完成"
                                };
        [self sendEvent:dict];
    }
    
}

- (void)synthesizerNewDataArrived:(NSData *)newData
                       DataFormat:(BDSAudioFormat)fmt
                   characterCount:(int)newLength
                   sentenceNumber:(NSInteger)SynthesizeSentence{
}

- (void)synthesizerTextSpeakLengthChanged:(int)newLength
                           sentenceNumber:(NSInteger)SpeakSentence{
    NSLog(@"SpeakLen %ld, %d", SpeakSentence, newLength);
}

- (void)synthesizerdidPause{
}

- (void)synthesizerResumed{
    NSLog(@"Did resume");
}

- (void)synthesizerCanceled{
    NSLog(@"Did cancel");
    [BDSSpeechSynthesizer releaseInstance];
    NSLog(@"释放语音合成实例");
}

- (void)synthesizerErrorOccurred:(NSError *)error
                        speaking:(NSInteger)SpeakSentence
                    synthesizing:(NSInteger)SynthesizeSentence{
    NSLog(@"合成和播放过程中出错，语句对应的ID： %ld, %ld", SpeakSentence, SynthesizeSentence);
    [[BDSSpeechSynthesizer sharedInstance] cancel];
}



@end

