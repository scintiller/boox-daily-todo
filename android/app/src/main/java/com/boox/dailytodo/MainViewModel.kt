package com.boox.dailytodo

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.LocalDate

class MainViewModel : ViewModel() {

    private val repo = Repository()

    var tasks by mutableStateOf<List<Task>>(emptyList())
        private set
    var routines by mutableStateOf<List<Routine>>(emptyList())
        private set
    var logs by mutableStateOf<List<RoutineLog>>(emptyList())
        private set
    var goals by mutableStateOf<List<Goal>>(emptyList())
        private set
    var focusSessions by mutableStateOf<List<FocusSession>>(emptyList())
        private set
    var weather by mutableStateOf<List<DayWeather>>(emptyList())
        private set
    var loading by mutableStateOf(false)
        private set
    var error by mutableStateOf<String?>(null)
        private set

    init {
        refresh()
        viewModelScope.launch {
            while (true) {
                delay(60_000)
                refresh()
            }
        }
    }

    fun refresh() {
        viewModelScope.launch {
            loading = true
            error = null
            try {
                val since = LocalDate.now().minusWeeks(8).toString()
                tasks = repo.getTasks()
                routines = repo.getRoutines()
                logs = repo.getLogsSince(since)
                goals = repo.getGoals()
                focusSessions = repo.getFocusSessions()
            } catch (e: Exception) {
                error = e.message ?: "网络错误"
            } finally {
                loading = false
            }
        }
        // Weather fetched separately so a weather hiccup never blanks the tasks.
        viewModelScope.launch {
            try {
                weather = repo.getWeather()
            } catch (_: Exception) { /* ignore weather errors */ }
        }
    }

    fun toggleTask(t: Task) {
        viewModelScope.launch {
            try {
                repo.setTaskDone(t.id, !t.done)
                refresh()
            } catch (e: Exception) {
                error = e.message ?: "操作失败"
            }
        }
    }

    fun toggleGoal(g: Goal) {
        viewModelScope.launch {
            try { repo.setGoalDone(g.id, !g.done); refresh() }
            catch (e: Exception) { error = e.message ?: "操作失败" }
        }
    }

    fun setTaskSection(t: Task, section: String) {
        viewModelScope.launch {
            try { repo.setTaskSection(t.id, section); refresh() }
            catch (e: Exception) { error = e.message ?: "操作失败" }
        }
    }

    fun moveToMemo(t: Task) {
        viewModelScope.launch {
            try { repo.setTaskMemo(t.id, true); refresh() }
            catch (e: Exception) { error = e.message ?: "操作失败" }
        }
    }

    fun moveToToday(t: Task) {
        viewModelScope.launch {
            try { repo.setTaskMemo(t.id, false); refresh() }
            catch (e: Exception) { error = e.message ?: "操作失败" }
        }
    }

    fun deleteTask(t: Task) {
        viewModelScope.launch {
            try { repo.deleteTask(t.id); refresh() }
            catch (e: Exception) { error = e.message ?: "操作失败" }
        }
    }

    fun toggleRoutineToday(r: Routine) {
        viewModelScope.launch {
            val today = LocalDate.now().toString()
            val currentlyDone = logs.any { it.routineId == r.id && it.date == today && it.done }
            try {
                repo.logRoutine(r.id, today, !currentlyDone)
                refresh()
            } catch (e: Exception) {
                error = e.message ?: "操作失败"
            }
        }
    }
}
