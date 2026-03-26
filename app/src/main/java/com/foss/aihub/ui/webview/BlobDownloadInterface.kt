package com.foss.aihub.ui.webview

import android.content.ContentValues
import android.content.Context
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Log
import android.webkit.JavascriptInterface
import android.widget.Toast
import androidx.annotation.RequiresApi
import com.foss.aihub.R
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.util.Base64

class BlobDownloadInterface(private val context: Context) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    @RequiresApi(Build.VERSION_CODES.Q)
    @JavascriptInterface
    fun saveBase64File(base64: String, fileName: String, mimeType: String) {
        Log.d(
            "BlobDownload",
            "saveBase64File called - fileName: $fileName, mimeType: $mimeType, base64 length: ${base64.length}"
        )

        scope.launch {
            try {
                val decodedBytes = decodeBase64(base64)
                Log.d("BlobDownload", "Decoded bytes: ${decodedBytes.size}")

                saveToDownloads(
                    fileName, mimeType.ifEmpty { "application/octet-stream" }, decodedBytes
                )

                withContext(Dispatchers.Main) {
                    Toast.makeText(
                        context,
                        context.getString(R.string.msg_saved, fileName),
                        Toast.LENGTH_SHORT
                    ).show()
                }
            } catch (e: Exception) {
                Log.e("BlobDownload", "Failed to save blob", e)
                withContext(Dispatchers.Main) {
                    Toast.makeText(
                        context,
                        context.getString(R.string.msg_fail_to_save_blob),
                        Toast.LENGTH_SHORT
                    ).show()
                }
            }
        }
    }

    @JavascriptInterface
    fun downloadFailed(message: String) {
        Log.e("BlobDownload", "Download failed: $message")
        scope.launch(Dispatchers.Main) {
            Toast.makeText(
                context,
                context.getString(R.string.msg_download_failed),
                Toast.LENGTH_SHORT
            ).show()
        }
    }

    private fun decodeBase64(base64: String): ByteArray {
        val cleanBase64 = if (base64.contains(",")) {
            base64.substringAfter(",")
        } else {
            base64
        }
        return Base64.getDecoder().decode(cleanBase64)
    }

    private suspend fun saveToDownloads(
        fileName: String, mimeType: String, data: ByteArray
    ) {
        withContext(Dispatchers.IO) {
            val resolver = context.contentResolver
            val safeName = fileName.replace(Regex("[^a-zA-Z0-9._-]"), "_")

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val contentValues = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, safeName)
                    put(MediaStore.Downloads.MIME_TYPE, mimeType)
                    put(MediaStore.Downloads.IS_PENDING, 1)
                    put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                }

                val collection = MediaStore.Downloads.EXTERNAL_CONTENT_URI
                val itemUri = resolver.insert(collection, contentValues)
                    ?: throw Exception("Failed to create MediaStore entry")

                try {
                    resolver.openOutputStream(itemUri)?.use { outputStream ->
                        outputStream.write(data)
                        outputStream.flush()
                    } ?: throw Exception("Failed to open output stream")


                    val updateValues = ContentValues().apply {
                        put(MediaStore.Downloads.IS_PENDING, 0)
                    }
                    resolver.update(itemUri, updateValues, null, null)

                    Log.d("BlobDownload", "File saved successfully (API 29+): $safeName")
                } catch (e: Exception) {
                    resolver.delete(itemUri, null, null)
                    throw e
                }
            } else {
                val downloadsDir =
                    Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                var finalFile = File(downloadsDir, safeName)

                var counter = 1
                while (finalFile.exists()) {
                    val nameWithoutExt = safeName.substringBeforeLast(".", safeName)
                    val ext = safeName.substringAfterLast(".", "")
                    val newName = if (ext.isNotEmpty()) "${nameWithoutExt}_$counter.$ext"
                    else "${nameWithoutExt}_$counter"

                    finalFile = File(downloadsDir, newName)
                    counter++
                }

                downloadsDir.mkdirs()

                finalFile.outputStream().use { it.write(data) }

                MediaScannerConnection.scanFile(
                    context, arrayOf(finalFile.absolutePath), arrayOf(mimeType)
                ) { path, uri ->
                    Log.d("BlobDownload", "File scanned: $path → $uri")
                }

                Log.d(
                    "BlobDownload", "File saved successfully (Legacy API 26-28): ${finalFile.name}"
                )
            }
        }
    }
}