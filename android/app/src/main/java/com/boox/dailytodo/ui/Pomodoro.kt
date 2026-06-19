package com.boox.dailytodo.ui

import android.content.Context
import android.media.AudioManager
import android.media.ToneGenerator
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

/** Pomodoro state + timer. 专注 counts down; 休息 counts up (ends at target). */
class PomodoroController(
    private val scope: CoroutineScope,
    ctx: Context,
    private val onComplete: (String, Int) -> Unit,
) {
    private val prefs = ctx.getSharedPreferences("pomo", Context.MODE_PRIVATE)

    var phase by mutableStateOf("work")            // "work" | "rest"
    var running by mutableStateOf(false)
    var remaining by mutableIntStateOf(45 * 60)    // seconds
    var awaitingChoice by mutableStateOf(false)
    var workMins by mutableIntStateOf(prefs.getInt("work", 45))
    var restMins by mutableIntStateOf(prefs.getInt("rest", 10))

    private var endAt = 0L
    private var job: Job? = null

    val durationMins: Int get() = if (phase == "work") workMins else restMins
    val idle: Boolean get() = !running && !awaitingChoice && remaining == durationMins * 60
    val phaseLabel: String get() = if (phase == "work") "专注" else "休息"
    val label: String get() {
        val secs = if (phase == "rest") (durationMins * 60 - remaining).coerceAtLeast(0)
                   else remaining.coerceAtLeast(0)
        return "%02d:%02d".format(secs / 60, secs % 60)
    }

    fun setWork(m: Int) { workMins = m; prefs.edit().putInt("work", m).apply(); if (!running && phase == "work") remaining = m * 60 }
    fun setRest(m: Int) { restMins = m; prefs.edit().putInt("rest", m).apply(); if (!running && phase == "rest") remaining = m * 60 }
    fun selectPhase(p: String) { awaitingChoice = false; phase = p; if (!running) remaining = durationMins * 60 }

    fun toggle() { if (running) pause() else start() }
    fun start() {
        awaitingChoice = false; running = true
        endAt = System.currentTimeMillis() + remaining * 1000L
        job?.cancel()
        job = scope.launch { while (running) { delay(500); tick() } }
    }
    fun pause() { running = false; job?.cancel() }
    fun reset() { pause(); awaitingChoice = false; phase = "work"; remaining = workMins * 60 }
    fun skip() {
        val elapsed = ((durationMins * 60 - remaining) / 60.0).roundToInt()
        if (elapsed >= 1) onComplete(phase, elapsed)
        advance()
    }
    fun extend(mins: Int = 10) { awaitingChoice = false; remaining = mins * 60; start() }
    fun chooseRest() { awaitingChoice = false; phase = "rest"; remaining = restMins * 60 }

    private fun tick() {
        if (!running) return
        val r = ((endAt - System.currentTimeMillis()) / 1000.0).roundToInt()
        if (r <= 0) {
            playChime()
            onComplete(phase, durationMins)
            if (phase == "work") { running = false; job?.cancel(); remaining = 0; awaitingChoice = true }
            else advance()
        } else remaining = r
    }
    private fun advance() {
        running = false; job?.cancel(); awaitingChoice = false
        phase = if (phase == "work") "rest" else "work"
        remaining = durationMins * 60
    }
    private fun playChime() {
        scope.launch(Dispatchers.IO) {
            try {
                val tg = ToneGenerator(AudioManager.STREAM_ALARM, ToneGenerator.MAX_VOLUME)
                val end = System.currentTimeMillis() + 7000
                while (System.currentTimeMillis() < end) { tg.startTone(ToneGenerator.TONE_PROP_BEEP, 250); delay(420) }
                tg.release()
            } catch (_: Exception) {}
        }
    }
}

