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
import java.time.Instant
import java.util.concurrent.TimeUnit

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
        val url = base + "tasks?select=*&done=is.false&order=due_date.asc.nullslast,created_at.asc"
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
}
