package com.example.icepenguin

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.io.InputStream

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { MaterialTheme { IcePenguinScreen() } }
    }
}

@Composable
fun IcePenguinScreen() {
    val context = LocalContext.current
    var selectedBitmap by remember { mutableStateOf<Bitmap?>(null) }
    var history by remember { mutableStateOf(listOf<Bitmap>()) }
    var containerSize by remember { mutableStateOf(IntSize.Zero) }
    var startPoint by remember { mutableStateOf(Offset.Zero) }
    var currentRect by remember { mutableStateOf(Rect.Zero) }
    var isDragging by remember { mutableStateOf(false) }

    val pickerLauncher = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? ->
        uri?.let {
            val inputStream: InputStream? = context.contentResolver.openInputStream(it)
            val bitmap = BitmapFactory.decodeStream(inputStream)
            selectedBitmap = bitmap?.copy(Bitmap.Config.ARGB_8888, true)
            history = emptyList()
            currentRect = Rect.Zero
        }
    }

    Column(modifier = Modifier.fillMaxSize().background(Color(0xFFEFEFEF))) {
        Row(modifier = Modifier.fillMaxWidth().padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
            RetroButton("PHOTOS") { pickerLauncher.launch("image/*") }
            Spacer(modifier = Modifier.width(8.dp))
            RetroButton("FILES") { pickerLauncher.launch("*/*") }
            Spacer(modifier = Modifier.weight(1f))
            Text("ICE PENGUIN v1.0", fontFamily = FontFamily.Monospace, fontSize = 10.sp, fontWeight = FontWeight.Bold)
        }

        Box(modifier = Modifier.fillMaxWidth().height(1.dp).background(Color.Black))

        Box(
            modifier = Modifier.weight(1f).fillMaxWidth().onGloballyPositioned { containerSize = it.size }
                .pointerInput(Unit) {
                    detectDragGestures(
                        onDragStart = { startPoint = it; isDragging = true },
                        onDrag = { change, _ ->
                            val endPoint = change.position
                            currentRect = Rect(
                                minOf(startPoint.x, endPoint.x), minOf(startPoint.y, endPoint.y),
                                maxOf(startPoint.x, endPoint.x), maxOf(startPoint.y, endPoint.y)
                            )
                        },
                        onDragEnd = { isDragging = false }
                    )
                },
            contentAlignment = Alignment.Center
        ) {
            selectedBitmap?.let { bitmap ->
                androidx.compose.foundation.Image(
                    bitmap = bitmap.asImageBitmap(), contentDescription = null,
                    modifier = Modifier.fillMaxSize(), contentScale = ContentScale.Fit
                )
                if (isDragging || !currentRect.isEmpty) {
                    Canvas(modifier = Modifier.fillMaxSize()) {
                        drawRect(color = Color.Black.copy(alpha = 0.3f), topLeft = currentRect.topLeft, size = currentRect.size)
                        drawRect(color = Color.Red, topLeft = currentRect.topLeft, size = currentRect.size, 
                            style = androidx.compose.ui.graphics.drawscope.Stroke(width = 2.dp.toPx()))
                    }
                }
            } ?: Text("NO MEDIA", fontFamily = FontFamily.Monospace, color = Color.Gray)
        }

        Box(modifier = Modifier.fillMaxWidth().height(1.dp).background(Color.Black))

        Row(modifier = Modifier.fillMaxWidth().padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
            RetroButton("REDACT", Color.Black, Color.White, enabled = !currentRect.isEmpty && selectedBitmap != null) {
                selectedBitmap?.let { img ->
                    val mutableBitmap = img.copy(Bitmap.Config.ARGB_8888, true)
                    val canvas = Canvas(mutableBitmap)
                    val paint = Paint().apply { color = android.graphics.Color.BLACK }
                    
                    val scaleX = img.width.toFloat() / containerSize.width.toFloat()
                    val scaleY = img.height.toFloat() / containerSize.height.toFloat()
                    val scale = maxOf(scaleX, scaleY)
                    
                    val offsetX = (containerSize.width - (img.width / scale)) / 2
                    val offsetY = (containerSize.height - (img.height / scale)) / 2
                    
                    val pixelRect = android.graphics.Rect(
                        ((currentRect.left - offsetX) * scale).toInt(),
                        ((currentRect.top - offsetY) * scale).toInt(),
                        ((currentRect.right - offsetX) * scale).toInt(),
                        ((currentRect.bottom - offsetY) * scale).toInt()
                    )
                    
                    canvas.drawRect(pixelRect, paint)
                    history = history + img
                    selectedBitmap = mutableBitmap
                    currentRect = Rect.Zero
                }
            }
            Spacer(modifier = Modifier.width(8.dp))
            RetroButton("UNDO", enabled = history.isNotEmpty()) {
                selectedBitmap = history.last()
                history = history.dropLast(1)
            }
            Spacer(modifier = Modifier.weight(1f))
            IconButton(onClick = { }) {
                Icon(Icons.Default.Share, contentDescription = null, tint = Color.Black)
            }
        }
    }
}

@Composable
fun RetroButton(text: String, bgColor: Color = Color.White, txtColor: Color = Color.Black, enabled: Boolean = true, onClick: () -> Unit) {
    Button(
        onClick = onClick, enabled = enabled, shape = androidx.compose.ui.graphics.RectangleShape,
        colors = ButtonDefaults.buttonColors(containerColor = bgColor, contentColor = txtColor, disabledContainerColor = Color.LightGray),
        modifier = Modifier.border(2.dp, Color.Black),
        contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp)
    ) {
        Text(text, fontFamily = FontFamily.Monospace, fontSize = 11.sp, fontWeight = FontWeight.Bold)
    }
}
