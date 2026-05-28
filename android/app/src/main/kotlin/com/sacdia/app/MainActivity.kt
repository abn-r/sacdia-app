package com.sacdia.app

import android.media.AudioAttributes
import android.media.MediaPlayer
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val audioChannelName = "sacdia/audio_player"
    private var mediaPlayer: MediaPlayer? = null
    private var isPrepared = false
    private var pendingPlayResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            audioChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "playUrl" -> {
                    val url = call.argument<String>("url")
                    if (url.isNullOrBlank()) {
                        result.error("invalid_url", "Invalid audio URL", null)
                    } else {
                        playUrl(url, result)
                    }
                }
                "pause" -> {
                    if (isPrepared == true) mediaPlayer?.pause()
                    result.success(null)
                }
                "resume" -> {
                    if (isPrepared == true) mediaPlayer?.start()
                    result.success(null)
                }
                "stop" -> {
                    releasePlayer()
                    result.success(null)
                }
                "position" -> {
                    result.success(
                        mapOf(
                            "positionMs" to if (isPrepared == true) (mediaPlayer?.currentPosition ?: 0) else 0,
                            "durationMs" to if (isPrepared == true) (mediaPlayer?.duration ?: 0) else 0,
                            "isPlaying" to (mediaPlayer?.isPlaying ?: false),
                        ),
                    )
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        releasePlayer()
        super.onDestroy()
    }

    private fun playUrl(url: String, result: MethodChannel.Result) {
        releasePlayer()
        pendingPlayResult = result

        try {
            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .build(),
                )
                setDataSource(url)
                setOnPreparedListener {
                    isPrepared = true
                    it.start()
                    pendingPlayResult?.success(null)
                    pendingPlayResult = null
                }
                setOnErrorListener { _, what, extra ->
                    isPrepared = false
                    pendingPlayResult?.error(
                        "audio_playback",
                        "Audio playback failed",
                        mapOf("what" to what, "extra" to extra),
                    )
                    pendingPlayResult = null
                    true
                }
                prepareAsync()
            }
        } catch (error: Exception) {
            pendingPlayResult = null
            result.error("audio_playback", error.message, null)
        }
    }

    private fun releasePlayer() {
        isPrepared = false
        pendingPlayResult = null
        mediaPlayer?.release()
        mediaPlayer = null
    }
}
