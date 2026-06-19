package com.boox.dailytodo

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class Task(
    val id: String,
    val title: String,
    val notes: String? = null,
    val done: Boolean = false,
    val memo: Boolean = false,       // true = 备忘录, 不进今日待办
    @SerialName("due_date") val dueDate: String? = null,
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("completed_at") val completedAt: String? = null,
    val category: String? = null,   // 工作 | 运动 | 生活
    @SerialName("work_section") val workSection: String? = null, // 工作: focus | feature
)

@Serializable
data class Goal(
    val id: String,
    val title: String,
    val period: String = "week",    // week | month
    val done: Boolean = false,
)

@Serializable
data class FocusSession(
    val id: String,
    val phase: String = "work",     // work | rest
    val minutes: Int = 0,
    @SerialName("ended_at") val endedAt: String? = null,
)

@Serializable
data class Routine(
    val id: String,
    val name: String,
    val icon: String? = null,
    val weekdays: List<Int> = emptyList(), // ISO weekday: 1=Mon .. 7=Sun
    val active: Boolean = true,
    val category: String? = null,   // 工作 | 运动 | 生活
    @SerialName("created_at") val createdAt: String? = null,
)

@Serializable
data class RoutineLog(
    val id: String? = null,
    @SerialName("routine_id") val routineId: String,
    val date: String,        // YYYY-MM-DD
    val done: Boolean = true,
)

/** Trigger for the completion celebration overlay. effect 0..<N picks the effect. */
data class CelebrationEvent(val id: Int, val effect: Int)
const val CELEBRATION_COUNT = 6

/** One day of forecast (from Open-Meteo). */
data class DayWeather(
    val date: String,      // YYYY-MM-DD
    val code: Int,         // WMO weather code
    val tMax: Int,         // °C  今日最高
    val tMin: Int,         // °C  今日最低
    val precip: Double,    // mm
    val precipProb: Int,   // %
    val currentTemp: Int? = null, // °C 当前温度 (仅今天有)
)
