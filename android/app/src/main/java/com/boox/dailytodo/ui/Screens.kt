package com.boox.dailytodo.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
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
import com.boox.dailytodo.MainViewModel
import com.boox.dailytodo.Routine
import java.time.LocalDate

private val WEEKDAY_CN = mapOf(1 to "周一", 2 to "周二", 3 to "周三", 4 to "周四", 5 to "周五", 6 to "周六", 7 to "周日")

fun weekdaysLabel(days: List<Int>): String =
    days.sorted().joinToString("、") { WEEKDAY_CN[it] ?: "?" }

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
        Text("待办", fontSize = 22.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(8.dp))
        if (vm.tasks.isEmpty()) {
            Text("今天没有待办 🎉", fontSize = 16.sp)
        } else {
            val order = listOf("工作", "运动", "生活")
            val grouped = vm.tasks.groupBy { it.category ?: "其他" }
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
    }
}

@Composable
fun StatsScreen(vm: MainViewModel) {
    val weeks = 8
    val today = LocalDate.now()
    val start = today.minusWeeks(weeks.toLong())

    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp)
    ) {
        Text("坚持度（最近 $weeks 周）", fontSize = 22.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(4.dp))
        Text("■ = 完成   □ = 漏掉", fontSize = 13.sp)
        Spacer(Modifier.height(12.dp))

        if (vm.routines.isEmpty()) {
            Text("还没有 routine，先在 Claude 里添加吧", fontSize = 16.sp)
            return@Column
        }

        vm.routines.forEach { r ->
            val scheduled = ArrayList<LocalDate>()
            var d = start
            while (!d.isAfter(today)) {
                if (r.weekdays.contains(d.dayOfWeek.value)) scheduled.add(d)
                d = d.plusDays(1)
            }
            val doneDates = vm.logs.filter { it.routineId == r.id && it.done }.map { it.date }.toSet()
            val doneCount = scheduled.count { doneDates.contains(it.toString()) }
            val pct = if (scheduled.isNotEmpty()) doneCount * 100 / scheduled.size else 0

            Spacer(Modifier.height(16.dp))
            Text(
                "${r.icon ?: ""}${r.name}  ($doneCount/${scheduled.size}, $pct%)  —  ${weekdaysLabel(r.weekdays)}",
                fontSize = 17.sp,
                fontWeight = FontWeight.Bold
            )
            Spacer(Modifier.height(6.dp))
            Row(
                Modifier.horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                scheduled.forEach { day ->
                    val ok = doneDates.contains(day.toString())
                    Box(
                        Modifier
                            .size(24.dp)
                            .border(1.dp, Color.Black)
                            .background(if (ok) Color.Black else Color.White)
                    )
                }
            }
        }
        Spacer(Modifier.height(24.dp))
    }
}
