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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.Dp
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.boox.dailytodo.DayWeather
import com.boox.dailytodo.Goal
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

private val SECTION_NAMES = listOf("focus" to "🧠 专注力", "feature" to "🛠 随手做")

@Composable
private fun CircleCheck(done: Boolean, color: Color, dim: Dp = 24.dp) {
    if (done) {
        Box(Modifier.size(dim).background(color, CircleShape), contentAlignment = Alignment.Center) {
            Text("✓", color = Color.White, fontSize = (dim.value * 0.62f).sp, fontWeight = FontWeight.Bold)
        }
    } else {
        Box(Modifier.size(dim).border(2.dp, color, CircleShape))
    }
}

/** iOS-style card row. */
@Composable
private fun TaskRow(vm: MainViewModel, t: Task, todayStr: String, accent: Color) {
    val on = t.done || vm.completingIds.contains(t.id)
    Row(
        Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(CardBg)
            .noRippleClickable { if (!on) vm.toggleTask(t) }
            .padding(horizontal = 14.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        CircleCheck(on, accent)
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(
                t.title, fontSize = 17.sp,
                color = if (on) InkSecondary else InkPrimary,
                textDecoration = if (on) androidx.compose.ui.text.style.TextDecoration.LineThrough else null
            )
            t.dueDate?.let { due ->
                val overdue = due < todayStr
                Text(
                    (if (overdue) "⚠ 逾期 " else "⏰ ") + due,
                    fontSize = 13.sp, color = InkSecondary,
                    fontWeight = if (overdue) FontWeight.Bold else FontWeight.Normal
                )
            }
        }
    }
}

@Composable
private fun SubHeader(text: String) {
    Text(text, fontSize = 14.sp, fontWeight = FontWeight.Bold, color = InkSecondary,
        modifier = Modifier.padding(top = 14.dp, bottom = 2.dp))
}

@Composable
private fun PrioHeader(text: String) {
    Text(text, fontSize = 12.sp, fontWeight = FontWeight.Bold, color = AccentIndigo,
        modifier = Modifier.padding(start = 12.dp, top = 8.dp, bottom = 2.dp))
}

