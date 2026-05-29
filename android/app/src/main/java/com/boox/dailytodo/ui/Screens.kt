package com.boox.dailytodo.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.boox.dailytodo.DayWeather
import com.boox.dailytodo.MainViewModel
import com.boox.dailytodo.Routine
import com.boox.dailytodo.Task
import java.time.LocalDate
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter

private val WEEKDAY_CN = mapOf(1 to "周一", 2 to "周二", 3 to "周三", 4 to "周四", 5 to "周五", 6 to "周六", 7 to "周日")

fun weekdaysLabel(days: List<Int>): String =
    days.sorted().joinToString("、") { WEEKDAY_CN[it] ?: "?" }

private val HHMM: DateTimeFormatter = DateTimeFormatter.ofPattern("HH:mm")

/** Parse a Postgres timestamptz (e.g. 2026-05-28T18:32:00+00:00) into the device's local zone. */
private fun completedZdt(iso: String?) =
    iso?.let { runCatching { OffsetDateTime.parse(it).atZoneSameInstant(ZoneId.systemDefault()) }.getOrNull() }

// ---------- weather (WMO code -> emoji + 中文) ----------
private fun weatherInfo(code: Int): Pair<String, String> = when (code) {
    0 -> "☀️" to "晴"
    1, 2 -> "🌤" to "多云"
    3 -> "☁️" to "阴"
    45, 48 -> "🌫" to "雾"
    in 51..57 -> "🌦" to "毛毛雨"
    61, 63 -> "🌧" to "小雨"
    65 -> "🌧" to "大雨"
    66, 67 -> "🌧" to "冻雨"
    in 71..77 -> "🌨" to "雪"
    80, 81 -> "🌦" to "阵雨"
    82 -> "⛈" to "强阵雨"
    85, 86 -> "🌨" to "阵雪"
    95 -> "⛈" to "雷暴"
    96, 99 -> "⛈" to "雷暴冰雹"
    else -> "❓" to "—"
}

/** Heavy downpour / storm worth warning about. */
private fun isHeavyRain(w: DayWeather): Boolean =
    w.code in setOf(65, 82, 95, 96, 99) || w.precip >= 20.0

/** Short inline summary of today's weather for the date header, e.g. "☁️阴 32°/20°". */
fun todayWeatherSummary(days: List<DayWeather>): String? {
    val w = days.firstOrNull() ?: return null
    val (emoji, label) = weatherInfo(w.code)
    return if (w.currentTemp != null) "$emoji$label ${w.currentTemp}° (${w.tMax}°/${w.tMin}°)"
    else "$emoji$label ${w.tMax}°/${w.tMin}°"
}

/** Heavy-rain banner — always shown when a storm is forecast, regardless of expand state. */
@Composable
fun WeatherAlert(days: List<DayWeather>) {
    val labels = listOf("今天", "明天", "后天")
    val (i, w) = days.take(3).withIndex().firstOrNull { isHeavyRain(it.value) } ?: return
    val (_, label) = weatherInfo(w.code)
    val mm = if (w.precip >= 1.0) "，预计降水 ${w.precip.toInt()}mm" else ""
    Box(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .border(3.dp, Color.Black)
            .padding(12.dp)
    ) {
        Text(
            "⚠️ 大暴雨预警：${labels.getOrElse(i) { "近期" }}有$label$mm，记得带伞 ☔",
            fontSize = 17.sp,
            fontWeight = FontWeight.Bold
        )
    }
    Spacer(Modifier.height(8.dp))
}

/** Expandable 3-day forecast detail (今天/明天/后天). */
@Composable
fun WeatherDetail(days: List<DayWeather>) {
    if (days.isEmpty()) return
    val labels = listOf("今天", "明天", "后天")
    Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
        days.take(3).forEachIndexed { i, w ->
            val (emoji, label) = weatherInfo(w.code)
            Column(
                Modifier.weight(1f).padding(vertical = 4.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(labels.getOrElse(i) { "" }, fontSize = 14.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(2.dp))
                Text(emoji, fontSize = 30.sp)
                Text(label, fontSize = 14.sp)
                if (w.currentTemp != null) {
                    Text("${w.currentTemp}°", fontSize = 22.sp, fontWeight = FontWeight.Bold)
                    Text("(${w.tMax}°/${w.tMin}°)", fontSize = 13.sp)
                } else {
                    Text("${w.tMax}° / ${w.tMin}°", fontSize = 15.sp)
                }
                if (w.precipProb > 0) Text("💧 ${w.precipProb}%", fontSize = 12.sp)
            }
        }
    }
    Spacer(Modifier.height(8.dp))
}

