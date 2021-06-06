package org.apache.cordova.baiduasrtts;

import android.Manifest;
import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.media.AudioManager;
import android.util.Log;
import android.widget.Toast;
import com.baidu.speech.EventListener;
import com.baidu.speech.EventManager;
import com.baidu.speech.EventManagerFactory;
import com.baidu.speech.asr.SpeechConstant;
import com.baidu.tts.client.SpeechError;
import com.baidu.tts.client.SpeechSynthesizer;
import com.baidu.tts.client.SpeechSynthesizerListener;
import com.baidu.tts.client.TtsMode;
import com.cordova.ifapp.R;
import org.apache.cordova.*;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;


/**
 * This class echoes a string called from JavaScript.
 */
public class Baiduasrtts extends CordovaPlugin {
    SpeechSynthesizer mSpeechSynthesizer;
    private CallbackContext bleCallbackContext = null;
    AudioManager mAudioManager;
    private EventManager wakeup;
    private EventManager asr;
    private static CallbackContext pushCallback;
    private String permission = Manifest.permission.RECORD_AUDIO;
    private String speech_APP_ID;
    private String speech_API_KEY;
    private String speech_SECRET_KEY;
    private String utteranceId;
    public static final String TAG = "Baiduasrtts";


    private Context getApplicationContext() {
        return this.cordova.getActivity().getApplicationContext();
    }

    protected void getMicPermission(int requestCode) {
        PermissionHelper.requestPermission(this, requestCode, permission);
    }


    @Override
    public void onRequestPermissionResult(int requestCode, String[] permissions,
                                          int[] grantResults) throws JSONException {
        for (int r : grantResults) {
            if (r == PackageManager.PERMISSION_DENIED) {
                Toast.makeText(getApplicationContext(), "用户未授权使用麦克风", Toast.LENGTH_LONG).show();
                return;
            }
        }
        promptForRecord();
        //        startSpeechRecognize();
    }

    @Override
    public void onPause(boolean multitasking) {
        super.onPause(multitasking);
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        if(wakeup!= null) {
            wakeup.send(SpeechConstant.WAKEUP_STOP, null, null, 0, 0);
            wakeup.unregisterListener(wpListener);
            wakeup = null;
        }
        if (asr != null) {
            asr.send(SpeechConstant.ASR_STOP, null, null, 0, 0);
            // 必须与registerListener成对出现，否则可能造成内存泄露
            asr.unregisterListener(asrListener);
            asr = null;
        }
    }

    /**
     * Called after plugin construction and fields have been initialized. Prefer to
     * use pluginInitialize instead since there is no value in having parameters on
     * the initialize() function.
     *
     * @param cordova
     * @param webView
     */
    @Override
    public void initialize(CordovaInterface cordova, CordovaWebView webView) {
        Log.e(TAG, "语音唤醒/识别初始化..." );
        super.initialize(cordova, webView);
        Context context = this.cordova.getActivity().getApplicationContext();
        mAudioManager = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
        ApplicationInfo applicationInfo = null;
        try {
            applicationInfo = context.getPackageManager().getApplicationInfo(context.getPackageName(),
                    PackageManager.GET_META_DATA);

        } catch (PackageManager.NameNotFoundException e) {
            e.printStackTrace();
        }
        speech_APP_ID =  (applicationInfo.metaData.get("com.baidu.speech.APP_ID")).toString();
        speech_API_KEY =  (applicationInfo.metaData.get("com.baidu.speech.API_KEY")).toString();
        speech_SECRET_KEY =  (applicationInfo.metaData.get("com.baidu.speech.SECRET_KEY")).toString();
        initWp();
        initAsr();
//        initTts();

    }

