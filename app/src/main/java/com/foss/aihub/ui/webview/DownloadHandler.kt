package com.foss.aihub.ui.webview

import android.content.ContentValues
import android.content.Context
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Log
import android.webkit.CookieManager
import android.webkit.URLUtil
import android.webkit.WebView
import android.widget.Toast
import com.foss.aihub.R
import com.foss.aihub.utils.readAssetsFile
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

object DownloadHandler {
    fun handleDownload(
        webView: WebView,
        url: String,
        userAgent: String,
        contentDisposition: String?,
        mimeType: String?
    ) {
        when {
            url.startsWith("blob:") -> {
                val script =
                    webView.context.readAssetsFile("forceDownload.js").replace("<url>", url)
                        .trimIndent()

                webView.evaluateJavascript(script) { result ->
                    Log.d("WebView", "Blob download trigger result: $result")
                }

                Toast.makeText(
                    webView.context,
                    webView.context.getString(R.string.msg_processing_blob),
                    Toast.LENGTH_SHORT
                ).show()
            }

            url.startsWith("http") -> {
                downloadFileToDownloads(
                    webView.context, url, userAgent, contentDisposition, mimeType
                )
            }

            else -> {
                Toast.makeText(
                    webView.context,
                    webView.context.getString(R.string.msg_unsupported_scheme),
                    Toast.LENGTH_SHORT
                ).show()
            }
        }
    }

    private fun downloadFileToDownloads(
        context: Context,
        url: String,
        userAgent: String,
        contentDisposition: String?,
        mimeType: String?
    ) {
        CoroutineScope(Dispatchers.Main).launch {
            try {
                val fileName = URLUtil.guessFileName(url, contentDisposition, mimeType)
                val sanitized = fileName.replace(Regex("[^a-zA-Z0-9._-]"), "_")

                Toast.makeText(
                    context,
                    context.getString(R.string.msg_downloading, sanitized),
                    Toast.LENGTH_SHORT
                ).show()

                val bytes = downloadFileWithCookies(url, userAgent)

                saveToDownloadsFolder(
                    context = context,
                    fileName = sanitized,
                    mimeType = mimeType ?: "application/octet-stream",
                    data = bytes
                )

                Toast.makeText(
                    context,
                    context.getString(R.string.msg_dowload_complete, sanitized),
                    Toast.LENGTH_LONG
                ).show()
            } catch (e: Exception) {
                e.printStackTrace()
                Toast.makeText(
                    context,
                    context.getString(R.string.msg_download_failed),
                    Toast.LENGTH_SHORT
                ).show()
            }
        }
    }

    private suspend fun downloadFileWithCookies(url: String, userAgent: String): ByteArray =
        withContext(Dispatchers.IO) {
            val connection = URL(url).openConnection() as HttpURLConnection
            try {
                connection.requestMethod = "GET"
                connection.setRequestProperty("User-Agent", userAgent)

                val cookies = CookieManager.getInstance().getCookie(url)
                if (!cookies.isNullOrBlank()) {
                    connection.setRequestProperty("Cookie", cookies)
                }

                connection.instanceFollowRedirects = true
                connection.connect()

                val responseCode = connection.responseCode
                if (responseCode != HttpURLConnection.HTTP_OK) {
                    throw Exception("Server returned code $responseCode")
                }

                val inputStream = connection.inputStream
                val byteArrayOutputStream = ByteArrayOutputStream()

                val buffer = ByteArray(8192)
                var bytesRead: Int
                val contentLength = connection.contentLength.toLong()

                while (inputStream.read(buffer).also { bytesRead = it } != -1) {
                    byteArrayOutputStream.write(buffer, 0, bytesRead)
                    if (contentLength > 0) {
                        val progress = (byteArrayOutputStream.size() * 100 / contentLength).toInt()
                        Log.d("Download", "Progress: $progress%")
                    }
                }
                byteArrayOutputStream.toByteArray()
            } finally {
                connection.disconnect()
            }
        }

    private suspend fun saveToDownloadsFolder(
        context: Context, fileName: String, mimeType: String, data: ByteArray
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

                    Log.d("Download", "File saved successfully (API 29+): $safeName at $itemUri")
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
                    Log.d("Download", "File scanned successfully: $path → $uri")
                }

                Log.d(
                    "Download",
                    "File saved successfully (Legacy API 26-28): ${finalFile.absolutePath}"
                )
            }
        }
    }
}