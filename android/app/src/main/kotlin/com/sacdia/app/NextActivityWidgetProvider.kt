package com.sacdia.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class NextActivityWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.next_activity_widget).apply {
                val title = widgetData.getString("activity_title", null)
                    ?.takeIf { it.isNotBlank() }
                    ?: context.getString(R.string.next_activity_widget_empty)
                val dateLabel = widgetData.getString("activity_date", null).orEmpty()
                val clubName = widgetData.getString("activity_club", null).orEmpty()
                var weekday = widgetData.getString("activity_weekday", null).orEmpty()
                var day = widgetData.getString("activity_day", null).orEmpty()
                var month = widgetData.getString("activity_month", null).orEmpty()
                var timeLabel = widgetData.getString("activity_time", null).orEmpty()
                val activityId = widgetData.getString("activity_id", null)?.takeIf { it.isNotBlank() }

                if (day.isBlank()) {
                    val legacy = parseLegacyDate(dateLabel)
                    weekday = legacy.weekday
                    day = legacy.day
                    month = legacy.month
                    if (timeLabel.isBlank()) timeLabel = legacy.time
                }

                val plateMeta = listOf(weekday, month)
                    .filter { it.isNotBlank() }
                    .joinToString(" · ")
                val meta = listOf(timeLabel, clubName)
                    .filter { it.isNotBlank() }
                    .joinToString(" · ")
                    .ifBlank { dateLabel }

                setTextViewText(R.id.widget_title, title)
                setTextViewText(R.id.widget_day, day)
                setTextViewText(R.id.widget_when, plateMeta)
                setTextViewText(R.id.widget_meta, meta)
                setViewVisibility(
                    R.id.widget_heading,
                    if (day.isBlank()) View.GONE else View.VISIBLE,
                )
                setViewVisibility(
                    R.id.widget_meta,
                    if (meta.isBlank()) View.GONE else View.VISIBLE,
                )
                setInt(
                    R.id.widget_root,
                    "setBackgroundResource",
                    if (day.isBlank()) {
                        R.drawable.next_activity_widget_quiet
                    } else {
                        R.drawable.next_activity_widget_background
                    },
                )

                val launchUri = activityId?.let {
                    Uri.parse("io.sacdia.app://activity/$it?homeWidget")
                }
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    launchUri,
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

private data class LegacyDate(
    val weekday: String,
    val day: String,
    val month: String,
    val time: String,
)

private fun parseLegacyDate(label: String): LegacyDate {
    val chunks = label.split(" · ")
    val time = chunks.getOrNull(1)?.trim().orEmpty()
    val tokens = chunks.first()
        .split(" ")
        .map { it.trim().trim('.') }
        .filter { it.isNotEmpty() }
    if (tokens.size >= 3 && tokens[1].all { it.isDigit() }) {
        return LegacyDate(
            weekday = tokens[0].uppercase(),
            day = tokens[1],
            month = tokens[2].uppercase(),
            time = time,
        )
    }
    return LegacyDate(weekday = "", day = "", month = "", time = time)
}
