package com.boox.dailytodo.ui

import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.clickable
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color

/** Pure black/white scheme — high contrast for e-ink. */
private val EinkColors = lightColorScheme(
    primary = Color.Black,
    onPrimary = Color.White,
    secondary = Color.Black,
    onSecondary = Color.White,
    background = Color.White,
    onBackground = Color.Black,
    surface = Color.White,
    onSurface = Color.Black,
    surfaceVariant = Color.White,
    onSurfaceVariant = Color.Black,
    outline = Color.Black,
)

@Composable
fun DailyTodoTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = EinkColors, content = content)
}

/** Click with no ripple/animation — better for e-ink (no ghosting flashes). */
@Composable
fun Modifier.noRippleClickable(onClick: () -> Unit): Modifier {
    val source = remember { MutableInteractionSource() }
    return this.clickable(interactionSource = source, indication = null, onClick = onClick)
}
