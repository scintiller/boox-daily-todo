package com.boox.dailytodo.ui

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.boox.dailytodo.CelebrationEvent
import kotlinx.coroutines.delay
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.random.Random

private val confettiColors = listOf(
    Color(0xFFFF3B30), Color(0xFFFF9500), Color(0xFFFFCC00), Color(0xFF34C759),
    Color(0xFF00C7BE), Color(0xFF007AFF), Color(0xFF5856D6), Color(0xFFAF52DE), Color(0xFFFF2D55)
)
private val praises = listOf("太棒啦，又完成了一件事 🎉", "干得漂亮 💪", "完成 +1 ✅", "继续加油 🔥", "你真厉害 ⭐️")

private data class P(
    val sx: Float, val sy: Float, val vx: Float, val vy: Float,
    val color: Color, val rot: Float, val size: Float, val emoji: String? = null
)

@Composable
fun CelebrationOverlay(event: CelebrationEvent, onDone: () -> Unit) {
    val progress = remember(event.id) { Animatable(0f) }
    LaunchedEffect(event.id) {
        progress.snapTo(0f)
        progress.animateTo(1f, tween(1700, easing = LinearOutSlowInEasing))
        delay(250)
        onDone()
    }
    val rnd = remember(event.id) { Random(event.id) }
    val particles = remember(event.id) {
        when (event.effect) {
            0 -> burstCenter(rnd)
            1 -> rain(rnd, emoji = false)
            2 -> rain(rnd, emoji = true)
            4 -> fireworks(rnd)
            else -> emptyList()
        }
    }
    val p = progress.value
    Box(Modifier.fillMaxSize()) {
        when (event.effect) {
            3 -> TextBanner(p, remember(event.id) { praises[rnd.nextInt(praises.size)] })
            5 -> EmojiPop(p, remember(event.id) { listOf("🎉", "🥳", "✨", "🏆", "🌟")[rnd.nextInt(5)] })
            else -> ParticleField(p, particles, gravity = if (event.effect == 0) 0.9f else 0.25f)
        }
    }
}

@Composable
private fun ParticleField(progress: Float, particles: List<P>, gravity: Float) {
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val w = constraints.maxWidth.toFloat()
        val h = constraints.maxHeight.toFloat()
        val alpha = (1f - progress).coerceIn(0f, 1f)
        particles.forEach { pt ->
            val x = (pt.sx + pt.vx * progress) * w
            val y = (pt.sy + pt.vy * progress + 0.5f * gravity * progress * progress) * h
            if (pt.emoji != null) {
                Text(
                    pt.emoji, fontSize = pt.size.sp,
                    modifier = Modifier
                        .offset { IntOffset(x.roundToInt(), y.roundToInt()) }
                        .graphicsLayer { this.alpha = alpha; rotationZ = pt.rot * progress }
                )
            } else {
                Box(
                    Modifier
                        .offset { IntOffset(x.roundToInt(), y.roundToInt()) }
                        .graphicsLayer { this.alpha = alpha; rotationZ = pt.rot * progress }
                        .size(pt.size.dp, (pt.size * 0.6f).dp)
                        .clip(RoundedCornerShape(2.dp))
                        .background(pt.color)
                )
            }
        }
    }
}

@Composable
private fun TextBanner(progress: Float, text: String) {
    val scale = if (progress < 0.25f) 0.6f + 1.6f * progress else 1f
    val alpha = if (progress > 0.8f) ((1f - progress) / 0.2f).coerceIn(0f, 1f) else 1f
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Text(
            text, fontSize = 22.sp, fontWeight = FontWeight.Bold, color = Color.White,
            modifier = Modifier
                .graphicsLayer { this.alpha = alpha; scaleX = scale; scaleY = scale }
                .clip(RoundedCornerShape(50))
                .background(AccentIndigo)
                .padding(horizontal = 22.dp, vertical = 14.dp)
        )
    }
}

@Composable
private fun EmojiPop(progress: Float, emoji: String) {
    val scale = if (progress < 0.3f) 0.3f + 2.3f * progress else 1f + 0.3f * progress
    val alpha = if (progress > 0.7f) ((1f - progress) / 0.3f).coerceIn(0f, 1f) else 1f
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Text(emoji, fontSize = 110.sp, modifier = Modifier.graphicsLayer { this.alpha = alpha; scaleX = scale; scaleY = scale })
    }
}

// generators (normalized 0..1 coords)
private fun burstCenter(r: Random): List<P> = (0 until 46).map {
    val ang = r.nextDouble(0.0, 2 * Math.PI)
    val dist = r.nextDouble(0.15, 0.7).toFloat()
    P(0.5f, 0.42f, (cos(ang) * dist).toFloat(), (sin(ang) * dist).toFloat() - 0.2f,
      confettiColors.random(r), r.nextFloat() * 720 - 360, r.nextInt(7, 14).toFloat())
}

private fun rain(r: Random, emoji: Boolean): List<P> = (0 until 56).map {
    val x = r.nextFloat()
    val e = if (emoji) listOf("🎉", "✨", "🌟", "💫", "⭐️").random(r) else null
    P(x, r.nextFloat() * -0.2f - 0.05f, r.nextFloat() * 0.1f - 0.05f, 1.2f + r.nextFloat() * 0.4f,
      confettiColors.random(r), r.nextFloat() * 600 - 300,
      if (emoji) r.nextInt(18, 28).toFloat() else r.nextInt(6, 12).toFloat(), e)
}

private fun fireworks(r: Random): List<P> {
    val out = ArrayList<P>()
    repeat(3) {
        val cx = r.nextFloat() * 0.6f + 0.2f
        val cy = r.nextFloat() * 0.35f + 0.15f
        val col = confettiColors.random(r)
        for (k in 0 until 20) {
            val ang = k / 20.0 * 2 * Math.PI
            val dist = 0.18f + r.nextFloat() * 0.12f
            out.add(P(cx, cy, (cos(ang) * dist).toFloat(), (sin(ang) * dist).toFloat(), col, 0f, 7f))
        }
    }
    return out
}

private fun List<Color>.random(r: Random) = this[r.nextInt(size)]
private fun List<String>.random(r: Random) = this[r.nextInt(size)]
