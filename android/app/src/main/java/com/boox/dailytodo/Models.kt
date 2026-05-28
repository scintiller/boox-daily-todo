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

/** One day of forecast (from Open-Meteo). */
data class DayWeather(
    val date: String,      // YYYY-MM-DD
    val code: Int,         // WMO weather code
    val tMax: Int,         // °C
    val tMin: Int,         // °C
    val precip: Double,    // mm
    val precipProb: Int,   // %
)