@Composable
fun PomodoroBar(pomo: PomodoroController) {
    var expanded by remember { mutableStateOf(false) }
    val color = if (pomo.phase == "work") AccentIndigo else AccentGreen

    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(CardBg)
    ) {
        // header
        Row(
            Modifier
                .fillMaxWidth()
                .noRippleClickable { expanded = !expanded }
                .padding(horizontal = 14.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text("🍅 番茄钟", fontSize = 15.sp, fontWeight = FontWeight.Bold, color = InkPrimary)
            if (pomo.awaitingChoice) {
                Spacer(Modifier.width(8.dp)); Text("· 专注结束 🎉", fontSize = 14.sp, color = color)
            } else if (!pomo.idle) {
                Spacer(Modifier.width(8.dp))
                Text("· ${pomo.phaseLabel} ${pomo.label}", fontSize = 14.sp, color = color)
            }
            Spacer(Modifier.weight(1f))
            Text(if (expanded) "▾" else "▸", fontSize = 14.sp, color = InkSecondary)
        }

        if (expanded) {
            Column(
                Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, bottom = 16.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                if (!pomo.awaitingChoice) {
                    // 专注 / 休息 toggle
                    Row(
                        Modifier.clip(RoundedCornerShape(50)).background(Color(0xFFE5E5EA)).padding(3.dp),
                        horizontalArrangement = Arrangement.spacedBy(0.dp)
                    ) {
                        listOf("work" to "专注", "rest" to "休息").forEach { (key, lbl) ->
                            val sel = pomo.phase == key
                            Text(
                                lbl, fontSize = 14.sp, fontWeight = FontWeight.SemiBold,
                                color = if (sel) Color.White else InkSecondary,
                                modifier = Modifier
                                    .clip(RoundedCornerShape(50))
                                    .background(if (sel) color else Color.Transparent)
                                    .noRippleClickable { pomo.selectPhase(key) }
                                    .padding(horizontal = 22.dp, vertical = 7.dp)
                            )
                        }
                    }
                }

                when {
                    pomo.awaitingChoice -> {
                        Text("专注结束 🎉", fontSize = 22.sp, fontWeight = FontWeight.Bold, color = color)
                        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            PomoPillButton("延长 10 分钟", color, filled = false) { pomo.extend(10) }
                            PomoPillButton("开始休息", AccentGreen, filled = true) { pomo.chooseRest() }
                        }
                    }
                    pomo.idle -> {
                        val presets = if (pomo.phase == "work") listOf(45, 30, 15) else listOf(15, 10, 5)
                        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            presets.forEach { m ->
                                val sel = pomo.durationMins == m
                                Text(
                                    "$m", fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
                                    color = if (sel) Color.White else color,
                                    modifier = Modifier
                                        .clip(RoundedCornerShape(50))
                                        .background(if (sel) color else color.copy(alpha = 0.12f))
                                        .noRippleClickable { if (pomo.phase == "work") pomo.setWork(m) else pomo.setRest(m) }
                                        .padding(horizontal = 18.dp, vertical = 8.dp)
                                )
                            }
                            Text("分钟", fontSize = 13.sp, color = InkSecondary, modifier = Modifier.align(Alignment.CenterVertically))
                        }
                        // − N + stepper
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(18.dp)) {
                            StepBtn("−", color) { adjust(pomo, -5) }
                            Text("${pomo.durationMins} 分钟", fontSize = 20.sp, fontWeight = FontWeight.Bold, color = InkPrimary)
                            StepBtn("+", color) { adjust(pomo, +5) }
                        }
                        PomoPillButton("▶  开始${pomo.phaseLabel}", color, filled = true) { pomo.start() }
                    }
                    else -> {
                        Text(pomo.label, fontSize = 56.sp, fontWeight = FontWeight.Bold, color = color)
                        Row(horizontalArrangement = Arrangement.spacedBy(28.dp), verticalAlignment = Alignment.CenterVertically) {
                            StepBtn("↺", InkSecondary) { pomo.reset() }
                            Text(if (pomo.running) "⏸" else "▶", fontSize = 44.sp, color = color,
                                modifier = Modifier.noRippleClickable { pomo.toggle() })
                            StepBtn("⏭", InkSecondary) { pomo.skip() }
                        }
                    }
                }
            }
        }
    }
}

private fun adjust(pomo: PomodoroController, d: Int) {
    val v = (pomo.durationMins + d).coerceIn(1, 90)
    if (pomo.phase == "work") pomo.setWork(v) else pomo.setRest(v)
}

@Composable
private fun PomoPillButton(text: String, color: Color, filled: Boolean, onClick: () -> Unit) {
    Text(
        text, fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
        color = if (filled) Color.White else color,
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .then(if (filled) Modifier.background(color) else Modifier.border(1.5.dp, color, RoundedCornerShape(50)))
            .noRippleClickable(onClick)
            .padding(horizontal = 24.dp, vertical = 12.dp)
    )
}

@Composable
private fun StepBtn(symbol: String, color: Color, onClick: () -> Unit) {
    Box(
        Modifier.size(40.dp).clip(CircleShape).noRippleClickable(onClick),
        contentAlignment = Alignment.Center
    ) { Text(symbol, fontSize = 22.sp, color = color) }
}
