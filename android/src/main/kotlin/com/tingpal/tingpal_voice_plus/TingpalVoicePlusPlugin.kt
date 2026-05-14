package com.tingpal.tingpal_voice_plus

import android.content.Context
import android.os.Bundle
import android.os.Environment
import android.util.Log
import com.iflytek.cloud.ErrorCode
import com.iflytek.cloud.InitListener
import com.iflytek.cloud.RecognizerListener
import com.iflytek.cloud.RecognizerResult
import com.iflytek.cloud.Setting
import com.iflytek.cloud.SpeechConstant
import com.iflytek.cloud.SpeechError
import com.iflytek.cloud.SpeechRecognizer
import com.iflytek.cloud.SpeechUtility
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class TingpalVoicePlusPlugin :
    FlutterPlugin,
    MethodCallHandler,
    EventChannel.StreamHandler {
    private val tag: String = TingpalVoicePlusPlugin::class.java.simpleName

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private var applicationContext: Context? = null

    private var appIdAndroid: String? = null
    private var voiceOptions: Map<String, Any?> = emptyMap()
    private var recognizer: SpeechRecognizer? = null
    private var audioFilePath: String = ""

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = flutterPluginBinding.applicationContext
        methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "tingpal_voice_plus")
        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "tingpal_voice_plus/events")
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        when (call.method) {
            "init" -> {
                val args = call.arguments as? Map<*, *>
                appIdAndroid = args?.get("appIdAndroid") as? String
                initRecognizer(appIdAndroid)
                result.success(null)
            }

            "setOptions" -> {
                @Suppress("UNCHECKED_CAST")
                voiceOptions = (call.arguments as? Map<String, Any?>) ?: emptyMap()
                applyOptions(voiceOptions)
                result.success(null)
            }

            "startListening" -> {
                if (recognizer == null) {
                    result.error("NOT_INITIALIZED", "Recognizer is null. Call init first.", null)
                    return
                }
                val code = recognizer?.startListening(recognizerListener) ?: ErrorCode.ERROR_UNKNOWN
                if (code != ErrorCode.SUCCESS) {
                    result.error("START_FAILED", "startListening failed with code=$code", null)
                    return
                }
                result.success(null)
            }

            "stopListening" -> {
                recognizer?.stopListening()
                result.success(null)
            }

            "cancelListening" -> {
                recognizer?.cancel()
                emitEvent("onCancel", emptyMap<String, Any>())
                result.success(null)
            }

            "disposeClient" -> {
                recognizer?.cancel()
                recognizer?.destroy()
                recognizer = null
                appIdAndroid = null
                voiceOptions = emptyMap()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        eventSink = null
        recognizer?.cancel()
        recognizer?.destroy()
        recognizer = null
        applicationContext = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private fun emitEvent(eventName: String, payload: Map<String, Any>) {
        val eventMap = payload.toMutableMap()
        eventMap["event"] = eventName
        eventSink?.success(eventMap)
    }

    private val recognizerListener: RecognizerListener = object : RecognizerListener {
        override fun onBeginOfSpeech() {
            emitEvent("onBeginOfSpeech", emptyMap<String, Any>())
        }

        override fun onError(error: SpeechError?) {
            val errorInfo = mutableMapOf<String, Any>()
            if (error != null) {
                errorInfo["code"] = error.errorCode
                errorInfo["desc"] = error.errorDescription
            }
            emitEvent(
                "onCompleted",
                mapOf(
                    "error" to errorInfo,
                    "audioFilePath" to audioFilePath,
                ),
            )
        }

        override fun onEndOfSpeech() {
            emitEvent("onEndOfSpeech", emptyMap<String, Any>())
        }

        override fun onResult(results: RecognizerResult?, isLast: Boolean) {
            emitEvent(
                "onResults",
                mapOf(
                    "result" to (results?.resultString ?: ""),
                    "isLast" to isLast,
                ),
            )

            if (isLast) {
                emitEvent(
                    "onCompleted",
                    mapOf(
                        "error" to emptyMap<String, Any>(),
                        "audioFilePath" to audioFilePath,
                    ),
                )
            }
        }

        override fun onVolumeChanged(volume: Int, data: ByteArray?) {
            emitEvent("onVolumeChanged", mapOf("volume" to volume))
        }

        override fun onEvent(eventType: Int, arg1: Int, arg2: Int, obj: Bundle?) {
            // No-op
        }
    }

    private fun initRecognizer(appId: String?) {
        val context = applicationContext ?: return
        if (appId.isNullOrBlank()) {
            Log.e(tag, "appIdAndroid is empty")
            return
        }

        SpeechUtility.createUtility(context, "${SpeechConstant.APPID}=$appId")
        Setting.setLocationEnable(false)

        recognizer = SpeechRecognizer.createRecognizer(context, InitListener { code ->
            if (code != ErrorCode.SUCCESS) {
                Log.e(tag, "createRecognizer failed, code=$code")
            }
        })
    }

    private fun applyOptions(options: Map<String, Any?>) {
        val localRecognizer = recognizer ?: return

        for ((key, rawValue) in options) {
            val value = rawValue?.toString() ?: continue
            if (key == SpeechConstant.ASR_AUDIO_PATH || key == "asr_audio_path") {
                val path = Environment.getExternalStorageDirectory().path + "/msc/$value"
                audioFilePath = path
                localRecognizer.setParameter(SpeechConstant.ASR_AUDIO_PATH, path)
            } else {
                localRecognizer.setParameter(key, value)
            }
        }
    }
}
