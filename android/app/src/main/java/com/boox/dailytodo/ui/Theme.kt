package com.boox.dailytodo.ui

import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.clickable
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color

// iOS-style accent colors (shared with section grouping)
val AccentIndigo = Color(0xFF5856D6)   // 主线 / 强调
val AccentOrange = Color(0xFFFF9500)   // 随手做
val AccentGreen = Color(0xFF34C759)    // 生活 / routine
val CardBg = Color(0xFFF2F2F7)         // iOS secondarySystemBackground
val GoalBg = Color(0xFFECEAFB)
val InkPrimary = Color(0xFF1C1C1E)
val InkSecondary = Color(0xFF8A8A8E)

private val LightColors = lightColorScheme(
    primary = AccentIndigo,
    onPrimary = Color.White,
    secondary = AccentIndigo,
    background = Color.White,
    onBackground = InkPrimary,
    surface = Color.White,
    onSurface = InkPrimary,
    surfaceVariant = CardBg,
    onSurfaceVariant = InkSecondary,
    outline = Color(0xFFD1D1D6),
)

@Composable
fun DailyTodoTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = LightColors, content = content)
}

/** Accent color for a work section / 生活. */
fun sectionAccent(key: String?): Color = when (key) {
    "focus" -> AccentIndigo
    "feature" -> AccentOrange
    else -> AccentGreen
}

/** Click with no ripple/animation — better for e-ink (no ghosting flashes). */
@Composable
fun Modifier.noRippleClickable(onClick: () -> Unit): Modifier {
    val source = remember { MutableInteractionSource() }
    return this.clickable(interactionSource = source, indication = null, onClick = onClick)
}