    public void initWp(){
        wakeup = EventManagerFactory.create(getApplicationContext(), "wp");
        wakeup.registerListener(wpListener);

    }
    public void initAsr(){
        asr = EventManagerFactory.create(getApplicationContext(), "asr");
        asr.registerListener(asrListener);

    }
    public void initTts(){
        // 初始化TTS
        mSpeechSynthesizer = SpeechSynthesizer.getInstance();
        mSpeechSynthesizer.setContext(webView.getContext());
        mSpeechSynthesizer.setSpeechSynthesizerListener(speechSynthesizerListener);



        mSpeechSynthesizer.setAppId(speech_APP_ID);
        mSpeechSynthesizer.setApiKey(speech_API_KEY,speech_SECRET_KEY);

        // mSpeechSynthesizer.setAppId("24199891");
        // mSpeechSynthesizer.setApiKey("eD1sKZD8LSeQr3N2DFvG4Rz0","OZXu3V2I3xZgPIfAQn48yItKteNGfjHY");
        // 5. 以下setParam 参数选填。不填写则默认值生效
        // 设置在线发声音人： 0 普通女声（默认） 1 普通男声 2 特别男声 3 情感男声<度逍遥> 4 情感儿童声<度丫丫>
        mSpeechSynthesizer.setParam(SpeechSynthesizer.PARAM_SPEAKER, "4");
        // 设置合成的音量，0-9 ，默认 5
        mSpeechSynthesizer.setParam(SpeechSynthesizer.PARAM_VOLUME, "9");
        // 设置合成的语速，0-9 ，默认 5
        mSpeechSynthesizer.setParam(SpeechSynthesizer.PARAM_SPEED, "5");
        // 设置合成的语调，0-9 ，默认 5
        mSpeechSynthesizer.setParam(SpeechSynthesizer.PARAM_PITCH, "5");
        mSpeechSynthesizer.setParam(SpeechSynthesizer.PARAM_MIX_MODE, SpeechSynthesizer.MIX_MODE_HIGH_SPEED_NETWORK);
        int result = mSpeechSynthesizer.initTts(TtsMode.ONLINE);
        LOG.e(TAG, "result="+result);

    }
    @Override
    public boolean execute(String action, CordovaArgs args, final CallbackContext callbackContext) throws JSONException {

        Log.e(TAG, "开始执行。。。 " + action);

        if ("wakeup".equals(action)) {
            cordova.getThreadPool().execute(() -> {
                    Log.i("wakeup","唤醒开始了");
                    promptForRecord();
                    callbackContext.sendPluginResult( new PluginResult(PluginResult.Status.OK,"wakeup") );
            });
        }
        else if("sleep".equals(action)){
            cordova.getThreadPool().execute(() -> {
                    Log.i("wakeup","唤醒停止了");
                    wakeup.send(SpeechConstant.WAKEUP_STOP, null, null, 0, 0);
                    callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK,"sleep"));
            });

        }
        else if ("startSpeechRecognize".equals(action)) {
            cordova.getThreadPool().execute(() -> {
                    boolean flag = startSpeechRecognize();
                    if(flag){
                        System.out.println("开始语音识别成功");
                        callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK,"startSpeechRecognize"));
                    }else{
                        System.out.println("开始语音识别失败，没有权限");
                        callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.ERROR,"startSpeechRecognize"));
                    }

            });
        } else if ("closeSpeechRecognize".equals(action)) {
            // 停止录音
            cordova.getThreadPool().execute(() -> {
                asr.send(SpeechConstant.ASR_STOP, null, null, 0, 0);
                callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK,"closeSpeechRecognize"));
            });

        } else if ("cancelSpeechRecognize".equals(action)) {
            cordova.getThreadPool().execute(() -> {
                if (asr != null) {
                    asr.send(SpeechConstant.ASR_CANCEL, "{}", null, 0, 0);
                }
                callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK,"cancelSpeechRecognize"));
            });
        } else if ("addEventListener".equals(action)) {
            cordova.getThreadPool().execute(() -> {
                pushCallback = callbackContext;
                addEventListenerCallback(callbackContext);
            });
        }
        else if ("synthesizeSpeech".equals(action)) {
            initTts();
            String speech_text = args.getString(0);
            Log.e(TAG, "要播报的文字长度：  " + speech_text.length());
            Log.e(TAG, "要播报的文字：  " + speech_text);
            if(speech_text.length()<60){
                utteranceId ="0";
                mSpeechSynthesizer.speak(speech_text,utteranceId);
            }else{
                speakLongStr(speech_text,60);
            }

            callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK,"synthesizeSpeech"));
        }
        else if ("stopSpeak".equals(action)) {

            int res = mSpeechSynthesizer.stop();
            Log.e(TAG, "停止语音播报 : " + res);
            //释放实例
            int result = mSpeechSynthesizer.release();
            callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK,"stopSpeak"));
        }
        else if ("initTTSconfig".equals(action)) {
            //插件初始化时已经初始化tts，因为SpeechSynthesizer的setContext方法需要参数，初始化方法有
        }
        else {
            Log.e(TAG, "无当前命令： Invalid action : " + action);
            callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.INVALID_ACTION));
            return false;
        }

        return true;
    }




    private void promptForRecord() {
        if (PermissionHelper.hasPermission(this, permission)) {
            Log.i(TAG,"开启唤醒");
            Map<String, Object> params = new LinkedHashMap<String, Object>();
            params.put(SpeechConstant.APP_ID, speech_APP_ID);
            params.put(SpeechConstant.ACCEPT_AUDIO_VOLUME, false);
            params.put(SpeechConstant.WP_WORDS_FILE, "assets://WakeUp.bin");
            String json = null; // 这里可以替换成你需要测试的json
            json = new JSONObject(params).toString();
            Log.i(TAG,json.toString());
            wakeup.send(SpeechConstant.WAKEUP_START, json, null, 0, 0);
        } else {
            getMicPermission(0);
        }

    }

    private boolean startSpeechRecognize() {

        if (PermissionHelper.hasPermission(this, permission)) {

            Map<String, Object> params = new LinkedHashMap<String, Object>();
            String event = SpeechConstant.ASR_START; // 替换成测试的event

            params.put(SpeechConstant.ACCEPT_AUDIO_VOLUME, false);
            params.put(SpeechConstant.SOUND_START, R.raw.bdspeech_recognition_start);
            params.put(SpeechConstant.SOUND_END, R.raw.bdspeech_speech_end);
            params.put(SpeechConstant.SOUND_SUCCESS, R.raw.bdspeech_recognition_success);
            params.put(SpeechConstant.SOUND_ERROR, R.raw.bdspeech_recognition_error);
            params.put(SpeechConstant.SOUND_CANCEL, R.raw.bdspeech_recognition_cancel);
            // params.put(SpeechConstant.NLU, "enable");
            // params.put(SpeechConstant.VAD_ENDPOINT_TIMEOUT, 0); // 长语音
            // params.put(SpeechConstant.IN_FILE, "res:///com/baidu/android/voicedemo/16k_test.pcm");
            // params.put(SpeechConstant.VAD, SpeechConstant.VAD_DNN);
            // params.put(SpeechConstant.PROP ,20000);

            params.put(SpeechConstant.PID, 1537); // 中文输入法模型，有逗号
            params.put(SpeechConstant.DISABLE_PUNCTUATION, true); // 默认false=不禁用标点

            // 请先使用如‘在线识别’界面测试和生成识别参数。 params同ActivityRecog类中myRecognizer.start(params);
            String json = new JSONObject(params).toString(); // 这里可以替换成你需要测试的json
            asr.send(event, json, null, 0, 0);
            return true;
        } else {
            getMicPermission(0);
            return false;
        }

    }

    private void addEventListenerCallback(CallbackContext callbackContext) {

        PluginResult result = new PluginResult(PluginResult.Status.NO_RESULT);
        result.setKeepCallback(true);
        callbackContext.sendPluginResult(result);

    }
    EventListener wpListener = new EventListener() {
        @Override
        public void onEvent(String name, String params, byte [] data, int offset, int length) {
            Log.i(TAG,"语音唤醒的事件");
            Log.i(TAG,"name="+name);
            Log.i(TAG,"params="+params);
            //唤醒成功
            if(name.equals("wp.data")){
                try {
                    JSONObject json = new JSONObject(params);
                    int errorCode = json.getInt("errorCode");
                    if(errorCode == 0){
                        //唤醒成功
                        sendEvent("wakeup",json.toString());
                        Log.i(TAG,"语音唤醒成功");
                    } else {
                        //唤醒失败
                        sendError("fail",json.toString());
                        Log.i(TAG,"语音唤醒失败");
                    }
                } catch (JSONException e) {
                    //唤醒失败
                    sendError("fail",e.getMessage());
                    Log.i(TAG,"语音唤醒失败");
                    e.printStackTrace();
                }
            }
            if("wp.exit".equals(name)){
                //唤醒已停止
                sendEvent("sleep",params);
                Log.i(TAG,"语音唤醒停止");
            }
            if("wp.error".equals(name)){
                sendError("error",params);
                Log.i(TAG,params);
            }
        }
    };
    EventListener asrListener = new EventListener() {
        @Override
        public void onEvent(String name, String params, byte [] data, int offset, int length) {
            Log.i(TAG,"语音识别的事件");
            Log.i(TAG,"name="+name);
            Log.i(TAG,"params="+params);
            if (name.equals(SpeechConstant.CALLBACK_EVENT_ASR_READY)) {
                // 引擎就绪，可以说话，一般在收到此事件后通过UI通知用户可以说话了
                sendEvent("asrReady", "ok");
            }

            if (name.equals(SpeechConstant.CALLBACK_EVENT_ASR_BEGIN)) {
                // 检测到说话开始
                sendEvent("asrBegin", "ok");
            }

            if (name.equals(SpeechConstant.CALLBACK_EVENT_ASR_END)) {
                // 检测到说话结束
                sendEvent("asrEnd", "ok");
            }

            if (name.equals(SpeechConstant.CALLBACK_EVENT_ASR_FINISH)) {
                // 识别结束（可能含有错误信息）
                try {
                    JSONObject jsonObject = new JSONObject(params);
                    int errCode = jsonObject.getInt("error");

                    if (errCode != 0) {
                        sendError("asrError","语音识别错误");
                    } else {
                        sendEvent("asrFinish", "ok");
                    }

                } catch (JSONException e) {
                    Log.i(TAG, e.getMessage());
                }


            }

            if (name.equals(SpeechConstant.CALLBACK_EVENT_ASR_PARTIAL)) {
                try {
                    JSONObject p = new JSONObject(params);
                    String result_type = p.getString("result_type");
                    if(result_type.equals("partial_result")){
                        // 实时识别结果
                        sendEvent("asrPartialResult", p.toString());
                    }
                    if(result_type.equals("final_result")){
                        // 语音校正结果
                        sendEvent("asrFinalResult", p.toString());
                    }

                } catch (JSONException e) {
                    e.printStackTrace();
                }

            }

            if (name.equals(SpeechConstant.CALLBACK_EVENT_ASR_CANCEL)) {
                sendEvent("asrCancel", "ok");
            }
        }
    };
    SpeechSynthesizerListener speechSynthesizerListener = new SpeechSynthesizerListener() {
        @Override
        public void onSynthesizeStart(String s) {
            Log.i(TAG, "开始合成新的语句，语句对应的ID：" + s);
        }
        @Override
        public void onSynthesizeDataArrived(String s, byte[] bytes, int i) {
            Log.i(TAG, "合成过程中的数据回调接口：" + s);
        }
        @Override
        public void onSynthesizeFinish(String s) {
            Log.i(TAG, "合成结束，语句对应的ID：" + s);
        }
        @Override
        public void onSpeechStart(String s) {
            Log.i(TAG, "播放开始，语句对应的ID：" + s);
        }
        @Override
        public void onSpeechProgressChanged(String s, int i) {
            Log.i(TAG, "播放过程中的回调，语句对应的ID：" + s);
        }
        @Override
        public void onSpeechFinish(String s) {
            Log.i(TAG, "播放完成，语句对应的ID：" + s);
            //播放结束
            if(s.equals(utteranceId)){
                //释放实例
                int result = mSpeechSynthesizer.release();
                sendEvent("ttsfinish", "语音朗读完成");
            }

        }
        @Override
        public void onError(String s, SpeechError speechError) {
            //合成和播放过程中出错时的回调
            Log.i(TAG, "合成和播放过程中出错，语句对应的ID：" + s+"，错误信息："+speechError);
        }
    };



    private void sendEvent(String type, String msg) {
        JSONObject response = new JSONObject();
        try {
            response.put("type", type);
            response.put("message", msg);

            final PluginResult pluginResult = new PluginResult(PluginResult.Status.OK, response);
            pluginResult.setKeepCallback(true);
            if (pushCallback != null) {
                pushCallback.sendPluginResult(pluginResult);
            }

        } catch (JSONException e) {
            Log.i(TAG, e.getMessage());
        }
    }

    private void sendError(String type,String message) {
        JSONObject err = new JSONObject();
        try {
            err.put("type", type);
            err.put("message", message);

            PluginResult pluginResult = new PluginResult(PluginResult.Status.ERROR, err);
            pluginResult.setKeepCallback(true);
            if (pushCallback != null) {
                pushCallback.sendPluginResult(pluginResult);
            }

        } catch (JSONException e) {
            Log.i(TAG, e.getMessage());
        }


    }
    /**
     * 播报长字符串
     *
     * @param inputString
     *            原始字符串
     * @param length
     *            指定长度
     * @return
     */
    public void speakLongStr(String inputString, int length) {
        int size = inputString.length() / length;
        if (inputString.length() % length != 0) {
            size += 1;
        }
        speakStr(inputString, length, size);
    }
    /**
     * 把原始字符串分割成指定长度的字符串播放
     *
     * @param inputString
     *            原始字符串
     * @param length
     *            指定长度
     * @param size
     *            指定列表大小
     * @return
     */
    public void speakStr(String inputString, int length,
                                          int size) {
        for (int index = 0; index < size; index++) {
            String childStr = substring(inputString, index * length,
                    (index + 1) * length);
            utteranceId =""+index;
            mSpeechSynthesizer.speak(childStr,utteranceId);
        }
    }
    /**
     * 分割字符串，如果开始位置大于字符串长度，返回空
     *
     * @param str
     *            原始字符串
     * @param f
     *            开始位置
     * @param t
     *            结束位置
     * @return
     */
    public String substring(String str, int f, int t) {
        if (f > str.length()) {
            return null;
        }
        if (t > str.length()) {
            return str.substring(f, str.length());
        } else {
            return str.substring(f, t);
        }
    }
    private void registerNotifyCallback(CallbackContext callbackContext) {

        PluginResult result = new PluginResult(PluginResult.Status.NO_RESULT);
        result.setKeepCallback(true);
        callbackContext.sendPluginResult(result);

    }


}