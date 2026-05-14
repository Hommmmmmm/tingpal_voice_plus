#import "TingpalVoicePlusPlugin.h"
#import <iflyMSC/iflyMSC.h>

@interface TingpalVoicePlusPlugin () <FlutterStreamHandler, IFlySpeechRecognizerDelegate>

@property (nonatomic, strong) FlutterEventSink eventSink;
@property (nonatomic, strong) NSString *cachedResult;

@end

@implementation TingpalVoicePlusPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel *methodChannel = [FlutterMethodChannel
                                         methodChannelWithName:@"tingpal_voice_plus"
                                         binaryMessenger:[registrar messenger]];
  FlutterEventChannel *eventChannel = [FlutterEventChannel
                                       eventChannelWithName:@"tingpal_voice_plus/events"
                                       binaryMessenger:[registrar messenger]];

  TingpalVoicePlusPlugin *instance = [[TingpalVoicePlusPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:methodChannel];
  [eventChannel setStreamHandler:instance];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([@"init" isEqualToString:call.method]) {
    NSDictionary *args = (NSDictionary *)call.arguments;
    NSString *appIdIos = args[@"appIdIos"];
    [self initializeRecognizer:appIdIos];
    result(nil);
  } else if ([@"setOptions" isEqualToString:call.method]) {
    [self applyOptions:(NSDictionary *)call.arguments];
    result(nil);
  } else if ([@"startListening" isEqualToString:call.method]) {
    if ([[IFlySpeechRecognizer sharedInstance] isListening]) {
      result(nil);
      return;
    }
    self.cachedResult = nil;
    [[IFlySpeechRecognizer sharedInstance] startListening];
    result(nil);
  } else if ([@"stopListening" isEqualToString:call.method]) {
    [[IFlySpeechRecognizer sharedInstance] stopListening];
    result(nil);
  } else if ([@"cancelListening" isEqualToString:call.method]) {
    [[IFlySpeechRecognizer sharedInstance] cancel];
    [self emitEvent:@"onCancel" payload:@{}];
    result(nil);
  } else if ([@"disposeClient" isEqualToString:call.method]) {
    [[IFlySpeechRecognizer sharedInstance] cancel];
    result(nil);
  } else {
    result(FlutterMethodNotImplemented);
  }
}

- (FlutterError *)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)events {
  self.eventSink = events;
  return nil;
}

- (FlutterError *)onCancelWithArguments:(id)arguments {
  self.eventSink = nil;
  return nil;
}

- (void)initializeRecognizer:(NSString *)appId {
  if (appId.length == 0) {
    return;
  }
  NSString *initString = [NSString stringWithFormat:@"appid=%@", appId];
  [IFlySpeechUtility createUtility:initString];
  [[IFlySpeechRecognizer sharedInstance] setDelegate:self];
  [IFlySetting setLogFile:LVL_NONE];
}

- (void)applyOptions:(NSDictionary *)options {
  [options enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
    NSString *value = [NSString stringWithFormat:@"%@", obj];
    [[IFlySpeechRecognizer sharedInstance] setParameter:value forKey:key];
  }];
}

- (void)emitEvent:(NSString *)event payload:(NSDictionary *)payload {
  if (!self.eventSink) {
    return;
  }
  NSMutableDictionary *eventMap = [NSMutableDictionary dictionaryWithDictionary:payload];
  eventMap[@"event"] = event;
  self.eventSink(eventMap);
}

#pragma mark - IFlySpeechRecognizerDelegate

- (void)onCompleted:(IFlySpeechError *)errorCode {
  NSDictionary *error = @{};
  if (errorCode.errorCode != 0) {
    error = @{
      @"code": @(errorCode.errorCode),
      @"type": @(errorCode.errorType),
      @"desc": errorCode.errorDesc ?: @"",
    };
  }

  NSString *path = [[IFlySpeechRecognizer sharedInstance] parameterForKey:@"asr_audio_path"] ?: @"";
  NSString *filePath = @"";
  if (path.length > 0) {
    NSArray *cachePaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *folder = cachePaths.firstObject ?: @"";
    filePath = [folder stringByAppendingPathComponent:path];
  }

  [self emitEvent:@"onCompleted" payload:@{
    @"error": error,
    @"audioFilePath": filePath,
  }];
}

- (void)onResults:(NSArray *)results isLast:(BOOL)isLast {
  NSString *resultText = @"";
  if (results.count > 0) {
    NSDictionary *dic = [results firstObject];
    resultText = dic.allKeys.firstObject ?: @"";
    self.cachedResult = resultText;
  } else if (self.cachedResult != nil) {
    resultText = self.cachedResult;
  }

  [self emitEvent:@"onResults" payload:@{
    @"result": resultText,
    @"isLast": @(isLast),
  }];
}

- (void)onVolumeChanged:(int)volume {
  [self emitEvent:@"onVolumeChanged" payload:@{ @"volume": @(volume) }];
}

- (void)onBeginOfSpeech {
  [self emitEvent:@"onBeginOfSpeech" payload:@{}];
}

- (void)onEndOfSpeech {
  [self emitEvent:@"onEndOfSpeech" payload:@{}];
}

- (void)onCancel {
  [self emitEvent:@"onCancel" payload:@{}];
}

@end
