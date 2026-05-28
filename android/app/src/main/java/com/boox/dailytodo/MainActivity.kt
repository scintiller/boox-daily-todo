package com.boox.dailytodo

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.boox.dailytodo.ui.DailyTodoTheme
import com.boox.dailytodo.ui.StatsScreen
import com.boox.dailytodo.ui.TodayScreen
import com.boox.dailytodo.ui.noRippleClickable
import java.time.LocalDate

class MainActivity : ComponentActivity() {

    private val vm: MainViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            DailyTodoTheme {
                Surface(modifier = Modifier.fillMaxSize(), color = Color.White) {
                    AppRoot(vm)
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        vm.refresh()
    }
}

private val WEEKDAY_CN = mapOf(1 to "周一", 2 to "周二", 3 to "周三", 4 to "周四", 5 to "周五", 6 to "周六", 7 to "周日")

@Composable
fun AppRoot(vm: MainViewModel) {
    var tab by remember { mutableIntStateOf(0) }
    val today = LocalDate.now()
    val header = "${today} ${WEEKDAY_CN[today.dayOfWeek.value]}"

    Column(Modifier.fillMaxSize()) {
        // Header: date + manual refresh
        Row(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(header, fontSize = 16.sp, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
            Text(
                if (vm.loading) "刷新中…" else "↻ 刷新",
                fontSize = 16.sp,
                modifier = Modifier.noRippleClickable { vm.refresh() }
            )
        }

        // Tabs
        Row(Modifier.fillMaxWidth()) {
            TabButton("今日", tab == 0, Modifier.weight(1f)) { tab = 0 }
            TabButton("坚持度", tab == 1, Modifier.weight(1f)) { tab = 1 }
        }
        HorizontalDivider(color = Color.Black, thickness = 2.dp)

        vm.error?.let {
            Text("⚠ $it", fontSize = 13.sp, modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp))
        }

        Box(Modifier.weight(1f)) {
            when (tab) {
                0 -> TodayScreen(vm)
                1 -> StatsScreen(vm)
            }
        }
    }
}

@Composable
private fun TabButton(label: String, selected: Boolean, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Box(
        modifier = modifier.noRippleClickable(onClick),
        contentAlignment = Alignment.Center
    ) {
        Text(
            label,
            fontSize = 18.sp,
            fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal,
            modifier = Modifier.padding(vertical = 12.dp),
            color = Color.Black
        )
    }
}