@Composable
fun TodayScreen(vm: MainViewModel, pomo: PomodoroController) {
    val today = LocalDate.now()
    val todayStr = today.toString()

    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp)
    ) {
        // 🍅 番茄钟
        PomodoroBar(pomo)
        Spacer(Modifier.height(16.dp))

        // 🎯 本周目标
        if (vm.goals.isNotEmpty()) {
            Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(GoalBg).padding(16.dp)) {
                Column {
                    Text("🎯 目标", fontSize = 14.sp, fontWeight = FontWeight.Bold, color = InkSecondary)
                    Spacer(Modifier.height(6.dp))
                    vm.goals.forEach { g ->
                        Row(
                            Modifier.fillMaxWidth().noRippleClickable { vm.toggleGoal(g) }.padding(vertical = 8.dp),
                            verticalAlignment = Alignment.Top
                        ) {
                            CircleCheck(false, AccentIndigo, 22.dp)
                            Spacer(Modifier.width(12.dp))
                            Column {
                                Text(g.title, fontSize = 16.sp, fontWeight = FontWeight.Medium, color = InkPrimary)
                                g.targetDate?.let { Text("🗓 预期 $it", fontSize = 12.sp, color = InkSecondary) }
                            }
                        }
                    }
                }
            }
            Spacer(Modifier.height(22.dp))
        }

        // 今日待办: 未完成、非备忘、无到期日或已到期
        val pending = vm.tasks.filter {
            !it.done && !it.memo && (it.dueDate == null || it.dueDate <= todayStr)
        }
        Text("待办", fontSize = 22.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(8.dp))
        if (pending.isEmpty()) {
            Text("今天没有待办 🎉", fontSize = 16.sp)
        } else {
            // 工作: 主线 / 随手做
            val work = pending.filter { it.category == "工作" }
            if (work.isNotEmpty()) {
                Text("工作", fontSize = 16.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 6.dp))
                SECTION_NAMES.forEach { (key, name) ->
                    val items = work.filter { (it.workSection ?: "") == key }
                    if (items.isNotEmpty()) {
                        SubHeader(name)
                        if (key == "feature") {
                            val p1 = items.filter { it.title.contains("🌟") }
                            val p2 = items.filter { !it.title.contains("🌟") }
                            if (p1.isNotEmpty()) { PrioHeader("P1"); p1.forEach { TaskRow(vm, it, todayStr, sectionAccent(key)) } }
                            if (p2.isNotEmpty()) { PrioHeader("P2"); p2.forEach { TaskRow(vm, it, todayStr, sectionAccent(key)) } }
                        } else {
                            items.forEach { TaskRow(vm, it, todayStr, sectionAccent(key)) }
                        }
                    }
                }
                val uncat = work.filter { (it.workSection ?: "") !in listOf("focus", "feature") }
                if (uncat.isNotEmpty()) { SubHeader("· 未分类"); uncat.forEach { TaskRow(vm, it, todayStr, AccentIndigo) } }
            }
            // 生活 (非工作)
            val life = pending.filter { it.category != "工作" }
            if (life.isNotEmpty()) {
                Text("生活", fontSize = 16.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 14.dp))
                Spacer(Modifier.height(2.dp))
                life.forEach { TaskRow(vm, it, todayStr, AccentGreen) }
            }
        }

        Spacer(Modifier.height(28.dp))
        Text("今日 Routine", fontSize = 22.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(8.dp))
        // 今天排了的 routine，外加今天补打卡的(即使不在排期里，比如临时做了复健)
        val todays = vm.routines.filter { r ->
            r.weekdays.contains(today.dayOfWeek.value) ||
                vm.logs.any { it.routineId == r.id && it.date == todayStr && it.done }
        }
        if (todays.isEmpty()) {
            Text("今天没有安排的 routine", fontSize = 16.sp)
        } else {
            todays.forEach { r ->
                val done = vm.logs.any { it.routineId == r.id && it.date == todayStr && it.done }
                Row(
                    Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp)
                        .clip(RoundedCornerShape(14.dp))
                        .background(CardBg)
                        .noRippleClickable { vm.toggleRoutineToday(r) }
                        .padding(horizontal = 14.dp, vertical = 14.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    CircleCheck(done, AccentGreen)
                    Spacer(Modifier.width(12.dp))
                    Text("${r.icon ?: ""}${r.name}", fontSize = 17.sp, color = InkPrimary)
                }
            }
        }

        // ── 已完成 (今天 / 昨天)，默认折叠，点标题展开 ──
        val yesterday = today.minusDays(1)
        val doneItems = vm.tasks
            .filter { it.done }
            .mapNotNull { t -> completedZdt(t.completedAt)?.let { it to t } }
            .filter { (zdt, _) -> zdt.toLocalDate() == today || zdt.toLocalDate() == yesterday }
        if (doneItems.isNotEmpty()) {
            var doneExpanded by remember { mutableStateOf(false) }
            Spacer(Modifier.height(28.dp))
            Row(
                Modifier.fillMaxWidth().noRippleClickable { doneExpanded = !doneExpanded },
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("已完成 (${doneItems.size})", fontSize = 22.sp, fontWeight = FontWeight.Bold)
                Text(if (doneExpanded) "  ▾" else "  ▸", fontSize = 18.sp)
            }
            if (doneExpanded) listOf("今天" to today, "昨天" to yesterday).forEach { (label, date) ->
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
                                .padding(vertical = 4.dp)
                                .clip(RoundedCornerShape(14.dp))
                                .background(CardBg)
                                .noRippleClickable { vm.toggleTask(t) }
                                .padding(horizontal = 14.dp, vertical = 12.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            CircleCheck(true, InkSecondary, 22.dp)
                            Spacer(Modifier.width(12.dp))
                            Text(t.title, fontSize = 16.sp, color = InkSecondary, modifier = Modifier.weight(1f))
                            Text(zdt.format(HHMM), fontSize = 13.sp, color = InkSecondary)
                        }
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
            val life = items.filter { it.category != "工作" }
            val work = items.filter { it.category == "工作" }
            if (life.isNotEmpty()) {
                SubHeader("生活")
                life.forEach { MemoRow(vm, it) }
            }
            if (work.isNotEmpty()) {
                SubHeader("工作")
                work.forEach { MemoRow(vm, it) }
            }
        }
    }
}

