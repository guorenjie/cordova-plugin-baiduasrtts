### 前言
这是一个百度语音唤醒、识别、合成的cordova插件。 
基于[https://gitlab.com/zzl_public/cordova-plugin-baiduasrtts](https://gitlab.com/zzl_public/cordova-plugin-baiduasrtts)修改，添加了语音唤醒和语音识别提示音，语音识别使用短语音识别普通话，语音合成使用基础音库



官网链接：  

[https://ai.baidu.com/ai-doc/SPEECH/Ek39uxgre](https://ai.baidu.com/ai-doc/SPEECH/Ek39uxgre)

支持平台： 

Android
iOS
---
### 安装

在线url安装:  
cordova plugin add
https://github.com/guorenjie/cordova-plugin-baiduasrtts.git --variable APIKEY=[your apikey] --variable SECRETKEY=[your secretkey] --variable APPID=[your appid]

本地安装:  

cordova plugin add local_plugins/cordova-plugin-baiduasrtts --variable APIKEY=[your apikey] --variable SECRETKEY=[your secretkey] --variable APPID=[your appid]


---

### API使用 


```
// 初始化插件，调用一次
Baiduasrtts.initTTSconfig();
// 开启语音唤醒，后面紧跟唤醒的监听
Baiduasrtts.wakeup();
// 语音唤醒事件监听
Baiduasrtts.addEventListener(
    (res) => {
        // res参数都带有一个type
        if (!res) {
            return;
        }
        switch (res.type) {
            case "wakeup": {
                console.debug("百度唤醒成功");
                break;
            }
            case "wakefail": {
                console.debug("百度唤醒失败");
                break;
            }
            case "sleep": {
                console.debug("百度唤醒停止");
                break;
            }
            case "error": {
                console.debug(res);
                break;
            }
            default:
                break;
        }
    },
    (err) => {
        console.debug(err);
    }
);
// 关闭语音唤醒
Baiduasrtts.sleep();

//开始语音识别，回调中添加语音识别监听
Baiduasrtts.startSpeechRecognize(
    "",
    (res) => {
        if(res=='startSpeechRecognize'){
            console.info('开始语音识别的回调');
            console.info(res);
            //语音识别监听
            this.speechRecognizeListener();
        }   
    },
    (err) => {
        console.debug("开始语音识别err");
        console.debug(err);
        this.$Toast("请授予语音识别需要的录音权限");
        this.stopVoice('error');
    }
);
/**
  * 语音识别监听
  */
speechRecognizeListener() {
    // 语音识别事件监听
    Baiduasrtts.addEventListener(
        (res) => {
            // res参数都带有一个type
            if (!res) {
                return;
            }

            switch (res.type) {
                case "asrReady": {
                    // 识别工作开始,开始采集及处理数据
                    break;
                }

                case "asrBegin": {
                    // 检测到用户开始说话
                    break;
                }

                case "asrEnd": {
                    // 本地声音采集结束,等待识别结果返回并结束录音
                    break;
                }

                case "asrText": {
                    break;
                }

                case "asrPartialResult": {
                    //实时识别结果
                    console.debug("语音实时识别结果");
                    console.debug(JSON.parse(res.message));
                    let result = JSON.parse(res.message)[
                        "results_recognition"
                    ][0];

                    break;
                }

                case "asrFinalResult": {
                    //语音校正结果
                    console.debug("语音最终识别结果");
                    console.debug(JSON.parse(res.message));
                    let result = JSON.parse(res.message)[
                        "results_recognition"
                    ][0];
                    break;
                }

                case "asrFinish": {
                    // 语音识别功能完成
                    break;
                }

                case "asrCancel": {
                    // 语音识别取消
                    break;
                }

                default:
                    break;
            }
        },
        (err) => {
            console.debug(err);
        }
    );
}
//取消语音识别
Baiduasrtts.cancelSpeechRecognize();
//关闭语音识别
Baiduasrtts.closeSpeechRecognize();
//开始语音合成，后面紧跟语音合成监听
Baiduasrtts.synthesizeSpeech('要合成的文本'));
// 语音合成事件监听
Baiduasrtts.addEventListener(
    (res) => {
        // res参数都带有一个type
        if (!res) {
            return;
        }
        switch (res.type) {
            case "ttsfinish":
            {
                //tts播放完成
                break;
            }
            default:
                break;
        }
    },
    (err) => {
        console.debug(err);
    }
);
//停止语音合成
Baiduasrtts.stopSpeak();

```

## 注意事项
以下文件太大，需自己去百度官网SDK下载

src\ios\BDSClientLib\ASR\bds_easr_input_model.dat

src\ios\BDSClientLib\ASR\libBaiduSpeechSDK.a
 

src\ios\BDSClientLib\TTS\libBaiduSpeech_TTS_SDK.a