@Composable
fun TodayScreen(vm: MainViewModel) {
    val today = LocalDate.now()
    val todayStr = today.toString()

    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp)
    ) {
        // 今日待办: 未完成、非备忘、无到期日或已到期 (未来日期的任务等到当天才出现)
        val pending = vm.tasks.filter {
            !it.done && !it.memo && (it.dueDate == null || it.dueDate <= todayStr)
        }
        Text("待办", fontSize = 22.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(8.dp))
        if (pending.isEmpty()) {
            Text("今天没有待办 🎉", fontSize = 16.sp)
        } else {
            val order = listOf("工作", "运动", "生活")
            val grouped = pending.groupBy { it.category ?: "其他" }
            val cats = order.filter { grouped.containsKey(it) } +
                grouped.keys.filter { it !in order }
            cats.forEach { cat ->
                Text(
                    cat,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(top = 12.dp, bottom = 2.dp)
                )
                grouped.getValue(cat).forEach { t ->
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .noRippleClickable { vm.toggleTask(t) }
                            .padding(vertical = 12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(if (t.done) "☑" else "☐", fontSize = 26.sp)
                        Spacer(Modifier.width(12.dp))
                        Column {
                            Text(t.title, fontSize = 18.sp)
                            t.dueDate?.let { due ->
                                val overdue = due < todayStr
                                Text(
                                    (if (overdue) "⚠ 逾期 " else "⏰ ") + due,
                                    fontSize = 13.sp,
                                    fontWeight = if (overdue) FontWeight.Bold else FontWeight.Normal
                                )
                            }
                        }
                    }
                    HorizontalDivider(color = Color.Black, thickness = 1.dp)
                }
            }
        }

        Spacer(Modifier.height(28.dp))
        Text("今日 Routine", fontSize = 22.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(8.dp))
        val todays = vm.routines.filter { it.weekdays.contains(today.dayOfWeek.value) }
        if (todays.isEmpty()) {
            Text("今天没有安排的 routine", fontSize = 16.sp)
        } else {
            todays.forEach { r ->
                val done = vm.logs.any { it.routineId == r.id && it.date == todayStr && it.done }
                Row(
                    Modifier
                        .fillMaxWidth()
                        .noRippleClickable { vm.toggleRoutineToday(r) }
                        .padding(vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(if (done) "✔" else "☐", fontSize = 26.sp)
                    Spacer(Modifier.width(12.dp))
                    Text("${r.icon ?: ""}${r.name}", fontSize = 18.sp)
                }
                HorizontalDivider(color = Color.Black, thickness = 1.dp)
            }
        }

        // ── 已完成 (今天 / 昨天)，时间按勾选完成的时刻 ──
        val yesterday = today.minusDays(1)
        val doneItems = vm.tasks
            .filter { it.done }
            .mapNotNull { t -> completedZdt(t.completedAt)?.let { it to t } }
        if (doneItems.any { (zdt, _) -> zdt.toLocalDate() == today || zdt.toLocalDate() == yesterday }) {
            Spacer(Modifier.height(28.dp))
            Text("已完成", fontSize = 22.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(8.dp))
            listOf("今天" to today, "昨天" to yesterday).forEach { (label, date) ->
                val items = doneItems
                    .filter { (zdt, _) -> zdt.toLocalDate() == date }
                    .sortedByDescending { (zdt, _) -> zdt }
                if (items.isNotEmpty()) {
                    Text(
                        label,
                        fontSize = 15.sp,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(top = 12.dp, bottom = 2.dp)
                    )
                    items.forEach { (zdt, t) ->
                        Row(
                            Modifier
                                .fillMaxWidth()
                                .noRippleClickable { vm.toggleTask(t) }
                                .padding(vertical = 12.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text("☑", fontSize = 26.sp)
                            Spacer(Modifier.width(12.dp))
                            Text(t.title, fontSize = 18.sp, modifier = Modifier.weight(1f))
                            Text(zdt.format(HHMM), fontSize = 14.sp)
                        }
                        HorizontalDivider(color = Color.Black, thickness = 1.dp)
                    }
                }
            }
        }
    }
}

@Composable
fun MemoScreen(vm: MainViewModel) {
    val todayStr = LocalDate.now().toString()
    // 备忘事项 + 未来日期的待办 (今天还没到的事)，到期当天会回到「今日」
    val items = vm.tasks
        .filter { !it.done && (it.memo || (it.dueDate != null && it.dueDate > todayStr)) }
        .sortedWith(compareBy({ it.dueDate == null }, { it.dueDate }))
    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp)
    ) {
        Text("备忘录", fontSize = 22.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(8.dp))
        if (items.isEmpty()) {
            Text("还没有备忘 📝", fontSize = 16.sp)
        } else {
            items.forEach { t ->
                Row(
                    Modifier
                        .fillMaxWidth()
                        .noRippleClickable { vm.toggleTask(t) }
                        .padding(vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("☐", fontSize = 26.sp)
                    Spacer(Modifier.width(12.dp))
                    Column {
                        Text(t.title, fontSize = 18.sp)
                        val sub = t.dueDate?.let { "⏰ $it" } ?: t.category
                        sub?.let { Text(it, fontSize = 13.sp) }
                    }
                }
                HorizontalDivider(color = Color.Black, thickness = 1.dp)
            }
        }
    }
}