@Composable
private fun MemoRow(vm: MainViewModel, t: Task) {
    val accent = if (t.category == "工作") sectionAccent(t.workSection) else AccentGreen
    Row(
        Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(CardBg)
            .noRippleClickable { vm.toggleTask(t) }
            .padding(horizontal = 14.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        CircleCheck(false, accent)
        Spacer(Modifier.width(12.dp))
        Column {
            Text(t.title, fontSize = 17.sp, color = InkPrimary)
            val sub = t.dueDate?.let { "⏰ $it" } ?: t.category
            sub?.let { Text(it, fontSize = 13.sp, color = InkSecondary) }
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

private fun fmtMin(m: Int) = if (m >= 60) "${m / 60}h ${m % 60}m" else "${m}m"

@Composable
private fun FocusSummaryCard(vm: MainViewModel) {
    val zone = ZoneId.systemDefault()
    val byDay = HashMap<LocalDate, Int>()
    vm.focusSessions.filter { it.phase == "work" }.forEach { s ->
        s.endedAt?.let { iso ->
            runCatching { OffsetDateTime.parse(iso).atZoneSameInstant(zone).toLocalDate() }
                .getOrNull()?.let { d -> byDay[d] = (byDay[d] ?: 0) + s.minutes }
        }
    }
    val today = LocalDate.now()
    val monday = today.minusDays((today.dayOfWeek.value - 1).toLong())
    val weekMin = byDay.filterKeys { !it.isBefore(monday) }.values.sum()
    val total = vm.focusSessions.count { it.phase == "work" }
    val todayMin = byDay[today] ?: 0
    val days = (6 downTo 0).map { today.minusDays(it.toLong()) }
    val maxMin = (days.maxOfOrNull { byDay[it] ?: 0 } ?: 0).coerceAtLeast(1)

    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(CardBg).padding(16.dp)) {
        Row(verticalAlignment = Alignment.Bottom) {
            Text("🍅 专注", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = InkPrimary)
            Spacer(Modifier.weight(1f))
            Text("本周 ${fmtMin(weekMin)} · 累计 $total 🍅", fontSize = 12.sp, color = InkSecondary)
        }
        Text("今日 ${fmtMin(todayMin)}", fontSize = 14.sp, color = AccentIndigo, modifier = Modifier.padding(top = 2.dp))
        Spacer(Modifier.height(12.dp))
        Row(
            Modifier.fillMaxWidth().height(120.dp),
            verticalAlignment = Alignment.Bottom,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            days.forEach { d ->
                val mins = byDay[d] ?: 0
                val frac = (mins.toFloat() / maxMin).coerceIn(0.02f, 1f)
                Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                    Box(Modifier.height(92.dp).width(22.dp), contentAlignment = Alignment.BottomCenter) {
                        Box(Modifier.fillMaxHeight(frac).width(22.dp).clip(RoundedCornerShape(4.dp)).background(AccentIndigo))
                    }
                    Spacer(Modifier.height(4.dp))
                    Text("${d.monthValue}/${d.dayOfMonth}", fontSize = 10.sp, color = InkSecondary)
                }
            }
        }
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
        FocusSummaryCard(vm)
        Spacer(Modifier.height(22.dp))
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
