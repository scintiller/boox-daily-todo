package com.boox.dailytodo

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import kotlinx.serialization.Serializable
import java.time.Instant
import java.util.concurrent.TimeUnit
import kotlin.math.roundToInt

/** Thin Supabase PostgREST client. All calls run on Dispatchers.IO. */
class Repository {

    private val base = BuildConfig.SUPABASE_URL.trimEnd('/') + "/rest/v1/"
    private val key = BuildConfig.SUPABASE_ANON_KEY
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }
    private val media = "application/json".toMediaType()
    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .build()

    private fun request(url: String, method: String, body: RequestBody? = null, prefer: String? = null): Request {
        val b = Request.Builder()
            .url(url)
            .header("apikey", key)
            .header("Authorization", "Bearer $key")
            .header("Accept", "application/json")
        if (prefer != null) b.header("Prefer", prefer)
        b.method(method, body)
        return b.build()
    }

    private fun exec(req: Request): String = client.newCall(req).execute().use { r ->
        val s = r.body?.string() ?: ""
        if (!r.isSuccessful) throw RuntimeException("HTTP ${r.code}: $s")
        s
    }

    suspend fun getTasks(): List<Task> = withContext(Dispatchers.IO) {
        // Pending tasks (done=false, incl. memos) OR anything completed in the last 3 days,
        // so the 已完成 section can show today's / yesterday's checked-off items.
        val cutoff = Instant.now().minusSeconds(3 * 24 * 3600)
        val url = base + "tasks?select=*&or=(done.is.false,completed_at.gte.$cutoff)" +
            "&order=due_date.asc.nullslast,created_at.asc"
        json.decodeFromString(exec(request(url, "GET")))
    }

    suspend fun setTaskDone(id: String, done: Boolean) = withContext(Dispatchers.IO) {
        val url = base + "tasks?id=eq.$id"
        val payload = buildJsonObject {
            put("done", done)
            if (done) put("completed_at", Instant.now().toString()) else put("completed_at", JsonNull)
        }
        exec(request(url, "PATCH", payload.toString().toRequestBody(media), "return=minimal"))
    }

    suspend fun getRoutines(): List<Routine> = withContext(Dispatchers.IO) {
        val url = base + "routines?select=*&active=is.true&order=created_at.asc"
        json.decodeFromString(exec(request(url, "GET")))
    }

    suspend fun getLogsSince(date: String): List<RoutineLog> = withContext(Dispatchers.IO) {
        val url = base + "routine_logs?select=*&date=gte.$date"
        json.decodeFromString(exec(request(url, "GET")))
    }

    suspend fun logRoutine(routineId: String, date: String, done: Boolean) = withContext(Dispatchers.IO) {
        if (done) {
            val url = base + "routine_logs?on_conflict=routine_id,date"
            val payload = buildJsonObject {
                put("routine_id", routineId)
                put("date", date)
                put("done", true)
            }
            exec(request(url, "POST", payload.toString().toRequestBody(media), "resolution=merge-duplicates,return=minimal"))
        } else {
            val url = base + "routine_logs?routine_id=eq.$routineId&date=eq.$date"
            exec(request(url, "DELETE"))
        }
    }

    suspend fun getWeather(): List<DayWeather> = withContext(Dispatchers.IO) {
        // Open-Meteo: free, no API key. Fixed to Gilbert, AZ.
        val url = "https://api.open-meteo.com/v1/forecast" +
            "?latitude=33.3528&longitude=-111.789" +
            "&daily=weather_code,temperature_2m_max,temperature_2m_min," +
            "precipitation_sum,precipitation_probability_max" +
            "&timezone=America%2FPhoenix&forecast_days=3" +
            "&temperature_unit=fahrenheit&precipitation_unit=mm"
        val req = Request.Builder().url(url).header("Accept", "application/json").get().build()
        val d = json.decodeFromString<WeatherResponse>(exec(req)).daily
        d.time.indices.map { i ->
            DayWeather(
                date = d.time[i],
                code = d.weatherCode.getOrElse(i) { 0 },
                tMax = d.tMax.getOrElse(i) { 0.0 }.roundToInt(),
                tMin = d.tMin.getOrElse(i) { 0.0 }.roundToInt(),
                precip = d.precip.getOrElse(i) { 0.0 },
                precipProb = d.precipProb.getOrElse(i) { null } ?: 0,
            )
        }
    }
}

@Serializable
private data class WeatherResponse(val daily: WeatherDaily)

@Serializable
private data class WeatherDaily(
    val time: List<String> = emptyList(),
    @kotlinx.serialization.SerialName("weather_code") val weatherCode: List<Int> = emptyList(),
    @kotlinx.serialization.SerialName("temperature_2m_max") val tMax: List<Double> = emptyList(),
    @kotlinx.serialization.SerialName("temperature_2m_min") val tMin: List<Double> = emptyList(),
    @kotlinx.serialization.SerialName("precipitation_sum") val precip: List<Double> = emptyList(),
    @kotlinx.serialization.SerialName("precipitation_probability_max") val precipProb: List<Int?> = emptyList(),
)