private enum class HeatState { MET, MISS, BLANK }

private val WD_SHORT = mapOf(1 to "一", 2 to "二", 3 to "三", 4 to "四", 5 to "五", 6 to "六", 7 to "日")

@Composable
private fun HeatCell(state: HeatState, dim: androidx.compose.ui.unit.Dp) {
    val m = Modifier.size(dim)
    when (state) {
        HeatState.MET -> Box(m.background(Color.Black, RoundedCornerShape(5.dp)))
        HeatState.MISS -> Box(m.border(1.5.dp, Color.Black, RoundedCornerShape(5.dp)))
        HeatState.BLANK -> Box(m.border(1.dp, Color(0xFFBBBBBB), RoundedCornerShape(5.dp)))
    }
}

@Composable
fun StatsScreen(vm: MainViewModel) {
    val weeks = 8
    val today = LocalDate.now()
    val thisMonday = today.minusDays((today.dayOfWeek.value - 1).toLong())
    val weekStarts = (weeks - 1 downTo 0).map { thisMonday.minusWeeks(it.toLong()) } // 旧 → 新
    val cell = 30.dp
    val gap = 6.dp

    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp)
    ) {
        Text("坚持度（最近 $weeks 周）", fontSize = 22.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(8.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            HeatCell(HeatState.MET, 16.dp); Spacer(Modifier.width(6.dp))
            Text("达成", fontSize = 13.sp); Spacer(Modifier.width(18.dp))
            HeatCell(HeatState.MISS, 16.dp); Spacer(Modifier.width(6.dp))
            Text("漏掉", fontSize = 13.sp); Spacer(Modifier.width(18.dp))
            Text("每格一周 · 左旧右新", fontSize = 13.sp)
        }

        if (vm.routines.isEmpty()) {
            Spacer(Modifier.height(16.dp))
            Text("还没有 routine，先在 Claude 里添加吧", fontSize = 16.sp)
            return@Column
        }

        vm.routines.forEach { r ->
            val doneDates = vm.logs.filter { it.routineId == r.id && it.done }.map { it.date }.toSet()
            val createdDate = completedZdt(r.createdAt)?.toLocalDate()
            val days = r.weekdays.sorted()

            fun stateOf(date: LocalDate): HeatState = when {
                date.isAfter(today) -> HeatState.BLANK
                createdDate != null && date.isBefore(createdDate) -> HeatState.BLANK
                doneDates.contains(date.toString()) -> HeatState.MET
                else -> HeatState.MISS
            }

            // 统计 (只算已发生且 routine 已存在的格子)
            val counted = weekStarts.flatMap { ws -> days.map { ws.plusDays((it - 1).toLong()) } }
                .map { stateOf(it) }
                .filter { it != HeatState.BLANK }
            val total = counted.size
            val met = counted.count { it == HeatState.MET }
            val pct = if (total > 0) met * 100 / total else 0
            // 连续达成 (从最近一次排程往回数)
            val streak = weekStarts.flatMap { ws -> days.map { ws.plusDays((it - 1).toLong()) } }
                .filter { !it.isAfter(today) && (createdDate == null || !it.isBefore(createdDate)) }
                .sortedDescending()
                .takeWhile { doneDates.contains(it.toString()) }
                .count()

            Spacer(Modifier.height(18.dp))
            HorizontalDivider(color = Color.Black, thickness = 1.dp)
            Spacer(Modifier.height(14.dp))
            Row(verticalAlignment = Alignment.Bottom) {
                Text(
                    "${r.icon ?: ""}${r.name}",
                    fontSize = 18.sp, fontWeight = FontWeight.Bold,
                    modifier = Modifier.weight(1f)
                )
                Text("$pct%", fontSize = 26.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.width(10.dp))
                Text("$met/$total 次", fontSize = 14.sp)
            }
            Spacer(Modifier.height(2.dp))
            Text(
                weekdaysLabel(r.weekdays) + if (streak > 0) "   ·   🔥 连续达成 $streak 次" else "",
                fontSize = 13.sp
            )
            Spacer(Modifier.height(8.dp))
            // 进度条
            Box(
                Modifier
                    .fillMaxWidth()
                    .height(12.dp)
                    .border(1.dp, Color.Black)
            ) {
                Box(Modifier.fillMaxHeight().fillMaxWidth(pct / 100f).background(Color.Black))
            }
            Spacer(Modifier.height(14.dp))
            // 周历热力图: 行 = 排程的星期, 列 = 周
            Column(verticalArrangement = Arrangement.spacedBy(gap)) {
                days.forEach { wd ->
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(gap)
                    ) {
                        Text(WD_SHORT[wd] ?: "?", fontSize = 13.sp, modifier = Modifier.width(20.dp))
                        weekStarts.forEach { ws ->
                            HeatCell(stateOf(ws.plusDays((wd - 1).toLong())), cell)
                        }
                    }
                }
            }
        }
        Spacer(Modifier.height(24.dp))
    }
}
